import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // SceneDelegate 模式下，application(_:didFinishLaunchingWithOptions:) 阶段
    // window 还不存在；不能依赖 window?.rootViewController 拿 messenger。
    // 改用 registrar(forPlugin:)，内部会拿到 implicit FlutterEngine 的
    // binaryMessenger —— 与 FlutterSceneDelegate 创建的 FlutterViewController
    // 共用同一个 engine，所以 Dart 端 invokeMethod 时能命中 handler。
    if let registrar = self.registrar(forPlugin: "AppIconChannel") {
      let channel = FlutterMethodChannel(
        name: "com.yt.threads/app_icon",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "supportsAlternateIcons":
          result(UIApplication.shared.supportsAlternateIcons)
        case "getAlternateIconName":
          result(UIApplication.shared.alternateIconName)
        case "setAlternateIconName":
          guard let args = call.arguments as? [String: Any],
                let name = args["name"] as? String? else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "name (String?) required",
                                details: nil))
            return
          }
          UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
              result(FlutterError(code: "ICON_SET_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
              result(nil)
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
