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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
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

  @override
  void dispose() {
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

  // ── Tab Bar ──

  Widget _buildTabBar(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return TabBar(
      controller: _tabController,
      labelColor: appColors.textPrimary,
      unselectedLabelColor: appColors.textSecondary,
      indicatorColor: appColors.textPrimary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      tabs: [
        Tab(text: AppLocalizations.of(context)!.tabTop),
        Tab(text: AppLocalizations.of(context)!.tabUsers),
        Tab(text: AppLocalizations.of(context)!.tabTopics),
        Tab(text: AppLocalizations.of(context)!.tabPosts),
      ],
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

  Widget _buildTopTab(SearchState state) {
    final hasResults = state.searchUsers.isNotEmpty ||
        state.searchTopics.isNotEmpty ||
        state.searchPosts.isNotEmpty;

    if (!hasResults) {
      return _buildNoResults();
    }

    return ListView(
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      itemCount: state.searchUsers.length,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        return UserTilePage(user: state.searchUsers[index], isadded: state.searchUsers[index].isFollowing ?? false);
      },
    );
  }

  Widget _buildTopicsTab(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (state.searchTopics.isEmpty) return _buildNoResults();
    return ListView.separated(
      itemCount: state.searchTopics.length,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        return TopicTile(trendingTopic: state.searchTopics[index]);
      },
    );
  }

  Widget _buildPostsTab(SearchState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (state.searchPosts.isEmpty) return _buildNoResults();
    return ListView.separated(
      itemCount: state.searchPosts.length,
      separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5, indent: 65),
      itemBuilder: (context, index) {
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
              Icon(Iconsax.clock, size: 20, color: appColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.query,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
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
