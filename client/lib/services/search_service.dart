import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';

class SearchService {
  final ApiClient _apiClient;

  SearchService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// search_type: 1=top, 2=users, 3=topics, 4=posts
  Future<SearchResult> search({
    required String keyword,
    int? searchType,
    String sort = 'top',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'search',
        queryParameters: {
          'keyword': keyword,
          if (searchType != null) 'search_type': searchType.toString(),
          'sort': sort,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      return SearchResult.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// @mention 专用：模糊搜索用户（包含私密用户）。
  ///
  /// 用服务端最新签名 `type=2` + `include_private=1`，
  /// 仅返回用户列表（不带帖子 / 话题）。
  Future<List<UserInfo>> searchMentionUsers(String keyword, {int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'search',
        queryParameters: {
          'type': '2',
          'include_private': '1',
          'keyword': keyword,
          'limit': limit.toString(),
        },
      );
      return SearchResult.fromJson(response['data']).users;
    } on ApiException {
      rethrow;
    }
  }

  Future<SearchHistoryResponse> getSearchHistory({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'search/history',
        queryParameters: {
          'limit': limit.toString(),
        },
      );
      final data = response['data'];
      if (data is Map) {
        return SearchHistoryResponse.fromJson(Map<String, dynamic>.from(data));
      }
      final list = (data as List? ?? []).cast<Map<String, dynamic>>();
      return SearchHistoryResponse(
        items: list.map((e) => SearchHistoryItem.fromJson(e)).toList(),
        total: list.length,
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _apiClient.delete('search/history');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> deleteSearchHistoryItem(String historyId) async {
    try {
      await _apiClient.delete('search/history/$historyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<List<TrendingTopic>> getHotTopics({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'search/hot-topics',
        queryParameters: {
          'limit': limit.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => TrendingTopic.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<List<SearchPostItem>> getTrendingPosts({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'search/trending',
        queryParameters: {
          'limit': limit.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => SearchPostItem.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }
}

class SearchResult {
  final String keyword;
  final List<UserInfo> users;
  final List<SearchPostItem> posts;
  final List<TrendingTopic> topics;
  final int totalUsers;
  final int totalPosts;
  final int totalTopics;

  SearchResult({
    this.keyword = '',
    this.users = const [],
    this.posts = const [],
    this.topics = const [],
    this.totalUsers = 0,
    this.totalPosts = 0,
    this.totalTopics = 0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      keyword: json['keyword'] ?? '',
      users: (json['users'] as List?)?.map((e) => UserInfo.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      posts: (json['posts'] as List?)?.map((e) => SearchPostItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      topics: (json['topics'] as List?)?.map((e) => TrendingTopic.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      totalUsers: json['total_users'] ?? 0,
      totalPosts: json['total_posts'] ?? 0,
      totalTopics: json['total_topics'] ?? 0,
    );
  }
}

class SearchPostItem {
  final int id;
  final int userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final int mediaCount;
  final int likesCount;
  final int repliesCount;
  final String createTime;

  SearchPostItem({
    required this.id,
    required this.userId,
    this.username = '',
    this.displayName = '',
    this.avatarUrl,
    this.content = '',
    this.mediaCount = 0,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.createTime = '',
  });

  factory SearchPostItem.fromJson(Map<String, dynamic> json) {
    return SearchPostItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'],
      content: json['content'] ?? '',
      mediaCount: json['media_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      repliesCount: json['replies_count'] ?? 0,
      createTime: json['create_time'] ?? '',
    );
  }
}

class SearchHistoryItem {
  final String id;
  final String query;
  final int searchType;
  final int resultCount;
  final DateTime searchedAt;

  SearchHistoryItem({
    required this.id,
    required this.query,
    this.searchType = 1,
    this.resultCount = 0,
    required this.searchedAt,
  });

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id']?.toString() ?? '',
      query: json['keyword'] ?? json['query'] ?? '',
      searchType: json['search_type'] ?? 1,
      resultCount: json['result_count'] ?? 0,
      searchedAt: json['create_time'] != null
          ? DateTime.tryParse(json['create_time']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SearchHistoryResponse {
  final List<SearchHistoryItem> items;
  final int total;

  SearchHistoryResponse({
    this.items = const [],
    this.total = 0,
  });

  factory SearchHistoryResponse.fromJson(Map<String, dynamic> json) {
    return SearchHistoryResponse(
      items: (json['items'] as List?)?.map((e) => SearchHistoryItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      total: json['total'] ?? 0,
    );
  }
}

class TrendingTopic {
  final String id;
  final String name;
  final int postsCount;
  final bool isFollowing;

  TrendingTopic({
    required this.id,
    required this.name,
    this.postsCount = 0,
    this.isFollowing = false,
  });

  factory TrendingTopic.fromJson(Map<String, dynamic> json) {
    return TrendingTopic(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['topic_name'] ?? '',
      postsCount: json['posts_count'] ?? json['postsCount'] ?? 0,
      isFollowing: json['is_following'] ?? json['isFollowing'] ?? false,
    );
  }
}
