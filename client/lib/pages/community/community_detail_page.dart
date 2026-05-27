import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/community.module.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/community.state.dart';
import 'package:threads/widget/feedpost.dart';
import 'package:threads/pages/community/community_members_page.dart';

class CommunityDetailPage extends StatefulWidget {
  final int communityId;
  final String? communityName;

  const CommunityDetailPage({
    Key? key,
    required this.communityId,
    this.communityName,
  }) : super(key: key);

  static PageRouteBuilder getRoute({
    required int communityId,
    String? communityName,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return CommunityDetailPage(
          communityId: communityId,
          communityName: communityName,
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
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _membersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _postsScrollController.addListener(_onPostsScroll);
    _membersScrollController.addListener(_onMembersScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<CommunityState>(context, listen: false);
      state.loadCommunityDetail(widget.communityId);
      state.loadCommunityPosts(widget.communityId);
      state.loadMembers(widget.communityId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postsScrollController.removeListener(_onPostsScroll);
    _postsScrollController.dispose();
    _membersScrollController.removeListener(_onMembersScroll);
    _membersScrollController.dispose();
    super.dispose();
  }

  void _onPostsScroll() {
    if (_postsScrollController.position.pixels >=
        _postsScrollController.position.maxScrollExtent - 200) {
      final state = context.read<CommunityState>();
      if (state.hasMorePosts && !state.isLoadingPosts) {
        state.loadMoreCommunityPosts(widget.communityId);
      }
    }
  }

  void _onMembersScroll() {
    if (_membersScrollController.position.pixels >=
        _membersScrollController.position.maxScrollExtent - 200) {
      final state = context.read<CommunityState>();
      if (state.hasMoreMembers && !state.isLoadingMembers) {
        state.loadMoreMembers(widget.communityId);
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
    final state = context.read<CommunityState>();
    await Future.wait([
      state.loadCommunityDetail(widget.communityId),
      state.loadCommunityPosts(widget.communityId),
      state.loadMembers(widget.communityId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: Colors.white),
        ),
        title: Consumer<CommunityState>(
          builder: (context, state, _) {
            return Text(
              state.communityDetail?.name ?? widget.communityName ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        actions: [
          GestureDetector(
            onTap: () => _showMoreMenu(context),
            child: Container(
              width: 50,
              height: 50,
              child: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<CommunityState>(
        builder: (context, state, _) {
          if (state.isLoadingDetail && state.communityDetail == null) {
            return const Center(child: CupertinoActivityIndicator());
          }

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.black,
            onRefresh: _onRefresh,
            child: ListView(
              children: [
                _buildHeader(state),
                const SizedBox(height: 12),
                const Divider(
                    color: Color.fromARGB(255, 46, 46, 46), height: 0.5),
                _buildTabBar(state),
                const SizedBox(height: 8),
                _buildTabContent(state),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== Header ====================

  Widget _buildHeader(CommunityState state) {
    final detail = state.communityDetail;
    if (detail == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          if (detail.coverUrl != null && detail.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: detail.coverUrl!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          // Community name
          Text(
            detail.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Description
          if (detail.description != null &&
              detail.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail.description!,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _buildStatItem('${detail.membersCount}', ' members'),
              const SizedBox(width: 16),
              _buildStatItem('${detail.postsCount}', ' posts'),
            ],
          ),
          const SizedBox(height: 16),
          // Join / Leave button
          _buildJoinButton(state),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: label,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(CommunityState state) {
    final detail = state.communityDetail;
    if (detail == null) return const SizedBox.shrink();
    final isJoined = detail.isJoined;

    return GestureDetector(
      onTap: () {
        if (isJoined) {
          state.leaveCommunity(widget.communityId);
        } else {
          state.joinCommunity(widget.communityId);
        }
      },
      child: Container(
        height: 42,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isJoined ? Colors.black : Colors.blue,
          borderRadius: BorderRadius.circular(10),
          border: isJoined
              ? Border.all(color: Colors.grey, width: 0.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          isJoined ? 'Joined' : 'Join Community',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ==================== Tab Bar ====================

  Widget _buildTabBar(CommunityState state) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
        },
        isScrollable: false,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.white,
        indicatorWeight: 1,
        tabs: [
          Tab(
            child: Text(
              'Posts',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Members',
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

  // ==================== Tab Content ====================

  Widget _buildTabContent(CommunityState state) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(state),
          _buildMembersTab(state),
        ],
      ),
    );
  }

  // ==================== Posts Tab ====================

  Widget _buildPostsTab(CommunityState state) {
    final posts = state.communityPosts;

    if (posts.isEmpty && !state.isLoadingPosts) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No posts yet.',
          style: TextStyle(
            color: Color.fromARGB(255, 63, 63, 63),
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _postsScrollController,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: posts.length + (state.isLoadingPosts ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return FeedPostWidget(
          postModel: _postToPostModel(posts[index]),
          key: ValueKey(posts[index].id),
        );
      },
    );
  }

  // ==================== Members Tab ====================

  Widget _buildMembersTab(CommunityState state) {
    final members = state.members;

    if (members.isEmpty && !state.isLoadingMembers) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No members yet.',
          style: TextStyle(
            color: Color.fromARGB(255, 63, 63, 63),
            fontSize: 15,
          ),
        ),
      );
    }

    return Column(
      children: [
        // "See all members" link
        if (members.length >= 5)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                CommunityMembersPage.getRoute(
                  communityId: widget.communityId,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'See all members',
                  style: TextStyle(
                    color: Colors.blue[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: _membersScrollController,
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: members.length + (state.isLoadingMembers ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(
              height: 0.5,
              color: Color.fromARGB(255, 46, 46, 46),
              indent: 72,
            ),
            itemBuilder: (context, index) {
              if (index == members.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              return _buildMemberItem(members[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(CommunityMember member) {
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;
    final isAdmin = member.role == 2;

    return GestureDetector(
      onLongPress: () => _showMemberOptions(member),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildMemberAvatar(member),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (member.username.isNotEmpty)
                    Text(
                      '@${member.username}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (member.isChampion)
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(CommunityMember member) {
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(member.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey[800],
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  // ==================== More Menu ====================

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 28, 28, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // View all members
              ListTile(
                leading: const Icon(Icons.people_outline,
                    color: Colors.white),
                title: const Text(
                  'View all members',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    this.context,
                    CommunityMembersPage.getRoute(
                      communityId: widget.communityId,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ==================== Member Options (Champion) ====================

  void _showMemberOptions(CommunityMember member) {
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 28, 28, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Member name header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(
                  color: Color.fromARGB(255, 46, 46, 46), height: 0.5),
              // Set / Remove champion
              if (member.isChampion)
                ListTile(
                  leading: const Icon(Icons.star_outline,
                      color: Colors.amber),
                  title: const Text(
                    'Remove Champion',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final state =
                        Provider.of<CommunityState>(this.context,
                            listen: false);
                    state.removeChampion(
                        widget.communityId, member.userId);
                  },
                )
              else
                ListTile(
                  leading:
                      const Icon(Icons.star, color: Colors.amber),
                  title: const Text(
                    'Set as Champion',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final state =
                        Provider.of<CommunityState>(this.context,
                            listen: false);
                    state.setChampion(
                        widget.communityId, member.userId);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
