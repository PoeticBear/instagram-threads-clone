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
    String? pronouns,
    int? gender,
    String? location,
    int? isPrivate,
    int? accountType,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['display_name'] = displayName;
      if (bio != null) body['bio'] = bio;
      if (websiteUrl != null) body['website_url'] = websiteUrl;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;
      if (pronouns != null) body['pronouns'] = pronouns;
      if (gender != null) body['gender'] = gender;
      if (location != null) body['location'] = location;
      if (isPrivate != null) body['is_private'] = isPrivate;
      if (accountType != null) body['account_type'] = accountType;

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

  // ==================== Relation Controls ====================

  // POST /user/relation-control
  Future<void> addRelationControl({required int targetUserId, required int controlType, String? reason}) async {
    try {
      final body = <String, dynamic>{
        'target_user_id': targetUserId,
        'control_type': controlType, // 1=mute, 2=restrict, 3=block
      };
      if (reason != null) body['reason'] = reason;
      await _apiClient.post('user/relation-control', body: body);
    } on ApiException {
      rethrow;
    }
  }

  // DELETE /user/relation-control/{target_user_id}
  Future<void> removeRelationControl(int targetUserId) async {
    try {
      await _apiClient.delete('user/relation-control/$targetUserId');
    } on ApiException {
      rethrow;
    }
  }

  // GET /user/relation-control/list?control_type=1|2|3
  Future<List<RelationControlledUser>> getRelationControlList({int? controlType}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (controlType != null) queryParams['control_type'] = controlType.toString();
      final response = await _apiClient.get('user/relation-control/list', queryParameters: queryParams);
      final list = response['data'] as List? ?? [];
      return list.map((e) => RelationControlledUser.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Save Collections ====================

  // POST /user/save-collections
  Future<SaveCollection> createCollection(String name) async {
    try {
      final response = await _apiClient.post('user/save-collections', body: {'name': name});
      return SaveCollection.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  // GET /user/save-collections
  Future<List<SaveCollection>> getCollections() async {
    try {
      final response = await _apiClient.get('user/save-collections');
      final list = response['data'] as List? ?? [];
      return list.map((e) => SaveCollection.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  // DELETE /user/save-collections/{collection_id}
  Future<void> deleteCollection(int collectionId) async {
    try {
      await _apiClient.delete('user/save-collections/$collectionId');
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Hidden Words ====================

  // GET /user/hidden-words
  Future<List<HiddenWord>> getHiddenWords() async {
    try {
      final response = await _apiClient.get('user/hidden-words');
      final list = response['data'] as List? ?? [];
      return list.map((e) => HiddenWord.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  // POST /user/hidden-words?word_type=1&content=xxx
  Future<void> addHiddenWord({required int wordType, required String content}) async {
    try {
      await _apiClient.post('user/hidden-words', body: {}, queryParameters: {
        'word_type': wordType.toString(), // 1=keyword, 2=phrase, 3=emoji
        'content': content,
      });
    } on ApiException {
      rethrow;
    }
  }

  // DELETE /user/hidden-words/{word_id}
  Future<void> deleteHiddenWord(int wordId) async {
    try {
      await _apiClient.delete('user/hidden-words/$wordId');
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Links ====================

  // GET /user/links
  Future<List<UserLink>> getLinks() async {
    try {
      final response = await _apiClient.get('user/links');
      final list = response['data'] as List? ?? [];
      return list.map((e) => UserLink.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  // POST /user/links?title=xxx&url=xxx
  Future<void> addLink({required String title, required String url}) async {
    try {
      await _apiClient.post('user/links', body: {}, queryParameters: {
        'title': title,
        'url': url,
      });
    } on ApiException {
      rethrow;
    }
  }

  // PUT /user/links/{link_id}?title=xxx&url=xxx
  Future<void> updateLink(int linkId, {required String title, required String url}) async {
    try {
      await _apiClient.put('user/links/$linkId', body: {}, queryParameters: {
        'title': title,
        'url': url,
      });
    } on ApiException {
      rethrow;
    }
  }

  // DELETE /user/links/{link_id}
  Future<void> deleteLink(int linkId) async {
    try {
      await _apiClient.delete('user/links/$linkId');
    } on ApiException {
      rethrow;
    }
  }
}

class UserSettings {
  // Reply permission
  int replyAllowType;           // 1=Everyone, 2=Followers, 3=Pages you follow, 4=Mentioned
  // Mention permission
  int mentionAllowType;         // 1=Everyone, 2=Users you follow, 3=Mutuals only
  // Message settings
  int messageRequestEnabled;    // 0=Off, 1=On
  int messageRequestAllowType;  // 1=Only followed users, 2=Anyone
  // Notification toggles (11 items)
  int notifyLikes;
  int notifyReplies;
  int notifyMentions;
  int notifyFollows;
  int notifyTrending;
  int notifySystem;
  int notifyGroupMessages;
  int notifyQuotes;
  int notifyReposts;
  int notifyPolls;
  int notifyCommunities;
  // Privacy
  int showReadReceipts;
  int showOnlineStatus;
  int allowRecommend;
  // Display
  int hideLikesCount;
  // Interaction restriction
  int interactionRestrictionType; // 1=None, 2=Followed >1 week, 3=Mutuals only
  // Silent mode
  int silentMode;               // 0=Off, 1=On
  // Content rating
  int contentRating;            // 1=All, 2=Teen, 3=Adult

  UserSettings({
    this.replyAllowType = 1,
    this.mentionAllowType = 1,
    this.messageRequestEnabled = 1,
    this.messageRequestAllowType = 1,
    this.notifyLikes = 1,
    this.notifyReplies = 1,
    this.notifyMentions = 1,
    this.notifyFollows = 1,
    this.notifyTrending = 1,
    this.notifySystem = 1,
    this.notifyGroupMessages = 1,
    this.notifyQuotes = 1,
    this.notifyReposts = 1,
    this.notifyPolls = 1,
    this.notifyCommunities = 1,
    this.showReadReceipts = 1,
    this.showOnlineStatus = 1,
    this.allowRecommend = 1,
    this.hideLikesCount = 0,
    this.interactionRestrictionType = 1,
    this.silentMode = 0,
    this.contentRating = 1,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      replyAllowType: json['reply_allow_type'] ?? 1,
      mentionAllowType: json['mention_allow_type'] ?? 1,
      messageRequestEnabled: json['message_request_enabled'] ?? 1,
      messageRequestAllowType: json['message_request_allow_type'] ?? 1,
      notifyLikes: json['notify_likes'] ?? 1,
      notifyReplies: json['notify_replies'] ?? 1,
      notifyMentions: json['notify_mentions'] ?? 1,
      notifyFollows: json['notify_follows'] ?? 1,
      notifyTrending: json['notify_trending'] ?? 1,
      notifySystem: json['notify_system'] ?? 1,
      notifyGroupMessages: json['notify_group_messages'] ?? 1,
      notifyQuotes: json['notify_quotes'] ?? 1,
      notifyReposts: json['notify_reposts'] ?? 1,
      notifyPolls: json['notify_polls'] ?? 1,
      notifyCommunities: json['notify_communities'] ?? 1,
      showReadReceipts: json['show_read_receipts'] ?? 1,
      showOnlineStatus: json['show_online_status'] ?? 1,
      allowRecommend: json['allow_recommend'] ?? 1,
      hideLikesCount: json['hide_likes_count'] ?? 0,
      interactionRestrictionType: json['interaction_restriction_type'] ?? 1,
      silentMode: json['silent_mode'] ?? 0,
      contentRating: json['content_rating'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'reply_allow_type': replyAllowType,
    'mention_allow_type': mentionAllowType,
    'message_request_enabled': messageRequestEnabled,
    'message_request_allow_type': messageRequestAllowType,
    'notify_likes': notifyLikes,
    'notify_replies': notifyReplies,
    'notify_mentions': notifyMentions,
    'notify_follows': notifyFollows,
    'notify_trending': notifyTrending,
    'notify_system': notifySystem,
    'notify_group_messages': notifyGroupMessages,
    'notify_quotes': notifyQuotes,
    'notify_reposts': notifyReposts,
    'notify_polls': notifyPolls,
    'notify_communities': notifyCommunities,
    'show_read_receipts': showReadReceipts,
    'show_online_status': showOnlineStatus,
    'allow_recommend': allowRecommend,
    'hide_likes_count': hideLikesCount,
    'interaction_restriction_type': interactionRestrictionType,
    'silent_mode': silentMode,
    'content_rating': contentRating,
  };

  UserSettings copyWith({
    int? replyAllowType,
    int? mentionAllowType,
    int? messageRequestEnabled,
    int? messageRequestAllowType,
    int? notifyLikes,
    int? notifyReplies,
    int? notifyMentions,
    int? notifyFollows,
    int? notifyTrending,
    int? notifySystem,
    int? notifyGroupMessages,
    int? notifyQuotes,
    int? notifyReposts,
    int? notifyPolls,
    int? notifyCommunities,
    int? showReadReceipts,
    int? showOnlineStatus,
    int? allowRecommend,
    int? hideLikesCount,
    int? interactionRestrictionType,
    int? silentMode,
    int? contentRating,
  }) {
    return UserSettings(
      replyAllowType: replyAllowType ?? this.replyAllowType,
      mentionAllowType: mentionAllowType ?? this.mentionAllowType,
      messageRequestEnabled: messageRequestEnabled ?? this.messageRequestEnabled,
      messageRequestAllowType: messageRequestAllowType ?? this.messageRequestAllowType,
      notifyLikes: notifyLikes ?? this.notifyLikes,
      notifyReplies: notifyReplies ?? this.notifyReplies,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notifyFollows: notifyFollows ?? this.notifyFollows,
      notifyTrending: notifyTrending ?? this.notifyTrending,
      notifySystem: notifySystem ?? this.notifySystem,
      notifyGroupMessages: notifyGroupMessages ?? this.notifyGroupMessages,
      notifyQuotes: notifyQuotes ?? this.notifyQuotes,
      notifyReposts: notifyReposts ?? this.notifyReposts,
      notifyPolls: notifyPolls ?? this.notifyPolls,
      notifyCommunities: notifyCommunities ?? this.notifyCommunities,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowRecommend: allowRecommend ?? this.allowRecommend,
      hideLikesCount: hideLikesCount ?? this.hideLikesCount,
      interactionRestrictionType: interactionRestrictionType ?? this.interactionRestrictionType,
      silentMode: silentMode ?? this.silentMode,
      contentRating: contentRating ?? this.contentRating,
    );
  }
}

class FollowStats {
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool isFollowedByMe;
  final bool isMutual;

  FollowStats({
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing = false,
    this.isFollowedByMe = false,
    this.isMutual = false,
  });

  factory FollowStats.fromJson(Map<String, dynamic> json) {
    return FollowStats(
      followersCount: json['followers_count'] ?? json['followersCount'] ?? 0,
      followingCount: json['following_count'] ?? json['followingCount'] ?? 0,
      postsCount: json['posts_count'] ?? json['postsCount'] ?? 0,
      isFollowing: json['is_following'] ?? json['isFollowing'] ?? false,
      isFollowedByMe: json['is_followed_by_me'] ?? json['isFollowedByMe'] ?? false,
      isMutual: json['is_mutual'] ?? json['isMutual'] ?? false,
    );
  }
}

class RelationControlledUser {
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int controlType; // 1=mute, 2=restrict, 3=block
  final String? reason;
  final String? createTime;

  RelationControlledUser({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.controlType,
    this.reason,
    this.createTime,
  });

  factory RelationControlledUser.fromJson(Map<String, dynamic> json) {
    return RelationControlledUser(
      userId: json['user_id'] ?? json['userId'] ?? json['target_user_id'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      controlType: json['control_type'] ?? json['controlType'] ?? 1,
      reason: json['reason'],
      createTime: json['create_time'] ?? json['createTime'],
    );
  }
}

class SaveCollection {
  final int id;
  final String name;
  final bool isDefault;
  final int saveCount;
  final String? createTime;

  SaveCollection({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.saveCount = 0,
    this.createTime,
  });

  factory SaveCollection.fromJson(Map<String, dynamic> json) {
    return SaveCollection(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
      saveCount: json['save_count'] ?? json['saveCount'] ?? 0,
      createTime: json['create_time'] ?? json['createTime'],
    );
  }
}

class HiddenWord {
  final int id;
  final int wordType; // 1=keyword, 2=phrase, 3=emoji
  final String content;
  final String? createTime;

  HiddenWord({
    required this.id,
    required this.wordType,
    required this.content,
    this.createTime,
  });

  factory HiddenWord.fromJson(Map<String, dynamic> json) {
    return HiddenWord(
      id: json['id'] ?? 0,
      wordType: json['word_type'] ?? json['wordType'] ?? 1,
      content: json['content'] ?? '',
      createTime: json['create_time'] ?? json['createTime'],
    );
  }
}

class UserLink {
  final int id;
  final String title;
  final String url;
  final String? createTime;

  UserLink({
    required this.id,
    required this.title,
    required this.url,
    this.createTime,
  });

  factory UserLink.fromJson(Map<String, dynamic> json) {
    return UserLink(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      createTime: json['create_time'] ?? json['createTime'],
    );
  }
}