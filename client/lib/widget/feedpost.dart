import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/network/api_config.dart';
import 'package:threads/pages/composePost/post.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/media_layout_preferences.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/poll_widget.dart';
import 'package:threads/widget/user_avatar_with_follow.dart';
import 'package:threads/widget/quote_card.dart';
import 'package:threads/widget/video_player_pool.dart';
import 'package:threads/pages/media/media_viewer_page.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:threads/pages/post/post_detail_page.dart';
import 'package:threads/widget/edit_history_sheet.dart';
import 'package:threads/widget/reply_bottom_sheet.dart';
import 'package:video_player/video_player.dart';

// ignore: must_be_immutable
class FeedPostWidget extends StatefulWidget {
  PostModel postModel;

  /// 帖子删除成功后由父组件提供的回调。
  /// 用于让父级本地列表（如 ProfilePage._userPosts）同步移除该项，
  /// 解决 Threads Tab 中删除帖子后列表不刷新的问题。
  /// 不传时仅依赖 PostState 的全局列表，行为与之前一致。
  VoidCallback? onPostDeleted;

  /// 是否是列表中的第一项。
  ///
  /// true 时跳过组件顶部的 0.2px 分割线 + 10px 间距。
  /// 这两个元素在首页 Feed 里是必要的——用来跟「快捷发帖」区分；
  /// 但在 Threads Tab（[ProfilePage._buildThreadsTab]）里 TabBar 下面直接
  /// 接第一个帖子，没有前置内容，这 10px 会变成 TabBar 和帖子之间的明显空白。
  /// 传 true 让第一项紧贴 TabBar，从第二项开始保持原样以维持帖子之间的视觉分隔。
  /// 默认 false：所有现有调用点（首页 Feed / 主题详情 / 社区详情 / 收藏 / 定时）
  /// 行为完全不变。
  bool isFirst;

  FeedPostWidget({
    required this.postModel,
    this.onPostDeleted,
    this.isFirst = false,
    super.key,
  });

  @override
  State<FeedPostWidget> createState() => _FeedPostWidgetState();
}

class _FeedPostWidgetState extends State<FeedPostWidget> {
  /// 帖子正文展开/收起状态：默认收起，超过 [kCollapsedMaxLines] 行时显示"展开全文"按钮。
  /// 每个帖子的展开状态是独立的（一个帖子展开不会影响其他帖子）。
  bool _isTextExpanded = false;

  /// 收起时的最大行数。500 字 + 媒体时折叠到 5 行，媒体区域有空间显示。
  static const int _kCollapsedMaxLines = 5;

  /// 正文里 @mention 点击手势识别器缓存：userId → recognizer。
  ///
  /// TapGestureRecognizer 注册到 native gesture binding 后必须显式 dispose，
  /// 否则会泄漏。此处按 userId 复用：当帖子正文 build 时按需创建；当
  /// [didUpdateWidget] 检测到 mentionedUsers 变化时清理过期项；[dispose] 时全部释放。
  /// key 用 userId（int）而非 username 字符串：因为同一 userId 跳转目标是固定的，
  /// username 即使被改名也不影响路由。
  final Map<int, TapGestureRecognizer> _mentionRecognizers = {};

  @override
  void initState() {
    super.initState();
    // 订阅 VideoPlayerPool 变更：池内 controller ready 后触发重建（主帖视频用）
    VideoPlayerPool.instance.version.addListener(_onPoolChanged);
  }

