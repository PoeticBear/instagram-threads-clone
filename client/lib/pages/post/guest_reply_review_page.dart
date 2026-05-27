import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/services/post_service.dart';

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request.'),
            backgroundColor: Colors.red,
          ),
        );
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.guestReplyReviewTitle,
          style: const TextStyle(
            color: Colors.white,
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
                    style: const TextStyle(
                      color: Color(0xff888888),
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: const Color(0xff222222),
                  color: Colors.white,
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: Color(0xff333333),
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
                        style: const TextStyle(
                          color: Colors.white,
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
                        style: const TextStyle(
                          color: Color(0xff555555),
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
                    style: const TextStyle(
                      color: Color(0xff888888),
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
                      color: Colors.green,
                      onTap: () => _approveRequest(request),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      label: l10n.reject,
                      icon: CupertinoIcons.xmark_circle_fill,
                      color: Colors.red,
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
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xff1a1a1a),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        CupertinoIcons.person_fill,
        color: Color(0xff888888),
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
