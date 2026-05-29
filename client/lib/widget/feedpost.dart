import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/poll_widget.dart';
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
  @override
  Widget build(BuildContext context) {
    final user = widget.postModel.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName ?? 'Unknown';
    final hasImage = widget.postModel.imagePath != null &&
        widget.postModel.imagePath!.isNotEmpty;
    final hasPoll = widget.postModel.pollData != null;
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

    return Container(
        color: appColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: 0.2,
              width: MediaQuery.of(context).size.width,
              color: appColors.divider,
            ),
            Container(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: avatar(profilePic, 35),
                ),
                Container(
                  width: 5,
                ),
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 4,
                ),
                Text(
                  Utility.getdob(widget.postModel.createdAt),
                  style: TextStyle(color: appColors.textMuted),
                ),
                Container(
                  width: 5,
                ),
                GestureDetector(
                  onTap: () => _showMoreMenu(context),
                  child: Icon(Icons.more_horiz, color: appColors.textPrimary),
                ),
              ],
            ),
            Padding(
                padding: EdgeInsets.only(left: 55),
                child: Text(
                  widget.postModel.bio ?? '',
                  style: TextStyle(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 18),
                )),
            hasPoll
                ? PollWidget(
                    postId: widget.postModel.id,
                    pollData: widget.postModel.pollData!,
                  )
                : !hasImage
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                          ),
                          Column(
                            children: [
                              Container(
                                width: 2,
                                height: 30,
                                color: appColors.divider,
                              ),
                              Container(
                                height: 5,
                          ),
                              avatar(profilePic, 15),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(left: 20, right: 10),
                              child: SizedBox.shrink()),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                          ),
                          Column(
                            children: [
                              Container(
                                width: 2,
                                height: 300,
                                color: appColors.divider,
                              ),
                              Container(
                                height: 5,
                          ),
                              avatar(profilePic, 15),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(left: 48, right: 10),
                              child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: CachedNetworkImage(
                                          height: 300,
                                          width: 290,
                                          fit: BoxFit.cover,
                                          imageUrl: widget.postModel.imagePath!,
                                          placeholder: (context, url) => Container(
                                            height: 300,
                                            width: 290,
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
                                            width: 290,
                                            color: appColors.surface,
                                            child: Icon(Icons.broken_image, color: appColors.textSecondary),
                                          ),
                                      ))),
                        ],
                      ),
            Container(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 50,
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
        ));
  }

  // ==================== Navigation ====================

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          profileId: widget.postModel.user?.userId.toString() ?? '',
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
    final isReposted = widget.postModel.isReposted == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReposted) ...[
              _buildSheetOption(
                label: 'Repost',
                onTap: () {
                  Navigator.pop(context);
                  final state = Provider.of<PostState>(context, listen: false);
                  state.repost(widget.postModel.id);
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: AppLocalizations.of(context)!.quote,
              onTap: () {
                Navigator.pop(context);
                _showQuoteSheet(context);
              },
            ),
            _buildSheetDivider(),
            if (isReposted) ...[
              _buildSheetOption(
                label: 'Undo Repost',
                textColor: appColors.destructive,
                onTap: () {
                  Navigator.pop(context);
                  final state = Provider.of<PostState>(context, listen: false);
                  state.unrepost(widget.postModel.id);
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
                        userId: authState.userId != null ? int.tryParse(authState.userId!) : null,
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
    final postId = widget.postModel.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetOption(
              label: 'Copy Link',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(
                  text: '${ApiConfig.baseUrl}t/$postId',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Link copied to clipboard'),
                    backgroundColor: appColors.surface,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                final state = Provider.of<PostState>(context, listen: false);
                state.sharePost(postId);
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
    final isOwnPost = currentUserId != null && postUserId != null && currentUserId == postUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost) ...[
              _buildSheetOption(
                label: l10n.editPost,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComposePost(
                        onPostSuccess: () {
                          final state = Provider.of<PostState>(context, listen: false);
                          state.getDataFromDatabase();
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
                  Navigator.pop(context);
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
                    final state = Provider.of<PostState>(context, listen: false);
                    final success = await state.deletePost(postId);
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
                  Navigator.pop(context);
                  final state = Provider.of<PostState>(context, listen: false);
                  if (isPinned) {
                    state.unpinPost(postId);
                  } else {
                    state.pinPost(postId);
                  }
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: isSaved ? l10n.unsave : l10n.save,
              onTap: () {
                Navigator.pop(context);
                final state = Provider.of<PostState>(context, listen: false);
                if (isSaved) {
                  state.unsavePost(postId);
                } else {
                  state.savePost(postId);
                }
              },
            ),
            _buildSheetDivider(),
            if (!isOwnPost) ...[
              _buildSheetOption(
                label: l10n.report,
                textColor: appColors.destructive,
                onTap: () {
                  Navigator.pop(context);
                  final state = Provider.of<PostState>(context, listen: false);
                  state.reportPost(postId, reason: 'Inappropriate content');
                },
              ),
              _buildSheetDivider(),
            ],
            _buildSheetOption(
              label: l10n.editHistory,
              onTap: () {
                Navigator.pop(context);
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
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
