// ignore_for_file: must_be_immutable
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';
import 'package:threads/pages/composePost/post.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      var state = Provider.of<PostState>(context, listen: false);
      state.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var authState = Provider.of<AuthState>(context, listen: false);
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      extendBody: true,
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: Container(),
        centerTitle: true,
        title: Consumer<PostState>(
          builder: (_, state, __) {
            if (state.isBusy) {
              return Lottie.network(
                "https://assets3.lottiefiles.com/packages/lf20_Ht77kFLXYw.json",
                height: 50,
                repeat: true,
                animate: true,
              );
            }
            return SizedBox(
              height: 30,
              child: Lottie.network(
                "https://assets3.lottiefiles.com/packages/lf20_Ht77kFLXYw.json",
                height: 30,
                repeat: false,
                animate: false,
              ),
            );
          },
        ),
        toolbarHeight: 37,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<PostState>(builder: (context, state, child) {
        if (state.isBusy) {
          return Center(
            child: CircularProgressIndicator(color: appColors.textPrimary),
          );
        }

        final posts = state.getPostList(authState.userModel);
        if (posts == null || posts.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.noPostsYet,
                style: TextStyle(color: appColors.textSecondary, fontSize: 16)),
          );
        }

        return ListView.builder(
            controller: _scrollController,
            itemCount: posts.length + 1 + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildQuickPostArea(authState.userModel);
              }
              final postIndex = index - 1;
              if (postIndex == posts.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return FeedPostWidget(
                postModel: posts[postIndex],
              );
            });
      }),
    );
  }

  Widget _buildQuickPostArea(userModel) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final profilePic = userModel?.profilePic ?? '';
    final displayName = userModel?.displayName ?? userModel?.userName ?? '';

    Widget avatar(String url, double size) {
      if (url.isEmpty) {
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: appColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, size: size * 0.6, color: appColors.textSecondary),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: size,
          width: size,
          child: CachedNetworkImage(imageUrl: url),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final postState = Provider.of<PostState>(context, listen: false);
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ComposePost(
              onPostSuccess: () {
                postState.getDataFromDatabase();
              },
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: appColors.background,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar(profilePic, 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isNotEmpty ? displayName : (userModel?.userName ?? AppLocalizations.of(context)!.anonymousUser),
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.whatsNew,
                    style: TextStyle(color: appColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
