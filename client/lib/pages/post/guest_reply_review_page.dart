import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/theme/app_colors.dart';

class GuestReplyReviewPage extends StatefulWidget {
  final String postId;

  const GuestReplyReviewPage({super.key, required this.postId});

  @override
  State<GuestReplyReviewPage> createState() => _GuestReplyReviewPageState();
}

class _GuestReplyReviewPageState extends State<GuestReplyReviewPage> {
  List<GuestReplyRequest> _requests = [];
  bool _isLoading = true;
  late PostService _postService;

  @override
  void initState() {
    super.initState();
    _postService = PostService(apiClient: getIt<ApiClient>());
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _postService.getPendingGuestReplies(widget.postId);
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveRequest(GuestReplyRequest request) async {
    try {
      await _postService.approveGuestReply(request.postId);
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
        });
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.showApiError(e);
      }
    }
  }

  Future<void> _rejectRequest(GuestReplyRequest request) async {
    try {
      await _postService.rejectGuestReply(request.postId);
      if (mounted) {
        setState(() {
          _requests.removeWhere((r) => r.id == request.id);
        });
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.showApiError(e);
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
          l10n.guestReplyReviewTitle,
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _requests.isEmpty
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
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: appColors.divider,
                        height: 0.5,
                        thickness: 0.5,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return _buildRequestTile(request, l10n);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequestTile(GuestReplyRequest request, AppLocalizations l10n) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final displayName = request.displayName?.isNotEmpty == true
        ? request.displayName!
        : request.username;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: request.avatarUrl != null && request.avatarUrl!.isNotEmpty
                ? Image.network(
                    request.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
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
                        displayName,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (request.createTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        request.createTime!,
                        style: TextStyle(
                          color: appColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Content preview
                if (request.content != null && request.content!.isNotEmpty)
                  Text(
                    request.content!,
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
                      onTap: () => _approveRequest(request),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      label: l10n.reject,
                      icon: CupertinoIcons.xmark_circle_fill,
                      color: appColors.destructive,
                      onTap: () => _rejectRequest(request),
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
