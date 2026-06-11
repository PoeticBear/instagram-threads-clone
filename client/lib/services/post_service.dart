import 'dart:convert';
import 'dart:developer' as developer;

import '../model/draft.module.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_exception.dart';

/// 后端返回的时间字符串是 naive 格式（无 `Z` 也无 `+HH:MM` 后缀），
/// 实际语义为 UTC。Dart `DateTime.parse` 对无时区后缀的字符串会按本地时区解析，
/// 在 +08:00 客户端上会出现"刚刚发布却显示 8 小时前"的偏差。
/// 此处兜底：没有时区标识时强制按 UTC 解析。
DateTime _parseUtc(String s) {
  final hasZone = s.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z');
}

class PostService {
  final ApiClient _apiClient;

  PostService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Post> createPost({
    required String content,
    List<String>? mediaUrls,
    List<int>? mediaTypes,
    List<String>? pollOptions,
    int? replyType,
    String? replyToPostId,
    int? replyToUserId,
    String? location,
    List<int>? topicIds,
    int? communityId,
    int? quoteRepostId,
    String? scheduledTime,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
      };
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        body['media_urls'] = mediaUrls;
        body['media_types'] = mediaTypes ?? List.filled(mediaUrls.length, 1);
      }
      if (pollOptions != null && pollOptions.isNotEmpty) {
        body['poll_options'] = pollOptions;
      }
      if (replyType != null) {
        body['reply_type'] = replyType;
      }
      if (replyToPostId != null) {
        body['reply_to_post_id'] = int.tryParse(replyToPostId);
      }
      if (replyToUserId != null) body['reply_to_user_id'] = replyToUserId;
      if (location != null) body['location'] = location;
      if (topicIds != null && topicIds.isNotEmpty) body['topic_ids'] = topicIds;
      if (communityId != null) body['community_id'] = communityId;
      if (quoteRepostId != null) body['quote_post_id'] = quoteRepostId;
      if (scheduledTime != null) body['scheduled_publish_time'] = scheduledTime;

