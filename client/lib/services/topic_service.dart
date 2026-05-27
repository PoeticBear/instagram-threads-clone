import '../model/topic.module.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'post_service.dart';

class TopicService {
  final ApiClient _apiClient;

  TopicService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /topic/trending - 热门话题
  Future<List<TopicInfo>> getTrendingTopics({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'topic/trending',
        queryParameters: {
          'limit': limit.toString(),
        },
      );
      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }
      return items
          .map((e) => TopicInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// GET /topic/list - 话题列表（分页）
  Future<Map<String, dynamic>> getTopics({
    int page = 1,
    int size = 20,
    int? sourceType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (sourceType != null) {
        queryParams['source_type'] = sourceType.toString();
      }

      final response = await _apiClient.get(
        'topic/list',
        queryParameters: queryParams,
      );

      final data = response['data'];
      List items;
      int total;
      int currentPage;
      int pageSize;

      if (data is List) {
        items = data;
        total = items.length;
        currentPage = page;
        pageSize = size;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
        total = data['total'] ?? items.length;
        currentPage = data['page'] ?? page;
        pageSize = data['size'] ?? size;
      } else {
        items = [];
        total = 0;
        currentPage = page;
        pageSize = size;
      }

      final topicList = items
          .map((e) => TopicInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      return {
        'items': topicList,
        'total': total,
        'page': currentPage,
        'size': pageSize,
      };
    } on ApiException {
      rethrow;
    }
  }

  /// GET /topic/detail/$topicId - 话题详情
  Future<TopicInfo> getTopicDetail(int topicId) async {
    try {
      final response = await _apiClient.get('topic/detail/$topicId');
      return TopicInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// POST /topic/follow/$topicId - 关注话题
  Future<void> followTopic(int topicId) async {
    try {
      await _apiClient.post('topic/follow/$topicId');
    } on ApiException {
      rethrow;
    }
  }

  /// DELETE /topic/follow/$topicId - 取消关注
  Future<void> unfollowTopic(int topicId) async {
    try {
      await _apiClient.delete('topic/follow/$topicId');
    } on ApiException {
      rethrow;
    }
  }

  /// POST /topic/mute/$topicId - 静音话题
  Future<void> muteTopic(int topicId) async {
    try {
      await _apiClient.post('topic/mute/$topicId');
    } on ApiException {
      rethrow;
    }
  }

  /// DELETE /topic/mute/$topicId - 取消静音
  Future<void> unmuteTopic(int topicId) async {
    try {
      await _apiClient.delete('topic/mute/$topicId');
    } on ApiException {
      rethrow;
    }
  }

  /// GET /topic/muted - 已静音话题 ID 列表
  Future<List<int>> getMutedTopics() async {
    try {
      final response = await _apiClient.get('topic/muted');
      final data = response['data'];
      if (data is List) {
        return data.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
      }
      return [];
    } on ApiException {
      rethrow;
    }
  }

  /// GET /topic/posts/$topicId - 话题帖子列表
  Future<List<Post>> getTopicPosts(
    int topicId, {
    int page = 1,
    int size = 20,
    String sort = 'latest',
  }) async {
    try {
      final response = await _apiClient.get(
        'topic/posts/$topicId',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
          'sort': sort,
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else if (data is Map && data.containsKey('posts')) {
        items = data['posts'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// GET /topic/related/$topicId - 相关话题推荐
  Future<List<TopicInfo>> getRelatedTopics(int topicId, {int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        'topic/related/$topicId',
        queryParameters: {
          'limit': limit.toString(),
        },
      );
      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }
      return items
          .map((e) => TopicInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }
}
