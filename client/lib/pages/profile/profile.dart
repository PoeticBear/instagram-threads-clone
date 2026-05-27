// ignore_for_file: deprecated_member_use, unnecessary_null_comparison
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/pages/profile/edit.dart';
import 'package:threads/common/settings.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/profile.state.dart';
import 'package:threads/widget/feedpost.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/l10n/generated/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key, required this.profileId, this.scaffoldKey})
      : super(key: key);
  final GlobalKey<ScaffoldState>? scaffoldKey;

  final String profileId;
  static PageRouteBuilder getRoute({required String profileId}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChangeNotifierProvider(
          create: (BuildContext context) => ProfileState(profileId),
          child: ProfilePage(
            profileId: profileId,
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
  int pageIndex = 0;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<ProfileState>(context);
    return state.isbusy
        ? Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CupertinoActivityIndicator()),
          )
        : Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.black,
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
                              color: Colors.white)))
              ],
              leading: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Icon(CupertinoIcons.back, color: Colors.white)),
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
                        // Name + Avatar row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.profileUserModel?.displayName ?? '',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600),
                                ),
                                Container(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '@${state.profileUserModel?.userName ?? ''}',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400),
                                    ),
                                    if (state.profileUserModel?.link != null &&
                                        state.profileUserModel!.link!
                                            .isNotEmpty) ...[
                                      Container(width: 5),
                                      Container(
                                        height: 20,
                                        decoration: BoxDecoration(
                                            color:
                                                Color.fromARGB(255, 19, 19, 19),
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
                            Container(width: 63),
                            Container(
                                width: 60,
                                height: 60,
                                child: _buildAvatar(state)),
                          ],
                        ),
                        Container(height: 12),
                        // Bio
                        if (state.profileUserModel?.bio != null &&
                            state.profileUserModel!.bio!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              state.profileUserModel!.bio!,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ),
                        Container(height: 16),
                        // Follower / Following counts
                        Row(
                          children: [
                            _buildStatItem(
                              '${state.followStats.followingCount}',
                              ' following',
                            ),
                            Container(width: 16),
                            _buildStatItem(
                              '${state.followStats.followersCount}',
                              ' followers',
                            ),
                          ],
                        ),
                        Container(height: 16),
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (state.isMyProfile) ...[
                              _buildActionButton(
                                label: 'Edit profile',
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              EditProfilePage()));
                                },
                              ),
                              Container(width: 10),
                              _buildActionButton(label: 'Share profile'),
                            ] else ...[
                              _buildActionButton(
                                label: state.isFollowing ? 'Following' : 'Follow',
                                isHighlighted: !state.isFollowing,
                                onTap: () {
                                  state.followUser(
                                      removeFollower: state.isFollowing);
                                },
                              ),
                              Container(width: 10),
                              _buildActionButton(label: 'Share profile'),
                            ],
                          ],
                        ),
                        Container(height: 20),
                        // TabBar
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
                                    'Threads',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ))),
                              Padding(
                                padding: EdgeInsets.only(right: 0),
                                child: Tab(
                                    child: Text(
                                  'Replies',
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
                            height: 300,
                            child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildThreadsTab(),
                                  _buildRepliesTab(),
                                ]))
                      ]))
            ])));
  }

  Widget _buildThreadsTab() {
    if (_isLoadingPosts) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_userPosts.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noThreadsYetOthers,
          style: TextStyle(color: Color(0xff555555)),
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

  Widget _buildRepliesTab() {
    final replies = _userPosts.where((p) => p.replyToPostId != null && p.replyToPostId!.isNotEmpty).toList();
    if (replies.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noRepliesYet,
          style: TextStyle(color: Color(0xff555555)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: replies.length,
      itemBuilder: (context, index) {
        return FeedPostWidget(postModel: replies[index]);
      },
    );
  }

  Widget _buildAvatar(ProfileState state) {
    final pic = state.profileUserModel?.profilePic ?? '';
    if (pic.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 36, color: Colors.grey[600]),
      );
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CachedNetworkImage(
          fit: BoxFit.cover,
          height: 60,
          width: 60,
          imageUrl: pic,
        ));
  }

  Widget _buildStatItem(String count, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: count,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          TextSpan(
            text: label,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    bool isHighlighted = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            height: 40,
            width: 170,
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.blue : Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? null
                  : Border.all(
                      color: Colors.grey,
                      width: 0.5,
                    ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isHighlighted ? Colors.white : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            )));
  }
}
