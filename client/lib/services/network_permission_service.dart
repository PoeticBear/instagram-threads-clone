import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 首次启动网络权限弹窗（"允许使用无线局域网和蜂窝网络"）状态检测。
///
/// 仅 iOS 端通过 CTCellularData 暴露真实状态；Android / 原生未实现时一律
/// 返回 false，保留 [NetworkErrorNotifier] 原有"显示 SnackBar"的行为。
///
/// 原生实现见 `ios/Runner/AppDelegate.swift` 的 NetworkPermissionChannel。
class NetworkPermissionService {
  static const _channel = MethodChannel('com.yt.threads/network_permission');

  /// true 表示 iOS 当前权限未决（restricted / unknown），应静默网络错误提示；
  /// false 表示已授权（notRestricted）或非 iOS 平台，可正常提示。
  ///
  /// 选择 "unknown 也视为未决" 的原因：iOS 首次启动时 CTCellularData 实例
  /// 刚创建，notifier 异步回调尚未触发，此时 [restrictedState] 仍是 unknown，
  /// 这正是需要识别的"请求早于权限决定"窗口。
  static Future<bool> isNetworkPermissionUndetermined() async {
    if (!Platform.isIOS) return false;
    try {
      final status = await _channel.invokeMethod<String>('getPermissionStatus');
      // notRestricted → 用户已授权，正常显示
      // restricted / unknown / null → 静默
      return status != 'notRestricted';
    } on PlatformException {
      // 原生未实现 / Channel 失败 → 不过滤，保留原行为
      return false;
    } on MissingPluginException {
      // 原生 handler 未注册 → 不过滤
      return false;
    }
  }
}
