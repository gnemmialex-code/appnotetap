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
    if #available(iOS 16.0, *) {
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

// MARK: - App Intents (iOS 16+)
// S'enregistre automatiquement dans la liste Touche arrière → plus besoin de créer un Raccourci manuellement.

#if canImport(AppIntents)

@available(iOS 16.0, *)
struct OpenShortistIntent: AppIntent {
  static var title: LocalizedStringResource = "Ouvrir Shortist"
  static var description = IntentDescription("Ouvre le panneau de commande Shortist")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    // Marque le flag AVANT de poster la notif (cold start safety)
    UserDefaults.standard.set(true, forKey: "shortist_tap_pending")
    NotificationCenter.default.post(name: .shortistTapTrigger, object: nil)
    return .result()
  }
}

@available(iOS 16.0, *)
struct ShortistShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenShortistIntent(),
      phrases: ["Ouvrir \(.applicationName)"],
      shortTitle: "Ouvrir Shortist",
      systemImageName: "bolt.fill"
    )
  }
}

#endif
