import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/theme/app_colors.dart';

class ReplyReviewPage extends StatefulWidget {
  final String postId;

  const ReplyReviewPage({super.key, required this.postId});

  @override
  State<ReplyReviewPage> createState() => _ReplyReviewPageState();
}

class _ReplyReviewPageState extends State<ReplyReviewPage> {
  List<Reply> _pendingReplies = [];
  bool _isLoading = true;
  late PostService _postService;

  @override
  void initState() {
    super.initState();
    _postService = PostService(apiClient: getIt<ApiClient>());
    _loadPendingReplies();
  }

  Future<void> _loadPendingReplies() async {
    setState(() => _isLoading = true);
    try {
      final replies = await _postService.getPendingReplies(
        int.tryParse(widget.postId) ?? 0,
      );
      if (mounted) {
        setState(() {
          _pendingReplies = replies;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveReply(Reply reply) async {
    try {
      await _postService.approvePendingReply(
        int.tryParse(widget.postId) ?? 0,
        int.tryParse(reply.id) ?? 0,
      );
      if (mounted) {
        setState(() {
          _pendingReplies.removeWhere((r) => r.id == reply.id);
        });
      }
    } catch (_) {
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve reply.'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _rejectReply(Reply reply) async {
    try {
      await _postService.rejectPendingReply(
        int.tryParse(widget.postId) ?? 0,
        int.tryParse(reply.id) ?? 0,
      );
      if (mounted) {
        setState(() {
          _pendingReplies.removeWhere((r) => r.id == reply.id);
        });
      }
    } catch (_) {
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject reply.'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: appColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pending Replies',
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _pendingReplies.isEmpty
              ? Center(
                  child: Text(
                    l10n.noPendingRequests,
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: appColors.surfaceSecondary,
                  color: appColors.textPrimary,
                  onRefresh: _loadPendingReplies,
                  child: ListView.separated(
                    itemCount: _pendingReplies.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: appColors.divider,
                        height: 0.5,
                        thickness: 0.5,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final reply = _pendingReplies[index];
                      return _buildReplyTile(reply, l10n);
                    },
                  ),
                ),
    );
  }

  Widget _buildReplyTile(Reply reply, AppLocalizations l10n) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(reply.profilePic),
          const SizedBox(width: 12),
          // Content area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.displayName.isNotEmpty ? reply.displayName : reply.username,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Utility.getdob(reply.createdAt.toIso8601String()),
                      style: TextStyle(
                        color: appColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Content preview
                if (reply.content.isNotEmpty)
                  Text(
                    reply.content,
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),
                // Action buttons
                Row(
                  children: [
                    _buildActionButton(
                      label: l10n.approve,
                      icon: CupertinoIcons.checkmark_circle_fill,
                      color: appColors.repost,
                      onTap: () => _approveReply(reply),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      label: l10n.reject,
                      icon: CupertinoIcons.xmark_circle_fill,
                      color: appColors.destructive,
                      onTap: () => _rejectReply(reply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? profilePic) {
    if (profilePic != null && profilePic.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: profilePic,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildDefaultAvatar(),
        ),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        CupertinoIcons.person_fill,
        color: appColors.textMuted,
        size: 20,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
