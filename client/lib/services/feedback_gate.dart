import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bug 反馈功能（内部测试）的编译期总开关。
///
/// 发 TestFlight 时带 `--dart-define=FEEDBACK_ENABLED=true`；
/// 发 App Store 正式包时**不带**（默认 false）。在 main.dart 用
/// `if (kDebugMode || feedbackCompileEnabled)` 包裹挂载逻辑，App Store
/// 包里两者皆为编译期 false，整块被 AOT tree-shake，反馈模块（Detector /
/// Service / Sheet）连同引用被物理剔除，不出现在产物中。
const bool feedbackCompileEnabled =
    bool.fromEnvironment('FEEDBACK_ENABLED', defaultValue: false);

/// 运行时隔离判定 —— 双保险的第二层。
///
/// 即便编译期开关为 true（TestFlight 包），也用 sandboxReceipt 二次确认
/// 当前是 TestFlight 构建而非 App Store 正式包，防止发版脚本误带 define
/// 导致线上包误触发。
///
/// 原生侧见 `ios/Runner/AppDelegate.swift` 的 BuildConfigChannel。
class FeedbackGate {
  FeedbackGate._();
  static final FeedbackGate instance = FeedbackGate._();

  static const _channel = MethodChannel('com.yt.threads/build_config');

  bool? _isTestFlight;

  /// 预取 sandboxReceipt 状态并缓存。幂等。
  Future<void> preload() async {
    if (_isTestFlight != null) return;
    try {
      _isTestFlight =
          await _channel.invokeMethod<bool>('isTestFlightBuild') ?? false;
    } on PlatformException {
      _isTestFlight = false;
    }
  }

  /// 当前构建是否应启用 Bug 反馈。
  ///
  /// - Debug（`flutter run`）：直接放行，省一次 channel 往返，便于开发验证。
  /// - Release：要求编译期开关 [feedbackCompileEnabled] **且** sandbox receipt
  ///   判定为 TestFlight；任一不满足返回 false。
  Future<bool> isReady() async {
    if (kDebugMode) return true;
    if (!feedbackCompileEnabled) return false;
    await preload();
    return _isTestFlight ?? false;
  }
}
