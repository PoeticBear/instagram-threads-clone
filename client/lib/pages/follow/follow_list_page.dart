import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/follow_list.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/list.dart';

class FollowListPage extends StatefulWidget {
  const FollowListPage({
    Key? key,
    required this.profileId,
    this.initialTab = 0,
  }) : super(key: key);

  final String profileId;
  final int initialTab;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final state = Provider.of<FollowListState>(context, listen: false);
      state.setKeyword(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: appColors.textPrimary,
          unselectedLabelColor: appColors.textSecondary,
          indicatorColor: appColors.textPrimary,
          indicatorWeight: 1,
          tabs: [
            Tab(child: Text(l10n.statFollowers, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Tab(child: Text(l10n.statFollowing, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(appColors),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowersTab(appColors, l10n),
                _buildFollowingTab(appColors, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColors appColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          onChanged: _onSearchChanged,
          style: TextStyle(fontSize: 14, color: appColors.textPrimary),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.search,
            hintStyle: TextStyle(fontSize: 14, color: appColors.textSecondary),
            prefixIcon: Icon(CupertinoIcons.search, size: 18, color: appColors.textSecondary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(bottom: 8),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowersTab(AppColors appColors, AppLocalizations l10n) {
    return Consumer<FollowListState>(
      builder: (context, state, _) {
        if (state.isLoadingFollowers && state.followers.isEmpty) {
          return Center(child: CupertinoActivityIndicator());
        }
        if (state.followers.isEmpty) {
          return Center(
            child: Text(
              l10n.noUsersFound,
              style: TextStyle(color: appColors.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          color: appColors.textPrimary,
          backgroundColor: appColors.background,
          onRefresh: state.refreshFollowers,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                if (state.hasMoreFollowers && !state.isLoadingFollowers) {
                  state.loadFollowers();
                }
              }
              return false;
            },
            child: ListView.separated(
              itemCount: state.followers.length + (state.hasMoreFollowers ? 1 : 0),
              separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
              itemBuilder: (context, index) {
                if (index >= state.followers.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }
                final user = state.followers[index];
                return UserTilePage(
                  user: user,
                  isFollowing: user.isFollowing ?? false,
                  isLoading: state.isToggleLoading(user.userId ?? 0),
                  onFollowTap: () {
                    state.toggleFollow(
                      user,
                      isCurrentlyFollowing: user.isFollowing ?? false,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowingTab(AppColors appColors, AppLocalizations l10n) {
    return Consumer<FollowListState>(
      builder: (context, state, _) {
        if (state.isLoadingFollowing && state.following.isEmpty) {
          return Center(child: CupertinoActivityIndicator());
        }
        if (state.following.isEmpty) {
          return Center(
            child: Text(
              l10n.noUsersFound,
              style: TextStyle(color: appColors.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          color: appColors.textPrimary,
          backgroundColor: appColors.background,
          onRefresh: state.refreshFollowing,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                if (state.hasMoreFollowing && !state.isLoadingFollowing) {
                  state.loadFollowing();
                }
              }
              return false;
            },
            child: ListView.separated(
              itemCount: state.following.length + (state.hasMoreFollowing ? 1 : 0),
              separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
              itemBuilder: (context, index) {
                if (index >= state.following.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }
                final user = state.following[index];
                return UserTilePage(
                  user: user,
                  isFollowing: user.isFollowing ?? false,
                  isLoading: state.isToggleLoading(user.userId ?? 0),
                  onFollowTap: () {
                    state.toggleFollow(
                      user,
                      isCurrentlyFollowing: user.isFollowing ?? false,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
