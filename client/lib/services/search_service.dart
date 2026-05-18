import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';

class SearchService {
  final ApiClient _apiClient;

  SearchService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<SearchResult> search({
    required String query,
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'search',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      return SearchResult.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<List<SearchHistoryItem>> getSearchHistory() async {
    try {
      final response = await _apiClient.get('search/history');
      final list = response['data'] as List? ?? [];
      return list.map((e) => SearchHistoryItem.fromJson(e)).toList();
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

  Future<List<TrendingTopic>> getHotTopics() async {
    try {
      final response = await _apiClient.get('search/hot-topics');
      final list = response['data'] as List? ?? [];
      return list.map((e) => TrendingTopic.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<List<dynamic>> getTrendingPosts() async {
    try {
      final response = await _apiClient.get('search/trending');
      final list = response['data'] as List? ?? [];
      return list;
    } on ApiException {
      rethrow;
    }
  }
}

class SearchResult {
  final List<UserInfo> users;
  final List<dynamic> posts;
  final List<TrendingTopic> topics;

  SearchResult({
    this.users = const [],
    this.posts = const [],
    this.topics = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      users: (json['users'] as List?)?.map((e) => UserInfo.fromJson(e)).toList() ?? [],
      posts: json['posts'] as List? ?? [],
      topics: (json['topics'] as List?)?.map((e) => TrendingTopic.fromJson(e)).toList() ?? [],
    );
  }
}

class SearchHistoryItem {
  final String id;
  final String query;
  final DateTime searchedAt;

  SearchHistoryItem({
    required this.id,
    required this.query,
    required this.searchedAt,
  });

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id']?.toString() ?? '',
      query: json['query'] ?? json['q'] ?? '',
      searchedAt: json['searched_at'] != null
          ? DateTime.parse(json['searched_at'])
          : DateTime.now(),
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