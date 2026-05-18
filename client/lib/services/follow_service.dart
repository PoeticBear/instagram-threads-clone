import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';
import 'user_service.dart';

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

  Future<List<UserInfo>> getFollowing(int userId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/following/$userId',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserInfo.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<List<UserInfo>> getFollowers(int userId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/followers/$userId',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserInfo.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<List<UserInfo>> getMutualFollowers(int userId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/mutual/$userId',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserInfo.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<List<UserInfo>> getRecommendedUsers({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'follow/recommend',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserInfo.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }
}