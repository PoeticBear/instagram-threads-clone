import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/network/api_config.dart';
import 'package:threads/pages/post/post_detail_page.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 全屏媒体查看页面 — 支持图片（缩放）和视频（播放）
///
/// 视频按方向分流：
/// - 竖屏（ratio < 1）：cover 铺满全屏，沉浸式（忽略安全区）。
/// - 横屏 / 方形（ratio >= 1）：居中 contain，上下留黑；横屏（ratio >= 1.2）
///   右下角出现旋转按钮，可手动锁横屏铺满观看。
///
/// 底部横条（[media-viewer-interaction-bar]）：展示当前帖子的
/// 点赞 / 回复 / 转发 / 分享 4 个互动统计（图标 + 数值），与 FeedPost 卡片对齐；
/// 点赞与转发可交互、回复跳详情、分享弹复制链接+系统分享。
class MediaViewerPage extends StatefulWidget {
  final List<MediaItemModel> mediaItems;
  final int initialIndex;

  /// 当前帖子的 PostModel，用于渲染底部互动统计横条 + 与 PostState 同步。
  final PostModel postModel;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.postModel,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _videoControllers = {};

  /// 本地持有的 PostModel 快照 —— 初始取自 widget.postModel，
  /// PostState 通知时按 postId 同步最新值。
  late PostModel _currentPost;

  /// 是否处于手动锁定的横屏模式。
  bool _isLandscape = false;

  /// aspect ratio 达到该阈值才认为是「横屏视频」，显示旋转按钮。
  static const double _landscapeThreshold = 1.2;

  /// PostState 引用：在 didChangeDependencies 中拿到，避免 initState 期间
  /// context 还未就绪的问题；dispose 中移除监听。
  PostState? _postStateRef;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentPost = widget.postModel;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initVideoControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 第一次绑定：在 didChangeDependencies 拿 PostState 引用并订阅。
    // didChangeDependencies 可能在生命周期内被多次调用（依赖变更时），
    // 因此加 ref == null 守卫避免重复 addListener。
    _postStateRef ??= Provider.of<PostState>(context, listen: false);
    _postStateRef!.addListener(_onPostStateChanged);
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
    _postStateRef?.removeListener(_onPostStateChanged);
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

  /// PostState 变更时同步本地 PostModel 快照（按 postId 匹配）。
  ///
  /// PostState.feedlist 为 null 或找不到匹配项时保留原快照 —— 这通常发生在
  /// 全局列表被重置（如切换账号）的边缘场景。
  void _onPostStateChanged() {
    if (!mounted) return;
    final list = _postStateRef?.feedlist;
    if (list == null) return;
    final idx = list.indexWhere(
      (p) => p.postId == _currentPost.postId || p.id == _currentPost.id,
    );
    if (idx == -1) return;
    final updated = list[idx];
    if (updated.likesCount == _currentPost.likesCount &&
        updated.repliesCount == _currentPost.repliesCount &&
        updated.quotesCount == _currentPost.quotesCount &&
        updated.repostsCount == _currentPost.repostsCount &&
        updated.isLiked == _currentPost.isLiked &&
        updated.isReposted == _currentPost.isReposted) {
      return; // 无变化，避免无谓重建
    }
    setState(() => _currentPost = updated);
  }

  // ==================== 底部横条按钮行为 ====================

  /// 点赞：调 PostState.likePost / unlikePost，数字与激活态由 PostState
  /// 通知后自动同步（见 _onPostStateChanged）。
  void _onLikeTap() {
    final postState = _postStateRef ?? Provider.of<PostState>(context, listen: false);
    final isLiked = _currentPost.isLiked == true;
    if (isLiked) {
      postState.unlikePost(_currentPost.postId ?? _currentPost.id);
    } else {
      postState.likePost(_currentPost.postId ?? _currentPost.id);
    }
  }

