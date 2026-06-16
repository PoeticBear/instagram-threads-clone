import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 帖子卡片媒体布局模式偏好（纯客户端，不与服务端同步）
class MediaLayoutPreferences extends ChangeNotifier {
  static const String _kFeedMediaLayoutMode = 'feed_media_layout_mode';

  /// 0 = 九宫格（默认，行为不变）；1 = 单行水平滚动
  static const int layoutGrid = 0;
  static const int layoutHorizontal = 1;

  final SharedPreferences _prefs;

  int _feedMediaLayoutMode = layoutGrid;
  int get feedMediaLayoutMode => _feedMediaLayoutMode;
  bool get isHorizontalLayout => _feedMediaLayoutMode == layoutHorizontal;
  bool get isGridLayout => _feedMediaLayoutMode == layoutGrid;

  MediaLayoutPreferences(this._prefs) {
    _load();
  }

  void _load() {
    final stored = _prefs.getInt(_kFeedMediaLayoutMode);
    _feedMediaLayoutMode =
        (stored == layoutHorizontal) ? layoutHorizontal : layoutGrid;
  }

  /// [value] 必须是 [layoutGrid] 或 [layoutHorizontal]，其它值忽略
  Future<void> setFeedMediaLayoutMode(int value) async {
    if (value != layoutGrid && value != layoutHorizontal) return;
    if (value == _feedMediaLayoutMode) return;
    _feedMediaLayoutMode = value;
    notifyListeners();
    await _prefs.setInt(_kFeedMediaLayoutMode, value);
  }
}
