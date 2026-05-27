import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/post.state.dart';

class ReplyBottomSheet extends StatefulWidget {
  final String postId;

  const ReplyBottomSheet({required this.postId, super.key});

  @override
  State<ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<ReplyBottomSheet> {
  List<Reply> _replies = [];
  bool _isLoading = true;
  bool _isPosting = false;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    try {
      final postService =
          Provider.of<PostState>(context, listen: false).postService;
      final replies = await postService.getReplies(widget.postId);
      if (mounted) {
        setState(() {
          _replies = replies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final postService =
          Provider.of<PostState>(context, listen: false).postService;
      final newReply = await postService.createReply(
        postId: widget.postId,
        content: content,
      );
      if (mounted) {
        setState(() {
          _replies.insert(0, newReply);
          _replyController.clear();
          _isPosting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply'),
            backgroundColor: Colors.grey[900],
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(Reply reply, int index) async {
    final postService =
        Provider.of<PostState>(context, listen: false).postService;

    // Optimistic update
    setState(() {
      _replies[index] = Reply(
        id: reply.id,
        postId: reply.postId,
        userId: reply.userId,
        username: reply.username,
        displayName: reply.displayName,
        profilePic: reply.profilePic,
        content: reply.content,
        imageUrl: reply.imageUrl,
        createdAt: reply.createdAt,
        likesCount: reply.isLiked ? reply.likesCount - 1 : reply.likesCount + 1,
        isLiked: !reply.isLiked,
        isPinned: reply.isPinned,
        isHidden: reply.isHidden,
      );
    });

    try {
      if (reply.isLiked) {
        await postService.unlikeReply(reply.id);
      } else {
        await postService.likeReply(reply.id);
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _replies[index] = reply;
        });
      }
    }
  }

  void _showReplyOptions(Reply reply, int index) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1a1a1a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                reply.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                color: Colors.white,
                size: 22,
              ),
              title: Text(
                reply.isPinned ? 'Unpin reply' : 'Pin reply',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePinReply(reply, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePinReply(Reply reply, int index) async {
    final postState = Provider.of<PostState>(context, listen: false);

    // Optimistic update
    setState(() {
      _replies[index] = Reply(
        id: reply.id,
        postId: reply.postId,
        userId: reply.userId,
        username: reply.username,
        displayName: reply.displayName,
        profilePic: reply.profilePic,
        content: reply.content,
        imageUrl: reply.imageUrl,
        createdAt: reply.createdAt,
        likesCount: reply.likesCount,
        isLiked: reply.isLiked,
        isPinned: !reply.isPinned,
        isHidden: reply.isHidden,
      );
    });

    try {
      final replyId = int.tryParse(reply.id) ?? 0;
      if (reply.isPinned) {
        await postState.unpinReply(replyId);
      } else {
        await postState.pinReply(replyId);
      }
      if (mounted) {
        _sortReplies();
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _replies[index] = reply;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reply.isPinned ? 'Failed to unpin reply' : 'Failed to pin reply'),
            backgroundColor: Colors.grey[900],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Sort replies so pinned ones appear at the top.
  void _sortReplies() {
    setState(() {
      _replies.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    });
  }

  Widget _buildAvatar(String? profilePic) {
    if (profilePic == null || profilePic.isEmpty) {
      return Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 18, color: Colors.grey[600]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 30,
        width: 30,
        child: CachedNetworkImage(imageUrl: profilePic),
      ),
    );
  }

  Widget _buildReplyItem(Reply reply, int index) {
    return GestureDetector(
      onLongPress: () => _showReplyOptions(reply, index),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(reply.profilePic),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        Utility.getdob(reply.createdAt.toIso8601String()),
                        style: TextStyle(
                          color: Color.fromARGB(255, 78, 78, 78),
                          fontSize: 12,
                        ),
                      ),
                      if (reply.isPinned) ...[
                        SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.pin,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    reply.content,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _toggleLike(reply, index),
                    child: Row(
                      children: [
                        Icon(
                          reply.isLiked ? Iconsax.heart5 : Iconsax.heart,
                          size: 14,
                          color: reply.isLiked ? Colors.red : Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${reply.likesCount}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Top drag handle
          Container(
            margin: EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Replies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(
            color: Color.fromARGB(255, 46, 46, 46),
            height: 0.5,
          ),
          // Reply list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[600],
                    ),
                  )
                : _replies.isEmpty
                    ? Center(
                        child: Text(
                          'No replies yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: _replies.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Color.fromARGB(255, 46, 46, 46),
                          height: 0.5,
                          indent: 56,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) =>
                            _buildReplyItem(_replies[index], index),
                      ),
          ),
          Divider(
            color: Color.fromARGB(255, 46, 46, 46),
            height: 0.5,
          ),
          // Bottom input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Color.fromARGB(255, 22, 22, 22),
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
                              color: Colors.white,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _postReply,
                          icon: Icon(Iconsax.send_2, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
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
