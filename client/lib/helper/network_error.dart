import 'package:flutter/material.dart';
import 'package:threads/services/network_permission_service.dart';
import 'package:threads/network/api_exception.dart';

/// Global navigator key for showing error SnackBars from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Shows a brief, user-friendly error SnackBar.
/// Debounced: ignores calls while a previous error is still visible.
class NetworkErrorNotifier {
  static bool _isShowing = false;

  static void show(String message) {
    if (_isShowing) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isShowing = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ))
        .closed
        .then((_) => _isShowing = false);
  }

  /// Friendly message for network connectivity issues.
  ///
  /// iOS 首次启动「允许使用无线局域网和蜂窝网络」系统权限弹窗未决期间，
  /// 网络请求会被系统拦截而失败，但此时弹"网络似乎不太顺畅"是误导性的。
  /// 故先查权限状态：权限未决（restricted / unknown）时静默；用户已授权或
  /// 非 iOS 平台时正常显示。
  ///
  /// 调试阶段：透传 [e] 的 toString() 便于排错（DNS 失败 / 连接拒绝 / SSL 错误等）。
  ///
  /// 异步方法，调用方保持 fire-and-forget 即可（如
  /// `NetworkErrorNotifier.showNetworkError(e);`）。
  static Future<void> showNetworkError(Object e) async {
    if (await NetworkPermissionService.isNetworkPermissionUndetermined()) {
      return;
    }
    show('网络错误: $e');
  }

  /// Friendly message for server-side issues.
  ///
  /// 透传 [ServerException] 的真实 message + 业务 code，便于联调 / 线上排错。
  /// 仍保留「服务暂时不可用」前缀做用户友好提示。
  static void showServerError(ServerException e) {
    final code = e.statusCode;
    final codePart = code != null ? '[code=$code] ' : '';
    show('服务暂时不可用：$codePart${e.message}');
  }

  /// Friendly message for request timeout.
  ///
  /// 调试阶段：透传 [e] 的 toString()（如 "TimeoutException after 0:00:30.000000"）。
  static void showTimeoutError(Object e) => show('请求超时: $e');

  /// 统一 API 错误入口（UI 层 catch 块调用此方法即可）。
  ///
  /// 调试阶段：根据异常类型分发到对应 [showServerError] / `网络错误` 提示，
  /// 全部透传服务端 code + message 或原始 exception 信息。
  ///
  /// 用法：
  /// ```dart
  /// try {
  ///   await apiClient.get(...);
  /// } catch (e) {
  ///   NetworkErrorNotifier.showApiError(e);
  /// }
  /// ```
  static void showApiError(Object e) {
    if (e is ServerException) {
      showServerError(e);
    } else if (e is NetworkException) {
      show('网络错误: ${e.message}');
    } else {
      show('请求失败: $e');
    }
  }
}
