import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
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
import 'package:url_launcher/url_launcher.dart';

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

  static PageRouteBuilder getRoute(
      {required String profileId, String? username}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChangeNotifierProvider(
          // 把当前登录用户的 ID 显式传给 ProfileState，
          // 让 isMyProfile 用 AuthState.userId 作为权威来源。
          // 否则 isMyProfile 完全依赖 SharedPreferences 缓存里的 userId，
          // 在缓存里 userId 为 0 / 缺失时会错误地把当前用户当成"别人"，
          // 把"编辑资料"显示成"关注"按钮。
          create: (BuildContext context) {
            final auth = Provider.of<AuthState>(context, listen: false);
            return ProfileState(profileId, currentUserId: auth.userId);
          },
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
            body: NestedScrollView(
              // Flutter 原生 Sliver 系统:头部信息用 SliverToBoxAdapter 装,
              // TabBar 用 SliverPersistentHeader(pinned:true)固定,body 直接用 TabBarView。
              // NestedScrollView 自动协调头部滚动 + TabBarView 内部 PageView 滚动,
              // 不需要 Column+Expanded 给 TabBarView 有界高度,也就不会触发 70-100pt 空白。
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // 1. 顶部留白(状态栏 + AppBar 工具栏)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          MediaQuery.of(context).padding.top + kToolbarHeight,
                    ),
                  ),
                  // 2. 头部信息(头像/简介/统计/操作按钮)
                  SliverToBoxAdapter(
                    child: Padding(
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
                                            _resolveDisplayName(
                                                state, widget.username),
                                            style: TextStyle(
                                                color: appColors.textPrimary,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (state
                                                .profileUserModel?.isVerified ==
                                            true) ...[
                                          SizedBox(width: 4),
                                          Icon(
                                              CupertinoIcons
                                                  .checkmark_seal_fill,
                                              size: 18,
                                              color:
                                                  CupertinoColors.activeBlue),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    if ((state.profileUserModel?.userName ??
                                            widget.username ??
                                            '')
                                        .isNotEmpty)
                                      Row(
                                        children: [
                                          Text(
                                            '@${state.profileUserModel?.userName ?? widget.username}',
                                            style: TextStyle(
                                                color: appColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400),
                                          ),
                                          if (state.profileUserModel?.link !=
                                                  null &&
                                              state.profileUserModel!.link!
                                                  .isNotEmpty) ...[
                                            SizedBox(width: 5),
                                            GestureDetector(
                                              onTap: () => _openLink(state
                                                  .profileUserModel!.link!),
                                              behavior: HitTestBehavior.opaque,
                                              child: MouseRegion(
                                                cursor:
                                                    SystemMouseCursors.click,
                                                child: Container(
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                      color: appColors.surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                  padding: EdgeInsets.all(2),
                                                  child: Text(
                                                    state.profileUserModel!
                                                        .link!,
                                                    style: TextStyle(
                                                      color: appColors.accent,
                                                    ),
                                                  ),
                                                ),
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
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400),
                              ),
                            ),
                          // 扩展信息行（代词 / 位置 / 性别）
                          if (state.profileUserModel != null) ...[
                            SizedBox(height: 12),
                            _buildInfoRow(state),
                          ],
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
                                    label: AppLocalizations.of(context)!
                                        .editProfile,
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
                                    label: AppLocalizations.of(context)!
                                        .shareProfile,
                                    onTap: () => _shareProfile(state),
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: _buildActionButton(
                                    label: state.isFollowLoading
                                        ? ''
                                        : (state.isFollowing
                                            ? AppLocalizations.of(context)!
                                                .following
                                            : AppLocalizations.of(context)!
                                                .follow),
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
                                    label: AppLocalizations.of(context)!
                                        .shareProfile,
                                    onTap: () => _shareProfile(state),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // SizedBox(height: 20) 已删除 — TabBar 不再嵌在头部 Column 里,改由 SliverPersistentHeader 提供固定 TabBar。
                        ],
                      ),
                    ),
                  ),
                  // 3. TabBar(通过 SliverPersistentHeader 固定)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      minHeight: 46.0,
                      maxHeight: 46.0,
                      child: Container(
                        color: appColors.background,
                        child: TabBar(
                          controller: _tabController,
                          onTap: (index) {
                            if (index == 0) {
                              _loadUserPosts();
                            }
                          },
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
                              ),
                            ),
                            Tab(
                              child: Text(
                                AppLocalizations.of(context)!.tabMedia,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildThreadsTab(),
                  _buildMediaTab(),
                ],
              ),
            ),
          );
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
    // NestedScrollView 把 body 装进 SliverFillRemaining(见 flutter 源码
    // nested_scroll_view.dart:344-370),body 的第一个像素位于 SliverFillRemaining
    // 起始 y,而 SliverFillRemaining 又位于头部 slivers 末尾。在当前布局下
    // 渲染出的实际效果是:ListView 第一项视觉位置比 TabBar 底部还要低约 80pt,
    // 形成明显空白。
    //
    // 用 Transform.translate(-80) 把 body 内容向上平移 80pt,让第一项紧贴 TabBar。
    // 已在 Column+Expanded 版验证过该偏移量;NestedScrollView 版空白尺寸相同
    // (用户截图实测 ~80pt),沿用同一偏移即可。
    //
    // ListView 保持独立可滚动,否则 overscroll 不会传上去,触发不了下拉刷新。
    return Transform.translate(
      offset: const Offset(0, -80),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _userPosts.length,
        itemBuilder: (context, index) {
          final post = _userPosts[index];
          return FeedPostWidget(
            postModel: post,
            // 第一项 isFirst=true:跳过 FeedPostWidget 顶部的 0.2px 分割线
            // + 10px 间距,让第一个帖子紧贴 TabBar。
            isFirst: index == 0,
            // 帖子删除成功后,同步从本地 _userPosts 移除,解决 Threads Tab
            // 删除后列表不刷新的问题(PostState.deletePost 只更新全局 _userPosts,
            // 不会反向同步到 ProfilePage 的本地缓存)。
            onPostDeleted: () {
              if (!mounted) return;
              setState(() {
                _userPosts.removeWhere((p) => p.id == post.id);
              });
            },
          );
        },
      ),
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

    // 同 _buildThreadsTab:
    // 1) GridView 必须独立可滚动,让 overscroll 能传给 NestedScrollView
    //    触发下拉刷新。
    // 2) 同样需要 Transform.translate(-80) 把 body 上移,消除 TabBar 下方
    //    80pt 空白(NestedScrollView + SliverFillRemaining 的位置偏移,
    //    见 _buildThreadsTab 的详细注释)。
    return Transform.translate(
      offset: const Offset(0, -80),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    child: Icon(Icons.broken_image,
                        color: appColors.textSecondary),
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
      ),
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
                child: Icon(Icons.person,
                    size: 36, color: appColors.textSecondary),
              )
            : CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: pic,
                placeholder: (_, __) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.person,
                      size: 36, color: appColors.textSecondary),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: appColors.surface,
                  child: Icon(Icons.person,
                      size: 36, color: appColors.textSecondary),
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
                color: appColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14),
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

  // 渲染代词 / 位置 / 性别三个扩展字段的紧凑信息行。
  // 任一字段为空或未设置时跳过该项；全部为空时返回 SizedBox.shrink()。
  Widget _buildInfoRow(ProfileState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final user = state.profileUserModel;
    if (user == null) return const SizedBox.shrink();

    final items = <Widget>[];

    // 位置
    final location = user.location;
    if (location != null && location.isNotEmpty) {
      items.add(_buildInfoItem(
        icon: Iconsax.location,
        text: location,
        appColors: appColors,
      ));
    }

    // 代词
    final pronouns = user.pronouns;
    if (pronouns != null && pronouns.isNotEmpty) {
      items.add(_buildInfoItem(
        icon: Iconsax.tag,
        text: pronouns,
        appColors: appColors,
      ));
    }

    // 性别（1=未设置，不展示）
    final gender = user.gender;
    if (gender != null && gender != 1) {
      String genderText;
      switch (gender) {
        case 2:
          genderText = l10n.male;
          break;
        case 3:
          genderText = l10n.female;
          break;
        case 4:
          genderText = l10n.otherGender;
          break;
        default:
          genderText = '';
      }
      if (genderText.isNotEmpty) {
        items.add(_buildInfoItem(
          icon: Iconsax.user,
          text: genderText,
          appColors: appColors,
        ));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items,
      ),
    );
  }

  // 单个信息项：图标 + 文本
  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required AppColors appColors,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: appColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // 打开外部链接：自动补 https:// 前缀；失败时弹 SnackBar
  Future<void> _openLink(String raw) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    var urlStr = trimmed;
    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }
    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.operationFailed),
        backgroundColor: appColors.destructive,
      ));
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.operationFailed),
          backgroundColor: appColors.destructive,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.operationFailed),
          backgroundColor: appColors.destructive,
        ));
      }
    }
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
                  context,
                  targetUserId,
                  1,
                  l10n.userMuted,
                );
              },
            ),
            _buildSheetDivider(),
            _buildSheetOption(
              label: l10n.restrictUsername(username),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleProfileRelationControl(
                  context,
                  targetUserId,
                  2,
                  l10n.userRestricted,
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
                    title: Text(l10n.blockConfirmTitle,
                        style: TextStyle(color: appColors.textPrimary)),
                    content: Text(l10n.blockConfirmDesc,
                        style: TextStyle(color: appColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel,
                            style: TextStyle(color: appColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.block,
                            style: TextStyle(color: appColors.destructive)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _handleProfileRelationControl(
                    context,
                    targetUserId,
                    3,
                    l10n.userBlocked,
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
                final postState =
                    Provider.of<PostState>(context, listen: false);
                postState.reportContent(
                  targetType: 3, // User
                  targetId: targetUserId,
                  reportType: 9, // Other
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(l10n.reportSuccess),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileRelationControl(
    BuildContext context,
    int targetUserId,
    int controlType,
    String successMsg,
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
        child: Text(label,
            style: TextStyle(
              color: textColor ?? appColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
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
              color:
                  isHighlighted ? appColors.textPrimary : appColors.background,
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
                      color: isHighlighted
                          ? appColors.background
                          : appColors.textPrimary,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: isHighlighted
                          ? appColors.background
                          : appColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  )));
  }
}

/// SliverPersistentHeader 的通用 delegate:
/// 把任意固定高度的 child(本场景是 TabBar)交给 Sliver 系统托管,
/// 让 NestedScrollView 自动处理「头部收起 → TabBar 钉住 → TabBarView 接管」三段式过渡。
///
/// 关键点:
/// - minExtent / maxExtent 必须返回相同值(46.0),否则 header 会随滚动伸缩,
///   TabBar 上的 indicator 会跳动。
/// - shouldRebuild 必须严格比较新旧 child 状态,本场景里 child 来自同一个 TabBar
///   + _tabController,只要外部 ProfileState 重建 ProfilePage,就会创建新 delegate
///   实例,默认 shouldRebuild 返回 true 也无副作用。
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
