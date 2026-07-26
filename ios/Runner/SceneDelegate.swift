import Flutter
import UIKit

// Engine is created and run here (rather than left to Flutter's implicit,
// storyboard-triggered creation) to work around a Flutter engine race where
// FlutterViewController.viewDidLoad can fire before the implicit engine's
// platformTaskRunner is attached, crashing on launch on ProMotion devices.
// https://github.com/flutter/flutter/issues/183900
class SceneDelegate: FlutterSceneDelegate {
  let flutterEngine = FlutterEngine(name: "main engine")

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)

    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    self.registerSceneLifeCycle(with: flutterEngine)

    let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    window?.rootViewController = flutterViewController
    window?.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
