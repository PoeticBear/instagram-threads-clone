import 'package:flutter/material.dart';

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
  static void showNetworkError() => show('网络似乎不太顺畅，请稍后再试');

  /// Friendly message for server-side issues.
  static void showServerError() => show('服务暂时不可用，请稍后再试');

  /// Friendly message for request timeout.
  static void showTimeoutError() => show('请求超时，请稍后再试');
}
