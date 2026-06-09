import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  private weak var mainScene: UIScene?

  // MARK: - Lifecycle

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    mainScene = scene

    // Écoute les triggers AppIntent (iOS 16+) et URL scheme
    NotificationCenter.default.addObserver(
      forName: .shortistTapTrigger,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      UserDefaults.standard.removeObject(forKey: "shortist_tap_pending")
      self?.fireTrigger(delay: 0.1)
    }

    // Cold start via URL scheme (shortist://tapback)
    if let url = connectionOptions.urlContexts.first?.url {
      handleURL(url, delay: 0.5)
    }
  }

  // Warm resume via URL scheme
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url {
      handleURL(url, delay: 0)
    }
  }

  // MARK: - Helpers

  private func handleURL(_ url: URL, delay: TimeInterval) {
    guard url.scheme == "shortist", url.host == "tapback" else { return }
    fireTrigger(delay: delay)
  }

  private func fireTrigger(delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard
        let windowScene = self?.mainScene as? UIWindowScene,
        let controller = windowScene.windows.first?.rootViewController as? FlutterViewController
      else { return }
      FlutterMethodChannel(
        name: "com.gnemmialex.tapbacknote/tapback",
        binaryMessenger: controller.binaryMessenger
      ).invokeMethod("trigger", arguments: nil)
    }
  }
}
