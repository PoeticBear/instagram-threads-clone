import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/state/search.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/list.dart';
import 'package:threads/widget/search_post_tile.dart';
import 'package:threads/widget/user_card.dart';
import 'package:threads/widget/topic_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<SearchState>(context, listen: false);
      state.loadEmptyStateData();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final state = Provider.of<SearchState>(context, listen: false);
    state.changeTab(SearchTab.values[_tabController.index]);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.8) {
      final state = Provider.of<SearchState>(context, listen: false);
      state.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.searchTitle,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<SearchState>(
        builder: (context, state, _) {
          return Column(
            children: [
              _buildSearchField(state),
              if (state.searchQuery.isNotEmpty) _buildTabBar(state),
              Expanded(
                child: state.searchQuery.isEmpty
                    ? _buildEmptyState(state)
                    : _buildSearchResults(state),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Search Field ──

  Widget _buildSearchField(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: TextField(
        cursorColor: appColors.textPrimary,
        controller: _textController,
        onChanged: (value) => state.onSearchChanged(value),
        style: TextStyle(color: appColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(Iconsax.search_normal, size: 18, color: appColors.textSecondary),
          suffixIcon: state.searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _textController.clear();
                    state.onSearchChanged('');
                  },
                  child: Icon(Icons.close, size: 18, color: appColors.textSecondary),
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.transparent, width: 0.7),
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.transparent, width: 0.7),
            borderRadius: BorderRadius.circular(10.0),
          ),
          fillColor: appColors.surface,
          filled: true,
          contentPadding: const EdgeInsets.only(left: 15, top: 5),
          alignLabelWithHint: true,
          hintText: AppLocalizations.of(context)!.search,
          hintStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: appColors.textSecondary,
            fontFamily: 'arial',
          ),
        ),
      ),
    );
  }

  // ── Sort Toggle + Tab Bar ──

  Widget _buildTabBar(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Sort toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          child: Row(
            children: [
              _sortChip(state, 'top', l10n.sortTop, appColors),
              const SizedBox(width: 8),
              _sortChip(state, 'recent', l10n.sortRecent, appColors),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: appColors.textPrimary,
          unselectedLabelColor: appColors.textSecondary,
          indicatorColor: appColors.textPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          tabs: [
            Tab(text: l10n.tabTop),
            Tab(text: l10n.tabUsers),
            Tab(text: l10n.tabTopics),
            Tab(text: l10n.tabPosts),
          ],
        ),
      ],
    );
  }

  Widget _sortChip(SearchState state, String value, String label, AppColors appColors) {
    final isActive = state.sortOrder == value;
    return GestureDetector(
      onTap: () => state.changeSortOrder(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? appColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? appColors.textPrimary : appColors.textSecondary,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? appColors.background : appColors.textSecondary,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ── Search Results ──

  Widget _buildSearchResults(SearchState state) {
    if (state.isSearching) {
      final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
      return Center(
        child: CircularProgressIndicator(color: appColors.textPrimary),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildTopTab(state),
        _buildUsersTab(state),
        _buildTopicsTab(state),
        _buildPostsTab(state),
      ],
    );
  }

  bool _getHasMore(SearchState state, SearchTab tab) {
    switch (tab) {
      case SearchTab.top:
        return state.hasMoreUsers || state.hasMorePosts || state.hasMoreTopics;
      case SearchTab.users:
        return state.hasMoreUsers;
      case SearchTab.topics:
        return state.hasMoreTopics;
      case SearchTab.posts:
        return state.hasMorePosts;
    }
  }

  Widget _buildLoadingFooter(SearchState state, SearchTab tab) {
    if (!state.isLoadingMore) return const SizedBox.shrink();
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildTopTab(SearchState state) {
    final hasResults = state.searchUsers.isNotEmpty ||
        state.searchTopics.isNotEmpty ||
        state.searchPosts.isNotEmpty;

    if (!hasResults) {
      return _buildNoResults();
    }

    return ListView(
      controller: _scrollController,
      children: [
        if (state.searchUsers.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context)!.sectionUsers, state.totalUsers),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: state.searchUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final u = state.searchUsers[index];
                return SizedBox(
                  width: 140,
                  height: 210,
                  child: UserCard(user: u, isFollowing: u.isFollowing ?? false),
                );
              },
            ),
          ),
        ],
        if (state.searchTopics.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context)!.sectionTopics, state.totalTopics),
          ...state.searchTopics.take(3).map((t) => TopicTile(trendingTopic: t)),
          if (state.totalTopics > 3)
            _buildSeeAllButton(AppLocalizations.of(context)!.seeAllTopics, () {
              _tabController.animateTo(2);
            }),
        ],
        if (state.searchPosts.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context)!.sectionPosts, state.totalPosts),
          ...state.searchPosts.take(5).map((p) => SearchPostTile(post: p)),
        ],
        _buildLoadingFooter(state, SearchTab.top),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(color: appColors.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeAllButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.blue[400],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (state.searchUsers.isEmpty) return _buildNoResults();
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      itemCount: state.searchUsers.length + 1,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        if (index == state.searchUsers.length) {
          return _buildLoadingFooter(state, SearchTab.users);
        }
        return UserTilePage(user: state.searchUsers[index], isFollowing: state.searchUsers[index].isFollowing ?? false);
      },
    );
  }

  Widget _buildTopicsTab(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (state.searchTopics.isEmpty) return _buildNoResults();
    return ListView.separated(
      controller: _scrollController,
      itemCount: state.searchTopics.length + 1,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        if (index == state.searchTopics.length) {
          return _buildLoadingFooter(state, SearchTab.topics);
        }
        return TopicTile(trendingTopic: state.searchTopics[index]);
      },
    );
  }

  Widget _buildPostsTab(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (state.searchPosts.isEmpty) return _buildNoResults();
    return ListView.separated(
      controller: _scrollController,
      itemCount: state.searchPosts.length + 1,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        if (index == state.searchPosts.length) {
          return _buildLoadingFooter(state, SearchTab.posts);
        }
        return SearchPostTile(post: state.searchPosts[index]);
      },
    );
  }

  Widget _buildNoResults() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.search_normal, size: 48, color: appColors.textMuted),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noResultsFound,
            style: TextStyle(color: appColors.textMuted, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ── Empty State (no query) ──

  Widget _buildEmptyState(SearchState state) {
    if (state.isLoadingEmptyState) {
      final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
      return Center(
        child: CircularProgressIndicator(color: appColors.textPrimary),
      );
    }

    return ListView(
      children: [
        if (state.searchHistory.isNotEmpty) ...[
          _buildEmptySectionHeader(
            AppLocalizations.of(context)!.recent,
            actionText: AppLocalizations.of(context)!.clearAll,
            onAction: () => state.clearSearchHistory(),
          ),
          ...state.searchHistory.map((item) => _buildHistoryItem(item, state)),
        ],
        if (state.hotTopics.isNotEmpty) ...[
          _buildEmptySectionHeader(AppLocalizations.of(context)!.trendingTopics),
          ...state.hotTopics.map((t) => TopicTile(
            trendingTopic: t,
            onTap: () {
              _textController.text = t.name;
              state.onSearchChanged(t.name);
            },
          )),
        ],
        if (state.trendingPosts.isNotEmpty) ...[
          _buildEmptySectionHeader(AppLocalizations.of(context)!.trendingPosts),
          ...state.trendingPosts.map((p) => SearchPostTile(post: p)),
        ],
      ],
    );
  }

  Widget _buildEmptySectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText,
                style: TextStyle(
                  color: appColors.textMuted,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _historyTypeIcon(int searchType) {
    switch (searchType) {
      case 2: return Iconsax.user;
      case 3: return Iconsax.hashtag;
      case 4: return Iconsax.document_text;
      default: return Iconsax.clock;
    }
  }

  String _formatTime(DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 30) return l10n.daysAgo(diff.inDays);
    return '${time.month}/${time.day}';
  }

  Widget _buildHistoryItem(SearchHistoryItem item, SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appColors.destructive,
        child: Icon(Icons.delete_outline, color: appColors.background),
      ),
      onDismissed: (_) => state.deleteHistoryItem(item.id),
      child: GestureDetector(
        onTap: () {
          _textController.text = item.query;
          state.onSearchChanged(item.query);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          child: Row(
            children: [
              Icon(_historyTypeIcon(item.searchType), size: 20, color: appColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.query,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.searchedAt),
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.resultCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${item.resultCount}',
                    style: TextStyle(color: appColors.textMuted, fontSize: 14),
                  ),
                ),
              GestureDetector(
                onTap: () => state.deleteHistoryItem(item.id),
                child: Icon(Icons.close, size: 18, color: appColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
