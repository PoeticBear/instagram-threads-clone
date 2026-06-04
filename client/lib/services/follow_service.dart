import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';
import 'user_service.dart';

class FollowListResult {
  final List<UserInfo> users;
  final int total;

  FollowListResult({required this.users, required this.total});
}

class FollowService {
  final ApiClient _apiClient;

  FollowService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<void> followUser(int userId) async {
    try {
      await _apiClient.post('follow/$userId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unfollowUser(int userId) async {
    try {
      await _apiClient.delete('follow/$userId');
    } on ApiException {
      rethrow;
    }
  }

  Future<FollowStats> getFollowStats(int userId) async {
    try {
      final response = await _apiClient.get('follow/$userId/stats');
      return FollowStats.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<FollowListResult> getFollowing(int userId, {int page = 1, int size = 20, String? keyword}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      final response = await _apiClient.get(
        'follow/following/$userId',
        queryParameters: queryParams,
      );
      final data = response['data'];
      final list = (data['items'] as List? ?? []);
      final total = data['total'] as int? ?? 0;
      return FollowListResult(
        users: list.map((e) => UserInfo.fromJson(e)).toList(),
        total: total,
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<FollowListResult> getFollowers(int userId, {int page = 1, int size = 20, String? keyword}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      final response = await _apiClient.get(
        'follow/followers/$userId',
        queryParameters: queryParams,
      );
      final data = response['data'];
      final list = (data['items'] as List? ?? []);
      final total = data['total'] as int? ?? 0;
      return FollowListResult(
        users: list.map((e) => UserInfo.fromJson(e)).toList(),
        total: total,
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<FollowListResult> getMutualFollowers({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/mutual',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final data = response['data'];
      final list = (data['items'] as List? ?? []);
      final total = data['total'] as int? ?? 0;
      return FollowListResult(
        users: list.map((e) => UserInfo.fromJson(e)).toList(),
        total: total,
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<FollowListResult> getRecommendedUsers({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/recommend',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final data = response['data'];
      final list = (data['items'] as List? ?? []);
      final total = data['total'] as int? ?? 0;
      return FollowListResult(
        users: list.map((e) => UserInfo.fromJson(e)).toList(),
        total: total,
      );
    } on ApiException {
      rethrow;
    }
  }
}
