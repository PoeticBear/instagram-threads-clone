import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/topic.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/topic.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';

class TopicDetailPage extends StatefulWidget {
  final int topicId;
  final String? topicName;

  const TopicDetailPage({
    Key? key,
    required this.topicId,
    this.topicName,
  }) : super(key: key);

  static PageRouteBuilder getRoute({
    required int topicId,
    String? topicName,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChangeNotifierProvider(
          create: (BuildContext context) => TopicState(topicId),
          child: TopicDetailPage(
            topicId: topicId,
            topicName: topicName,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<TopicState>();
      if (state.hasMorePosts && !state.isLoadingPosts) {
        state.loadMoreTopicPosts();
      }
    }
  }

  /// Convert a [Post] (from post_service) to [PostModel] (used by FeedPostWidget).
  PostModel _postToPostModel(Post post) {
    return PostModel(
      key: post.id,
      postId: post.id,
      bio: post.content,
      imagePath: post.imageUrl,
      createdAt: post.createdAt.toIso8601String(),
      user: UserModel(
        userId: post.user.userId,
        userName: post.user.userName,
        displayName: post.user.displayName,
        profilePic: post.user.profilePic,
      ),
      likesCount: post.likesCount,
      repliesCount: post.repliesCount,
      repostsCount: post.repostsCount,
      sharesCount: post.sharesCount,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      isReposted: post.isReposted,
    );
  }

  Future<void> _onRefresh() async {
    final state = context.read<TopicState>();
    await Future.wait([
      state.loadTopicDetail(),
      state.loadTopicPosts(widget.topicId, sort: state.sort),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        title: Text(
          widget.topicName ?? 'Topic',
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              // Placeholder for more options
            },
            child: Container(
              width: 50,
              height: 50,
              child: Icon(Icons.more_horiz, color: appColors.textPrimary),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<TopicState>(
        builder: (context, state, _) {
          if (state.isBusy) {
            return Center(child: CupertinoActivityIndicator());
          }

          return RefreshIndicator(
            color: appColors.textPrimary,
            backgroundColor: appColors.background,
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              children: [
                _buildTopicHeader(state),
                Container(height: 12),
                Divider(
                    color: appColors.divider, height: 0.5),
                _buildSortTabs(state),
                Container(height: 8),
                _buildPostList(state),
                if (state.relatedTopics.isNotEmpty) ...[
                  Container(height: 16),
                  Divider(
                      color: appColors.divider, height: 0.5),
                  _buildRelatedTopics(state),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== Topic Header ====================

  Widget _buildTopicHeader(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final topic = state.topicDetail;
    final name = topic?.name ?? widget.topicName ?? '';
    final description = topic?.description;
    final postsCount = topic?.postsCount ?? 0;
    final followersCount = topic?.followersCount ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic name
          Text(
            name,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Description
          if (description != null && description.isNotEmpty) ...[
            Container(height: 8),
            Text(
              description,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          Container(height: 12),
          // Stats row
          Row(
            children: [
              _buildStatItem('$postsCount', ' posts'),
              Container(width: 16),
              _buildStatItem('$followersCount', ' followers'),
            ],
          ),
          Container(height: 16),
          // Action buttons row
          Row(
            children: [
              _buildFollowButton(state),
              Container(width: 10),
              _buildMuteButton(state),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: count,
            style: TextStyle(
              color: appColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: label,
            style: TextStyle(color: appColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isFollowing = state.isFollowing;
    return GestureDetector(
      onTap: () {
        if (isFollowing) {
          state.unfollowTopic();
        } else {
          state.followTopic();
        }
      },
      child: Container(
        height: 40,
        width: 150,
        decoration: BoxDecoration(
          color: isFollowing ? appColors.background : appColors.accent,
          borderRadius: BorderRadius.circular(8),
          border: isFollowing
              ? Border.all(color: appColors.border, width: 0.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isMuted = state.isMuted;
    return GestureDetector(
      onTap: () {
        if (isMuted) {
          state.unmuteTopic();
        } else {
          state.muteTopic();
        }
      },
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: appColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appColors.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(
          isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell,
          color: isMuted ? appColors.textSecondary : appColors.textPrimary,
          size: 20,
        ),
      ),
    );
  }

  // ==================== Sort Tabs ====================

  Widget _buildSortTabs(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      width: MediaQuery.of(context).size.width,
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          final sort = index == 0 ? 'hot' : 'latest';
          state.loadTopicPosts(widget.topicId, sort: sort);
        },
        isScrollable: false,
        labelColor: appColors.textPrimary,
        unselectedLabelColor: appColors.textSecondary,
        indicatorColor: appColors.textPrimary,
        indicatorWeight: 1,
        tabs: [
          Tab(
            child: Text(
              'Hot',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Latest',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Post List ====================

  Widget _buildPostList(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final posts = state.topicPosts;

    if (posts.isEmpty && !state.isLoadingPosts) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No posts yet.',
          style: TextStyle(
            color: appColors.textHint,
            fontSize: 15,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < posts.length; i++)
          FeedPostWidget(
            postModel: _postToPostModel(posts[i]),
            key: ValueKey(posts[i].id),
          ),
        if (state.isLoadingPosts)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }

  // ==================== Related Topics ====================

  Widget _buildRelatedTopics(TopicState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final related = state.relatedTopics;
    if (related.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Related Topics',
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: related.length,
              separatorBuilder: (_, __) => Container(width: 10),
              itemBuilder: (context, index) {
                final topic = related[index];
                return _buildRelatedTopicCard(topic);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedTopicCard(TopicInfo topic) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          TopicDetailPage.getRoute(
            topicId: topic.id,
            topicName: topic.name,
          ),
        );
      },
      child: Container(
        width: 140,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appColors.divider,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              topic.name,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Container(height: 4),
            Text(
              '${topic.postsCount} posts',
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
