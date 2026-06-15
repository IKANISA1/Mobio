import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pendingPhotoSaveResults: [FlutterResult] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