  @override
  void didUpdateWidget(covariant FeedPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 帖子数据变化时（编辑、刷新等），清理不在新 mentionedUsers 集合里的 recognizer。
    final validIds = <int>{};
    if (widget.postModel.mentionedUsers != null) {
      for (final m in widget.postModel.mentionedUsers!) {
        validIds.add(m.userId);
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

  /// 获取或创建某个被提及用户的点击识别器（按 userId 缓存）。
  TapGestureRecognizer _mentionRecognizerFor(MentionedUser user) {
    return _mentionRecognizers.putIfAbsent(
      user.userId,
      () => TapGestureRecognizer()
        ..onTap = () => _navigateToMentionedUser(user),
    );
  }

  /// 跳转到被提及用户的主页（需求 2：走 userId，不走用户名）。
  void _navigateToMentionedUser(MentionedUser user) {
    Navigator.push(
      context,
      ProfilePage.getRoute(
        profileId: user.userId.toString(),
        username: user.username,
      ),
    );
  }

  void _onPoolChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.postModel.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.userName?.isNotEmpty == true ? user!.userName! : 'User${user?.userId ?? ''}');
    final hasMedia = widget.postModel.hasMedia;
    final hasPoll = widget.postModel.pollData != null;
    final hasQuoteId = widget.postModel.quoteRepostId != null;
    // 当前登录用户 ID（用于「加号」组件判断是否显示自己帖子的加号）
    final currentUserId = int.tryParse(
      Provider.of<AuthState>(context, listen: false).userId,
    );

    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        color: appColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 顶部 0.2px 分割线 + 10px 间距:首页 Feed 用来跟「快捷发帖」区
            // 分隔;Threads Tab 第一个帖子 isFirst=true 时跳过,避免 TabBar
            // 下面出现明显空白。
            if (!widget.isFirst) ...[
              Container(
                height: 0.2,
                width: double.infinity,
                color: appColors.divider,
              ),
              Container(
                height: 10,
              ),
            ],
            Row(
              children: [
                UserAvatarWithFollow(
                  avatarUrl: profilePic,
                  size: 35,
                  userId: user?.userId,
                  currentUserId: currentUserId,
                  isFollowing: widget.postModel.isFollowing,
                  userName: displayName,
                  onAvatarTap: () => _navigateToProfile(context),
                  onFollow: () async {
                    final postState = Provider.of<PostState>(context, listen: false);
                    final authorId = user?.userId;
                    if (authorId == null) return;
                    try {
                      await postState.followPostAuthor(widget.postModel.id, authorId);
                    } catch (_) {
                      // PostState 已自动回滚 PostModel.isFollowing，UI 重建后加号会
                      // 自动重新出现。这里不再弹 toast（错误已记录在 PostState 日志）。
                    }
                  },
                ),
                Container(width: 5),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(context),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Utility.getdob(widget.postModel.createdAt, context: context),
                      style: TextStyle(color: appColors.textMuted),
                    ),
                    if (widget.postModel.isEdited == true) ...[
                      Text(' · ',
                          style: TextStyle(color: appColors.textMuted)),
                      Text(
                        AppLocalizations.of(context)!.editedBadge,
                        style: TextStyle(
                          color: appColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(width: 5),
                GestureDetector(
                  onTap: () => _showMoreMenu(context),
                  child: Icon(Icons.more_horiz, color: appColors.textPrimary),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _navigateToPostDetail(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(left: 40),
                child: _buildPostContent(appColors),
              ),
            ),
            // ── 引用帖子预览卡片 ──（抽成 QuoteCard 共享组件，详情页复用）
            if (hasQuoteId) ...[
              Container(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 40, right: 10),
                child: QuoteCard(parentPost: widget.postModel),
              ),
            ],
            if (hasPoll)
              // 投票卡片自身处理选项 tap（投票 / 跳详情），不再用外层 GestureDetector 拦截
              PollWidget(
                postId: widget.postModel.id,
                pollData: widget.postModel.pollData!,
                onCardTap: () => _navigateToPostDetail(context),
                padding: EdgeInsets.only(left: 40, right: 10, top: 8),
              )
            else
              // ── [临时隐藏] 线程连接线设计 (后期需恢复) ──
              // 原始布局: Row 包含左侧竖线(2x300) + 迷你头像(15px) + 右侧图片(300x280)
              // 恢复时删除下方 Padding，取消注释下方 Row 代码块即可
              SizedBox.shrink(),
            // ── 帖子图片/视频/多图 ── 点击进入大图预览（不跳转详情页）
            if (!hasPoll && hasMedia)
              Padding(
                padding: EdgeInsets.only(left: 40, right: 10),
                child: Consumer<MediaLayoutPreferences>(
                  builder: (context, layoutPrefs, _) =>
                      _buildMediaGallery(appColors, layoutPrefs.isHorizontalLayout),
                ),
              ),
            Container(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                ),
                // Like button
                GestureDetector(
                  onTap: () {
                    final state = Provider.of<PostState>(context, listen: false);
                    final postId = widget.postModel.id;
                    if (widget.postModel.isLiked == true) {
                      state.unlikePost(postId);
                    } else {
                      state.likePost(postId);
                    }
                  },
                  child: Icon(
                    widget.postModel.isLiked == true
                        ? Iconsax.heart5
                        : Iconsax.heart,
                    size: 20,
                    color: widget.postModel.isLiked == true
                        ? appColors.like
                        : appColors.textPrimary,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.likesCount ?? 0}', style: TextStyle(color: appColors.textSecondary, fontSize: 13)),
                Container(width: 10),
                // Comment button
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: appColors.background,
                      builder: (context) => ReplyBottomSheet(postId: widget.postModel.id),
                    );
                  },
                  child: Icon(
                    Iconsax.message,
                    size: 20,
                    color: appColors.textPrimary,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.repliesCount ?? 0}', style: TextStyle(color: appColors.textSecondary, fontSize: 13)),
                Container(width: 10),
                // Repost button
                GestureDetector(
                  onTap: () => _showRepostSheet(context),
                  child: Icon(
                    Iconsax.repeat,
                    size: 20,
                    color: widget.postModel.isReposted == true
                        ? appColors.repost
                        : appColors.textPrimary,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.repostsCount ?? 0}', style: TextStyle(color: appColors.textSecondary, fontSize: 13)),
                Container(width: 10),
                // Share button
                GestureDetector(
                  onTap: () => _showShareSheet(context),
                  child: Icon(
                    Iconsax.send_2,
                    size: 20,
                    color: appColors.textPrimary,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.sharesCount ?? 0}', style: TextStyle(color: appColors.textSecondary, fontSize: 13)),
              ],
            ),
            Container(
              height: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Post Content (展开/收起) ====================

  /// 帖子正文渲染器：
  /// - 文本为空时返回空 widget
  /// - 文本字数 <= [_kCollapsedMaxLines] 行可放下时，正常显示 + 不显示"展开"按钮
  /// - 文本超过 [_kCollapsedMaxLines] 行时：默认折叠 + 末尾追加"展开全文"
  /// - 点击"展开全文"切换为完全展开 + 按钮变为"收起"
  /// - 点击文本区域（非按钮位置）跳转到 PostDetailPage
  ///
  /// 实现要点：用 [TextPainter] 在布局阶段判断 didExceedMaxLines，
  /// 避免短文本也显示"展开"按钮的尴尬。
  Widget _buildPostContent(AppColors appColors) {
    final text = widget.postModel.bio ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final textStyle = TextStyle(
      color: appColors.textPrimary,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.3, // 行高收敛一点，500 字长文更紧凑
    );

    // 切片：把正文里的 @username 高亮并挂点击（需求 2）。
    // mentionedUsers 为空时退化为纯 TextSpan，性能与原实现一致。
    final contentSpan = _buildMentionTextSpan(
      text,
      widget.postModel.mentionedUsers ?? const <MentionedUser>[],
      textStyle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 用 TextPainter 检测在 maxLines 限制下是否溢出
        final tp = TextPainter(
          text: contentSpan,
          maxLines: _kCollapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              contentSpan,
              maxLines: _isTextExpanded ? null : _kCollapsedMaxLines,
              overflow:
                  _isTextExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            // 仅当文本真的被截断时才显示展开/收起按钮
            if (isOverflowing)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isTextExpanded = !_isTextExpanded;
                  });
                },
                // opaque 让按钮区域消费 tap 事件，不冒泡到外层的 _navigateToPostDetail
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _isTextExpanded
                        ? AppLocalizations.of(context)!.showLess
                        : AppLocalizations.of(context)!.showMore,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 构建正文 TextSpan：按 `@username` 切片，命中的片段高亮 + 挂点击跳转。
  ///
  /// 仅当 [mentions] 非空且正文里出现对应 username 时才生成 TapGestureRecognizer；
  /// 未命中 mention 集合的 @ 字面量当普通文本（避免误跳转）。
  /// 邮箱场景（如 alice@bob.com）通过「@ 前是 word 字符则不当 mention」排除。
  ///
  /// Recognizer 由 [_mentionRecognizerFor] 按 userId 缓存管理，调用方无需 dispose。
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
      // 排除邮箱：@ 前若是 word 字符则不当 mention（与 ComposePost._detectMentionToken 一致）。
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
        // @ 字面量但不在 mention 集合里：当普通文本，避免误跳转。
        spans.add(TextSpan(text: token));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  // ==================== Media Gallery (multi-image) ====================

  /// 入口：按媒体数量分派到不同布局
  /// 风格参考：微博 / 微信朋友圈 / 小红书 —— 9 宫格风格
  /// 1 张：大图（保留原比例）
  /// 2-4 张：2 列网格（2×2 满格）
  /// 5-9 张：3 列网格（3×3 满格）
  /// >9 张：显示前 9 个，最后一个叠 +N 半透明角标
  Widget _buildMediaGallery(AppColors appColors, bool isHorizontal) {
    final items = widget.postModel.effectiveMediaItems;
    if (items.isEmpty) return SizedBox.shrink();
    if (isHorizontal) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 300.0; // 兜底：父级无界时给个固定值
          return _buildHorizontalMedia(appColors, items, maxWidth);
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 300.0; // 兜底：父级无界时给个固定值
        if (items.length == 1) {
          return _buildSingleMedia(appColors, items[0], 0, maxWidth);
        }
        return _buildGridMedia(appColors, items, maxWidth);
      },
    );
  }

  /// 单图：撑满父宽，按 width/height 比例渲染（缺值时 1:1 兜底）
  /// - 视频：包一层 VisibilityDetector，可见时调池自动播放；不可见时暂停
  Widget _buildSingleMedia(
    AppColors appColors,
    MediaItemModel item,
    int index,
    double maxWidth,
  ) {
    final w = item.width ?? 0;
    final h = item.height ?? 0;
    final hasRatio = w > 0 && h > 0;
    final aspectRatio = hasRatio ? w / h : 1.0; // 缺值时 1:1 兜底

    // 视频的池 key 用 (postId, mediaIndex) 唯一定位，避免与多图网格里的其它视频冲突
    final mediaKey = 'feed_video_${widget.postModel.id}_$index';

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildMediaImage(appColors, item, mediaKey: mediaKey),
      ),
    );

    // 非视频：保持原行为
    if (!item.isVideo || (item.url == null || item.url!.isEmpty)) {
      return GestureDetector(
        onTap: () => _openMediaViewer(context, tappedIndex: index),
        child: child,
      );
    }

    // 视频：包 VisibilityDetector，可见时让 VideoPlayerPool 接管自动播放
    final videoUrl = item.url!;
    return GestureDetector(
      onTap: () {
        // 进入大图前先暂停所有
        VideoPlayerPool.instance.pauseAll();
        _openMediaViewer(context, tappedIndex: index);
      },
      child: VisibilityDetector(
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
        child: child,
      ),
    );
  }

  /// 多图网格：2-4 张 2 列 / 5+ 张 3 列；>9 张时第 9 张叠 +N 角标
  Widget _buildGridMedia(
    AppColors appColors,
    List<MediaItemModel> items,
    double maxWidth,
  ) {
    final columns = items.length <= 4 ? 2 : 3;
    const gap = 2.0;
    final tileSize = (maxWidth - (columns - 1) * gap) / columns;
    final displayCount = items.length > 9 ? 9 : items.length;
    final rows = ((displayCount + columns - 1) / columns).floor();
    final gridHeight = rows * tileSize + (rows - 1) * gap;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 1,
        ),
        itemCount: displayCount,
        itemBuilder: (context, i) {
          final item = items[i];
          final isLast = i == displayCount - 1;
          final overflow = items.length - displayCount;

          // 视频子项：用 (postId, mediaIndex) 唯一定位池 key，并包 VisibilityDetector
          final mediaKey = 'feed_video_${widget.postModel.id}_$i';
          final isPlayableVideo =
              item.isVideo && (item.url != null && item.url!.isNotEmpty);

          Widget tile = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaImage(appColors, item, mediaKey: mediaKey),
                if (isLast && overflow > 0)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );

          // 视频子项：包 VisibilityDetector，可见时让 VideoPlayerPool 接管自动播放
          if (isPlayableVideo) {
            final videoUrl = item.url!;
            tile = VisibilityDetector(
              key: ValueKey('vd_$mediaKey'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.5) {
                  VideoPlayerPool.instance.acquire(mediaKey, videoUrl);
                  VideoPlayerPool.instance.playVisible(mediaKey);
                } else {
                  VideoPlayerPool.instance.pauseVisible(mediaKey);
                }
              },
              child: tile,
            );
          }

