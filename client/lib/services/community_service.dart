import '../model/community.module.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'post_service.dart';

class CommunityService {
  final ApiClient _apiClient;

  CommunityService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /community/list - 社区列表（分页）
  Future<Map<String, dynamic>> getCommunities({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'community/list',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
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

      final communityList = items
          .map((e) => CommunityInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      return {
        'items': communityList,
        'total': total,
        'page': currentPage,
        'size': pageSize,
      };
    } on ApiException {
      rethrow;
    }
  }

  /// GET /community/detail/{community_id} - 社区详情
  Future<CommunityInfo> getCommunityDetail(int communityId) async {
    try {
      final response = await _apiClient.get('community/detail/$communityId');
      return CommunityInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// POST /community/join - 加入社区
  Future<void> joinCommunity(int communityId) async {
    try {
      await _apiClient.post('community/join', body: {
        'community_id': communityId,
      });
    } on ApiException {
      rethrow;
    }
  }

  /// DELETE /community/leave/{community_id} - 离开社区
  Future<void> leaveCommunity(int communityId) async {
    try {
      await _apiClient.delete('community/leave/$communityId');
    } on ApiException {
      rethrow;
    }
  }

  /// GET /community/members/{community_id} - 社区成员列表（分页，支持关键词筛选）
  Future<Map<String, dynamic>> getCommunityMembers(
    int communityId, {
    int page = 1,
    int size = 20,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      final response = await _apiClient.get(
        'community/members/$communityId',
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

      final memberList = items
          .map((e) => CommunityMember.fromJson(e as Map<String, dynamic>))
          .toList();

      return {
        'items': memberList,
        'total': total,
        'page': currentPage,
        'size': pageSize,
      };
    } on ApiException {
      rethrow;
    }
  }

  /// GET /community/posts/{community_id} - 社区帖子列表（分页，sort: recent/top）
  Future<List<Post>> getCommunityPosts(
    int communityId, {
    int page = 1,
    int size = 20,
    String sort = 'recent',
  }) async {
    try {
      final response = await _apiClient.get(
        'community/posts/$communityId',
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

  /// POST /community/{community_id}/champion/{user_id} - 设置冠军
  Future<void> setChampion(int communityId, int userId) async {
    try {
      await _apiClient.post('community/$communityId/champion/$userId');
    } on ApiException {
      rethrow;
    }
  }

  /// DELETE /community/{community_id}/champion/{user_id} - 移除冠军
  Future<void> removeChampion(int communityId, int userId) async {
    try {
      await _apiClient.delete('community/$communityId/champion/$userId');
    } on ApiException {
      rethrow;
    }
  }
}
