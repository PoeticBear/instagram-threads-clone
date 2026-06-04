import 'dart:async';

import 'package:threads/model/user.module.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/services/topic_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

enum SearchTab { top, users, topics, posts }

class SearchState extends AppStates {
  SearchService? _searchService;
  TopicService? _topicService;
  FollowService? _followService;

  SearchService get searchService {
    _searchService ??= SearchService(apiClient: getIt());
    return _searchService!;
  }

  TopicService get topicService {
    _topicService ??= TopicService(apiClient: getIt());
    return _topicService!;
  }

  FollowService get followService {
    _followService ??= FollowService(apiClient: getIt());
    return _followService!;
  }

  // ── Search results ──
  SearchTab currentTab = SearchTab.top;
  String searchQuery = '';
  bool isSearching = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  static const int pageSize = 20;
  String sortOrder = 'top'; // 'top' or 'recent'
  List<UserModel> searchUsers = [];
  List<SearchPostItem> searchPosts = [];
  List<TrendingTopic> searchTopics = [];
  int totalUsers = 0;
  int totalPosts = 0;
  int totalTopics = 0;

  bool get hasMoreUsers => searchUsers.length < totalUsers;
  bool get hasMorePosts => searchPosts.length < totalPosts;
  bool get hasMoreTopics => searchTopics.length < totalTopics;

  // ── Empty state data ──
  List<SearchHistoryItem> searchHistory = [];
  int searchHistoryTotal = 0;
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
      final historyResp = results[0] as SearchHistoryResponse;
      searchHistory = historyResp.items;
      searchHistoryTotal = historyResp.total;
      hotTopics = results[1] as List<TrendingTopic>;
      trendingPosts = results[2] as List<SearchPostItem>;
    } catch (_) {}

    isLoadingEmptyState = false;
    notifyListeners();

    // 在后台补全关注状态，不阻塞 UI
    _enrichFollowStatus(hotTopics);
  }

  /// 用 topic/list 批量查询话题关注状态，补全 TrendingTopic.isFollowing
  Future<void> _enrichFollowStatus(List<TrendingTopic> topics) async {
    if (topics.isEmpty) return;
    try {
      final ids = topics.map((t) => int.tryParse(t.id)).whereType<int>().toSet();
      if (ids.isEmpty) return;

      // 查询话题列表获取关注状态
      final result = await topicService.getTopics(page: 1, size: 100);
      final items = result['items'] as List;
      final followedIds = <int>{};
      for (final item in items) {
        if (item.isFollowing && ids.contains(item.id)) {
          followedIds.add(item.id);
        }
      }

      // 匹配并更新
      bool changed = false;
      for (int i = 0; i < topics.length; i++) {
        final id = int.tryParse(topics[i].id);
        if (id != null && followedIds.contains(id) && !topics[i].isFollowing) {
          topics[i] = TrendingTopic(
            id: topics[i].id,
            name: topics[i].name,
            postsCount: topics[i].postsCount,
            isFollowing: true,
          );
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

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
    currentPage = 1;
    notifyListeners();

    if (searchQuery.isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    isSearching = true;
    currentPage = 1;
    notifyListeners();

    try {
      final searchType = _tabToSearchType(currentTab);
      final result = await searchService.search(
        keyword: searchQuery,
        searchType: searchType,
        sort: sortOrder,
        page: 1,
        limit: pageSize,
      );

      searchUsers = _mapUsers(result.users);
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

    // 在后台补全搜索结果中话题的关注状态
    if (searchTopics.isNotEmpty) _enrichFollowStatus(searchTopics);
    // 在后台补全搜索结果中用户的关注状态
    if (searchUsers.isNotEmpty) _enrichUserFollowStatus(searchUsers);
  }

  /// 加载下一页
  Future<void> loadMore() async {
    if (isLoadingMore || isSearching) return;

    final bool hasMore;
    switch (currentTab) {
      case SearchTab.top:
        hasMore = hasMoreUsers || hasMorePosts || hasMoreTopics;
        break;
      case SearchTab.users:
        hasMore = hasMoreUsers;
        break;
      case SearchTab.topics:
        hasMore = hasMoreTopics;
        break;
      case SearchTab.posts:
        hasMore = hasMorePosts;
        break;
    }
    if (!hasMore) return;

    isLoadingMore = true;
    currentPage++;
    notifyListeners();

    try {
      final searchType = _tabToSearchType(currentTab);
      final result = await searchService.search(
        keyword: searchQuery,
        searchType: searchType,
        sort: sortOrder,
        page: currentPage,
        limit: pageSize,
      );

      searchUsers = [...searchUsers, ..._mapUsers(result.users)];
      searchPosts = [...searchPosts, ...result.posts];
      searchTopics = [...searchTopics, ...result.topics];
      totalUsers = result.totalUsers;
      totalPosts = result.totalPosts;
      totalTopics = result.totalTopics;
    } catch (_) {}

    isLoadingMore = false;
    notifyListeners();
  }

  List<UserModel> _mapUsers(List<UserInfo> infos) {
    return infos.map((info) => UserModel(
      userId: info.userId,
      userName: info.username,
      displayName: info.displayName,
      bio: info.bio,
      profilePic: info.profilePic,
      followersCount: info.followersCount,
      followingCount: info.followingCount,
      isVerified: info.isVerified,
    )).toList();
  }

  /// 用 follow/{userId}/stats 批量查询用户关注状态，补全 UserModel.isFollowing
  Future<void> _enrichUserFollowStatus(List<UserModel> users) async {
    if (users.isEmpty) return;
    try {
      final futures = <Future<FollowStats>>[];
      final indices = <int>[];
      for (int i = 0; i < users.length; i++) {
        if (users[i].userId != null) {
          futures.add(followService.getFollowStats(users[i].userId!));
          indices.add(i);
        }
      }
      if (futures.isEmpty) return;
      final stats = await Future.wait(futures);

      bool changed = false;
      for (int j = 0; j < indices.length; j++) {
        final i = indices[j];
        if (stats[j].isFollowing && users[i].isFollowing != true) {
          users[i] = users[i].copyWith(isFollowing: true);
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  int? _tabToSearchType(SearchTab tab) {
    switch (tab) {
      case SearchTab.top: return 1;
      case SearchTab.users: return 2;
      case SearchTab.topics: return 3;
      case SearchTab.posts: return 4;
    }
  }

  void changeSortOrder(String sort) {
    if (sortOrder == sort) return;
    sortOrder = sort;
    if (searchQuery.isNotEmpty) {
      _performSearch();
    }
  }

  // ── Search history ──

  Future<void> loadSearchHistory() async {
    try {
      final resp = await searchService.getSearchHistory();
      searchHistory = resp.items;
      searchHistoryTotal = resp.total;
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
