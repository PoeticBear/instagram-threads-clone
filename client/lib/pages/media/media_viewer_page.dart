import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:threads/model/post.module.dart';

/// 全屏媒体查看页面 — 支持图片（缩放）和视频（播放）
///
/// 视频按方向分流：
/// - 竖屏（ratio < 1）：cover 铺满全屏，沉浸式（忽略安全区）。
/// - 横屏 / 方形（ratio >= 1）：居中 contain，上下留黑；横屏（ratio >= 1.2）
///   右下角出现旋转按钮，可手动锁横屏铺满观看。
class MediaViewerPage extends StatefulWidget {
  final List<MediaItemModel> mediaItems;
  final int initialIndex;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _videoControllers = {};

  /// 是否处于手动锁定的横屏模式。
  bool _isLandscape = false;

  /// aspect ratio 达到该阈值才认为是「横屏视频」，显示旋转按钮。
  static const double _landscapeThreshold = 1.2;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initVideoControllers();
  }

  void _initVideoControllers() {
    for (int i = 0; i < widget.mediaItems.length; i++) {
      final item = widget.mediaItems[i];
      if (item.isVideo && item.url != null) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(item.url!));
        _videoControllers[i] = controller;
        controller.initialize().then((_) {
          if (mounted && i == _currentIndex) {
            controller.play();
            setState(() {});
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    // 离开页面兜底恢复全局竖屏锁，避免回到首页后仍可旋转。
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Pause previous video
    final prevController = _videoControllers[_currentIndex];
    if (prevController != null && prevController.value.isPlaying) {
      prevController.pause();
      prevController.seekTo(Duration.zero);
    }

    setState(() => _currentIndex = index);

    // Play new video
    final newController = _videoControllers[index];
    if (newController != null && newController.value.isInitialized) {
      newController.play();
    }

    // 横屏模式下切到非横屏视频（竖屏视频 / 图片）→ 自动回竖屏，否则竖屏内容在横屏页面里很难看。
    if (_isLandscape) {
      final ratio = newController?.value.aspectRatio;
      final isLandscapeVideo = newController != null &&
          newController.value.isInitialized &&
          ratio != null &&
          ratio >= _landscapeThreshold;
      if (!isLandscapeVideo) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        setState(() => _isLandscape = false);
      }
    }
  }

  /// 当前视频的 aspect ratio（未初始化 / 非视频时为 null）。
  double? _currentVideoRatio() {
    final controller = _videoControllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return null;
    return controller.value.aspectRatio;
  }

  /// 手动切换横屏 / 竖屏。
  void _toggleLandscape() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      setState(() => _isLandscape = false);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() => _isLandscape = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _currentVideoRatio();
    final canRotate = ratio != null && ratio >= _landscapeThreshold;
    // 锁在横屏时也保留按钮，确保有退出入口（防卡死）。
    final showRotate = canRotate || _isLandscape;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.mediaItems.length,
            itemBuilder: (context, index) {
              final item = widget.mediaItems[index];
              if (item.isVideo) {
                return _VideoViewerItem(
                  controller: _videoControllers[index],
                );
              }
              return _ImageViewerItem(url: item.url ?? '');
            },
          ),
          // 顶部浮层：渐变 + 关闭 / 计数（按钮本身走 SafeArea，不被刘海挡）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x88000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            CupertinoIcons.xmark,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.mediaItems.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 右下角旋转按钮（仅横屏视频可用 / 或已锁横屏时作退出入口）
          if (showRotate)
            Positioned(
              bottom: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _toggleLandscape,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _isLandscape
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 图片查看项 — 支持双指缩放/平移
class _ImageViewerItem extends StatelessWidget {
  final String url;

  const _ImageViewerItem({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

/// 视频播放项 — 自动播放 + 点击暂停/恢复
///
/// 按方向分流：竖屏 cover 铺满全屏；横屏 / 方形居中 contain。
class _VideoViewerItem extends StatefulWidget {
  final VideoPlayerController? controller;

  const _VideoViewerItem({this.controller});

  @override
  State<_VideoViewerItem> createState() => _VideoViewerItemState();
}

class _VideoViewerItemState extends State<_VideoViewerItem> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final ratio = controller.value.aspectRatio;
    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: ratio < 1.0
          ? _buildPortrait(controller)
          : _buildLandscape(controller, ratio),
    );
  }

  /// 竖屏：cover 铺满，沉浸式（裁掉左右溢出部分）。
  Widget _buildPortrait(VideoPlayerController controller) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        _CoverVideo(controller: controller),
        _buildPlayIndicator(controller),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    );
  }

  /// 横屏 / 方形：居中 contain，进度条贴视频底边。
  Widget _buildLandscape(VideoPlayerController controller, double ratio) {
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            _buildPlayIndicator(controller),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayIndicator(VideoPlayerController controller) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, VideoPlayerValue value, child) {
        if (!value.isPlaying && !value.isBuffering) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// cover 播放：用 OverflowBox 把视频按短边放大到铺满、ClipRect 裁掉溢出。
class _CoverVideo extends StatelessWidget {
  final VideoPlayerController controller;

  const _CoverVideo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sw = constraints.maxWidth;
        final sh = constraints.maxHeight;
        final ratio = controller.value.aspectRatio;
        // cover：取能让两轴都填满的尺寸（另一轴必然溢出，交给 ClipRect 裁）。
        double vw, vh;
        if (ratio > sw / sh) {
          // 视频比屏幕「更宽」→ 撑满高度，宽度溢出
          vh = sh;
          vw = sh * ratio;
        } else {
          // 视频比屏幕「更高」→ 撑满宽度，高度溢出
          vw = sw;
          vh = sw / ratio;
        }
        return ClipRect(
          child: OverflowBox(
            minWidth: vw,
            maxWidth: vw,
            minHeight: vh,
            maxHeight: vh,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}
