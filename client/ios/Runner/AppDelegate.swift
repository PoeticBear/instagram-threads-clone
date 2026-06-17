import Flutter
import UIKit
import CoreTelephony

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 持有 CTCellularData 实例避免 notifier 被释放；缓存最新权限状态供 Flutter 查询。
  // 初始值 "unknown" 对应 CTCellularData 还没拿到首次回调的窗口期。
  private var cellularData: CTCellularData?
  private var lastKnownRestrictionState: String = "unknown"

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

    // ── NetworkPermissionChannel ──
    // 暴露 CTCellularData 蜂窝数据权限状态给 Flutter，用于识别 iOS 首次启动
    // 「允许使用无线局域网和蜂窝网络」系统弹窗未决的场景：
    // 此时所有网络请求会被系统拦截，但 NetworkErrorNotifier 不应误弹提示。
    // 必须在 didFinishLaunchingWithOptions 中尽早初始化 CTCellularData，
    // 让 notifier 尽快拿到首次回调（否则 Flutter 查询时仍是 unknown）。
    let cd = CTCellularData()
    cd.cellularDataRestrictionDidUpdateNotifier = { [weak self] state in
      switch state {
      case .restricted:    self?.lastKnownRestrictionState = "restricted"
      case .notRestricted: self?.lastKnownRestrictionState = "notRestricted"
      default:             self?.lastKnownRestrictionState = "unknown"
      }
    }
    self.cellularData = cd

    if let registrar = self.registrar(forPlugin: "NetworkPermissionChannel") {
      let channel = FlutterMethodChannel(
        name: "com.yt.threads/network_permission",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "getPermissionStatus":
          result(self?.lastKnownRestrictionState ?? "unknown")
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
