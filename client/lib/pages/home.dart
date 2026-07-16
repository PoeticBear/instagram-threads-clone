import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/pages/composePost/post.dart';
import 'package:threads/pages/message/message_page.dart';
import 'package:threads/pages/notification/notification.dart';
import 'package:threads/pages/search/search.dart';
import 'package:threads/pages/textNote/text_note_menu_sheet.dart';
import 'package:threads/pages/textNote/text_note_page.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/notification.state.dart';
import 'package:threads/pages/profile/myprofile.dart';
import 'package:threads/theme/app_colors.dart';
import 'camera/camera.dart';
import 'feed/feed.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _composePostKey = GlobalKey<ComposePostState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FeedPage(),
      SearchPage(),
      ComposePost(
        key: _composePostKey,
        onPostSuccess: () => setState(() => tab = 0),
        onCancel: () => setState(() => tab = 0),
      ),
      NotificationPage(),
      MyProfilePage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initPosts();
      initProfile();
      initNotifications();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void initProfile() {
    var state = Provider.of<AuthState>(context, listen: false);
    state.getProfileUser();
  }

  void initPosts() {
    var state = Provider.of<PostState>(context, listen: false);
    state.getDataFromDatabase();
  }

  void initNotifications() {
    var state = Provider.of<NotificationState>(context, listen: false);
    state.loadNotifications();
    state.fetchUnreadCount();
  }

  void _switchTab(int targetTab) {
    if (tab == targetTab) return;
    // ── 中间 "+" Tab：弹 Popup 菜单，由用户选择「写文字」或「普通图文」 ──
    if (targetTab == 2) {
      _showComposeMenu();
      return;
    }
    if (tab == 2) {
      _composePostKey.currentState?.handleTabSwitch(
        onSave: () => setState(() => tab = targetTab),
        onDiscard: () => setState(() => tab = targetTab),
      );
      return;
    }
    setState(() => tab = targetTab);
  }

  /// 弹出「写文字 / 普通图文」选择菜单。
  ///
  /// - 选「写文字」→ push 新的 TextNotePage
  /// - 选「普通图文」→ 切换 tab=2 进入 ComposePost（保留草稿拦截逻辑）
  Future<void> _showComposeMenu() async {
    final mode = await showModalBottomSheet<TextNoteMenuMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const TextNoteMenuSheet(),
    );
    if (!mounted || mode == null) return;
    switch (mode) {
      case TextNoteMenuMode.textNote:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TextNotePage()),
        );
        break;
      case TextNoteMenuMode.normalPost:
        setState(() => tab = 2);
        break;
    }
  }

  bool isSelected = false;

  static const double _iconSize = 30.0;

  Widget _tabBarItem({
    required int tabIndex,
    required IconData icon,
    required AppColors appColors,
    bool isActive = false,
    Widget? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(tabIndex),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: _iconSize,
                color: isActive ? appColors.textPrimary : appColors.textSecondary,
              ),
              if (badge != null) badge,
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomNavBar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: appColors.background.withAlpha(77),
          height: 90,
          padding: EdgeInsets.only(bottom: 20),
          width: MediaQuery.of(context).size.width,
          child: Row(children: [
            _tabBarItem(tabIndex: 0, icon: Iconsax.home, appColors: appColors, isActive: tab == 0),
            _tabBarItem(tabIndex: 1, icon: Iconsax.search_normal, appColors: appColors, isActive: tab == 1),
            _tabBarItem(tabIndex: 2, icon: Iconsax.edit, appColors: appColors, isActive: tab == 2),
            Consumer<NotificationState>(
              builder: (_, state, __) {
                return _tabBarItem(
                  tabIndex: 3,
                  icon: Iconsax.heart,
                  appColors: appColors,
                  isActive: tab == 3,
                  badge: state.unreadCount > 0
                      ? Positioned(
                          right: 22,
                          top: 14,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: appColors.destructive,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
            _tabBarItem(tabIndex: 4, icon: CupertinoIcons.person, appColors: appColors, isActive: tab == 4),
          ]),
        ),
      ),
    );
  }

  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBody: true,
        bottomNavigationBar: bottomNavBar(),
        extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: tab,
          children: _pages,
        ));
  }
}
