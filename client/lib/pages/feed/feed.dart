// ignore_for_file: must_be_immutable
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/pages/community/community_list_page.dart';
import 'package:threads/pages/message/message_page.dart';
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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  // 仅在用户向下滚动超过此阈值时，点击顶部中间区域才触发「返回顶部」
  static const double _scrollToTopThreshold = 200.0;

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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar with community and message icons
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const CommunityListPage()),
                      );
                    },
                    child: Icon(
                      Icons.groups_outlined,
                      size: 28,
                      color: appColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 仅当向下滚动超过阈值时，点击顶部中间区域才触发「返回顶部」
                        if (_scrollController.hasClients &&
                            _scrollController.offset >
                                _scrollToTopThreshold) {
                          _scrollToTop();
                        }
                      },
                      child: const SizedBox(height: 36),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => MessagePage()),
                      );
                    },
                    child: Icon(
                      Iconsax.message,
                      size: 28,
                      color: appColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Feed list
            Expanded(
              child: Consumer<PostState>(builder: (context, state, child) {
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

        // 内容未填满视口时，自动触发加载下一页
        if (state.hasMore && !state.isLoadingMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients &&
                _scrollController.position.maxScrollExtent <= 0) {
              state.loadMore();
            }
          });
        }

        return RefreshIndicator(
          color: appColors.textPrimary,
          backgroundColor: appColors.surface,
          onRefresh: () => state.refresh(),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length + 1 + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                // 用 Selector 精准订阅 AuthState.userModel 引用变化。
                // UserModel 是 Equatable 子类，profilePic/displayName/userName
                // 任一字段变化都会使新实例 != 旧实例 → 触发本 Selector 重建，
                // 从而让快捷发帖区的头像/昵称实时跟随 EditProfilePage 的更新。
                // 用 listen:false 拿不到这个效果（feed.dart:63 的 AuthState 是 listen:false）。
                return Selector<AuthState, UserModel?>(
                  selector: (_, a) => a.userModel,
                  builder: (context, userModel, _) {
                    return _buildQuickPostArea(userModel);
                  },
                );
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
            },
          ),
        );
          }),
          ),
        ],
      ),
    ),
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
          child: CachedNetworkImage(
            imageUrl: url,
            errorWidget: (context, url, error) => Container(
              decoration: BoxDecoration(
                color: appColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person,
                  size: size * 0.6, color: appColors.textSecondary),
            ),
          ),
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
                Navigator.of(context).pop();
              },
              onCancel: () {
                Navigator.of(context).pop();
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
