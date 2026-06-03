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
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/pages/community/community_members_page.dart';
import 'package:threads/theme/app_colors.dart';

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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        title: Consumer<CommunityState>(
          builder: (context, state, _) {
            return Text(
              state.communityDetail?.name ?? widget.communityName ?? '',
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        actions: [
          GestureDetector(
            onTap: () => _showMoreMenu(context),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.more_vert, color: appColors.textPrimary),
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
            color: appColors.textPrimary,
            backgroundColor: appColors.background,
            onRefresh: _onRefresh,
            child: ListView(
              children: [
                _buildHeader(state, appColors),
                const SizedBox(height: 12),
                Divider(
                    color: appColors.divider, height: 0.5),
                _buildTabBar(state, appColors),
                const SizedBox(height: 8),
                _buildTabContent(state, appColors),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== Header ====================

  Widget _buildHeader(CommunityState state, AppColors appColors) {
    final detail = state.communityDetail;
    if (detail == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (detail.coverUrl != null && detail.coverUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: detail.coverUrl!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _buildCoverPlaceholder(appColors),
                  )
                : _buildCoverPlaceholder(appColors),
          ),
          const SizedBox(height: 12),
          // Community name
          Text(
            detail.name,
            style: TextStyle(
              color: appColors.textPrimary,
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
                color: appColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _buildStatItem('${detail.membersCount}', ' ${AppLocalizations.of(context)!.members.toLowerCase()}', appColors),
              const SizedBox(width: 16),
              _buildStatItem('${detail.postsCount}', ' ${AppLocalizations.of(context)!.posts.toLowerCase()}', appColors),
            ],
          ),
          const SizedBox(height: 16),
          // Join / Leave button
          _buildJoinButton(state, appColors),
        ],
      ),
    );
  }
  Widget _buildCoverPlaceholder(AppColors appColors) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: appColors.surfaceSecondary,
      ),
      child: Center(
        child: Icon(
          Icons.groups_outlined,
          size: 48,
          color: appColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, AppColors appColors) {
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
            style: TextStyle(color: appColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(CommunityState state, AppColors appColors) {
    final detail = state.communityDetail;
    if (detail == null) return const SizedBox.shrink();
    final isJoined = detail.isJoined;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          color: isJoined
              ? appColors.surfaceSecondary
              : (isDark ? Colors.white : Colors.black),
          borderRadius: BorderRadius.circular(10),
          border: isJoined
              ? Border.all(color: appColors.divider, width: 0.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          isJoined
              ? AppLocalizations.of(context)!.joined
              : AppLocalizations.of(context)!.joinCommunity,
          style: TextStyle(
            color: isJoined
                ? appColors.textPrimary
                : (isDark ? Colors.black : Colors.white),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ==================== Tab Bar ====================

  Widget _buildTabBar(CommunityState state, AppColors appColors) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
        },
        isScrollable: false,
        labelColor: appColors.textPrimary,
        unselectedLabelColor: appColors.textSecondary,
        indicatorColor: appColors.textPrimary,
        indicatorWeight: 1,
        tabs: [
          Tab(
            child: Text(
              AppLocalizations.of(context)!.posts,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tab(
            child: Text(
              AppLocalizations.of(context)!.members,
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

  Widget _buildTabContent(CommunityState state, AppColors appColors) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(state, appColors),
          _buildMembersTab(state, appColors),
        ],
      ),
    );
  }

  // ==================== Posts Tab ====================

  Widget _buildPostsTab(CommunityState state, AppColors appColors) {
    final posts = state.communityPosts;

    if (posts.isEmpty && !state.isLoadingPosts) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context)!.noCommunityPosts,
          style: TextStyle(
            color: appColors.textHint,
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

  Widget _buildMembersTab(CommunityState state, AppColors appColors) {
    final members = state.members;

    if (members.isEmpty && !state.isLoadingMembers) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context)!.noCommunityMembers,
          style: TextStyle(
            color: appColors.textHint,
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
                  AppLocalizations.of(context)!.seeAllMembers,
                  style: TextStyle(
                    color: appColors.accent,
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
            separatorBuilder: (_, __) => Divider(
              height: 0.5,
              color: appColors.divider,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              if (index == members.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              return _buildMemberItem(members[index], appColors);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(CommunityMember member, AppColors appColors) {
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
            _buildMemberAvatar(member, appColors),
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
                          style: TextStyle(
                            color: appColors.textPrimary,
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
                            color: appColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.admin,
                            style: TextStyle(
                              color: appColors.accent,
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
                        color: appColors.textMuted,
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

  Widget _buildMemberAvatar(CommunityMember member, AppColors appColors) {
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(member.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: appColors.divider,
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: TextStyle(color: appColors.textPrimary, fontSize: 16),
      ),
    );
  }

  // ==================== More Menu ====================

  void _showMoreMenu(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceSecondary,
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
                    color: appColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // View all members
              ListTile(
                leading: Icon(Icons.people_outline,
                    color: appColors.textPrimary),
                title: Text(
                  AppLocalizations.of(context)!.viewAllMembers,
                  style: TextStyle(color: appColors.textPrimary),
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceSecondary,
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
                    color: appColors.textSecondary,
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
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(
                  color: appColors.divider, height: 0.5),
              // Set / Remove champion
              if (member.isChampion)
                ListTile(
                  leading: const Icon(Icons.star_outline,
                      color: Colors.amber),
                  title: Text(
                    AppLocalizations.of(context)!.removeChampion,
                    style: TextStyle(color: appColors.textPrimary),
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
                  title: Text(
                    AppLocalizations.of(context)!.setChampion,
                    style: TextStyle(color: appColors.textPrimary),
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
