import Flutter
import UIKit

#if canImport(AppIntents)
import AppIntents
#endif

// MARK: - App Delegate

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Le provider (défini dans QuickPanel.swift) référence le snippet iOS 26.
    if #available(iOS 26.0, *) {
      ShortistShortcuts.updateAppShortcutParameters()
    }
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
      switch call.method {

      case "openAccessibility":
        // Deep-link vers les réglages Accessibilité
        if let url = URL(string: "App-prefs:Accessibility") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)

      case "minimizeApp":
        // Renvoie l'app en arrière-plan : l'utilisateur retrouve l'écran
        // d'accueil de l'iPhone quand il ferme la petite fenêtre.
        // ⚠️ Sélecteur non documenté par Apple : à surveiller lors de la review App Store.
        DispatchQueue.main.async {
          UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        }
        result(nil)

      case "checkPendingTrigger":
        // Vérifie si un tap-back s'est produit avant que Flutter soit prêt (cold start)
        if UserDefaults.standard.bool(forKey: "shortist_tap_pending") {
          UserDefaults.standard.removeObject(forKey: "shortist_tap_pending")
          channel.invokeMethod("trigger", arguments: nil)
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

// MARK: - Notification name partagée entre AppIntent et SceneDelegate

extension Notification.Name {
  static let shortistTapTrigger = Notification.Name("com.gnemmialex.shortist.tapTrigger")
}

// L'ancien `OpenShortistIntent` (openAppWhenRun = true, qui ouvrait l'app en
// plein écran) a été remplacé par le panneau snippet iOS 26 : voir
// QuickPanel.swift (OpenPanelIntent + PanelSnippetIntent + ShortistShortcuts).
// Le trigger `.shortistTapTrigger` reste utilisé par l'URL scheme
// shortist://tapback (SceneDelegate) et le canal Flutter ci-dessus.
