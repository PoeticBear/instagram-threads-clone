import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/pages/profile/edit.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/settings.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/profile.state.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/follow_list.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/pages/media/media_viewer_page.dart';
import 'package:threads/pages/follow/follow_list_page.dart';
import 'package:threads/pages/profile/share_profile_sheet.dart';
import 'package:threads/l10n/generated/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    Key? key,
    required this.profileId,
    this.username,
    this.isOwnProfileTab = false,
  }) : super(key: key);

  final String profileId;
  final String? username;
  final bool isOwnProfileTab;

  static PageRouteBuilder getRoute({required String profileId, String? username}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChangeNotifierProvider(
          create: (BuildContext context) => ProfileState(profileId),
          child: ProfilePage(
            profileId: profileId,
            username: username,
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
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostModel> _userPosts = [];
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    final userId = int.tryParse(widget.profileId);
    if (userId == null) return;
    setState(() => _isLoadingPosts = true);
    final postState = Provider.of<PostState>(context, listen: false);
    final posts = await postState.getUserPosts(userId);
    if (mounted) {
      setState(() {
        _userPosts = posts;
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    final state = Provider.of<ProfileState>(context, listen: false);
    await Future.wait([
      state.refresh(),
      _loadUserPosts(),
    ]);
    // After refresh, also update the global AuthState so edit profile changes reflect
    if (widget.isOwnProfileTab && mounted) {
      try {
        final authState = Provider.of<AuthState>(context, listen: false);
        await authState.getProfileUser();
      } catch (_) {}
    }
  }

  void _shareProfile(ProfileState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ShareProfileSheet(
        user: state.profileUserModel ?? UserModel(),
      ),
    );
  }

  /// 解析个人中心顶部要显示的"显示名称"。
  ///
  /// 优先级：
  ///   1) profileUserModel.displayName（用户已设置）
  ///   2) profileUserModel.userName（注册时录入的账号，displayName 未设置时兜底）
  ///   3) widget.username（外部传入的 username，跳转到他人 profile 时使用）
  ///   4) ''（以上都为空时留空，不抛错）
  String _resolveDisplayName(ProfileState state, String? fallbackUsername) {
    final displayName = state.profileUserModel?.displayName ?? '';
    if (displayName.isNotEmpty) return displayName;

    final userName = state.profileUserModel?.userName ?? '';
    if (userName.isNotEmpty) return userName;

    return fallbackUsername ?? '';
  }

  void _navigateToFollowList(int initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => FollowListState(widget.profileId),
          child: FollowListPage(
            profileId: widget.profileId,
            initialTab: initialTab,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<ProfileState>(context);
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return state.isbusy
        ? Scaffold(
            backgroundColor: appColors.background,
            body: Center(child: CupertinoActivityIndicator()),
          )
        : Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: appColors.background,
            appBar: AppBar(
              actions: [
                if (state.isMyProfile)
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SettingsPage()));
                      },
                      child: Container(
                          width: 50,
                          height: 50,
                          child: Icon(CupertinoIcons.list_bullet_indent,
                              color: appColors.textPrimary)))
                else
                  GestureDetector(
                      onTap: () => _showProfileMenu(context, state),
                      child: Container(
                          width: 50,
                          height: 50,
                          child: Icon(CupertinoIcons.ellipsis,
                              color: appColors.textPrimary)))
              ],
              leading: widget.isOwnProfileTab
                  ? SizedBox.shrink()
                  : GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Icon(CupertinoIcons.back,
                          color: appColors.textPrimary)),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            body: RefreshIndicator(
              color: appColors.textPrimary,
              backgroundColor: appColors.background,
              onRefresh: _refreshAll,
              child: Center(
                child: ListView(children: [
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Name + Avatar row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _resolveDisplayName(state, widget.username),
                                          style: TextStyle(
                                              color: appColors.textPrimary,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (state.profileUserModel?.isVerified == true) ...[
                                        SizedBox(width: 4),
                                        Icon(CupertinoIcons.checkmark_seal_fill,
                                            size: 18, color: CupertinoColors.activeBlue),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  if ((state.profileUserModel?.userName ?? widget.username ?? '').isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        '@${state.profileUserModel?.userName ?? widget.username}',
                                        style: TextStyle(
                                            color: appColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400),
                                      ),
                                      if (state.profileUserModel?.link != null &&
                                          state.profileUserModel!.link!
                                              .isNotEmpty) ...[
                                        SizedBox(width: 5),
                                        Container(
                                          height: 20,
                                          decoration: BoxDecoration(
                                              color: appColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: EdgeInsets.all(2),
                                          child: Text(
                                            state.profileUserModel!.link!,
                                          ),
                                        ),
                                      ]
                                    ],
                                  )
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                                width: 60,
                                height: 60,
                                child: _buildAvatar(state)),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Bio
                        if (state.profileUserModel?.bio != null &&
                            state.profileUserModel!.bio!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              state.profileUserModel!.bio!,
                              style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ),
                        SizedBox(height: 16),
                        // Follower / Following counts
                        Row(
                          children: [
                            _buildStatItem(
                              '${state.followStats.followingCount}',
                              ' ${AppLocalizations.of(context)!.statFollowing}',
                              onTap: () => _navigateToFollowList(1),
                            ),
                            SizedBox(width: 16),
                            _buildStatItem(
                              '${state.followStats.followersCount}',
                              ' ${AppLocalizations.of(context)!.statFollowers}',
                              onTap: () => _navigateToFollowList(0),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Action buttons
                        Row(
                          children: [
                            if (state.isMyProfile) ...[
                              Expanded(
                                child: _buildActionButton(
                                  label: AppLocalizations.of(context)!.editProfile,
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                EditProfilePage()));
                                    if (mounted) {
                                      await _refreshAll();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildActionButton(
                                  label: AppLocalizations.of(context)!.shareProfile,
                                  onTap: () => _shareProfile(state),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: _buildActionButton(
                                  label: state.isFollowLoading
                                      ? ''
                                      : (state.isFollowing
                                          ? AppLocalizations.of(context)!.following
                                          : AppLocalizations.of(context)!.follow),
                                  isHighlighted: !state.isFollowing,
                                  isLoading: state.isFollowLoading,
                                  onTap: () {
                                    state.followUser(
                                        removeFollower: state.isFollowing);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildActionButton(
                                  label: AppLocalizations.of(context)!.shareProfile,
                                  onTap: () => _shareProfile(state),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 20),
                        // TabBar
                        Container(
                          width: MediaQuery.of(context).size.width,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: false,
                            labelColor: appColors.textPrimary,
                            unselectedLabelColor: appColors.textSecondary,
                            indicatorColor: appColors.textPrimary,
                            indicatorWeight: 1,
                            tabs: [
                              Tab(
                                  child: Text(
                                AppLocalizations.of(context)!.tabThreads,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                              Tab(
                                  child: Text(
                              AppLocalizations.of(context)!.tabMedia,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ))
                            ],
                          ),
                        ),
                        Container(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildThreadsTab(),
                                  _buildMediaTab(),
                                ]))
                      ]))
            ])),
            ));
  }

  Widget _buildThreadsTab() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (_isLoadingPosts) {
      return Center(
        child: CircularProgressIndicator(color: appColors.textPrimary),
      );
    }
    if (_userPosts.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noThreadsYetOthers,
          style: TextStyle(color: appColors.textHint),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        return FeedPostWidget(postModel: _userPosts[index]);
      },
    );
  }

  Widget _buildMediaTab() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    // 展平所有帖子的 mediaList，同时兼容旧的 imagePath
    final List<MediaItemModel> allMedia = [];
    for (final post in _userPosts) {
      if (post.mediaList != null && post.mediaList!.isNotEmpty) {
        allMedia.addAll(post.mediaList!);
      } else if (post.imagePath != null && post.imagePath!.isNotEmpty) {
        // 兼容旧数据：imagePath → image media item
        allMedia.add(MediaItemModel(
          mediaType: MediaType.image,
          url: post.imagePath,
        ));
      }
    }

    if (allMedia.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noMediaYet,
          style: TextStyle(color: appColors.textHint),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: allMedia.length,
      itemBuilder: (context, index) {
        final item = allMedia[index];
        final thumbnailUrl = item.thumbUrl ?? item.url ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaViewerPage(
                  mediaItems: allMedia,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: thumbnailUrl,
                placeholder: (_, __) => Container(color: appColors.surface),
                errorWidget: (_, __, ___) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.broken_image, color: appColors.textSecondary),
                ),
              ),
              // 视频播放图标叠加层
              if (item.isVideo)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(ProfileState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final pic = state.profileUserModel?.profilePic ?? '';
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: appColors.textSecondary, width: 0.5),
      ),
      child: ClipOval(
        child: pic.isEmpty
            ? Container(
                color: appColors.surface,
                child: Icon(Icons.person, size: 36, color: appColors.textSecondary),
              )
            : CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: pic,
                placeholder: (_, __) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.person, size: 36, color: appColors.textSecondary),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.person, size: 36, color: appColors.textSecondary),
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final child = RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: count,
            style: TextStyle(
                color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          TextSpan(
            text: label,
            style: TextStyle(color: appColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  // ==================== Profile Menu (Mute / Restrict / Block / Report) ====================

  void _showProfileMenu(BuildContext context, ProfileState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final username = state.profileUserModel?.userName ?? '';
    final targetUserId = int.tryParse(widget.profileId) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetOption(
              label: l10n.muteUsername(username),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleProfileRelationControl(
                  context, targetUserId, 1, l10n.userMuted,
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: l10n.restrictUsername(username),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleProfileRelationControl(
                  context, targetUserId, 2, l10n.userRestricted,
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: l10n.blockUsername(username),
              textColor: appColors.destructive,
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: appColors.surface,
                    title: Text(l10n.blockConfirmTitle, style: TextStyle(color: appColors.textPrimary)),
                    content: Text(l10n.blockConfirmDesc, style: TextStyle(color: appColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel, style: TextStyle(color: appColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.block, style: TextStyle(color: appColors.destructive)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _handleProfileRelationControl(
                    context, targetUserId, 3, l10n.userBlocked,
                  );
                }
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: l10n.reportUser,
              textColor: appColors.destructive,
              onTap: () {
                Navigator.pop(sheetContext);
                final postState = Provider.of<PostState>(context, listen: false);
                postState.reportContent(
                  targetType: 3, // User
                  targetId: targetUserId,
                  reportType: 9, // Other
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.reportSuccess), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileRelationControl(
    BuildContext context, int targetUserId, int controlType, String successMsg,
  ) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    try {
      final userService = UserService(apiClient: getIt());
      await userService.addRelationControl(
        targetUserId: targetUserId,
        controlType: controlType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.operationFailed),
            backgroundColor: appColors.destructive,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
        child: Text(label, style: TextStyle(
          color: textColor ?? appColors.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w400,
        )),
      ),
    );
  }

  Widget _buildSheetDivider() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Divider(color: appColors.divider, height: 0.5);
  }

  Widget _buildActionButton({
    required String label,
    bool isHighlighted = false,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isHighlighted ? appColors.textPrimary : appColors.background,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? null
                  : Border.all(
                      color: appColors.textSecondary,
                      width: 0.5,
                    ),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CupertinoActivityIndicator(
                      color: isHighlighted ? appColors.background : appColors.textPrimary,
                    ),
                  )
                : Text(
              label,
              style: TextStyle(
                color: isHighlighted ? appColors.background : appColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            )));
  }
}
