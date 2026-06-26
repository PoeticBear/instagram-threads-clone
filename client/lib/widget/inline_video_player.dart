import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/video_player_pool.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 内联视频播放组件 —— 可见时自动播放（接 [VideoPlayerPool]），**自治**：
/// 自己订阅池变更并重建，调用方无需额外管理。
///
/// 用于详情页主帖视频等「就地播放」场景。视频画面由 [VideoPlayer] 渲染，
/// **不依赖 thumb_url**（后端 video 帖常只回 url、thumb_url 为空串）。
///
/// - [mediaKey]：[VideoPlayerPool] 的唯一 key，调用方保证唯一
///   （如 `detail_video_{postId}_{i}`）
/// - [videoUrl]：视频地址，必须非空
/// - [thumbUrl]：缩略图地址，可空 / 空串；非空时作加载阶段背景
/// - [durationLabel]：右下角时长标签，空串则不显示
/// - [showMuteToggle]：是否显示右下角静音开关（网格小图可关）
class InlineVideoPlayer extends StatefulWidget {
  final String mediaKey;
  final String videoUrl;
  final String? thumbUrl;
  final String durationLabel;
  final bool showMuteToggle;

  const InlineVideoPlayer({
    super.key,
    required this.mediaKey,
    required this.videoUrl,
    this.thumbUrl,
    this.durationLabel = '',
    this.showMuteToggle = true,
  });

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  @override
  void initState() {
    super.initState();
    // 订阅池变更：controller initialize 完成后触发重建，VideoPlayer 画面才会出现
    VideoPlayerPool.instance.version.addListener(_onPoolChanged);
  }

  @override
  void dispose() {
    VideoPlayerPool.instance.version.removeListener(_onPoolChanged);
    super.dispose();
  }

  void _onPoolChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = VideoPlayerPool.instance.controllerOf(widget.mediaKey);
    final initialized = controller != null && controller.value.isInitialized;
    final hasThumb =
        widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty;

    return VisibilityDetector(
      key: ValueKey('vd_${widget.mediaKey}'),
      onVisibilityChanged: (info) {
        // visibleFraction > 0.5 视为「可见」
        if (info.visibleFraction > 0.5) {
          VideoPlayerPool.instance.acquire(widget.mediaKey, widget.videoUrl);
          VideoPlayerPool.instance.playVisible(widget.mediaKey);
        } else {
          VideoPlayerPool.instance.pauseVisible(widget.mediaKey);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景层：有缩略图用缩略图，否则深色 surface（视频 ready 后会被 VideoPlayer 盖住）
          if (hasThumb)
            CachedNetworkImage(
              imageUrl: widget.thumbUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: appColors.surface),
              errorWidget: (_, __, ___) =>
                  Container(color: appColors.surface),
            )
          else
            Container(color: appColors.surface),

          // 视频 ready → 叠加播放器
          if (initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),

          // 未初始化：居中播放图标（加载中提示）
          if (!initialized)
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white70,
                size: 56,
              ),
            ),

          // 右下角：时长标签 + 静音开关
          Positioned(
            right: 6,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.durationLabel.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.durationLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.durationLabel.isNotEmpty)
                  const SizedBox(width: 4),
                if (widget.showMuteToggle)
                  GestureDetector(
                    onTap: () => VideoPlayerPool.instance.toggleMute(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        VideoPlayerPool.instance.isMuted()
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
