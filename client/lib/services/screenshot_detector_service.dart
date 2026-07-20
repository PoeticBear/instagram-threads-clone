import 'package:flutter/services.dart';

/// 监听 iOS 系统级截屏事件，转触发回调。
///
/// 原生侧（`ios/Runner/AppDelegate.swift` 的 `ScreenshotChannel`）注册了
/// `UIApplication.userDidTakeScreenshotNotification` 观察者：用户按
/// 「电源 + 音量上」截屏后，原生通过 MethodChannel 以 native → flutter 方向
/// 推送 `onScreenshotTaken` 事件，本服务在此事件上触发 [onScreenshot]。
///
/// 防抖策略（避免一次连截叠一摞弹窗）：
/// 1. 表单已展开期间（[markSheetShowing] = true）忽略后续事件；
/// 2. 距上次触发不足 [_debounceWindow]（5s）的事件忽略。
///
/// 仅 iOS：Android 端不注册该 channel，自然收不到事件、不触发。
class ScreenshotDetectorService {
  ScreenshotDetectorService._();
  static final ScreenshotDetectorService instance =
      ScreenshotDetectorService._();

  static const _channel = MethodChannel('com.yt.threads/screenshot');

  /// 截屏事件回调。由 main.dart 挂载为「弹出 Bug 反馈表单」。
  VoidCallback? onScreenshot;

  bool _sheetShowing = false;
  DateTime? _lastTriggeredAt;

  /// 最近一次截屏事件的触发时刻。
  ///
  /// 表单据此判定相册里哪张图是「本次」截屏 —— iOS 截屏通知早于截图写入
  /// 相册，需轮询取 `createDateTime ≥ 此时刻` 的图，否则会取到截屏之前
  /// 的那张旧图。
  DateTime? get lastTriggeredAt => _lastTriggeredAt;

  /// 两次截屏触发之间至少间隔此时长，否则视为连截、忽略。
  static const _debounceWindow = Duration(seconds: 5);

  /// 注册原生事件监听。幂等，重复调用只会覆盖 handler。
  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshotTaken') {
        _handleScreenshot();
      }
      return null;
    });
  }

  void _handleScreenshot() {
    if (_sheetShowing) return; // 表单已开 → 不重弹
    final now = DateTime.now();
    if (_lastTriggeredAt != null &&
        now.difference(_lastTriggeredAt!) < _debounceWindow) {
      return; // 连截 → 忽略
    }
    _lastTriggeredAt = now;
    onScreenshot?.call();
  }

  /// 表单打开 / 关闭时调用，用于抑制重复弹窗。
  void markSheetShowing(bool showing) => _sheetShowing = showing;
}
