import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/common/locator.dart';
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

  @override
  void initState() {
    super.initState();
    _post = widget.postModel;
    _loadData();
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
              user: UserModel(
                userId: apiPost.user.userId,
                userName: apiPost.user.userName,
                displayName: apiPost.user.displayName,
                profilePic: apiPost.user.profilePic,
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
      final replies = await postService.getReplies(widget.postId, page: _currentPage);
      if (mounted) {
        setState(() {
          _replies = replies;
          _hasMore = replies.length >= 20;
        });
      }
    } catch (_) {}
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: Colors.black,
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
                    child: Divider(color: Color(0xff333333), height: 0.5),
                  ),
                  // Replies
                  if (_replies.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.noRepliesYet,
                          style: TextStyle(color: Color(0xff555555)),
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
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _buildReplyItem(context, _replies[index]);
                        },
                        childCount: _replies.length + (_hasMore ? 1 : 0),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPostContent(BuildContext context) {
    if (_post == null) return SizedBox.shrink();
    final post = _post!;
    final user = post.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName ?? '';
    final hasImage = post.imagePath != null && post.imagePath!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(profilePic, 35),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.black,
                    builder: (context) => ReplyBottomSheet(postId: widget.postId),
                  );
                },
                child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            post.bio ?? '',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
          ),
          if (hasImage) ...[
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: post.imagePath!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[900],
                  child: Icon(Icons.broken_image, color: Colors.grey[600]),
                ),
              ),
            ),
          ],
          if (post.location != null && post.location!.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Color(0xff888888)),
                SizedBox(width: 4),
                Text(post.location!, style: TextStyle(color: Color(0xff888888), fontSize: 13)),
              ],
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: post.isLiked == true ? Colors.red : Color(0xff888888)),
              SizedBox(width: 4),
              Text('${post.likesCount ?? 0}', style: TextStyle(color: Color(0xff888888), fontSize: 13)),
              SizedBox(width: 16),
              Text('${post.repliesCount ?? 0} replies', style: TextStyle(color: Color(0xff888888), fontSize: 13)),
              SizedBox(width: 16),
              Text('${post.repostsCount ?? 0} reposts', style: TextStyle(color: Color(0xff888888), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(BuildContext context, Reply reply) {
    final profilePic = reply.profilePic ?? '';
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(profilePic, 32),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          reply.displayName,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _formatTime(reply.createdAt),
                          style: TextStyle(color: Color(0xff555555), fontSize: 12),
                        ),
                        if (reply.isPinned) ...[
                          SizedBox(width: 8),
                          Icon(Icons.push_pin, size: 12, color: Colors.grey),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      reply.content,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            try {
                              if (reply.isLiked) {
                                await postService.unlikeReply(reply.id);
                              } else {
                                await postService.likeReply(reply.id);
                              }
                              if (mounted) setState(() {});
                            } catch (_) {}
                          },
                          child: Icon(
                            reply.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: reply.isLiked ? Colors.red : Color(0xff888888),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text('${reply.likesCount}', style: TextStyle(color: Color(0xff888888), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: Color(0xff333333), height: 0.5, indent: 54),
      ],
    );
  }

  Widget _buildAvatar(String url, double size) {
    if (url.isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: CachedNetworkImage(imageUrl: url, height: size, width: size, fit: BoxFit.cover),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
