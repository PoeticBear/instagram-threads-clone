import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/widget/poll_widget.dart';

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

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

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
                                return _buildReplyItem(context, _replies[index]);
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
    final hasImage = post.imagePath != null && post.imagePath!.isNotEmpty;

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
          if (hasImage && post.pollData == null) ...[
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showFullScreenImage(context, post.imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: post.imagePath!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: appColors.surface,
                    child: Icon(Icons.broken_image, color: appColors.textSecondary),
                  ),
                ),
              ),
            ),
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

  Widget _buildReplyItem(BuildContext context, Reply reply) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final profilePic = reply.profilePic ?? '';
    return Column(
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
            ],
          ),
        ),
        Divider(color: appColors.divider, height: 0.5, indent: 54),
      ],
    );
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(CupertinoIcons.xmark, color: Colors.white),
            ),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
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
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              style: TextStyle(color: appColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.writeAReply,
                hintStyle: TextStyle(color: appColors.textSecondary),
                filled: true,
                fillColor: appColors.surface,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

    setState(() => _isPosting = true);
    try {
      final newReply = await postService.createReply(
        postId: widget.postId,
        content: content,
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
    } catch (_) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToPostReply),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
