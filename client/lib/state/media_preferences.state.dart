import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threads/widget/video_player_pool.dart';

/// 纯客户端的多媒体偏好（不与任何服务端接口同步）。
class MediaPreferences extends ChangeNotifier {
  static const String _kFeedVideoAutoPlay = 'feed_video_auto_play';

  final SharedPreferences _prefs;

  /// 0=关闭，1=开启（默认）
  int _feedVideoAutoPlay = 1;
  int get feedVideoAutoPlay => _feedVideoAutoPlay;
  bool get isFeedVideoAutoPlayEnabled => _feedVideoAutoPlay == 1;

  MediaPreferences(this._prefs) {
    _load();
  }

  void _load() {
    _feedVideoAutoPlay = _prefs.getInt(_kFeedVideoAutoPlay) ?? 1;
    VideoPlayerPool.setAutoPlayEnabled(_feedVideoAutoPlay == 1);
  }

  /// [value] 0=关，1=开
  Future<void> setFeedVideoAutoPlay(int value) async {
    if (value != 0 && value != 1) return;
    if (value == _feedVideoAutoPlay) return;
    _feedVideoAutoPlay = value;
    notifyListeners();
    await _prefs.setInt(_kFeedVideoAutoPlay, value);
    VideoPlayerPool.setAutoPlayEnabled(value == 1);
  }
}
