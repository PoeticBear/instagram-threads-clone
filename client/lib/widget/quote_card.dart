import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/pages/post/post_detail_page.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/circle_avatar.dart';
import 'package:threads/widget/video_player_pool.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 引用卡 —— 渲染「被引用的原帖」(quotePost)。
///
/// 信息流 [FeedPostWidget] 和帖子详情页 [PostDetailPage] 共用本组件，统一引用区的
/// 渲染与交互：
/// - 作者（头像 + 昵称）、正文（含 @提及富文本）、首图 / 首段视频
/// - 被引用帖缺媒体时自动用 `/post/detail/{id}` 补抓（后端 Feed API 常只回最小版）
/// - 视频接入 [VideoPlayerPool]，可见时内联自动播放（与主帖视频行为一致）
/// - 点击整卡跳被引用帖详情；点头像 / 昵称跳被引用用户主页
///
/// [parentPost] 是外层引用帖（必须含 `quoteRepostId`；`quotePost` 可选，缺媒体时补抓）。
class QuoteCard extends StatefulWidget {
  final PostModel parentPost;

  const QuoteCard({super.key, required this.parentPost});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  PostModel? _fetchedQuotePost;
  bool _isFetchingQuote = false;
  final Map<int, TapGestureRecognizer> _mentionRecognizers = {};

  /// 选有效的被引用帖数据：
  /// - 优先有 media 的来源；都没有 media 时用 [_fetchedQuotePost]（更新、更可信）
  /// - 不能让空数据的 [_fetchedQuotePost] 永远盖住 parentPost.quotePost，
  ///   否则会影响「要不要再 fetch 一次」的判断
  PostModel? get _effectiveQuotePost {
    final fp = _fetchedQuotePost;
    final pp = widget.parentPost.quotePost;
    if (fp != null && fp.hasMedia) return fp;
    if (pp != null && pp.hasMedia) return pp;
    if (fp != null) return fp;
    return pp;
  }

  @override
  void initState() {
    super.initState();
    _maybeFetchQuotePost();
    // 订阅 VideoPlayerPool：池内 controller ready 后触发重建，视频画面才会出现
    VideoPlayerPool.instance.version.addListener(_onPoolChanged);
  }

  @override
  void didUpdateWidget(covariant QuoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 被引用帖变化时，清理不在新 mentionedUsers 集合里的 recognizer
    final validIds = <int>{};
    for (final p in [_fetchedQuotePost, widget.parentPost.quotePost]) {
      if (p?.mentionedUsers != null) {
        for (final m in p!.mentionedUsers!) {
          validIds.add(m.userId);
        }
      }
    }
    final expired = _mentionRecognizers.keys
        .where((id) => !validIds.contains(id))
        .toList();
    for (final id in expired) {
      _mentionRecognizers[id]?.dispose();
      _mentionRecognizers.remove(id);
    }
  }

  @override
  void dispose() {
    VideoPlayerPool.instance.version.removeListener(_onPoolChanged);
    for (final r in _mentionRecognizers.values) {
      r.dispose();
    }
    _mentionRecognizers.clear();
    super.dispose();
  }

  void _onPoolChanged() {
    if (mounted) setState(() {});
  }

  TapGestureRecognizer _mentionRecognizerFor(MentionedUser user) {
    return _mentionRecognizers.putIfAbsent(
      user.userId,
      () => TapGestureRecognizer()..onTap = () => _navigateToMentionedUser(user),
    );
  }

  void _navigateToMentionedUser(MentionedUser user) {
    Navigator.push(
      context,
      ProfilePage.getRoute(
        profileId: user.userId.toString(),
        username: user.username,
      ),
    );
  }

