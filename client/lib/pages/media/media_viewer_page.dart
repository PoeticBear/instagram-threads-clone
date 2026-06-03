import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:threads/model/post.module.dart';

/// 全屏媒体查看页面 — 支持图片（缩放）和视频（播放）
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        elevation: 0,
      ),
      body: PageView.builder(
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

    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              // Play/pause indicator
              ValueListenableBuilder(
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
              ),
              // Progress bar at bottom
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
      ),
    );
  }
}
