import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/common/settings.dart';
import 'package:threads/state/post.state.dart';
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
    _tabController.addListener(_onTabChanged);
    super.initState();
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && !_hasLoadedUserPosts) {
      _hasLoadedUserPosts = true;
      final authState = Provider.of<AuthState>(context, listen: false);
      final postState = Provider.of<PostState>(context, listen: false);
      if (authState.userId != null) {
        postState.loadUserPosts(int.parse(authState.userId!));
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var authState = Provider.of<AuthState>(context, listen: false);
    var state = Provider.of<AuthState>(context);
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        appBar: AppBar(
          actions: [
            GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SettingsPage()));
                },
                child: Icon(CupertinoIcons.list_bullet_indent,
                    color: Colors.white))
          ],
          leading: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Icon(CupertinoIcons.globe, color: Colors.white)),
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
                                    color: Colors.grey[800],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person,
                                      size: 40, color: Colors.grey[600]),
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
                            color: Colors.white,
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
                                color: Colors.grey,
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
                                    color: Colors.white,
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
                                color: Color.fromARGB(255, 19, 19, 19),
                                borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, size: 14, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  state.profileUserModel?.link ?? "",
                                  style: TextStyle(
                                      color: Colors.grey,
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
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey,
                                    width: 0.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text("编辑资料"))),
                        Container(
                          width: 10,
                        ),
                        Container(
                            height: 40,
                            width: 165,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey,
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text("分享资料"))
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
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.white,
                        indicatorWeight: 1,
                        tabs: [
                          Padding(
                              padding: EdgeInsets.only(left: 20),
                              child: Tab(
                                  child: Text(
                                '主题',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ))),
                          Padding(
                            padding: EdgeInsets.only(right: 0),
                            child: Tab(
                                child: Text(
                              '回复',
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
                                  "你还没有发布任何主题。",
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
                          Container(
                            height: 100,
                            width: 200,
                            alignment: Alignment.center,
                            child: Text(
                              "你还没有发布任何主题。",
                              style: TextStyle(
                                  color: Color.fromARGB(255, 84, 60, 60)),
                            ),
                          )
                        ]))
                  ]))
        ])));
  }
}
