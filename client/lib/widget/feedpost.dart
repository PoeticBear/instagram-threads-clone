import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
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
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/poll_widget.dart';
import 'package:threads/pages/media/media_viewer_page.dart';
import 'package:threads/pages/post/post_detail_page.dart';
import 'package:threads/widget/edit_history_sheet.dart';
import 'package:threads/widget/reply_bottom_sheet.dart';

// ignore: must_be_immutable
class FeedPostWidget extends StatefulWidget {
  PostModel postModel;
  FeedPostWidget({required this.postModel, super.key});

  @override
  State<FeedPostWidget> createState() => _FeedPostWidgetState();
}

class _FeedPostWidgetState extends State<FeedPostWidget> {
  PostModel? _fetchedQuotePost;
  bool _isFetchingQuote = false;

  /// 被引用帖子的有效数据：优先用已有 quotePost，否则用兜底拉取的
  PostModel? get _effectiveQuotePost =>
      widget.postModel.quotePost ?? _fetchedQuotePost;

  @override
  void initState() {
    super.initState();
    _maybeFetchQuotePost();
  }

  /// 当 quote_post_id 有值但 quotePost 为空时，拉取被引用帖子的详情
  void _maybeFetchQuotePost() {
    final post = widget.postModel;
    if (post.quotePost != null) return; // 已有数据，无需拉取
    final qid = post.quoteRepostId;
    if (qid == null) return;
    if (_isFetchingQuote) return;

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
    final user = widget.postModel.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.userName?.isNotEmpty == true ? user!.userName! : 'User${user?.userId ?? ''}');
    final hasImage = widget.postModel.imagePath != null &&
        widget.postModel.imagePath!.isNotEmpty;
    final hasPoll = widget.postModel.pollData != null;
    final hasQuoteId = widget.postModel.quoteRepostId != null;
    final quotePost = _effectiveQuotePost;

    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    Widget avatar(String url, double size) {
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
        child: Container(
          height: size,
          width: size,
          child: CachedNetworkImage(imageUrl: url),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        color: appColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: 0.2,
              width: double.infinity,
              color: appColors.divider,
            ),
            Container(
              height: 10,
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: avatar(profilePic, 35),
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
                Text(
                  Utility.getdob(widget.postModel.createdAt, context: context),
                  style: TextStyle(color: appColors.textMuted),
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
              child: Padding(
                padding: EdgeInsets.only(left: 40),
                child: Text(
                  widget.postModel.bio ?? '',
                  style: TextStyle(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w400,
                      fontSize: 16),
                ),
              ),
            ),
            // ── 引用帖子预览卡片 ──
            if (hasQuoteId) ...[
              Container(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 40, right: 10),
                child: _buildQuoteCard(
                  context: context,
                  quotePost: quotePost,
                  appColors: appColors,
                  avatar: avatar,
                ),
              ),
            ],
            GestureDetector(
              onTap: () => _navigateToPostDetail(context),
              child: hasPoll
                ? PollWidget(
                    postId: widget.postModel.id,
                    pollData: widget.postModel.pollData!,
                    padding: EdgeInsets.only(left: 40, right: 10, top: 8),
                  )
                // ── [临时隐藏] 线程连接线设计 (后期需恢复) ──
                // 原始布局: Row 包含左侧竖线(2x300) + 迷你头像(15px) + 右侧图片(300x280)
                // 恢复时删除下方 Padding，取消注释下方 Row 代码块即可
                // : Row(
                //     mainAxisAlignment: MainAxisAlignment.end,
                //     children: [
                //       Container(width: 10),
                //       Column(children: [
                //         Container(width: 2, height: 300, color: appColors.divider),
                //         Container(height: 5),
                //         avatar(profilePic, 15),
                //       ]),
                //       Flexible(
                //         child: Padding(
                //           padding: EdgeInsets.only(left: 48, right: 10),
                //           child: ClipRRect(
                //             borderRadius: BorderRadius.circular(20),
                //             child: CachedNetworkImage(
                //               height: 300, width: 280, fit: BoxFit.cover,
                //               imageUrl: widget.postModel.imagePath!,
                //               placeholder: (context, url) => Container(
                //                 height: 300, width: 280, color: appColors.surface,
                //                 child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: appColors.textSecondary)),
                //               ),
                //               errorWidget: (context, url, error) => Container(
                //                 height: 300, width: 280, color: appColors.surface,
                //                 child: Icon(Icons.broken_image, color: appColors.textSecondary),
                //               ),
                //             ),
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                : SizedBox.shrink(),
            ),
            // ── 帖子图片 ── 点击进入大图预览（不跳转详情页）
            if (!hasPoll && hasImage)
              GestureDetector(
                onTap: () => _openMediaViewer(context),
                child: Padding(
                  padding: EdgeInsets.only(left: 40, right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      height: 300,
                      width: 280,
                      fit: BoxFit.cover,
                      imageUrl: widget.postModel.imagePath!,
                      placeholder: (context, url) => Container(
                        height: 300,
                        width: 280,
                        color: appColors.surface,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appColors.textSecondary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        width: 280,
                        color: appColors.surface,
                        child: Icon(Icons.broken_image, color: appColors.textSecondary),
                      ),
                    ),
                  ),
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

  // ────────────────── 引用帖子卡片 ──────────────────

  Widget _buildQuoteCard({
    required BuildContext context,
    required PostModel? quotePost,
    required AppColors appColors,
    required Widget Function(String, double) avatar,
  }) {
    // 情况 1: 有完整的被引用帖子数据
    if (quotePost != null) {
      final qUser = quotePost.user;
      final qDisplayName = qUser?.displayName?.isNotEmpty == true
          ? qUser!.displayName!
          : (qUser?.userName?.isNotEmpty == true ? qUser!.userName! : '');
      final qAvatar = qUser?.profilePic ?? '';
      final qContent = quotePost.bio ?? '';
      final qHasImage = quotePost.imagePath != null && quotePost.imagePath!.isNotEmpty;

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
                    GestureDetector(
                      onTap: () => _navigateToQuotedUserProfile(context, quotePost),
                      child: avatar(qAvatar, 20),
                    ),
                    Container(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToQuotedUserProfile(context, quotePost),
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
                Text(
                  qContent,
                  style: TextStyle(
                    color: appColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              // 图片
              if (qHasImage) ...[
                Container(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    imageUrl: quotePost.imagePath!,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: appColors.surface,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appColors.textSecondary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 情况 2: 正在加载
    if (_isFetchingQuote) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: appColors.textSecondary),
            ),
            Container(width: 10),
            Text(
              'Loading...',
              style: TextStyle(color: appColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // 情况 3: 加载失败或原帖不可用
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

  /// 打开大图预览：优先用 mediaList，否则用 imagePath 兜底为单图
  void _openMediaViewer(BuildContext context) {
    final mediaList = widget.postModel.mediaList;
    final List<MediaItemModel> items;
    if (mediaList != null && mediaList.isNotEmpty) {
      items = mediaList;
    } else {
      final imagePath = widget.postModel.imagePath;
      if (imagePath == null || imagePath.isEmpty) return;
      items = [
        MediaItemModel(mediaType: MediaType.image, url: imagePath),
      ];
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(mediaItems: items),
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
              _buildSheetOption(
                label: l10n.editPost,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComposePost(
                        onPostSuccess: () {
                          postState.getDataFromDatabase();
                        },
                      ),
                    ),
                  );
                },
              ),
              _buildSheetDivider(),
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
                    final success = await postState.deletePost(postId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? l10n.postDeleted : 'Failed'),
                          backgroundColor: success ? appColors.repost : appColors.destructive,
                          duration: Duration(seconds: 1),
                        ),
                      );
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
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
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.operationFailed),
            backgroundColor: appColors.destructive,
            duration: Duration(seconds: 2),
          ),
        );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.reportFailed)),
                      );
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
