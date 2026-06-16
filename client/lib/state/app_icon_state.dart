import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_icon_service.dart';

/// 应用图标选中的全局状态。
///
/// - `selectedId = 0` 表示使用 primary `AppIcon`（即 `logo_01`），
/// - `selectedId = 1..25` 表示使用 `AppIcon-N` 对应的预打包 alternate。
///
/// 与 iOS 系统同步：构造时除了读 SharedPreferences，还会调用原生层
/// `getAlternateIconName()` 校正（用户在系统设置里手动改过也能感知到）。
class AppIconState extends ChangeNotifier {
  static const String _kSelectedId = 'app_icon_selected_id';
  static const int totalAlternates = 25;

  final SharedPreferences _prefs;

  int _selectedId = 0;
  bool _platformSupported = false;
  bool _loaded = false;

  AppIconState(this._prefs);

  int get selectedId => _selectedId;
  bool get platformSupported => _platformSupported;
  bool get isLoaded => _loaded;

  /// 当前选中对应 iOS 端的 alternate icon 名称（primary 时返回 `null`）。
  String? get currentAlternateName =>
      _selectedId == 0 ? null : 'AppIcon-$_selectedId';

  /// 初始化：同步读 SharedPreferences + 异步问原生层校正 + 异步检测平台能力。
  Future<void> load() async {
    _selectedId = _prefs.getInt(_kSelectedId) ?? 0;
    _loaded = true;
    notifyListeners();

    // 异步校正当前选中（不阻塞 UI 首次渲染）
    _platformSupported = await AppIconService.supportsAlternateIcons();
    if (_platformSupported) {
      final osName = await AppIconService.getAlternateIconName();
      // osName 形如 "AppIcon-3"；primary 时为 null
      if (osName == null && _selectedId != 0) {
        _selectedId = 0;
        await _prefs.setInt(_kSelectedId, 0);
      } else if (osName != null) {
        final m = RegExp(r'^AppIcon-(\d+)$').firstMatch(osName);
        if (m != null) {
          final osId = int.parse(m.group(1)!);
          if (osId != _selectedId) {
            _selectedId = osId;
            await _prefs.setInt(_kSelectedId, osId);
          }
        }
      }
    }
    notifyListeners();
  }

  /// 切换应用图标。`id = 0` 表示 primary，1..25 表示对应 alternate。
  Future<void> setIcon(int id) async {
    if (id < 0 || id > totalAlternates) return;
    if (id == _selectedId) return;

    if (_platformSupported) {
      await AppIconService.setAlternateIconName(
        id == 0 ? null : 'AppIcon-$id',
      );
    }
    _selectedId = id;
    await _prefs.setInt(_kSelectedId, id);
    notifyListeners();
  }
}
