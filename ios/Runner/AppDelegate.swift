import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShortistPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "com.gnemmialex.tapbacknote/tapback",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "openAccessibility" {
        if let url = URL(string: "App-prefs:Accessibility") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
