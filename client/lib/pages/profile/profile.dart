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
import 'package:threads/helper/network_error.dart';
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
          //
          // 同时注入 AuthState 引用：用于自己的 profile 兜底同步
          // userName/displayName/profilePic（与 MyProfilePage 路径保持一致）。
          create: (BuildContext context) {
            final auth = Provider.of<AuthState>(context, listen: false);
            return ProfileState(
              profileId,
              currentUserId: auth.userId,
              authState: auth,
            );
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
  // 与 home.dart bottomNavBar 的 Container height 一致（含 20pt home indicator 内边距）。
  // 当 ProfilePage 作为底部 Tab 4 显示时，HomePage 用了 extendBody: true，
  // 底部导航栏会浮在 body 之上，ListView/GridView 底部必须预留这个高度，
  // 否则最后一项被导航栏遮挡。
  static const double _kBottomNavBarHeight = 90.0;

  /// ListView / GridView 底部应预留的高度。
  /// - isOwnProfileTab=true（底部 Tab 入口）：被 90pt bottomNavigationBar 浮在上方，
  ///   预留导航栏高度 + 16pt 视觉余量。
  /// - isOwnProfileTab=false（push 进入的独立 route）：无导航栏覆盖，
  ///   仅留 16pt 视觉余量（home indicator 由 Scaffold 默认 SafeArea 处理）。
  double get _listBottomPadding =>
      (widget.isOwnProfileTab ? _kBottomNavBarHeight : 0) + 16;

  late TabController _tabController;
  List<PostModel> _userPosts = [];
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    // 始终使用同一个 Scaffold：loading 时仅替换 body 内容，避免 AppBar 突然出现/消失的跳变。
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        leading: widget.isOwnProfileTab
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(CupertinoIcons.back,
                      color: appColors.textPrimary, size: 24),
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: state.isMyProfile
                  ? () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SettingsPage()))
                  : () => _showProfileMenu(context, state),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                state.isMyProfile
                    ? CupertinoIcons.list_bullet_indent
                    : CupertinoIcons.ellipsis,
                color: appColors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: state.isbusy
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // 1. 头部信息：按内容高度自适应。Bio 受 maxLines:5 约束，
                //    极端小屏下剩余空间不足时 SingleChildScrollView 兜底防止 overflow。
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: _buildHeaderChildren(state, appColors),
                  ),
                ),
                // 2. TabBar（底部带分割线）
                Container(
                  decoration: BoxDecoration(
                    color: appColors.background,
                    border: Border(
                      bottom: BorderSide(
                          color: appColors.divider, width: 0.5),
                    ),
                  ),
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
                          AppLocalizations.of(context)!.tabPosts,
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
                      Tab(
                        child: Text(
                          AppLocalizations.of(context)!.tabReposts,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 3. TabBarView 占剩余高度
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildThreadsTab(),
                      _buildMediaTab(),
                      _buildRepostsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 头部信息所有子组件（头像/简介/统计/操作按钮）。
  /// 抽出来便于 build 内的 SingleChildScrollView 引用。
  List<Widget> _buildHeaderChildren(ProfileState state, AppColors appColors) {
    return [
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
                if ((state.profileUserModel?.userName ??
                        widget.username ??
                        '')
                    .isNotEmpty)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${state.profileUserModel?.userName ?? widget.username}',
                          style: TextStyle(
                              color: appColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.profileUserModel?.link != null &&
                          state.profileUserModel!.link!.isNotEmpty) ...[
                        SizedBox(width: 5),
                        GestureDetector(
                          onTap: () =>
                              _openLink(state.profileUserModel!.link!),
                          behavior: HitTestBehavior.opaque,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                  color: appColors.surface,
                                  borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.all(2),
                              child: Text(
                                state.profileUserModel!.link!,
                                style: TextStyle(color: appColors.accent),
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
          Container(width: 60, height: 60, child: _buildAvatar(state)),
        ],
      ),
      // 简介与扩展信息行（简介 / 位置 / 代词 / 性别）— 始终显示，未填写项以占位符呈现
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
                label: AppLocalizations.of(context)!.editProfile,
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EditProfilePage()));
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
                  state.followUser(removeFollower: state.isFollowing);
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
      SizedBox(height: 12),
    ];
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
    // padding: EdgeInsets.zero 避免 ListView 默认消费 MediaQuery.padding，
    // 导致第一项与 TabBar 之间出现额外间距（原 80pt 空白 hack 的根因）。
    // bottom: _listBottomPadding — 当 Profile 作为底部 Tab 显示时，
    // HomePage 用了 extendBody: true，90pt bottomNavigationBar 浮在 body 之上，
    // 列表底部必须预留对应高度，否则最后一项被导航栏遮挡。
    return ListView.builder(
      padding: EdgeInsets.only(bottom: _listBottomPadding),
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

    // 同 _buildThreadsTab：padding 显式设置以避免默认消费 MediaQuery.padding，
    // bottom: _listBottomPadding 预留底部导航栏遮挡高度。
    return GridView.builder(
      padding: EdgeInsets.only(bottom: _listBottomPadding),
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
      );
  }

  Widget _buildRepostsTab() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    // 暂时不需要加载数据，仅显示空态占位
    return Center(
      child: Text(
        AppLocalizations.of(context)!.noRepostsYet,
        style: TextStyle(color: appColors.textHint),
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

  // 渲染简介 / 位置 / 代词 / 性别四个字段的紧凑信息行。
  // 所有字段始终渲染；未填写时图标依旧显示，文本位置以淡色占位符呈现。
  Widget _buildInfoRow(ProfileState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final user = state.profileUserModel;
    if (user == null) return const SizedBox.shrink();

    final placeholder = l10n.notSet;

    // 性别文案（1=未设置 → 空，走占位符）
    String genderText = '';
    final gender = user.gender;
    if (gender != null && gender != 1) {
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
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildInfoItem(
            icon: Iconsax.note,
            text: user.bio ?? '',
            placeholder: placeholder,
            appColors: appColors,
          ),
          _buildInfoItem(
            icon: Iconsax.location,
            text: user.location ?? '',
            placeholder: placeholder,
            appColors: appColors,
          ),
          _buildInfoItem(
            icon: Iconsax.tag,
            text: user.pronouns ?? '',
            placeholder: placeholder,
            appColors: appColors,
          ),
          _buildInfoItem(
            icon: Iconsax.user,
            text: genderText,
            placeholder: placeholder,
            appColors: appColors,
          ),
        ],
      ),
    );
  }

  // 单个信息项：图标 + 文本；text 为空时显示淡色占位符，图标始终保持可见。
  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required String placeholder,
    required AppColors appColors,
  }) {
    final isEmpty = text.isEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: appColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isEmpty ? placeholder : text,
            style: TextStyle(
              color: isEmpty ? appColors.textHint : appColors.textPrimary,
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
    } catch (e) {
      if (context.mounted) {
        NetworkErrorNotifier.showApiError(e);
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
