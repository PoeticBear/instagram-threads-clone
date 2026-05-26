import 'dart:async';

import 'package:threads/model/user.module.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

enum SearchTab { top, users, topics, posts }

class SearchState extends AppStates {
  SearchService? _searchService;

  SearchService get searchService {
    _searchService ??= SearchService(apiClient: getIt());
    return _searchService!;
  }

  // ── Search results ──
  SearchTab currentTab = SearchTab.top;
  String searchQuery = '';
  bool isSearching = false;
  List<UserModel> searchUsers = [];
  List<SearchPostItem> searchPosts = [];
  List<TrendingTopic> searchTopics = [];
  int totalUsers = 0;
  int totalPosts = 0;
  int totalTopics = 0;

  // ── Empty state data ──
  List<SearchHistoryItem> searchHistory = [];
  List<TrendingTopic> hotTopics = [];
  List<SearchPostItem> trendingPosts = [];
  bool isLoadingEmptyState = false;

  // ── @-mention compat (client-side) ──
  List<UserModel>? _userlist;
  List<UserModel>? _userFilterlist;

  List<UserModel>? get userlist {
    if (_userFilterlist == null) return null;
    return List.from(_userFilterlist!);
  }

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Empty state ──

  Future<void> loadEmptyStateData() async {
    isLoadingEmptyState = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        searchService.getSearchHistory(),
        searchService.getHotTopics(),
        searchService.getTrendingPosts(),
      ]);
      searchHistory = results[0] as List<SearchHistoryItem>;
      hotTopics = results[1] as List<TrendingTopic>;
      trendingPosts = results[2] as List<SearchPostItem>;
    } catch (_) {}

    isLoadingEmptyState = false;
    notifyListeners();
  }

  // ── Search ──

  void onSearchChanged(String query) {
    searchQuery = query;
    _debounce?.cancel();

    if (query.isEmpty) {
      searchUsers = [];
      searchPosts = [];
      searchTopics = [];
      notifyListeners();
      loadEmptyStateData();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch();
    });
  }

  void changeTab(SearchTab tab) {
    if (currentTab == tab) return;
    currentTab = tab;
    notifyListeners();

    if (searchQuery.isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    isSearching = true;
    notifyListeners();

    try {
      final searchType = _tabToSearchType(currentTab);
      final result = await searchService.search(
        keyword: searchQuery,
        searchType: searchType,
      );

      searchUsers = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();
      searchPosts = result.posts;
      searchTopics = result.topics;
      totalUsers = result.totalUsers;
      totalPosts = result.totalPosts;
      totalTopics = result.totalTopics;
    } catch (_) {
      searchUsers = [];
      searchPosts = [];
      searchTopics = [];
    }

    isSearching = false;
    notifyListeners();
  }

  int? _tabToSearchType(SearchTab tab) {
    switch (tab) {
      case SearchTab.top: return 1;
      case SearchTab.users: return 2;
      case SearchTab.topics: return 3;
      case SearchTab.posts: return 4;
    }
  }

  // ── Search history ──

  Future<void> loadSearchHistory() async {
    try {
      searchHistory = await searchService.getSearchHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteHistoryItem(String id) async {
    try {
      await searchService.deleteSearchHistoryItem(id);
      searchHistory = searchHistory.where((h) => h.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearSearchHistory() async {
    try {
      await searchService.clearSearchHistory();
      searchHistory = [];
      notifyListeners();
    } catch (_) {}
  }

  // ── @-mention compat (client-side filter, used by ComposePostState) ──

  Future<void> getDataFromDatabase() async {
    try {
      final result = await searchService.search(keyword: '', limit: 100);
      _userlist = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();
      _userFilterlist = List.from(_userlist!);
      notifyListeners();
    } catch (_) {
      _userlist = [];
      _userFilterlist = [];
      notifyListeners();
    }
  }

  void filterByUsername(String? name) {
    if (_userlist == null || _userlist!.isEmpty) return;

    if (name != null && name.isEmpty) {
      _userFilterlist = List.from(_userlist!);
    } else if (name != null) {
      _userFilterlist = _userlist!
          .where((x) =>
              x.userName != null &&
              x.userName!.toLowerCase().contains(name.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  List<UserModel> getuserDetail(List<String> userIds) {
    if (_userlist == null) return [];
    return _userlist!.where((x) {
      return userIds.contains(x.userId?.toString()) || userIds.contains(x.key);
    }).toList();
  }
}
