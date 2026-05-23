import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';

class UserService {
  final ApiClient _apiClient;

  UserService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<UserInfo> getUserProfile(int userId) async {
    try {
      final response = await _apiClient.get('user/profile/$userId');
      debugPrint('user_service.getUserProfile raw response: $response');
      return UserInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '获取用户资料失败: $e');
    }
  }

  Future<UserInfo> updateProfile({
    String? displayName,
    String? bio,
    String? websiteUrl,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['display_name'] = displayName;
      if (bio != null) body['bio'] = bio;
      if (websiteUrl != null) body['website_url'] = websiteUrl;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final response = await _apiClient.put('user/profile', body: body);
      return UserInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<UserSettings> getSettings() async {
    try {
      final response = await _apiClient.get('user/settings');
      return UserSettings.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> updateSettings(UserSettings settings) async {
    try {
      await _apiClient.put('user/settings', body: settings.toJson());
    } on ApiException {
      rethrow;
    }
  }

  Future<List<UserInfo>> getFollowRequests() async {
    try {
      final response = await _apiClient.get('user/follow-requests/pending');
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserInfo.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> approveFollowRequest(int requestId) async {
    try {
      await _apiClient.post('user/follow-requests/$requestId/approve');
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
}

class UserSettings {
  final bool allowMentions;
  final bool allowReplies;
  final bool showOnlineStatus;
  final bool readReceipts;

  UserSettings({
    this.allowMentions = true,
    this.allowReplies = true,
    this.showOnlineStatus = true,
    this.readReceipts = true,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      allowMentions: json['allow_mentions'] ?? json['allowMentions'] ?? true,
      allowReplies: json['allow_replies'] ?? json['allowReplies'] ?? true,
      showOnlineStatus: json['show_online_status'] ?? json['showOnlineStatus'] ?? true,
      readReceipts: json['read_receipts'] ?? json['readReceipts'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'allow_mentions': allowMentions,
        'allow_replies': allowReplies,
        'show_online_status': showOnlineStatus,
        'read_receipts': readReceipts,
      };
}

class FollowStats {
  final int followersCount;
  final int followingCount;
  final int postsCount;

  FollowStats({
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  });

  factory FollowStats.fromJson(Map<String, dynamic> json) {
    return FollowStats(
      followersCount: json['followers_count'] ?? json['followersCount'] ?? 0,
      followingCount: json['following_count'] ?? json['followingCount'] ?? 0,
      postsCount: json['posts_count'] ?? json['postsCount'] ?? 0,
    );
  }
}