  /// 转发：复用 FeedPost 同款 RepostSheet（repost / quote / 撤销转发）。
  /// Sheet 内的逻辑由 PostState 单独处理；这里只负责弹窗。
  void _onRepostTap() {
    final postId = _currentPost.postId ?? _currentPost.id;
    final isReposted = _currentPost.isReposted == true;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final postState = _postStateRef ?? Provider.of<PostState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReposted)
              _sheetOption(
                context: sheetContext,
                label: l10n.repost,
                onTap: () {
                  Navigator.pop(sheetContext);
                  postState.repost(postId);
                },
              ),
            if (!isReposted) _sheetDivider(context),
            _sheetOption(
              context: sheetContext,
              label: l10n.quote,
              onTap: () {
                Navigator.pop(sheetContext);
                _showQuoteSheet(context);
              },
            ),
            _sheetDivider(context),
            if (isReposted)
              _sheetOption(
                context: sheetContext,
                label: l10n.undoRepost,
                textColor: appColors.destructive,
                onTap: () {
                  Navigator.pop(sheetContext);
                  postState.unrepost(postId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? appColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _sheetDivider(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Divider(color: appColors.divider, height: 0.5);
  }

  /// 引用（带评论转发）：复用 FeedPost._showQuoteSheet 写法。
  /// 走「关闭查看器 → 弹本地 Sheet 编辑 → 调 PostState.createPost quoteRepostId」
  /// 的链路，避免引入对 ComposePost 的额外依赖。
  void _onReplyTap() {
    final postId = _currentPost.postId ?? _currentPost.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(postId: postId, postModel: _currentPost),
      ),
    );
  }

  /// 跳到引用 Sheet：和 FeedPost._showQuoteSheet 完全等价。
  void _showQuoteSheet(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = TextEditingController();
    final authState = Provider.of<AuthState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.quoteRepost,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Icon(Icons.close, color: appColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPost.user?.displayName ?? '',
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentPost.bio ?? '',
                      style: TextStyle(color: appColors.textSecondary, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: appColors.textPrimary),
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.quotePlaceholder,
                  hintStyle: TextStyle(color: appColors.textHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: appColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: appColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: appColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final postState = _postStateRef ?? Provider.of<PostState>(context, listen: false);
                    final userModel = authState.userModel;
                    final newPost = PostModel(
                      user: UserModel(
                        userId: int.tryParse(authState.userId),
                        userName: userModel?.userName ?? '',
                        displayName: userModel?.displayName ?? '',
                        profilePic: userModel?.profilePic,
                      ),
                      bio: controller.text,
                      createdAt: DateTime.now().toIso8601String(),
                      key: authState.userId,
                    );
                    await postState.createPost(
                      newPost,
                      quoteRepostId: int.tryParse(_currentPost.postId ?? _currentPost.id),
                    );
                  },
                  child: Text(
                    l10n.post,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分享入口：与 FeedPost._showShareSheet 完全等价 ——
  /// 弹「复制链接」+「系统分享」两个选项。
  void _onShareTap() {
    final postId = _currentPost.postId ?? _currentPost.id;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final postState = _postStateRef ?? Provider.of<PostState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetOption(
              context: sheetContext,
              label: l10n.copyLink,
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(
                  text: '${ApiConfig.baseUrl}t/$postId',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.linkCopiedToClipboard),
                    backgroundColor: appColors.surface,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            _sheetDivider(context),
            _sheetOption(
              context: sheetContext,
              label: l10n.share,
              onTap: () {
                Navigator.pop(sheetContext);
                postState.sharePost(postId);
              },
            ),
          ],
        ),
      ),
    );
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
              return _ImageViewerPage(url: item.url ?? '');
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
          // 底部互动统计横条（点赞 / 回复 / 引用 / 转发）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _InteractionBar(
              post: _currentPost,
              onLikeTap: _onLikeTap,
              onReplyTap: _onReplyTap,
              onRepostTap: _onRepostTap,
              onShareTap: _onShareTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部互动统计横条 —— 黑色半透 + BackdropFilter 模糊，4 等分按钮。
///
/// 图标 / 数据 / 顺序与 FeedPost 卡片 L285-360 完全一致：
/// `heart(likes) / message(replies) / repeat(reposts) / send_2(shares)`。
class _InteractionBar extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback onRepostTap;
  final VoidCallback onShareTap;

  const _InteractionBar({
    required this.post,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.onRepostTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isLiked = post.isLiked == true;
    final isReposted = post.isReposted == true;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _InteractionBarButton(
                      icon: isLiked ? Iconsax.heart5 : Iconsax.heart,
                      count: post.likesCount ?? 0,
                      color: isLiked ? appColors.like : Colors.white,
                      onTap: onLikeTap,
                    ),
                  ),
                  Expanded(
                    child: _InteractionBarButton(
                      icon: Iconsax.message,
                      count: post.repliesCount ?? 0,
                      color: Colors.white,
                      onTap: onReplyTap,
                    ),
                  ),
                  Expanded(
                    child: _InteractionBarButton(
                      icon: Iconsax.repeat,
                      count: post.repostsCount ?? 0,
                      color: isReposted ? appColors.repost : Colors.white,
                      onTap: onRepostTap,
                    ),
                  ),
                  Expanded(
                    child: _InteractionBarButton(
                      icon: Iconsax.send_2,
                      count: post.sharesCount ?? 0,
                      color: Colors.white,
                      onTap: onShareTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 横条单个按钮：图标 + 数值，居中显示。
class _InteractionBarButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _InteractionBarButton({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片查看项 — 支持双指缩放/平移
/// 图片查看页 — 三层结构：
///
/// 1. 底层 cover + 高斯模糊（sigma 30）— 图片本身的氛围背景，铺满整屏
/// 2. 中间层 暗化叠加（alpha 0.25）— 让前景原图更突出
/// 3. 顶层 contain 居中 + InteractiveViewer — 清晰原图，支持双指缩放/平移
///
/// 视频页（[_VideoViewerItem]）保持纯黑，不走此结构。
class _ImageViewerPage extends StatelessWidget {
  final String url;

  const _ImageViewerPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) 底层：图片 cover 铺满 + 高斯模糊（不采样屏幕，用 ImageFiltered 直接装饰原图）
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // 2) 中间层：暗化叠加 — 让前景原图视觉更突出
        Container(color: Colors.black.withValues(alpha: 0.25)),
        // 3) 顶层：清晰原图，contain 居中 + InteractiveViewer
        Center(
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
        ),
      ],
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
