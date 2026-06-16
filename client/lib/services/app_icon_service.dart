import 'package:flutter/services.dart';

/// 运行时应用图标切换的原生桥接。
///
/// 仅 iOS 实现了原生能力（`UIApplication.setAlternateIconName`），
/// Android 上方法通道未注册，Dart 端会捕获 `MissingPluginException`
/// 并走降级路径（[supportsAlternateIcons] 返回 `false`）。
class AppIconService {
  static const _channel = MethodChannel('com.yt.threads/app_icon');

  /// 当前平台是否支持运行时切换图标。
  ///
  /// - iOS 14+：返回 `true`（前提是 Info.plist 中已声明 `CFBundleAlternateIcons`
  ///   且 pbxproj 中设置了 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`）。
  /// - Android / 未注册通道：返回 `false`。
  static Future<bool> supportsAlternateIcons() async {
    try {
      return await _channel.invokeMethod<bool>('supportsAlternateIcons') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 当前正在使用的 alternate icon 名称，null 表示使用 primary。
  static Future<String?> getAlternateIconName() async {
    try {
      return await _channel.invokeMethod<String?>('getAlternateIconName');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 设置 alternate icon。
  ///
  /// - [name] = `'AppIcon-N'`（N ∈ 1..25）：切到对应预打包图标。
  /// - [name] = `null`：重置为 primary 图标。
  ///
  /// iOS 不会立刻生效，需要 app 切到后台后由系统应用。
  /// Android 端不会真正执行（无原生支持）。
  static Future<void> setAlternateIconName(String? name) async {
    try {
      await _channel.invokeMethod('setAlternateIconName', {'name': name});
    } on MissingPluginException {
      throw AppIconException('当前平台不支持切换应用图标');
    } on PlatformException catch (e) {
      throw AppIconException(e.message ?? '设置应用图标失败');
    }
  }
}

class AppIconException implements Exception {
  final String message;
  AppIconException(this.message);
  @override
  String toString() => message;
}
