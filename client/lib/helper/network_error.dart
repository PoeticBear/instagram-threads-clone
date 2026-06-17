import 'package:flutter/material.dart';
import 'package:threads/services/network_permission_service.dart';

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
  /// 异步方法，调用方保持 fire-and-forget 即可（如
  /// `NetworkErrorNotifier.showNetworkError();`）。
  static Future<void> showNetworkError() async {
    if (await NetworkPermissionService.isNetworkPermissionUndetermined()) {
      return;
    }
    show('网络似乎不太顺畅，请稍后再试');
  }

  /// Friendly message for server-side issues.
  static void showServerError() => show('服务暂时不可用，请稍后再试');

  /// Friendly message for request timeout.
  static void showTimeoutError() => show('请求超时，请稍后再试');
}
