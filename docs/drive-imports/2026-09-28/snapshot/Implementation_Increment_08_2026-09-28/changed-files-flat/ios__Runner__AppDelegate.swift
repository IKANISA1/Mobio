import Security
import Flutter
import UIKit
import ContactsUI
import PhotosUI
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let discoveryPicker = BioPayDiscoveryPicker()
  private var pendingPhotoSaveResults: [FlutterResult] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SecureSessionChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
    discoveryPicker.register(messenger: engineBridge.applicationRegistrar.messenger())
    registerBioPayQrExportChannel(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func registerBioPayQrExportChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "rw.mobi.app/biopay_qr_export",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "savePngToGallery" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let data = arguments["bytes"] as? FlutterStandardTypedData,
        let image = UIImage(data: data.data)
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "PNG bytes are required.",
            details: nil
          )
        )
        return
      }

      self?.pendingPhotoSaveResults.append(result)
      UIImageWriteToSavedPhotosAlbum(
        image,
        self,
        #selector(AppDelegate.image(_:didFinishSavingWithError:contextInfo:)),
        nil
      )
    }
  }

  @objc private func image(
    _ image: UIImage,
    didFinishSavingWithError error: Error?,
    contextInfo: UnsafeRawPointer
  ) {
    guard !pendingPhotoSaveResults.isEmpty else { return }
    let result = pendingPhotoSaveResults.removeFirst()
    if let error {
      result(
        FlutterError(
          code: "BIOPAY_QR_SAVE_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }
    result(true)
  }
}


// Native selection discloses only the specific phone property/image chosen.
private final class BioPayDiscoveryPicker: NSObject, CNContactPickerDelegate, PHPickerViewControllerDelegate {
  private var pending: FlutterResult?
  private var channel: FlutterMethodChannel?

  func register(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "rw.mobi.app/biopay_discovery", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      guard self.pending == nil else {
        result(FlutterError(code: "PICKER_BUSY", message: "Finish the current selection.", details: nil)); return
      }
      guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
            var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "PICKER_UNAVAILABLE", message: "Enter receiving details to continue.", details: nil)); return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      if call.method == "pickPhone" {
        self.pending = result
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
        presenter.present(picker, animated: true)
      } else if call.method == "pickQrImage" {
        self.pending = result
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
      } else { result(FlutterMethodNotImplemented) }
    }
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) { finish(nil) }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    guard let phone = contactProperty.value as? CNPhoneNumber else { finish(nil); return }
    let label = CNContactFormatter.string(from: contactProperty.contact, style: .fullName) ?? ""
    finish(["phone": phone.stringValue, "label": label])
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { finish(nil); return }
    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
      do {
        guard let url else { throw NSError(domain: "BioPay", code: 1) }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= 10 * 1024 * 1024 else { throw NSError(domain: "BioPay", code: 2) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("biopay-qr-import")
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
        try FileManager.default.copyItem(at: url, to: copy)
        DispatchQueue.main.async { self?.finish(copy.path) }
      } catch {
        DispatchQueue.main.async {
          self?.finish(FlutterError(code: "IMAGE_UNAVAILABLE", message: "Choose a QR image smaller than 10 MB.", details: nil))
        }
      }
    }
  }

  private func finish(_ value: Any?) {
    let result = pending
    pending = nil
    result?(value)
  }
}


// Kept in this already-built compilation unit: no generated project IDs or
// unregistered Swift files are needed. No Keychain sharing or sync is enabled.
private enum SecureSessionChannel {
  private static let queue = DispatchQueue(label: "rw.mobi.app.secure-session")
  private static let service = (Bundle.main.bundleIdentifier ?? "rw.mobi.app") + ".session.v1"
  private enum StoreFailure: Error { case unavailable }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "rw.mobi.app/secure_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard ["read", "write", "clear", "reset"].contains(call.method) else {
        result(FlutterMethodNotImplemented); return
      }
      guard let args = call.arguments as? [String: Any],
            let namespace = args["namespace"] as? String,
            namespace.utf8.count == 64,
            namespace.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
        result(FlutterError(code: "AUTH_STORAGE_ARGUMENT", message: "Invalid storage request.", details: nil)); return
      }
      let value = args["value"] as? String
      if call.method == "write" && (value == nil || value!.utf8.isEmpty || value!.utf8.count > 65536) {
        result(FlutterError(code: "AUTH_STORAGE_ARGUMENT", message: "Invalid session size.", details: nil)); return
      }
      queue.async {
        do {
          try ensureInstallation(namespace, forceReset: call.method == "reset")
          var answer: Any? = true
          switch call.method {
          case "read": answer = try read(namespace)
          case "write":
            let data = Data(value!.utf8)
            let attributes: [String: Any] = [
              kSecValueData as String: data,
              kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let update = SecItemUpdate(query(namespace) as CFDictionary, attributes as CFDictionary)
            if update == errSecItemNotFound {
              var insert = query(namespace)
              attributes.forEach { insert[$0.key] = $0.value }
              guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw StoreFailure.unavailable }
            } else if update != errSecSuccess { throw StoreFailure.unavailable }
            guard try read(namespace) == value else { throw StoreFailure.unavailable }
          default: try clear(namespace)
          }
          DispatchQueue.main.async { result(answer) }
        } catch {
          // Never stringify OS errors or persisted session contents.
          DispatchQueue.main.async {
            result(FlutterError(code: "AUTH_STORAGE_UNAVAILABLE",
              message: "Unlock this device and try again. Saved login could not be accessed safely.", details: nil))
          }
        }
      }
    }
  }

  private static func query(_ namespace: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: namespace,
     kSecAttrSynchronizable as String: false]
  }

  private static func read(_ namespace: String) throws -> String? {
    var request = query(namespace)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var response: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &response)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = response as? Data,
          !data.isEmpty, data.count <= 65536,
          let value = String(data: data, encoding: .utf8) else { throw StoreFailure.unavailable }
    return value
  }

  private static func clear(_ namespace: String) throws {
    let status = SecItemDelete(query(namespace) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreFailure.unavailable }
    guard try read(namespace) == nil else { throw StoreFailure.unavailable }
  }

  private static func ensureInstallation(_ namespace: String, forceReset: Bool = false) throws {
    let manager = FileManager.default
    var directory = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true).appendingPathComponent("MobioAuth", isDirectory: true)
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    var resources = URLResourceValues(); resources.isExcludedFromBackup = true
    try directory.setResourceValues(resources)
    var marker = directory.appendingPathComponent(namespace + ".install")
    if forceReset || !manager.fileExists(atPath: marker.path) {
      // Keychain items may survive app removal. A missing excluded installation
      // marker means a fresh install/restore, never implicit re-authentication.
      try clear(namespace)
      try Data("mobio-auth-install-v1".utf8).write(to: marker,
        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    try marker.setResourceValues(resources)
    guard try Data(contentsOf: marker) == Data("mobio-auth-install-v1".utf8) else {
      throw StoreFailure.unavailable
    }
  }
}