  /// 当 quoteRepostId 有值但 quotePost 缺媒体时，拉被引用帖详情。
  /// 后端 Feed API 常只回填最小版（无 media_list），需用 /post/detail/{id} 补全，
  /// 否则引用卡只能显示文字、视频不显示。
  void _maybeFetchQuotePost() {
    final post = widget.parentPost;
    final qid = post.quoteRepostId;
    if (qid == null) return;
    if (_isFetchingQuote) return;
    if ((post.quotePost != null && post.quotePost!.hasMedia) ||
        (_fetchedQuotePost != null && _fetchedQuotePost!.hasMedia)) {
      return;
    }

    _isFetchingQuote = true;
    final postState = Provider.of<PostState>(context, listen: false);
    postState.fetchQuotePostDetail(qid).then((quotePost) {
      if (!mounted) return;
      setState(() {
        if (quotePost != null) {
          _fetchedQuotePost = quotePost;
        }
        _isFetchingQuote = false;
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isFetchingQuote = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return _buildQuoteCard(context, _effectiveQuotePost, appColors);
  }

  // ────────────────── 引用卡主体 ──────────────────

  Widget _buildQuoteCard(
    BuildContext context,
    PostModel? quotePost,
    AppColors appColors,
  ) {
    // 情况 1：有完整的被引用帖数据
    if (quotePost != null) {
      final qUser = quotePost.user;
      final qDisplayName = qUser?.displayName?.isNotEmpty == true
          ? qUser!.displayName!
          : (qUser?.userName?.isNotEmpty == true ? qUser!.userName! : '');
      final qAvatar = qUser?.profilePic ?? '';
      final qContent = quotePost.bio ?? '';
      final qHasMedia = quotePost.hasMedia;
      final qFirstMedia = qHasMedia ? quotePost.effectiveMediaItems.first : null;

      return GestureDetector(
        onTap: () => _navigateToQuotedPostDetail(context, quotePost),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 作者信息行
              if (qDisplayName.isNotEmpty) ...[
                Row(
                  children: [
                    AppCircleAvatar(
                      avatarUrl: qAvatar,
                      size: 20,
                      onTap: () =>
                          _navigateToQuotedUserProfile(context, quotePost),
                    ),
                    Container(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _navigateToQuotedUserProfile(context, quotePost),
                        child: Text(
                          qDisplayName,
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(height: 6),
              ],
              // 正文
              if (qContent.isNotEmpty)
                Text.rich(
                  _buildMentionTextSpan(
                    qContent,
                    quotePost.mentionedUsers ?? const <MentionedUser>[],
                    TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              // 首图 / 首段视频（引用卡保持单 tile 尺寸约束）
              if (qHasMedia && qFirstMedia != null) ...[
                Container(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: qFirstMedia.isVideo
                        ? _buildQuoteVideoPoster(appColors, qFirstMedia)
                        : _buildQuoteImage(appColors, qFirstMedia),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 情况 2：正在加载
    if (_isFetchingQuote) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appColors.border, width: 0.5),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: appColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    // 情况 3：加载失败或原帖不可用
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.border, width: 0.5),
      ),
      child: Text(
        'This post is unavailable',
        style: TextStyle(color: appColors.textMuted, fontSize: 13),
      ),
    );
  }

  /// 引用卡内首图（普通图片 / GIF）渲染
  Widget _buildQuoteImage(AppColors appColors, MediaItemModel item) {
    final url = item.thumbUrl ?? item.url;
    if (url == null || url.isEmpty) {
      return Container(
        color: appColors.surface,
        child: Icon(Icons.broken_image, color: appColors.textSecondary),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: appColors.surface,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: appColors.textSecondary,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: appColors.surface,
        child: Icon(Icons.broken_image, color: appColors.textSecondary),
      ),
    );
  }

  /// 引用卡内首段视频渲染
  /// - 接入 [VideoPlayerPool]，与主帖视频行为一致：可见时 acquire + 自动播放
  ///   （受全局 `feed_video_auto_play` 偏好控制），滑出屏幕时暂停。
  /// - 缩略图非空 → 加载阶段作 poster；为空 → 深色 surface 兜底；视频 ready 后
  ///   [VideoPlayer] 盖在背景上显示真实画面，**不依赖 thumb_url**。
  /// - 完全没 URL → videocam_off 占位。
  Widget _buildQuoteVideoPoster(AppColors appColors, MediaItemModel item) {
    final videoUrl = item.url;

    // 连视频 URL 都没有 → 「视频不可用」占位
    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        color: appColors.surface,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: appColors.textSecondary,
            size: 32,
          ),
        ),
      );
    }

    // 池 key 用外层引用帖 id 唯一定位（与信息流 FeedPostWidget 共享同一池）。
    final mediaKey = 'quote_video_${widget.parentPost.id}';

    return VisibilityDetector(
      key: ValueKey('vd_$mediaKey'),
      onVisibilityChanged: (info) {
        // visibleFraction > 0.5 视为「可见」
        if (info.visibleFraction > 0.5) {
          VideoPlayerPool.instance.acquire(mediaKey, videoUrl);
          VideoPlayerPool.instance.playVisible(mediaKey);
        } else {
          VideoPlayerPool.instance.pauseVisible(mediaKey);
        }
      },
      child: _buildQuoteVideoSurface(appColors, item, mediaKey),
    );
  }

  /// 引用卡视频的渲染面：背景（thumb / 深色兜底）+ [VideoPlayer] 叠加 + 时长 + 静音开关。
  Widget _buildQuoteVideoSurface(
    AppColors appColors,
    MediaItemModel item,
    String mediaKey,
  ) {
    final controller = VideoPlayerPool.instance.controllerOf(mediaKey);
    final initialized = controller != null && controller.value.isInitialized;
    final thumbUrl = item.thumbUrl;
    final hasThumb = thumbUrl != null && thumbUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景层：有缩略图用缩略图，否则深色 surface（视频 ready 后会被 VideoPlayer 盖住）
        if (hasThumb)
          CachedNetworkImage(
            imageUrl: thumbUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: appColors.surface),
            errorWidget: (context, url, error) =>
                Container(color: appColors.surface),
          )
        else
          Container(color: appColors.surface),

        // 视频初始化完成 → 叠加播放器（与主帖 _buildMediaImage 一致）
        if (initialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),

        // 未初始化时：居中播放图标（提示这是视频、加载中）
        if (!initialized)
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white70,
              size: 56,
            ),
          ),

        // 右下角：时长标签 + 静音开关（与主帖 _buildMediaImage 风格一致）
        Positioned(
          right: 6,
          bottom: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.durationLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.durationLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (item.durationLabel.isNotEmpty) const SizedBox(width: 4),
              // 音频开关：图标随 VideoPlayerPool.isMuted() 全局状态切换，点击作用于池中所有视频
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
    );
  }

  /// 正文 @提及富文本：匹配 `@username`，命中的高亮 + 可点击跳该用户主页。
  TextSpan _buildMentionTextSpan(
    String text,
    List<MentionedUser> mentions,
    TextStyle baseStyle,
  ) {
    if (mentions.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final byUsername = <String, MentionedUser>{
      for (final m in mentions) if (m.username.isNotEmpty) m.username: m,
    };
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@[A-Za-z0-9_]+');
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      // 排除邮箱：@ 前若是 word 字符则不当 mention
      if (match.start > 0 &&
          RegExp(r'[A-Za-z0-9_]').hasMatch(text[match.start - 1])) {
        continue;
      }
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final token = match[0]!; // 含 @
      final username = token.substring(1);
      final mentioned = byUsername[username];
      if (mentioned != null) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(
            color: CupertinoColors.activeBlue,
            fontWeight: FontWeight.w600,
          ),
          recognizer: _mentionRecognizerFor(mentioned),
        ));
      } else {
        // @ 字面量但不在 mention 集合里：当普通文本，避免误跳转
        spans.add(TextSpan(text: token));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  void _navigateToQuotedPostDetail(BuildContext context, PostModel quotePost) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PostDetailPage(
          postId: quotePost.id,
          postModel: quotePost,
        ),
      ),
    );
  }

  void _navigateToQuotedUserProfile(BuildContext context, PostModel quotePost) {
    if (quotePost.user == null) return;
    Navigator.push(
      context,
      ProfilePage.getRoute(
        profileId: quotePost.user!.userId.toString(),
        username: quotePost.user!.userName,
      ),
    );
  }
}
