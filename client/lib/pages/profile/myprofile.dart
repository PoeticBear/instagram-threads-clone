import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/common/settings.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';
import 'edit.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasLoadedUserPosts = false;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPosts();
    });
  }

  void _loadUserPosts() {
    if (_hasLoadedUserPosts) return;
    _hasLoadedUserPosts = true;
    final authState = Provider.of<AuthState>(context, listen: false);
    final postState = Provider.of<PostState>(context, listen: false);
    if (authState.userId != null) {
      postState.loadUserPosts(int.parse(authState.userId!));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var authState = Provider.of<AuthState>(context, listen: false);
    var state = Provider.of<AuthState>(context);
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: appColors.background,
        appBar: AppBar(
          actions: [
            GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SettingsPage()));
                },
                child: Icon(CupertinoIcons.list_bullet_indent,
                    color: appColors.textPrimary))
          ],
          leading: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Icon(CupertinoIcons.globe, color: appColors.textPrimary)),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
            child: ListView(children: [
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 头像
                    Center(
                      child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditProfilePage()));
                          },
                          child: (state.profileUserModel?.profilePic ?? '').isEmpty
                              ? Container(
                                  height: 72,
                                  width: 72,
                                  decoration: BoxDecoration(
                                    color: appColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person,
                                      size: 40, color: appColors.textSecondary),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: CachedNetworkImage(
                                    fit: BoxFit.cover,
                                    height: 72,
                                    width: 72,
                                    imageUrl: state.profileUserModel!.profilePic!,
                                  ))),
                    ),
                    SizedBox(height: 16),
                    // 名称（主）
                    Center(
                      child: Text(
                        state.profileUserModel?.displayName.toString() ?? "",
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(height: 4),
                    // 用户名
                    Center(
                      child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditProfilePage()));
                          },
                          child: Text(
                            '${state.profileUserModel?.userName.toString() ?? ""}',
                            style: TextStyle(
                                color: appColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w400),
                          )),
                    ),
                    // 简介（次）
                    if ((state.profileUserModel?.bio ?? '').isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Center(
                          child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => EditProfilePage()));
                              },
                              child: Text(
                                state.profileUserModel?.bio ?? "",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400),
                              )),
                        ),
                      ),
                    // 链接（次）
                    if ((state.profileUserModel?.link ?? '').isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                                color: appColors.surface,
                                borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, size: 14, color: appColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  state.profileUserModel?.link ?? "",
                                  style: TextStyle(
                                      color: appColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Container(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EditProfilePage()));
                            },
                            child: Container(
                                height: 40,
                                width: 165,
                                decoration: BoxDecoration(
                                  color: appColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: appColors.textSecondary,
                                    width: 0.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(AppLocalizations.of(context)!.editProfile, style: TextStyle(color: appColors.textPrimary)))),
                        Container(
                          width: 10,
                        ),
                        Container(
                            height: 40,
                            width: 165,
                            decoration: BoxDecoration(
                              color: appColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: appColors.textSecondary,
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(AppLocalizations.of(context)!.shareProfile, style: TextStyle(color: appColors.textPrimary)))
                      ],
                    ),
                    Container(
                      height: 20,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width,
                      child: TabBar(
                        onTap: (index) {},
                        controller: _tabController,
                        isScrollable: false,
                        labelColor: appColors.textPrimary,
                        unselectedLabelColor: appColors.textSecondary,
                        indicatorColor: appColors.textPrimary,
                        indicatorWeight: 1,
                        tabs: [
                          Padding(
                              padding: EdgeInsets.only(left: 20),
                              child: Tab(
                                  child: Text(
                                AppLocalizations.of(context)!.tabThreads,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ))),
                          Padding(
                            padding: EdgeInsets.only(right: 0),
                            child: Tab(
                                child: Text(
                              AppLocalizations.of(context)!.tabReplies,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                          )
                        ],
                      ),
                    ),
                    Container(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child:
                            TabBarView(controller: _tabController, children: [
                          Consumer<PostState>(builder: (context, postState, child) {
                            final list = postState.userPosts ?? [];
                            if (postState.isLoadingUserPosts) {
                              return Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                            }
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noThreadsYet,
                                  style: TextStyle(
                                      color: Color.fromARGB(255, 84, 60, 60)),
                                ),
                              );
                            }
                            return ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  return FeedPostWidget(
                                    postModel: list[index],
                                  );
                                });
                          }),
                          Consumer<PostState>(builder: (context, postState, child) {
                            final replies = (postState.userPosts ?? [])
                                .where((p) => p.replyToPostId != null && p.replyToPostId!.isNotEmpty)
                                .toList();
                            if (replies.isEmpty) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noRepliesYet,
                                  style: TextStyle(color: Color(0xff555555)),
                                ),
                              );
                            }
                            return ListView.builder(
                              itemCount: replies.length,
                              itemBuilder: (context, index) {
                                return FeedPostWidget(postModel: replies[index]);
                              },
                            );
                          }),
                        ]))
                  ]))
        ])));
  }
}