          return GestureDetector(
            onTap: () {
              if (isPlayableVideo) {
                // 进入大图前先暂停所有
                VideoPlayerPool.instance.pauseAll();
              }
              _openMediaViewer(context, tappedIndex: i);
            },
            child: tile,
          );
        },
      ),
    );
  }

  /// 单行横向滚动：固定高度 220pt，按宽高比缩放宽度；最后一个 tile 贴右。
  /// - 复用 _buildMediaImage（图片 / GIF / 视频 + 池控制器 + 时长 / 静音）
  /// - 视频子项：包 VisibilityDetector，可见时由 VideoPlayerPool 自动播放
  /// - 不裁切；tile 间 4pt 间隙作为滑动 peek
  /// - 无数量上限：所有媒体（>9 也可）都能横滑到
  Widget _buildHorizontalMedia(
    AppColors appColors,
    List<MediaItemModel> items,
    double maxWidth,
  ) {
    const double fixedHeight = 220.0;
    const double gap = 4.0;
    const double landscapeMaxRatio = 0.85; // 多图时横图封顶，避免单 tile 撑满
    const double minWidthRatio = 0.9; // 单图时最小宽度 = fixedHeight * 0.9

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final w = item.width ?? 0;
      final h = item.height ?? 0;
      final hasRatio = w > 0 && h > 0;
      final aspect = hasRatio ? w / h : 1.0;

      double tileWidth;
      if (items.length == 1) {
        tileWidth = (fixedHeight * aspect).clamp(
          fixedHeight * minWidthRatio,
          maxWidth,
        );
      } else {
        tileWidth = aspect >= 1.0
            ? (fixedHeight * aspect).clamp(0.0, maxWidth * landscapeMaxRatio)
            : fixedHeight * aspect;
      }

      final mediaKey = 'feed_video_${widget.postModel.id}_$i';
      final isPlayableVideo =
          item.isVideo && (item.url != null && item.url!.isNotEmpty);

      Widget tile = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: tileWidth,
          height: fixedHeight,
          child: _buildMediaImage(appColors, item, mediaKey: mediaKey),
        ),
      );

      if (isPlayableVideo) {
        final videoUrl = item.url!;
        tile = VisibilityDetector(
          key: ValueKey('vd_$mediaKey'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.5) {
              VideoPlayerPool.instance.acquire(mediaKey, videoUrl);
              VideoPlayerPool.instance.playVisible(mediaKey);
            } else {
              VideoPlayerPool.instance.pauseVisible(mediaKey);
            }
          },
          child: tile,
        );
      }

      tile = GestureDetector(
        onTap: () {
          if (isPlayableVideo) {
            VideoPlayerPool.instance.pauseAll();
          }
          _openMediaViewer(context, tappedIndex: i);
        },
        child: tile,
      );

      children.add(tile);
      if (i != items.length - 1) {
        children.add(const SizedBox(width: gap));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero, // 最后一个 tile 与外层 Padding.right=10 贴齐
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// 通用单图块（缩略图，点击进大图预览）
  /// - 图片 / GIF：直接显示缩略图（CachedNetworkImage 支持 GIF 动画）
  /// - 视频：缩略图 + 视频播放器（如果在池中已就绪）+ 右下角「时长 + 音频开关」
  ///   - 音频开关图标：volume_off (静音) / volume_up (有声)，
  ///     点击 VideoPlayerPool.toggleMute() 切换全局静音状态（影响池中所有视频）
  ///
  /// [mediaKey]：当 [item] 是视频时，从 VideoPlayerPool 查找 controller 用的 key。
  /// 多图网格里同一帖子可能有多段视频，必须用 (postId, mediaIndex) 唯一定位。
  Widget _buildMediaImage(
    AppColors appColors,
    MediaItemModel item, {
    String? mediaKey,
  }) {
    final url = item.thumbUrl ?? item.url;
    if (url == null || url.isEmpty) {
      return Container(
        color: appColors.surface,
        child: Icon(Icons.broken_image, color: appColors.textSecondary),
      );
    }

    if (item.isVideo) {
      // 视频：用 (postId, mediaIndex) 唯一定位池中的 controller
      final key = mediaKey ?? 'feed_video_${widget.postModel.id}';
      final controller = VideoPlayerPool.instance.controllerOf(key);
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
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
              child: const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
          // 视频已初始化 → 叠加播放器
          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          // 右下角：时长标签 + 音频开关（点击互不冲突）
          Positioned(
            right: 6,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.durationLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                // 音频开关：图标随 VideoPlayerPool.isMuted() 全局状态切换
                // 点击 toggleMute() 会作用于池中所有 video
                GestureDetector(
                  onTap: () {
                    VideoPlayerPool.instance.toggleMute();
                  },
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

  // ==================== Navigation ====================

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      ProfilePage.getRoute(
        profileId: widget.postModel.user?.userId.toString() ?? '',
        username: widget.postModel.user?.userName,
      ),
    );
  }

  void _navigateToPostDetail(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PostDetailPage(
          postId: widget.postModel.id,
          postModel: widget.postModel,
        ),
      ),
    );
  }

  /// 打开大图预览：tappedIndex 决定从哪张开始
  void _openMediaViewer(BuildContext context, {int tappedIndex = 0}) {
    final items = widget.postModel.effectiveMediaItems;
    if (items.isEmpty) return;
    final safeIndex = tappedIndex.clamp(0, items.length - 1);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(
          mediaItems: items,
          initialIndex: safeIndex,
          postModel: widget.postModel,
        ),
      ),
    );
  }

  // ==================== Bottom Sheet Helpers ====================

  Widget _buildSheetDivider() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Divider(color: appColors.divider, height: 0.5);
  }

  Widget _buildSheetOption({
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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

  // ==================== Repost Sheet ====================

  void _showRepostSheet(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final isReposted = widget.postModel.isReposted == true;
    final postId = widget.postModel.id;
    final postState = Provider.of<PostState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReposted) ...[
              _buildSheetOption(
                label: l10n.repost,
                onTap: () {
                  Navigator.pop(sheetContext);
                  postState.repost(postId);
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: AppLocalizations.of(context)!.quote,
              onTap: () {
                Navigator.pop(sheetContext);
                _showQuoteSheet(context);
              },
            ),
            _buildSheetDivider(),
            if (isReposted) ...[
              _buildSheetOption(
                label: l10n.undoRepost,
                textColor: appColors.destructive,
                onTap: () {
                  Navigator.pop(sheetContext);
                  postState.unrepost(postId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== Quote Sheet ====================

  void _showQuoteSheet(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.quoteRepost,
                    style: TextStyle(color: appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Icon(Icons.close, color: appColors.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Quoted post preview
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.postModel.user?.displayName ?? '',
                      style: TextStyle(color: appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.postModel.bio ?? '',
                      style: TextStyle(color: appColors.textSecondary, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
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
              SizedBox(height: 12),
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
                    final state = Provider.of<PostState>(context, listen: false);
                    final authState = Provider.of<AuthState>(context, listen: false);
                    final postModel = PostModel(
                      user: UserModel(
                        userId: int.tryParse(authState.userId),
                        userName: authState.userModel?.userName ?? '',
                        displayName: authState.userModel?.displayName ?? '',
                        profilePic: authState.userModel?.profilePic,
                      ),
                      bio: controller.text,
                      createdAt: DateTime.now().toIso8601String(),
                      key: authState.userId,
                    );
                    await state.createPost(
                      postModel,
                      quoteRepostId: int.tryParse(widget.postModel.id),
                    );
                  },
                  child: Text(l10n.post, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Share Sheet ====================

  void _showShareSheet(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final postId = widget.postModel.id;
    final postState = Provider.of<PostState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetOption(
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
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
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

  // ==================== More Menu Sheet ====================

  void _showMoreMenu(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isSaved = widget.postModel.isSaved == true;
    final isPinned = widget.postModel.isPinned == true;
    final postId = widget.postModel.id;
    final l10n = AppLocalizations.of(context)!;

    // Check if this is the current user's post
    final authState = Provider.of<AuthState>(context, listen: false);
    final currentUserId = authState.userId;
    final postUserId = widget.postModel.user?.userId?.toString();
    final isOwnPost = postUserId != null && currentUserId == postUserId;

    // 服务端约束：帖子发布后 15 分钟内 + 最多 5 次编辑
    // 前端预判用于隐藏入口（决策点 A1）
    bool canEdit = false;
    if (isOwnPost) {
      final createdAt = DateTime.tryParse(widget.postModel.createdAt);
      final editCount = widget.postModel.editCount ?? 0;
      canEdit = createdAt != null &&
          DateTime.now().difference(createdAt) < const Duration(minutes: 15) &&
          editCount < 5;
    }

    final postState = Provider.of<PostState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost) ...[
              if (canEdit) ...[
                _buildSheetOption(
                  label: l10n.editPost,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (routeContext) => ComposePost(
                          editingPostId: widget.postModel.id,
                          initialContent: widget.postModel.bio,
                          initialIsSensitive: widget.postModel.isSensitive,
                          initialContentWarning: widget.postModel.contentWarning,
                          // 修复:`onPostSuccess` 缺省会让 ComposePost 在 edit 保存后卡住(同
                          // TextNotePage → pushReplacement 那条 bug):见 `change-text-note-handoff`
                          // 决策 1。`PostState.updatePost` 已通过 `_updatePostInList` 完成本地
                          // 列表的局部更新（决策点 A3),不需要在回调里再触发刷新,只需 pop 回
                          // 列表;`onCancel` 同样。
                          onPostSuccess: () => Navigator.of(routeContext).pop(),
                          onCancel: () => Navigator.of(routeContext).pop(),
                        ),
                      ),
                    );
                  },
                ),
                _buildSheetDivider(),
              ],
              _buildSheetOption(
                label: l10n.deletePost,
                textColor: appColors.destructive,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: appColors.surface,
                      title: Text(l10n.deletePost, style: TextStyle(color: appColors.textPrimary)),
                      content: Text(l10n.deletePostConfirm, style: TextStyle(color: appColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel, style: TextStyle(color: appColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.deletePost, style: TextStyle(color: appColors.destructive)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    bool success = false;
                    try {
                      success = await postState.deletePost(postId);
                    } catch (e) {
                      if (context.mounted) {
                        NetworkErrorNotifier.showApiError(e);
                      }
                    }
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.postDeleted),
                            backgroundColor: appColors.repost,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                    if (success) {
                      // 通知父组件（如 ProfilePage._userPosts）从本地列表移除该项，
                      // 解决 Threads Tab 中删除后列表不刷新的问题。
                      widget.onPostDeleted?.call();
                    }
                  }
                },
              ),
              _buildSheetDivider(),
              _buildSheetOption(
                label: isPinned ? l10n.unpinPost : l10n.pinPost,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (isPinned) {
                    postState.unpinPost(postId);
                  } else {
                    postState.pinPost(postId);
                  }
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: isSaved ? l10n.unsave : l10n.save,
              onTap: () {
                Navigator.pop(sheetContext);
                if (isSaved) {
                  postState.unsavePost(postId);
                } else {
                  postState.savePost(postId);
                }
              },
            ),
            _buildSheetDivider(),
            if (!isOwnPost) ...[
              _buildSheetOption(
                label: l10n.muteUsername(widget.postModel.user?.userName ?? ''),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleRelationControl(
                    context: context,
                    targetUserId: int.tryParse(postUserId ?? '') ?? 0,
                    controlType: 1,
                    successMsg: l10n.userMuted,
                  );
                },
              ),
              _buildSheetDivider(),
              _buildSheetOption(
                label: l10n.restrictUsername(widget.postModel.user?.userName ?? ''),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleRelationControl(
                    context: context,
                    targetUserId: int.tryParse(postUserId ?? '') ?? 0,
                    controlType: 2,
                    successMsg: l10n.userRestricted,
                  );
                },
              ),
              _buildSheetDivider(),
              _buildSheetOption(
                label: l10n.blockUsername(widget.postModel.user?.userName ?? ''),
                textColor: appColors.destructive,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: appColors.surface,
                      title: Text(l10n.blockConfirmTitle, style: TextStyle(color: appColors.textPrimary)),
                      content: Text(l10n.blockConfirmDesc, style: TextStyle(color: appColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel, style: TextStyle(color: appColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.block, style: TextStyle(color: appColors.destructive)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _handleRelationControl(
                      context: context,
                      targetUserId: int.tryParse(postUserId ?? '') ?? 0,
                      controlType: 3,
                      successMsg: l10n.userBlocked,
                    );
                  }
                },
              ),
              _buildSheetDivider(),
              _buildSheetOption(
                label: l10n.report,
                textColor: appColors.destructive,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportMenu(context, postId, postState);
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: l10n.editHistory,
              onTap: () {
                Navigator.pop(sheetContext);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: appColors.background,
                  builder: (context) => EditHistorySheet(postId: postId),
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: l10n.notInterested,
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRelationControl({
    required BuildContext context,
    required int targetUserId,
    required int controlType,
    required String successMsg,
  }) async {
    try {
      final userService = UserService(apiClient: getIt());
      await userService.addRelationControl(
        targetUserId: targetUserId,
        controlType: controlType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        NetworkErrorNotifier.showApiError(e);
      }
    }
  }

  void _showReportMenu(BuildContext context, String postId, PostState postState) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final int targetId = int.tryParse(postId) ?? 0;

    // reportType values: 1=Spam, 2=Harassment, 3=Hate Speech, 4=Self-harm,
    //                    5=Violence, 6=Privacy Violation, 7=Misinformation,
    //                    8=Intellectual Property, 9=Other
    final reportOptions = [
      (type: 1, label: l10n.reportSpam),
      (type: 2, label: l10n.reportHarassment),
      (type: 3, label: l10n.reportHateSpeech),
      (type: 4, label: l10n.reportSelfHarm),
      (type: 5, label: l10n.reportViolence),
      (type: 6, label: l10n.reportPrivacyViolation),
      (type: 7, label: l10n.reportMisinformation),
      (type: 8, label: l10n.reportIntellectualProperty),
      (type: 9, label: l10n.reportOther),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: appColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.reportPost,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Divider(color: appColors.textSecondary.withOpacity(0.1)),
              ...reportOptions.map((option) => _buildSheetOption(
                label: option.label,
                textColor: appColors.destructive,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await postState.reportContent(
                      targetType: 1, // Post
                      targetId: targetId,
                      reportType: option.type,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.reportSuccess)),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      NetworkErrorNotifier.showApiError(e);
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}
