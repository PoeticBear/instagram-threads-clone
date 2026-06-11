import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Feed 自动播放的 VideoPlayer 池（单例）。
///
/// 行为：
/// - 最多持有 [_maxCapacity] 个活跃 VideoPlayerController
/// - LRU 淘汰：超出容量时，淘汰最久未访问的
/// - 静音 + 循环
/// - acquire 不会自动播放，需要外部触发 [playVisible]
///
/// 用法：
/// ```dart
/// final pool = VideoPlayerPool.instance;
/// pool.acquire(postId, videoUrl);          // 滚动到可见时调
/// pool.release(postId);                    // 滑出屏幕时调
/// pool.pauseAll();                         // 跳转详情页前调
/// ```
class VideoPlayerPool {
  VideoPlayerPool._();
  static final VideoPlayerPool instance = VideoPlayerPool._();

  /// 池容量上限：同时最多 3 个活跃 controller
  static const int _maxCapacity = 3;

  /// 自动播放总开关（灰度用）。默认关闭，避免新功能影响线上指标。
  /// 调 [setAutoPlayEnabled] 动态控制。
  static bool _autoPlayEnabled = false;
  bool get autoPlayEnabled => _autoPlayEnabled;
  static void setAutoPlayEnabled(bool value) {
    _autoPlayEnabled = value;
    if (!value) {
      instance.pauseAll();
    }
  }

  /// key → controller。LRU 顺序：先入为「最久未访问」。
  final LinkedHashMap<String, VideoPlayerController> _pool = LinkedHashMap();
  bool _disposed = false;

  /// 池变更通知（用于驱动 UI 重建）。Feed 订阅这个值即可。
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void _bumpVersion() {
    version.value = (version.value + 1) & 0x7fffffff;
  }

  /// 获取/创建指定 key 的 controller。若 url 与现有不同，会先释放旧 controller。
  /// 注意：本方法**不**自动播放；外部在 isVisible==true 时调 [playVisible]。
  VideoPlayerController? acquire(String key, String url) {
    if (_disposed) return null;
    if (url.isEmpty) return null;

    final existing = _pool[key];
    if (existing != null) {
      // 移动到末尾（最近访问）
      _pool.remove(key);
      _pool[key] = existing;
      return existing;
    }

    // 容量满：淘汰最久未访问的
    while (_pool.length >= _maxCapacity) {
      final oldestKey = _pool.keys.first;
      final oldCtrl = _pool.remove(oldestKey);
      _disposeController(oldCtrl);
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _pool[key] = controller;
    _bumpVersion();
    // 初始化在后台进行；外部等待 [controller.value.isInitialized]
    controller.initialize().then((_) {
      controller.setVolume(0);
      controller.setLooping(true);
      _bumpVersion();
    }).catchError((e) {
      developer.log('❌ VideoPlayerPool init failed: $e', name: 'VideoPlayerPool');
      // 失败则从池中移除
      _pool.remove(key);
      _bumpVersion();
    });
    return controller;
  }

  /// 释放指定 key（不调用 dispose，可能在可见性变化后再次 acquire）
  void release(String key) {
    final ctrl = _pool.remove(key);
    if (ctrl != null) _bumpVersion();
    _disposeController(ctrl);
  }

  /// 暂停所有 controller（不释放，保留预热的连接）
  void pauseAll() {
    for (final ctrl in _pool.values) {
      try {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
        }
      } catch (_) {}
    }
  }

  /// 播放指定 key（需要 autoPlayEnabled 且 controller 已 initialize）
  void playVisible(String key) {
    if (!_autoPlayEnabled) return;
    final ctrl = _pool[key];
    if (ctrl == null) return;
    if (!ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) return;
    try {
      ctrl.setVolume(0);
      ctrl.setLooping(true);
      ctrl.play();
    } catch (e) {
      developer.log('❌ VideoPlayerPool.play failed: $e', name: 'VideoPlayerPool');
    }
  }

  /// 暂停指定 key
  void pauseVisible(String key) {
    final ctrl = _pool[key];
    if (ctrl == null) return;
    try {
      if (ctrl.value.isPlaying) ctrl.pause();
    } catch (_) {}
  }

  VideoPlayerController? controllerOf(String key) => _pool[key];

  /// 全部释放 + dispose
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final all = _pool.values.toList();
    _pool.clear();
    _bumpVersion();
    for (final c in all) {
      _disposeController(c);
    }
  }

  void _disposeController(VideoPlayerController? c) {
    if (c == null) return;
    try {
      c.pause();
    } catch (_) {}
    c.dispose();
  }

  @visibleForTesting
  int get debugSize => _pool.length;
}
