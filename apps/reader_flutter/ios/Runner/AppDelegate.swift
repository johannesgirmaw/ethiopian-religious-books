import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var contentProtection: ContentProtectionHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    contentProtection = ContentProtectionHandler(window: window)

    let channel = FlutterMethodChannel(
      name: "com.ethiopianreligious.reader/content_protection",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSecureMode" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
      self?.contentProtection?.setSecureMode(enabled)
      result(nil)
    }
  }
}
