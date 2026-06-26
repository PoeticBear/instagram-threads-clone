import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/pages/media/media_viewer_page.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/widget/poll_widget.dart';
import 'package:threads/widget/quote_card.dart';
import 'package:threads/widget/inline_video_player.dart';
import 'package:threads/widget/mention_overlay.dart';
import 'package:threads/widget/reply_bottom_sheet.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final PostModel? postModel;

  const PostDetailPage({required this.postId, this.postModel, super.key});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  PostService? _postService;
  PostService get postService {
    _postService ??= PostService(apiClient: getIt());
    return _postService!;
  }

  PostModel? _post;
  List<Reply> _replies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isPosting = false;

  // ─── @mention 用户选择面板 ───
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<UserInfo> _filteredUsers = const [];
  // 当前 @token（含 @）在文本中的起始 offset，-1 表示无激活 token
  int _mentionTokenStart = -1;
  // 防抖 Timer：用户连续输入时只发最后一次请求
  Timer? _mentionDebounce;
  // 已选中的 mention 用户：username → userId。
  // 选中补全面板里的用户时写入；正文编辑时按 username 是否仍出现在文本里
  // 自动同步过滤。提交回复时把 values 作为 mentionedUserIds 传给服务端。
  final Map<String, int> _mentionUserIds = {};

  @override
  void dispose() {
    _replyController.removeListener(_onTextChanged);
    _mentionDebounce?.cancel();
    _hideOverlay();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _replyController.addListener(_onTextChanged);
    _post = widget.postModel;
    _loadData();
  }

  // ─── @mention 用户选择面板 ────────────────────────────────

  /// 文本变化监听：检测 @mention 并刷新浮层。
  void _onTextChanged() {
    // 同步 mention userId 集合：正文里不再出现的 username 自动移除。
    _syncMentionUserIds();
    final token = _detectMentionToken();
    if (token == null) {
      _mentionTokenStart = -1;
      _hideOverlay();
      return;
    }
    _mentionTokenStart = token.start;
    _filterAndShow(token.query);
  }

  /// 同步 [_mentionUserIds]：检查已记录的每个 username 是否仍以
  /// `@username` 形式出现在正文中，把不再出现的移除（用户删除/改名/覆盖时同步）。
  void _syncMentionUserIds() {
    if (_mentionUserIds.isEmpty) return;
    final text = _replyController.text;
    final toRemove = <String>[];
    _mentionUserIds.forEach((username, _) {
      final atUsername = '@$username';
      final idx = text.indexOf(atUsername);
      if (idx < 0) {
        toRemove.add(username);
        return;
      }
      // 排除邮箱：@ 前若是 word 字符则不算 mention。
      if (idx > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[idx - 1])) {
        toRemove.add(username);
        return;
      }
      // 右边界：@username 后若仍是用户名字符，则它只是更长 username 的前缀。
      final after = idx + atUsername.length;
      if (after < text.length &&
          RegExp(r'[A-Za-z0-9_.\-]').hasMatch(text[after])) {
        toRemove.add(username);
      }
    });
    for (final u in toRemove) {
      _mentionUserIds.remove(u);
    }
  }

  /// 从光标位置向前查找最近的合法 @token。
  /// 返回 (start, query)：start 是含 @ 的起始 offset，query 是不含 @ 的查询串。
  /// 只输了一个 @（query 为空）时返回 null —— 不弹面板。
  ({int start, String query})? _detectMentionToken() {
    final text = _replyController.text;
    final selection = _replyController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return null;

    // 1. 从光标向前找最近的 '@'
    int i = cursor - 1;
    while (i >= 0) {
      final ch = text[i];
      if (ch == '@') break;
      // token 内部只允许字母 / 数字 / 下划线；遇到空格或标点 → 非 token
      if (!RegExp(r'[A-Za-z0-9_]').hasMatch(ch)) return null;
      i--;
    }
    if (i < 0) return null; // 没找到 @

    // 2. @ 前必须是边界（排除 alice@bob 这种邮箱场景）
    if (i > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[i - 1])) return null;

    // 3. 提取 @ 和光标之间的字符作为 query
    final query = text.substring(i + 1, cursor);
    if (query.isEmpty) return null; // 只输了一个 @，不弹
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(query)) return null;
    return (start: i, query: query);
  }

  /// 调用服务端接口搜索用户并显示面板（带 250ms 防抖）。
  /// 用户连续输入时只发最后一次请求；接口失败 / 空结果 → 关闭面板。
  void _filterAndShow(String query) {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      try {
        final users = await SearchService(apiClient: getIt())
            .searchMentionUsers(query);
        if (!mounted) return;
        if (users.isEmpty) {
          _hideOverlay();
          return;
        }
        _filteredUsers = users;
        _showOverlay();
      } catch (_) {
        if (!mounted) return;
        _hideOverlay();
      }
    });
  }

  /// 创建并插入用户选择面板（通过 LayerLink 锚定到 TextField 下方）。
  void _showOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;

    final overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.of(ctx).size.width - 28,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: MentionOverlay(
            users: _filteredUsers,
            onSelected: _onUserSelected,
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
    _mentionOverlay = overlay;
  }

  /// 关闭用户选择面板。
  void _hideOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
    _filteredUsers = const [];
  }

  /// 选中某个用户后，把光标前的 @xxx 替换为 `@username `（含尾随空格），
  /// 光标移到空格之后，关闭面板；同时记录 username → userId。
  void _onUserSelected(UserInfo user) {
    if (_mentionTokenStart < 0) {
      _hideOverlay();
      return;
    }
    final text = _replyController.text;
    final cursor = _replyController.selection.baseOffset;
    final replacement = '@${user.username} ';
    final newText = text.replaceRange(_mentionTokenStart, cursor, replacement);
    _replyController.text = newText;
    final newCursor = _mentionTokenStart + replacement.length;
    _replyController.selection = TextSelection.collapsed(offset: newCursor);
    _mentionTokenStart = -1;
    if (user.username.isNotEmpty && user.userId > 0) {
      _mentionUserIds[user.username] = user.userId;
    }
    _hideOverlay();
  }

  Future<void> _loadData() async {
    try {
      if (_post == null) {
        final apiPost = await postService.getPostDetail(widget.postId);
        if (mounted) {
          setState(() {
            _post = PostModel(
              key: apiPost.id,
              postId: apiPost.id,
              bio: apiPost.content,
              createdAt: apiPost.createdAt.toIso8601String(),
              imagePath: apiPost.imageUrl,
              mediaList: apiPost.mediaList
                  .map((m) => m.toMediaItemModel())
                  .toList(),
              user: UserModel(
                userId: apiPost.userId,
                userName: apiPost.username,
                displayName: apiPost.displayName,
                profilePic: apiPost.profilePic,
              ),
              likesCount: apiPost.likesCount,
              repliesCount: apiPost.repliesCount,
              repostsCount: apiPost.repostsCount,
              sharesCount: apiPost.sharesCount,
              isLiked: apiPost.isLiked,
              isSaved: apiPost.isSaved,
              isReposted: apiPost.isReposted,
              pollData: apiPost.pollData,
              location: apiPost.location,
              isPinned: apiPost.isPinned,
            );
          });
        }
      }
      await _loadReplies();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadReplies() async {
    try {
      print('[REPLY_DEBUG] _loadReplies called, postId: ${widget.postId}, page: $_currentPage');
      final replies = await postService.getReplies(widget.postId, page: _currentPage);
      print('[REPLY_DEBUG] _loadReplies got ${replies.length} replies');
      if (mounted) {
        setState(() {
          _replies = replies;
          _hasMore = replies.length >= 20;
        });
      }
    } catch (e) {
      print('[REPLY_DEBUG] _loadReplies FAILED: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _currentPage++;
    try {
      final replies = await postService.getReplies(widget.postId, page: _currentPage);
      if (mounted) {
        setState(() {
          _replies.addAll(replies);
          _hasMore = replies.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      _currentPage--;
      _isLoadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.back, color: appColors.textPrimary),
              Text(
                AppLocalizations.of(context)!.back,
                style: TextStyle(color: appColors.textPrimary, fontSize: 16),
              ),
            ],
          ),
        ),
        leadingWidth: 80,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.postDetail,
          style: TextStyle(color: appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: appColors.textPrimary))
                : RefreshIndicator(
                    color: appColors.textPrimary,
                    backgroundColor: appColors.background,
                    onRefresh: () async {
                      _currentPage = 1;
                      _hasMore = true;
                      await _loadData();
                    },
                    child: CustomScrollView(
                      slivers: [
                        // Post content
                        SliverToBoxAdapter(child: _buildPostContent(context)),
                        // Divider
                        SliverToBoxAdapter(
                          child: Divider(color: appColors.divider, height: 0.5),
                        ),
                        // Replies
                        if (_replies.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.noRepliesYet,
                                style: TextStyle(color: appColors.textHint),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == _replies.length) {
                                  if (_hasMore) _loadMore();
                                  return Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: appColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return _buildReplyWithChildren(context, _replies[index]);
                              },
                              childCount: _replies.length + (_hasMore ? 1 : 0),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          // Bottom reply input bar
          _buildReplyInputBar(context),
        ],
      ),
    );
  }

  Widget _buildPostContent(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (_post == null) return SizedBox.shrink();
    final post = _post!;
    final user = post.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName ?? '';
    // 优先使用 effectiveMediaItems（统一处理 image / video / gif），
    // 兼容老接口 imagePath（纯图帖子）
    final mediaItems = post.effectiveMediaItems;
    final hasMedia = mediaItems.isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(context, profilePic, 35),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            post.bio ?? '',
            style: TextStyle(color: appColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
          ),
          if (post.pollData != null) ...[
            SizedBox(height: 12),
            Consumer<PostState>(
              builder: (context, postState, _) {
                PollData pollData = post.pollData!;
                try {
                  final feedPost = postState.feedlist?.firstWhere(
                    (p) => p.postId == widget.postId || p.key == widget.postId,
                  );
                  if (feedPost?.pollData != null) {
                    pollData = feedPost!.pollData!;
                  }
                } catch (_) {}
                return PollWidget(
                  postId: widget.postId,
                  pollData: pollData,
                  padding: EdgeInsets.zero,
                );
              },
            ),
          ],
          if (hasMedia && post.pollData == null) ...[
            SizedBox(height: 12),
            _buildMediaGallery(context, appColors, mediaItems),
          ],
          // 引用区（被引用的原帖）—— 与信息流共用 QuoteCard，视频支持内联播放
          if (post.quoteRepostId != null) ...[
            SizedBox(height: 12),
            QuoteCard(parentPost: post),
          ],
          if (post.location != null && post.location!.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: appColors.textMuted),
                SizedBox(width: 4),
                Text(post.location!, style: TextStyle(color: appColors.textMuted, fontSize: 13)),
              ],
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: post.isLiked == true ? appColors.like : appColors.textMuted),
              SizedBox(width: 4),
              Text('${post.likesCount ?? 0}', style: TextStyle(color: appColors.textMuted, fontSize: 13)),
              SizedBox(width: 16),
              Text(AppLocalizations.of(context)!.replyCount(post.repliesCount ?? 0), style: TextStyle(color: appColors.textMuted, fontSize: 13)),
              SizedBox(width: 16),
              Text(AppLocalizations.of(context)!.repostCount(post.repostsCount ?? 0), style: TextStyle(color: appColors.textMuted, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  /// 详情页媒体画廊：
  /// - 1 张：单图铺满宽
  /// - 多张：3 列 Grid
  /// - 视频：缩略图 + ▶ 角标 + 时长
  /// - 点击任一 → MediaViewerPage 全屏预览（已支持 video）
  Widget _buildMediaGallery(
    BuildContext context,
    AppColors appColors,
    List<MediaItemModel> items,
  ) {
    if (items.length == 1) {
      return _buildSingleMediaItem(context, appColors, items.first, 0, items);
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: [
        for (int i = 0; i < items.length; i++)
          _buildGridMediaItem(context, appColors, items[i], i, items),
      ],
    );
  }

  Widget _buildSingleMediaItem(
    BuildContext context,
    AppColors appColors,
    MediaItemModel item,
    int index,
    List<MediaItemModel> all,
  ) {
    // 视频：接入 InlineVideoPlayer 内联播放（与信息流一致），点击进全屏预览。
    // 不再用 thumb_url 当海报 —— 后端 video 帖 thumb_url 常为空串，会导致 broken_image。
    if (item.isVideo) {
      final videoUrl = item.url;
      return GestureDetector(
        onTap: () => _openMediaViewer(context, all, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: (videoUrl == null || videoUrl.isEmpty)
                ? Container(
                    color: appColors.surface,
                    child: Center(
                      child: Icon(Icons.videocam_off_outlined,
                          color: appColors.textSecondary, size: 32),
                    ),
                  )
                : InlineVideoPlayer(
                    mediaKey: 'detail_video_${widget.postId}_$index',
                    videoUrl: videoUrl,
                    thumbUrl: item.thumbUrl,
                    durationLabel: item.durationLabel,
                  ),
          ),
        ),
      );
    }
    // 图片
    final url = item.thumbUrl ?? item.url;
    return GestureDetector(
      onTap: () => _openMediaViewer(context, all, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: appColors.surface,
                  child: Icon(Icons.broken_image, color: appColors.textSecondary),
                ),
              )
            : Container(
                height: 200,
                color: appColors.surface,
                child: Icon(Icons.broken_image, color: appColors.textSecondary),
              ),
      ),
    );
  }

  Widget _buildGridMediaItem(
    BuildContext context,
    AppColors appColors,
    MediaItemModel item,
    int index,
    List<MediaItemModel> all,
  ) {
    // 视频：InlineVideoPlayer 内联播放（网格小图关掉静音开关）
    if (item.isVideo) {
      final videoUrl = item.url;
      return GestureDetector(
        onTap: () => _openMediaViewer(context, all, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: (videoUrl == null || videoUrl.isEmpty)
              ? Container(
                  color: appColors.surface,
                  child: Center(
                    child: Icon(Icons.videocam_off_outlined,
                        color: appColors.textSecondary, size: 20),
                  ),
                )
              : InlineVideoPlayer(
                  mediaKey: 'detail_video_${widget.postId}_$index',
                  videoUrl: videoUrl,
                  thumbUrl: item.thumbUrl,
                  durationLabel: item.durationLabel,
                  showMuteToggle: false,
                ),
        ),
      );
    }
    // 图片
    final url = item.thumbUrl ?? item.url;
    return GestureDetector(
      onTap: () => _openMediaViewer(context, all, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.broken_image,
                      color: appColors.textSecondary, size: 16),
                ),
              )
            : Container(
                color: appColors.surface,
                child: Icon(Icons.broken_image,
                    color: appColors.textSecondary, size: 16),
              ),
      ),
    );
  }

  void _openMediaViewer(
    BuildContext context,
    List<MediaItemModel> items,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(
          mediaItems: items,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildReplyItem(BuildContext context, Reply reply) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final profilePic = reply.profilePic ?? '';
    final canDelete = _canDeleteReply(reply);
    // 一级回复(parentId == null)才能触发 onTap,二级回复硬约束不可再回复。
    final canTapToReply = reply.parentId == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showReplyOptions(reply),
      onTap: canTapToReply ? () => _openReplySheet(reply) : null,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(context, profilePic, 32),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reply.displayName,
                            style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatTime(reply.createdAt),
                            style: TextStyle(color: appColors.textHint, fontSize: 12),
                          ),
                          if (reply.isPinned) ...[
                            SizedBox(width: 8),
                            Icon(Icons.push_pin, size: 12, color: appColors.textSecondary),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        reply.content,
                        style: TextStyle(color: appColors.textPrimary, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final old = reply;
                              final newLiked = !old.isLiked;
                              // 乐观更新：先翻转本地 isLiked / likesCount，让心形即时变红。
                              setState(() {
                                final idx = _replies.indexWhere((r) => r.id == old.id);
                                if (idx != -1) {
                                  _replies[idx] = old.copyWith(
                                    isLiked: newLiked,
                                    likesCount: newLiked
                                        ? old.likesCount + 1
                                        : (old.likesCount > 0 ? old.likesCount - 1 : 0),
                                  );
                                }
                              });
                              try {
                                if (old.isLiked) {
                                  await postService.unlikeReply(old.id);
                                } else {
                                  await postService.likeReply(old.id);
                                }
                              } catch (_) {
                                // 接口失败：回滚到点赞前状态。
                                if (mounted) {
                                  setState(() {
                                    final idx = _replies.indexWhere((r) => r.id == old.id);
                                    if (idx != -1) _replies[idx] = old;
                                  });
                                }
                              }
                            },
                            child: Icon(
                              reply.isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: reply.isLiked ? appColors.like : appColors.textMuted,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('${reply.likesCount}', style: TextStyle(color: appColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  PopupMenuButton<String>(
                    tooltip: AppLocalizations.of(context)!.deleteReply,
                    icon: Icon(Icons.more_horiz,
                        color: appColors.textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    color: appColors.surface,
                    position: PopupMenuPosition.under,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeleteReply(reply);
                      }
                    },
                    itemBuilder: (menuContext) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.delete,
                                color: appColors.like, size: 18),
                            SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(menuContext)!.deleteReply,
                              style: TextStyle(
                                color: appColors.like,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // 「查看 N 条回复 / 收起回复」按钮(仅一级回复且有子回复时显示)
          if (canTapToReply && reply.repliesCount > 0)
            _buildViewRepliesButton(context, reply),
          Divider(color: appColors.divider, height: 0.5, indent: 54),
        ],
      ),
    );
  }

  /// 「查看 N 条回复 / 收起回复」按钮。
  /// 视觉:左侧一根细线 + 向下回旋图标 + 文本,
  /// 与父回复 content 起始位置对齐(左缩进 58),与子回复缩进一致。
  Widget _buildViewRepliesButton(BuildContext context, Reply parent) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    // 通过 watch 拿到 PostState 来切换文案(避免 listen:false 后无法 rebuild)。
    final postState = context.watch<PostState>();
    final isExpanded = postState.isParentExpanded(parent.id);
    return Padding(
      padding: const EdgeInsets.only(left: 58, bottom: 4, top: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleChildReplies(parent),
        child: Row(
          children: [
            Container(width: 24, height: 1, color: appColors.divider),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.arrow_turn_down_left,
              size: 12,
              color: appColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              isExpanded
                  ? l10n.hideReplies
                  : l10n.viewReplies(parent.repliesCount),
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换某父回复的子回复展开/收起状态。
  void _toggleChildReplies(Reply parent) {
    final postState = Provider.of<PostState>(context, listen: false);
    if (postState.isParentExpanded(parent.id)) {
      postState.collapseChildReplies(parent.id);
    } else {
      // 触发异步加载,UI 状态由 PostState 通过 Consumer 自动刷新。
      postState
          .loadChildReplies(
            postId: widget.postId,
            parentReplyId: parent.id,
          )
          .catchError((e) {
        if (!mounted) return;
        NetworkErrorNotifier.showApiError(e);
      });
    }
  }

  /// 打开回复弹层。
  /// 等待弹层关闭后,根据返回结果(嵌套回复提交成功)同步父级 repliesCount 到本地 _replies。
  Future<void> _openReplySheet(Reply parent) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors.background,
      builder: (ctx) => ReplyBottomSheet(
        postId: widget.postId,
        parentReply: parent,
      ),
    );
    // result == true 表示成功创建了嵌套回复,本地把父级 repliesCount +1
    if (result == true && mounted) {
      setState(() {
        final idx = _replies.indexWhere((r) => r.id == parent.id);
        if (idx != -1) {
          _replies[idx] = _replies[idx].copyWith(
            repliesCount: _replies[idx].repliesCount + 1,
          );
        }
      });
    }
  }

  /// 把一级回复和其(已展开的)子回复组合成一个 widget,
  /// 作为 SliverList 的子项。
  Widget _buildReplyWithChildren(BuildContext context, Reply parent) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    // 嵌套回复视图:子列表来自 PostState (跨 widget 共享)。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReplyItem(context, parent),
        // 通过 Consumer 订阅 PostState,展开/收起/数据变化时自动 rebuild
        Consumer<PostState>(
          builder: (context, postState, _) {
            if (!postState.isParentExpanded(parent.id)) {
              return const SizedBox.shrink();
            }
            final children = postState.childRepliesFor(parent.id);
            final isLoading = postState.isChildLoading(parent.id);
            final hasMore = postState.childHasMore(parent.id);
            if (isLoading && children.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 54),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appColors.textSecondary,
                    ),
                  ),
                ),
              );
            }
            if (children.isEmpty) {
              // 已展开但暂无子回复(可能全部被删)
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in children)
                  _buildChildReplyItem(context, child),
                if (hasMore)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => postState.loadMoreChildReplies(
                      postId: widget.postId,
                      parentReplyId: parent.id,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 58, top: 4, bottom: 12),
                      child: Text(
                        AppLocalizations.of(context)!.loadMoreReplies,
                        style: TextStyle(
                          color: appColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 渲染子(二级)回复。
  /// 视觉:头像 26(比一级小),左缩进 58(=父 padding 16 + 父 avatar 32 + 父 gap 10),
  /// 与父回复 content 起始位置对齐,形成「父→缩进的子」树状嵌套;
  /// 不绑 onTap(硬约束:二级不允许再被回复),不支持展开。
  Widget _buildChildReplyItem(BuildContext context, Reply child) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final profilePic = child.profilePic ?? '';
    final canDelete = _canDeleteReply(child);
    return Padding(
      padding: const EdgeInsets.only(left: 58, right: 16, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(context, profilePic, 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      child.displayName,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(child.createdAt),
                      style: TextStyle(color: appColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  child.content,
                  style: TextStyle(color: appColors.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final postState = Provider.of<PostState>(context, listen: false);
                    final old = child;
                    final newLiked = !old.isLiked;
                    // 乐观更新：二级回复数据源在 PostState，复用 updateReplyInLists
                    // 同步翻转 isLiked / likesCount，Consumer 自动 rebuild 让心形即时变红。
                    postState.updateReplyInLists(old.copyWith(
                      isLiked: newLiked,
                      likesCount: newLiked
                          ? old.likesCount + 1
                          : (old.likesCount > 0 ? old.likesCount - 1 : 0),
                    ));
                    try {
                      if (old.isLiked) {
                        await postService.unlikeReply(old.id);
                      } else {
                        await postService.likeReply(old.id);
                      }
                    } catch (_) {
                      // 接口失败：回滚到点赞前状态。
                      postState.updateReplyInLists(old);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        child.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: child.isLiked ? appColors.like : appColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${child.likesCount}',
                        style: TextStyle(color: appColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            GestureDetector(
              onTap: () => _confirmDeleteReply(child),
              child: Icon(
                Icons.more_horiz,
                color: appColors.textMuted,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  /// 长按回复弹出操作菜单。当前仅评论作者本人与帖子作者可见"删除"项。
  void _showReplyOptions(Reply reply) {
    if (!_canDeleteReply(reply)) return;

    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: appColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                CupertinoIcons.delete,
                color: appColors.like,
                size: 22,
              ),
              title: Text(
                l10n.deleteReply,
                style: TextStyle(
                  color: appColors.like,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteReply(reply);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 删除前二次确认。
  Future<void> _confirmDeleteReply(Reply reply) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteReply),
        content: Text(l10n.deleteReplyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.deleteReply,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteReply(reply);
    }
  }

  /// 调用接口删除回复，成功后从本地列表移除并同步帖子回复计数。
  /// 还会清理 PostState 中的嵌套回复缓存(子回复列表、展开态等)。
  Future<void> _deleteReply(Reply reply) async {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final postState = Provider.of<PostState>(context, listen: false);
    final wasParent = reply.parentId == null;
    try {
      await postService.deleteReply(reply.id);
      if (!mounted) return;
      setState(() {
        _replies.removeWhere((r) => r.id == reply.id);
      });
      // 清理 PostState 嵌套回复缓存
      postState.removeReply(reply.id);
      // 只有一级回复删除才计入帖子总回复数 -1
      if (wasParent) {
        postState.decrementReplyCount(widget.postId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.replyDeleted),
          backgroundColor: appColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      NetworkErrorNotifier.showApiError(e);
    }
  }

  Widget _buildAvatar(BuildContext context, String url, double size) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (url.isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: appColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: size * 0.6, color: appColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: CachedNetworkImage(imageUrl: url, height: size, width: size, fit: BoxFit.cover),
    );
  }

  String _formatTime(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.month}/${dt.day}';
  }

  /// 当前用户是否有权删除这条回复。
  /// - 是回复作者本人；或
  /// - 是帖子作者（帖子作者对其帖子下所有回复拥有删除权限，符合 API 规范）。
  bool _canDeleteReply(Reply reply) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final myUserId = authState.userId;
    if (myUserId.isEmpty) return false;

    // 1. 回复作者本人
    if (myUserId == reply.userId.toString()) return true;

    // 2. 帖子作者（post 已加载完毕的前提下）
    final postAuthorId = _post?.user?.userId;
    if (postAuthorId != null && postAuthorId.toString() == myUserId) {
      return true;
    }
    return false;
  }

  Widget _buildReplyInputBar(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: appColors.background,
        border: Border(top: BorderSide(color: appColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                style: TextStyle(color: appColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.writeAReply,
                  hintStyle: TextStyle(color: appColors.textSecondary),
                  filled: true,
                  fillColor: appColors.surface,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postReply(),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 36,
            child: _isPosting
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appColors.textPrimary,
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _postReply,
                    icon: Icon(Iconsax.send_2, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: appColors.textPrimary,
                      foregroundColor: appColors.background,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _postReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    // 先同步一次 mention 集合（用户可能直接点发送而未触发最后一次文本变化），
    // 再把被提及用户的 userId 列表随回复一起提交（服务端字段 mentioned_user_ids）。
    _syncMentionUserIds();
    final mentionedUserIds = _mentionUserIds.values.toList();

    setState(() => _isPosting = true);
    try {
      final newReply = await postService.createReply(
        postId: widget.postId,
        content: content,
        mentionedUserIds: mentionedUserIds,
      );
      if (mounted) {
        Provider.of<PostState>(context, listen: false)
            .incrementReplyCount(widget.postId);
        setState(() {
          _replies.insert(0, newReply);
          _replyController.clear();
          _isPosting = false;
          if (_post != null) {
            _post = _post!.copyWith(
              repliesCount: (_post!.repliesCount ?? 0) + 1,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        NetworkErrorNotifier.showApiError(e);
      }
    }
  }
}
