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
