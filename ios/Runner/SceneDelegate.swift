import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Cold start — URL reçue avant que Flutter soit prêt (délai 0.5 s)
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      handleURL(url, scene: scene, delay: 0.5)
    }
  }

  // Warm resume — app déjà en mémoire
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url {
      handleURL(url, scene: scene, delay: 0)
    }
  }

  private func handleURL(_ url: URL, scene: UIScene, delay: TimeInterval) {
    guard url.scheme == "shortist", url.host == "tapback" else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak scene] in
      guard
        let windowScene = scene as? UIWindowScene,
        let controller = windowScene.windows.first?.rootViewController as? FlutterViewController
      else { return }
      FlutterMethodChannel(
        name: "com.gnemmialex.tapbacknote/tapback",
        binaryMessenger: controller.binaryMessenger
      ).invokeMethod("trigger", arguments: nil)
    }
  }
}
