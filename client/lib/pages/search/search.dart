import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/state/search.state.dart';
import 'package:threads/widget/list.dart';
import 'package:threads/widget/search_post_tile.dart';
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.searchTitle,
          style: TextStyle(
            color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: TextField(
        cursorColor: Colors.white,
        keyboardAppearance: Brightness.dark,
        controller: _textController,
        onChanged: (value) => state.onSearchChanged(value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(Iconsax.search_normal, size: 18, color: Colors.grey),
          suffixIcon: state.searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _textController.clear();
                    state.onSearchChanged('');
                  },
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
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
          fillColor: const Color.fromARGB(255, 48, 48, 48),
          filled: true,
          contentPadding: const EdgeInsets.only(left: 15, top: 5),
          alignLabelWithHint: true,
          hintText: AppLocalizations.of(context)!.search,
          hintStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
            fontFamily: 'arial',
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ──

  Widget _buildTabBar(SearchState state) {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.white,
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
          ...state.searchUsers.take(3).map((u) => UserTilePage(user: u, isadded: false)),
          if (state.totalUsers > 3)
            _buildSeeAllButton(AppLocalizations.of(context)!.seeAllUsers, () {
              _tabController.animateTo(1);
            }),
        ],
        if (state.searchTopics.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context)!.sectionTopics, state.totalTopics),
          ...state.searchTopics.take(3).map((t) => TopicTile(topic: t)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
    if (state.searchUsers.isEmpty) return _buildNoResults();
    return ListView.separated(
      itemCount: state.searchUsers.length,
      separatorBuilder: (_, __) => const Divider(color: Color.fromARGB(255, 69, 69, 69), height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        return UserTilePage(user: state.searchUsers[index], isadded: false);
      },
    );
  }

  Widget _buildTopicsTab(SearchState state) {
    if (state.searchTopics.isEmpty) return _buildNoResults();
    return ListView.separated(
      itemCount: state.searchTopics.length,
      separatorBuilder: (_, __) => const Divider(color: Color.fromARGB(255, 69, 69, 69), height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        return TopicTile(topic: state.searchTopics[index]);
      },
    );
  }

  Widget _buildPostsTab(SearchState state) {
    if (state.searchPosts.isEmpty) return _buildNoResults();
    return ListView.separated(
      itemCount: state.searchPosts.length,
      separatorBuilder: (_, __) => const Divider(color: Color.fromARGB(255, 69, 69, 69), height: 0.5, indent: 65),
      itemBuilder: (context, index) {
        return SearchPostTile(post: state.searchPosts[index]);
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.search_normal, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noResultsFound,
            style: TextStyle(color: Colors.grey[500], fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ── Empty State (no query) ──

  Widget _buildEmptyState(SearchState state) {
    if (state.isLoadingEmptyState) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
            topic: t,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(SearchHistoryItem item, SearchState state) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[800],
        child: const Icon(Icons.delete_outline, color: Colors.white),
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
              Icon(Iconsax.clock, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.query,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => state.deleteHistoryItem(item.id),
                child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