      print('📤 createPost 请求体: ${json.encode(body)}');
      final response = await _apiClient.post('post/create', body: body);
      print('✅ createPost 响应: ${json.encode(response)}');
      return Post.fromJson(response['data']);
    } on ApiException catch (e) {
      print('❌ createPost API异常: ${e.message} (status: ${e.statusCode}, data: ${e.data})');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ createPost 未知异常: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<Post> getPostDetail(String postId) async {
    try {
      final response = await _apiClient.get('post/detail/$postId');
      return Post.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _apiClient.delete('post/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<Post> updatePost({
    required String postId,
    String? content,
    String? imageUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (imageUrl != null) body['image_url'] = imageUrl;

      final response = await _apiClient.put('post/$postId', body: body);
      return Post.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Post>> getFeed({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/feed',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      // Support both flat list and paginated response (PageMeta with 'items' key)
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

      developer.log('Feed parsed ${items.length} items');

      final result = items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      return result;
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Post>> getUserPosts(int userId, {int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/user/$userId/posts',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      // Support both flat list and paginated response (PageMeta with 'items' key)
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

      return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> likePost(String postId) async {
    try {
      await _apiClient.post('post/like/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      await _apiClient.delete('post/like/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> repost(String postId, {String? content}) async {
    try {
      final body = <String, dynamic>{
        'repost_type': 1,
      };
      if (content != null) body['content'] = content;
      await _apiClient.post('post/repost/$postId', body: body);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> reportContent({
    required int targetType,
    required int targetId,
    required int reportType,
    String? description,
  }) async {
    try {
      await _apiClient.post(
        'post/report',
        body: {
          'target_type': targetType,
          'target_id': targetId,
          'report_type': reportType,
          if (description != null) 'description': description,
        },
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<void> savePost(String postId) async {
    try {
      await _apiClient.post('post/save/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unsavePost(String postId) async {
    try {
      await _apiClient.delete('post/save/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> sharePost(String postId) async {
    try {
      await _apiClient.post('post/share/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> pinPost(String postId) async {
    try {
      await _apiClient.post('post/pin/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unpinPost(String postId) async {
    try {
      await _apiClient.delete('post/pin/$postId');
    } on ApiException {
      rethrow;
    }
  }

  Future<Reply> createReply({
    required String postId,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'post_id': int.tryParse(postId),
        'content': content,
      };
      if (imageUrl != null) body['image_url'] = imageUrl;

      print('📤 createReply 请求体: ${json.encode(body)}');
      final response = await _apiClient.post('post/reply', body: body);
      print('✅ createReply 原始响应: ${json.encode(response)}');
      final reply = Reply.fromJson(response['data']);
      print('✅ createReply 解析结果: id=${reply.id}, content=${reply.content}, user=${reply.displayName}');
      return reply;
    } on ApiException catch (e) {
      print('❌ createReply API异常: ${e.message} (status: ${e.statusCode}, data: ${e.data})');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ createReply 未知异常: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Reply>> getReplies(String postId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/reply/list/$postId',
        queryParameters: {
          'page': page.toString(),
          'size': pageSize.toString(),
        },
      );
      print('[REPLY_DEBUG] getReplies raw response type: ${response.runtimeType}');
      print('[REPLY_DEBUG] getReplies raw response keys: ${response is Map ? response.keys.toList() : "N/A"}');

      // API returns PageMeta: { "data": { "items": [...], "total": ..., "page": ..., "size": ... } }
      final data = response['data'];
      print('[REPLY_DEBUG] response[\'data\'] type: ${data.runtimeType}, value: $data');

      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }
      print('[REPLY_DEBUG] parsed items count: ${items.length}');
      if (items.isNotEmpty) {
        print('[REPLY_DEBUG] first item raw: ${items.first}');
      }

      final replies = items.map((e) {
        try {
          return Reply.fromJson(e as Map<String, dynamic>);
        } catch (err) {
          print('[REPLY_DEBUG] Reply.fromJson FAILED for item: $e');
          print('[REPLY_DEBUG] Reply.fromJson error: $err');
          rethrow;
        }
      }).toList();
      print('[REPLY_DEBUG] getReplies success, reply count: ${replies.length}');
      return replies;
    } on ApiException {
      rethrow;
    }
  }

  Future<void> likeReply(String replyId) async {
    try {
      await _apiClient.post('post/reply/like/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unlikeReply(String replyId) async {
    try {
      await _apiClient.delete('post/reply/like/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Post>> getSavedPosts({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/saved',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      // Support both flat list and paginated response (PageMeta with 'items' key)
      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }
      return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> votePoll(int postId, int optionId) async {
    await _apiClient.post('post/poll/$postId/vote', body: {'option_id': optionId});
  }

  Future<void> hideReply(String replyId) async {
    try {
      await _apiClient.post('post/reply/hide/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unhideReply(String replyId) async {
    try {
      await _apiClient.delete('post/reply/hide/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Post>> getScheduledPosts({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/scheduled',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
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
      return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> cancelSchedule(String postId) async {
    try {
      await _apiClient.delete('post/$postId/schedule');
    } on ApiException {
      rethrow;
    }
  }

  Future<List<EditHistory>> getEditHistory(String postId) async {
    try {
      final response = await _apiClient.get('post/$postId/edit-history');
      final list = response['data'] as List? ?? [];
      return list.map((e) => EditHistory.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getNearbyPosts({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.post(
        'post/nearby',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
          'page': page,
          'size': size,
        },
      );
      return response['data'] ?? {};
    } on ApiException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOEmbed(String url) async {
    try {
      final response = await _apiClient.get(
        'post/oembed',
        queryParameters: {'url': url},
      );
      return response['data'] ?? {};
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Draft ====================

  Future<DraftInfo> saveDraft({
    required String content,
    List<String>? mediaUrls,
    List<String>? pollOptions,
    int? topicId,
    int? replyType,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{'content': content};
      if (mediaUrls != null && mediaUrls.isNotEmpty) body['media_urls'] = mediaUrls;
      if (pollOptions != null && pollOptions.isNotEmpty) body['poll_options'] = pollOptions;
      if (topicId != null) body['topic_id'] = topicId;
      if (replyType != null) body['reply_type'] = replyType;
      if (location != null) body['location'] = location;

      final response = await _apiClient.post('post/draft', body: body);
      return DraftInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<List<DraftInfo>> getDrafts({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/draft/list',
        queryParameters: {'page': page.toString(), 'size': size.toString()},
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
      return items.map((e) => DraftInfo.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<DraftInfo> getDraftDetail(int draftId) async {
    try {
      final response = await _apiClient.get('post/draft/$draftId');
      return DraftInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> deleteDraft(int draftId) async {
    try {
      await _apiClient.delete('post/draft/$draftId');
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Guest Reply Request (幽灵帖审核) ====================

  Future<void> requestGuestReply(String postId, {String? content}) async {
    try {
      final body = <String, dynamic>{'post_id': postId};
      if (content != null) body['content'] = content;
      await _apiClient.post('post/guest-reply-request', body: body);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> approveGuestReply(String postId) async {
    try {
      await _apiClient.post('post/guest-reply-request/$postId/approve');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> rejectGuestReply(String postId) async {
    try {
      await _apiClient.post('post/guest-reply-request/$postId/reject');
    } on ApiException {
      rethrow;
    }
  }

  Future<List<GuestReplyRequest>> getPendingGuestReplies(String postId) async {
    try {
      final response = await _apiClient.get('post/guest-reply-request/$postId/pending');
      final list = response['data'] as List? ?? [];
      return list.map((e) => GuestReplyRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Reply Pin / Unpin ====================

  Future<void> pinReply(int replyId) async {
    try {
      await _apiClient.post('post/reply/pin/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  Future<void> unpinReply(int replyId) async {
    try {
      await _apiClient.delete('post/reply/pin/$replyId');
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Pending Reply Moderation ====================

  Future<List<Reply>> getPendingReplies(int postId) async {
    try {
      final response = await _apiClient.get('post/reply/pending/$postId');
      final list = response['data'] as List? ?? [];
      return list.map((e) => Reply.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> approvePendingReply(int postId, int replyId) async {
    try {
      await _apiClient.post(
        'post/reply/pending/$postId/approve',
        body: {'reply_id': replyId},
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<void> rejectPendingReply(int postId, int replyId) async {
    try {
      await _apiClient.post(
        'post/reply/pending/$postId/reject',
        body: {'reply_id': replyId},
      );
    } on ApiException {
      rethrow;
    }
  }

  // ==================== Poll Results ====================

  Future<PollData?> getPollResults(int postId) async {
    try {
      final response = await _apiClient.get('post/poll/$postId');
      final data = response['data'];
      if (data == null) return null;

      // Parse poll data from response
      final pollOptionsRaw = data['poll_options'];
      final pollId = data['poll_id'];
      if (pollId != null && pollOptionsRaw is List && pollOptionsRaw.isNotEmpty) {
        final options = pollOptionsRaw.map((e) => PollOption.fromJson(e as Map<String, dynamic>)).toList();
        final expireStr = data['poll_expire_time'];
        return PollData(
          pollId: pollId is int ? pollId : int.tryParse(pollId.toString()),
          options: options,
          totalVotes: data['poll_total_votes'] ?? 0,
          expireTime: expireStr != null ? DateTime.tryParse(expireStr.toString()) : null,
          userVotedOptionId: data['poll_user_voted_option_id'] is int ? data['poll_user_voted_option_id'] : null,
        );
      }
      return null;
    } on ApiException {
      rethrow;
    }
  }
}

class Post {
  final String id;
  final int userId;
  final String username;
  final String displayName;
  final String? profilePic;
  final String content;
  final List<MediaItem> mediaList;
  final PollData? pollData;
  final DateTime createdAt;
  final int likesCount;
  final int repliesCount;
  final int repostsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  final Post? replyTo;
  final Reply? replyToReply;
  // P3 additional fields
  final String? location;
  final List<int> topicIds;
  final bool isGhost;
  final int? communityId;
  final int? replySettings;
  final int? quoteRepostId;
  final bool isPinned;
  // P3 remaining fields
  final String? scheduledTime;
  final bool isAi;
  // Quote / Repost / Thread fields
  final String? quoteContent;
  final Post? quotePost;
  final bool isRepost;
  final int? repostParentId;
  final List<Post> threadPosts;
  final List<int> threadPostIds;
  final int quotesCount;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.profilePic,
    required this.content,
    this.mediaList = const [],
    this.pollData,
    required this.createdAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.repostsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isReposted = false,
    this.replyTo,
    this.replyToReply,
    this.location,
    this.topicIds = const [],
    this.isGhost = false,
    this.communityId,
    this.replySettings,
    this.quoteRepostId,
    this.isPinned = false,
    this.scheduledTime,
    this.isAi = false,
    this.quoteContent,
    this.quotePost,
    this.isRepost = false,
    this.repostParentId,
    this.threadPosts = const [],
    this.threadPostIds = const [],
    this.quotesCount = 0,
  });

  /// First image URL from mediaList, or null
  String? get imageUrl => mediaList.where((m) => m.mediaType == 1 && m.url.isNotEmpty).map((m) => _resolveImageUrl(m.url)).firstOrNull;

  // Helper getter for compatibility with PostModel.user
  PostUser get user => PostUser(
    userId: userId,
    userName: username,
    displayName: displayName,
    profilePic: profilePic,
  );

  factory Post.fromJson(Map<String, dynamic> json) {
    // Parse user info from nested "user" object or flat fields
    final userObj = json['user'];
    final int userId;
    final String username;
    final String displayName;
    final String? profilePic;
    if (userObj is Map<String, dynamic>) {
      userId = userObj['user_id'] ?? userObj['userId'] ?? userObj['id'] ?? 0;
      username = userObj['username'] ?? '';
      displayName = userObj['display_name'] ?? userObj['displayName'] ?? '';
      profilePic = userObj['avatar'] ?? userObj['profile_pic'] ?? userObj['profilePic'];
    } else {
      userId = json['user_id'] ?? json['userId'] ?? 0;
      username = json['username'] ?? '';
      displayName = json['display_name'] ?? json['displayName'] ?? '';
      profilePic = json['avatar'] ?? json['profile_pic'] ?? json['profilePic'];
    }

    // Parse media_list
    final mediaRaw = json['media_list'];
    final List<MediaItem> mediaList;
    if (mediaRaw is List) {
      mediaList = mediaRaw.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      mediaList = [];
    }

    // Parse created_at / create_time
    final createdAtStr = json['created_at'] ?? json['createdAt'] ?? json['create_time'] ?? json['createTime'];
    final createdAt = createdAtStr != null ? _parseUtc(createdAtStr.toString()) : DateTime.now();

    // Parse poll data
    final pollOptionsRaw = json['poll_options'];
    final pollId = json['poll_id'];
    PollData? pollData;
    if (pollId != null && pollOptionsRaw is List && pollOptionsRaw.isNotEmpty) {
      final options = pollOptionsRaw.map((e) => PollOption.fromJson(e as Map<String, dynamic>)).toList();
      final expireStr = json['poll_expire_time'];
      pollData = PollData(
        pollId: pollId is int ? pollId : int.tryParse(pollId.toString()),
        options: options,
        totalVotes: json['poll_total_votes'] ?? 0,
        expireTime: expireStr != null ? DateTime.tryParse(expireStr.toString()) : null,
        userVotedOptionId: json['poll_user_voted_option_id'] is int ? json['poll_user_voted_option_id'] : null,
      );
    }

    // Parse topic_ids
    final topicIdsRaw = json['topic_ids'] ?? json['topicIds'];
    final List<int> topicIds;
    if (topicIdsRaw is List) {
      topicIds = topicIdsRaw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    } else {
      topicIds = [];
    }

    // Parse thread_post_ids
    final threadPostIdsRaw = json['thread_post_ids'] ?? json['threadPostIds'];
    final List<int> threadPostIds;
    if (threadPostIdsRaw is List) {
      threadPostIds = threadPostIdsRaw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    } else {
      threadPostIds = [];
    }

    // Parse thread_posts
    final threadPostsRaw = json['thread_posts'] ?? json['threadPosts'];
    final List<Post> threadPosts;
    if (threadPostsRaw is List) {
      threadPosts = threadPostsRaw.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      threadPosts = [];
    }

    // Parse quote_post (recursive)
    final quotePostRaw = json['quote_post'] ?? json['quotePost'];
    final Post? quotePost = quotePostRaw != null ? Post.fromJson(quotePostRaw as Map<String, dynamic>) : null;


    return Post(
      id: json['id']?.toString() ?? json['post_id']?.toString() ?? '',
      userId: userId,
      username: username,
      displayName: displayName,
      profilePic: profilePic,
      content: json['content'] ?? '',
      mediaList: mediaList,
      pollData: pollData,
      createdAt: createdAt,
      likesCount: json['likes_count'] ?? json['likesCount'] ?? 0,
      repliesCount: json['replies_count'] ?? json['repliesCount'] ?? 0,
      repostsCount: json['reposts_count'] ?? json['repostsCount'] ?? 0,
      sharesCount: json['shares_count'] ?? json['sharesCount'] ?? 0,
      isLiked: json['is_liked'] ?? json['isLiked'] ?? false,
      isSaved: json['is_saved'] ?? json['isSaved'] ?? false,
      isReposted: json['is_reposted'] ?? json['isReposted'] ?? false,
      replyTo: json['reply_to'] != null ? Post.fromJson(json['reply_to']) : null,
      replyToReply: json['reply_to_reply'] != null ? Reply.fromJson(json['reply_to_reply']) : null,
      // P3 fields
      location: json['location'],
      topicIds: topicIds,
      isGhost: json['is_ghost'] ?? json['isGhost'] ?? false,
      communityId: json['community_id'] ?? json['communityId'],
      replySettings: json['reply_settings'] ?? json['replySettings'],
      quoteRepostId: json['quote_repost_id'] ?? json['quoteRepostId'] ?? json['quote_post_id'] ?? json['quotePostId'],
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      scheduledTime: json['scheduled_time'] ?? json['scheduledTime'],
      isAi: json['is_ai'] ?? json['isAi'] ?? false,
      // Quote / Repost / Thread fields
      quoteContent: json['quote_content'] ?? json['quoteContent'],
      quotePost: quotePost,
      isRepost: json['is_repost'] ?? json['isRepost'] ?? false,
      repostParentId: json['repost_parent_id'] ?? json['repostParentId'],
      threadPosts: threadPosts,
      threadPostIds: threadPostIds,
      quotesCount: json['quotes_count'] ?? json['quotesCount'] ?? 0,
    );
  }

  static String? _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl
        : '${ApiConfig.baseUrl}/';
    return '$base${url.startsWith('/') ? url.substring(1) : url}';
  }
}

class PollData {
  final int? pollId;
  final List<PollOption> options;
  final int totalVotes;
  final DateTime? expireTime;
  final int? userVotedOptionId;

  PollData({
    this.pollId,
    this.options = const [],
    this.totalVotes = 0,
    this.expireTime,
    this.userVotedOptionId,
  });

  bool get hasVoted => userVotedOptionId != null;
  bool get isExpired => expireTime != null && DateTime.now().isAfter(expireTime!);

  PollData copyWith({
    int? pollId,
    List<PollOption>? options,
    int? totalVotes,
    DateTime? expireTime,
    int? userVotedOptionId,
  }) {
    return PollData(
      pollId: pollId ?? this.pollId,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      expireTime: expireTime ?? this.expireTime,
      userVotedOptionId: userVotedOptionId ?? this.userVotedOptionId,
    );
  }
}

class PollOption {
  final int id;
  final String optionText;
  final int votesCount;

  PollOption({
    required this.id,
    this.optionText = '',
    this.votesCount = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? 0,
      optionText: json['option_text'] ?? json['optionText'] ?? '',
      votesCount: json['votes_count'] ?? json['votesCount'] ?? 0,
    );
  }
}

class MediaItem {
  final int id;
  final int mediaType; // 1=image, 2=video, 3=GIF, 4=voice, 5=text
  final String url;
  final String thumbUrl;

  MediaItem({
    this.id = 0,
    this.mediaType = 1,
    this.url = '',
    this.thumbUrl = '',
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? 0,
      mediaType: json['media_type'] ?? json['mediaType'] ?? 1,
      url: json['url'] ?? '',
      thumbUrl: json['thumb_url'] ?? json['thumbUrl'] ?? '',
    );
  }
}

class PostUser {
  final int userId;
  final String userName;
  final String displayName;
  final String? profilePic;

  PostUser({
    required this.userId,
    required this.userName,
    required this.displayName,
    this.profilePic,
  });
}

class Reply {
  final String id;
  final String postId;
  final int userId;
  final String username;
  final String displayName;
  final String? profilePic;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;
  final bool isPinned;
  final bool isHidden;

  Reply({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.displayName,
    this.profilePic,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.isPinned = false,
    this.isHidden = false,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    // Parse user info from nested "user" object (API spec) or flat fields (legacy)
    final userObj = json['user'];
    final int userId;
    final String username;
    final String displayName;
    final String? profilePic;
    if (userObj is Map<String, dynamic>) {
      userId = userObj['id'] ?? userObj['user_id'] ?? userObj['userId'] ?? 0;
      username = userObj['username'] ?? '';
      displayName = userObj['display_name'] ?? userObj['displayName'] ?? '';
      profilePic = userObj['avatar'] ?? userObj['profile_pic'] ?? userObj['profilePic'];
    } else {
      userId = json['user_id'] ?? json['userId'] ?? 0;
      username = json['username'] ?? '';
      displayName = json['display_name'] ?? json['displayName'] ?? '';
      profilePic = json['avatar'] ?? json['profile_pic'] ?? json['profilePic'];
    }

    // Parse first image from media_list (API spec) or fallback to image_url
    String? imageUrl;
    final mediaList = json['media_list'];
    if (mediaList is List && mediaList.isNotEmpty) {
      final firstMedia = mediaList.first;
      if (firstMedia is Map<String, dynamic>) {
        imageUrl = firstMedia['url'];
      }
    }
    imageUrl ??= json['image_url'] ?? json['imageUrl'];

    // Parse create_time (API spec) or created_at / createdAt
    final createdAtStr = json['create_time'] ?? json['created_at'] ?? json['createdAt'] ?? json['createTime'];
    final createdAt = createdAtStr != null ? _parseUtc(createdAtStr.toString()) : DateTime.now();

    return Reply(
      id: json['id']?.toString() ?? json['reply_id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: userId,
      username: username,
      displayName: displayName,
      profilePic: profilePic,
      content: json['content'] ?? '',
      imageUrl: imageUrl,
      createdAt: createdAt,
      likesCount: json['likes_count'] ?? json['likesCount'] ?? 0,
      isLiked: json['is_liked'] ?? json['isLiked'] ?? false,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      isHidden: json['is_hidden'] ?? json['isHidden'] ?? false,
    );
  }
}

class GuestReplyRequest {
  final int id;
  final String postId;
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? content;
  final int status; // 0=pending, 1=approved, 2=rejected
  final String? createTime;

  GuestReplyRequest({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.content,
    this.status = 0,
    this.createTime,
  });

  factory GuestReplyRequest.fromJson(Map<String, dynamic> json) {
    return GuestReplyRequest(
      id: json['id'] ?? 0,
      postId: json['post_id']?.toString() ?? json['postId']?.toString() ?? '',
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      content: json['content'],
      status: json['status'] ?? 0,
      createTime: json['create_time'] ?? json['createTime'],
    );
  }
}

class EditHistory {
  final int id;
  final String postId;
  final String content;
  final DateTime editedAt;

  EditHistory({
    required this.id,
    required this.postId,
    required this.content,
    required this.editedAt,
  });

  factory EditHistory.fromJson(Map<String, dynamic> json) {
    return EditHistory(
      id: json['id'] ?? 0,
      postId: json['post_id']?.toString() ?? '',
      content: json['content'] ?? '',
      editedAt: json['edited_at'] != null
          ? _parseUtc(json['edited_at'].toString())
          : (json['editedAt'] != null ? _parseUtc(json['editedAt'].toString()) : DateTime.now()),
    );
  }
}