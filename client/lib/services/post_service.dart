import 'dart:convert';
import 'dart:developer' as developer;

import '../model/draft.module.dart';
import '../model/post.module.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_exception.dart';

/// 后端返回的时间字符串是 naive 格式（无 `Z` 也无 `+HH:MM` 后缀），
/// 实际语义为 UTC。Dart `DateTime.parse` 对无时区后缀的字符串会按本地时区解析，
/// 在 +08:00 客户端上会出现"刚刚发布却显示 8 小时前"的偏差。
/// 此处兜底：没有时区标识时强制按 UTC 解析。
DateTime _parseUtc(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
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
    double? latitude,
    double? longitude,
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
        // 透传 mediaTypes（不再写死为 1）。
        // 缺省时回退全 1，向后兼容老调用方（纯图片场景）。
        final types = mediaTypes ?? List.filled(mediaUrls.length, 1);
        assert(
          types.length == mediaUrls.length,
          'mediaTypes.length (${types.length}) must equal mediaUrls.length (${mediaUrls.length})',
        );
        body['media_types'] = types;
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
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (topicIds != null && topicIds.isNotEmpty) body['topic_ids'] = topicIds;
      if (communityId != null) body['community_id'] = communityId;
      if (quoteRepostId != null) body['quote_post_id'] = quoteRepostId;
      if (scheduledTime != null) body['scheduled_publish_time'] = scheduledTime;

      final response = await _apiClient.post('post/create', body: body);
      return Post.fromJson(response['data']);
    } on ApiException catch (e) {
      developer.log(
          '❌ createPost API异常: ${e.message} (status: ${e.statusCode}, data: ${e.data})',
          name: 'PostService');
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ createPost 未知异常: $e\n$stackTrace', name: 'PostService');
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

  /// 编辑帖子（PUT /post/{post_id}）
  ///
  /// 服务端约束：帖子发布后 15 分钟内允许编辑，最多编辑 5 次。
  /// 仅可编辑 [content] / [isSensitive] / [contentWarning]，媒体不可编辑。
  /// 服务端拒绝时会抛出 [ApiException]，调用方需捕获并展示 message。
  Future<Post> updatePost({
    required String postId,
    String? content,
    bool? isSensitive,
    String? contentWarning,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (content != null) body['content'] = content;
      if (isSensitive != null) body['is_sensitive'] = isSensitive ? 1 : 0;
      if (contentWarning != null) body['content_warning'] = contentWarning;

      final response = await _apiClient.put('post/$postId', body: body);
      return Post.fromJson(response['data']);
    } on ApiException catch (e) {
      developer.log(
          '❌ updatePost API异常: ${e.message} (status: ${e.statusCode}, data: ${e.data})',
          name: 'PostService');
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ updatePost 未知异常: $e\n$stackTrace', name: 'PostService');
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

      final result =
          items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      return result;
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Post>> getUserPosts(int userId,
      {int page = 1, int size = 20}) async {
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

      return items
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 用户转发列表（GET /post/user/{user_id}/reposts）
  ///
  /// 返回该用户转发过的所有帖子，每条记录包含被转发的原始帖子的完整信息。
  /// 响应是分页结构（PageMeta），沿用与 [getUserPosts] 相同的解析兜底。
  ///
  /// **响应是包装结构**（openapi 中 schema 为 `Page<dict>`，不是 `Page<PostResponse>`）：
  /// 每条记录除了包含被转发的原始帖子外，还附带了转发元信息（如 repost_id /
  /// user_id（转发者）/ reposted_at 等）。如果直接对整条 record 解析 Post.fromJson，
  /// 顶层的 `user_id`（=转发者）会被当成帖子作者，顶层的其他字段会覆盖原帖对应字段，
  /// 而真正的原帖内容（嵌套在子字段中）会被完全忽略 —— 表现为「Reposts Tab 列表项的
  /// 头像/用户名/内容全部错乱」。
  ///
  /// 通过 [_extractOriginalPostJson] 从包装层中抽离出真正的原始帖子 JSON 再解析。
  Future<List<Post>> getUserReposts(int userId,
      {int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/user/$userId/reposts',
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
      } else if (data is Map && data.containsKey('posts')) {
        items = data['posts'] as List? ?? [];
      } else {
        items = [];
      }

      // 每条 record 是「转发记录」包装层，原始 PostResponse 嵌在子字段中。
      // 找不到嵌套字段时回退到把整条 record 当作 PostResponse 解析
      // （旧行为兜底，确保不影响其他潜在的数据形态）。
      final reposts = <Post>[];
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final postJson = _extractOriginalPostJson(raw) ?? raw;
        try {
          reposts.add(Post.fromJson(postJson));
        } catch (_) {
          // 单条解析失败不影响整体；跳过坏记录。
        }
      }
      return reposts;
    } on ApiException {
      rethrow;
    }
  }

  /// 从 reposts 接口的单条 record 中抽离出被转发的原始帖子 JSON。
  ///
  /// openapi 描述：「每条记录包含被转发的原始帖子的完整信息」，但 schema 标记为
  /// 不透明 dict，未指定嵌套字段名。遍历常见命名（snake_case + camelCase）以
  /// 兼容服务端可能使用的字段名；找不到嵌套字段时返回 null。
  static Map<String, dynamic>? _extractOriginalPostJson(
      Map<String, dynamic> record) {
    const candidateKeys = <String>[
      'original_post',
      'originalPost',
      'post',
      'source_post',
      'sourcePost',
      'quote_post',
      'quotePost',
      'parent_post',
      'parentPost',
    ];
    for (final key in candidateKeys) {
      final v = record[key];
      if (v is Map<String, dynamic>) return v;
    }
    return null;
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

    /// 嵌套回复的父回复 ID（OpenAPI 字段 parent_id）。
    /// 为 null 时表示创建帖子的一级回复,非 null 时表示创建某条回复的子回复。
    int? parentId,
  }) async {
    try {
      final body = <String, dynamic>{
        'post_id': int.tryParse(postId),
        'content': content,
      };
      if (imageUrl != null) body['image_url'] = imageUrl;
      if (parentId != null) body['parent_id'] = parentId;

      print('📤 createReply 请求体: ${json.encode(body)}');
      final response = await _apiClient.post('post/reply', body: body);
      print('✅ createReply 原始响应: ${json.encode(response)}');
      final reply = Reply.fromJson(response['data']);
      print(
          '✅ createReply 解析结果: id=${reply.id}, content=${reply.content}, user=${reply.displayName}');
      return reply;
    } on ApiException catch (e) {
      print(
          '❌ createReply API异常: ${e.message} (status: ${e.statusCode}, data: ${e.data})');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ createReply 未知异常: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<List<Reply>> getReplies(
    String postId, {
    int page = 1,
    int pageSize = 20,

    /// 嵌套回复的父回复 ID（OpenAPI 字段 parent_id,GET 端点 schema 标的是 string）。
    /// 为 null 时获取帖子的一级回复列表,非 null 时获取该回复的子回复列表。
    int? parentId,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'size': pageSize.toString(),
      };
      if (parentId != null) {
        // 服务端 schema 在 GET 端点上是 string,统一转字符串传值。
        queryParameters['parent_id'] = parentId.toString();
      }
      final response = await _apiClient.get(
        'post/reply/list/$postId',
        queryParameters: queryParameters,
      );
      print(
          '[REPLY_DEBUG] getReplies raw response type: ${response.runtimeType}');
      print(
          '[REPLY_DEBUG] getReplies raw response keys: ${response is Map ? response.keys.toList() : "N/A"}');

      // API returns PageMeta: { "data": { "items": [...], "total": ..., "page": ..., "size": ... } }
      final data = response['data'];
      print(
          '[REPLY_DEBUG] response[\'data\'] type: ${data.runtimeType}, value: $data');

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
      return items
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> votePoll(int postId, int optionId) async {
    await _apiClient
        .post('post/poll/$postId/vote', body: {'option_id': optionId});
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

  /// 删除回复。
  ///
  /// OpenAPI 规范：`DELETE /post/reply/{reply_id}`。
  /// 权限：回复作者本人可删除自己的回复；帖子作者可删除该帖子下的任意回复。
  Future<void> deleteReply(String replyId) async {
    try {
      await _apiClient.delete('post/reply/$replyId');
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
      return items
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
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
      return list
          .map((e) => EditHistory.fromJson(e as Map<String, dynamic>))
          .toList();
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
    List<int>? mediaTypes,
    List<String>? pollOptions,
    int? topicId,
    int? replyType,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = <String, dynamic>{'content': content};
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        body['media_urls'] = mediaUrls;
        // 透传 mediaTypes（与 mediaUrls 等长），缺省时按全 1 兜底（向后兼容）
        if (mediaTypes != null) {
          assert(
            mediaTypes.length == mediaUrls.length,
            'mediaTypes.length (${mediaTypes.length}) must equal mediaUrls.length (${mediaUrls.length})',
          );
          body['media_types'] = mediaTypes;
        }
      }
      if (pollOptions != null && pollOptions.isNotEmpty)
        body['poll_options'] = pollOptions;
      if (topicId != null) body['topic_id'] = topicId;
      if (replyType != null) body['reply_type'] = replyType;
      if (location != null) body['location'] = location;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

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
      return items
          .map((e) => DraftInfo.fromJson(e as Map<String, dynamic>))
          .toList();
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
      final response =
          await _apiClient.get('post/guest-reply-request/$postId/pending');
      final list = response['data'] as List? ?? [];
      return list
          .map((e) => GuestReplyRequest.fromJson(e as Map<String, dynamic>))
          .toList();
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
      return list
          .map((e) => Reply.fromJson(e as Map<String, dynamic>))
          .toList();
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
      if (pollId != null &&
          pollOptionsRaw is List &&
          pollOptionsRaw.isNotEmpty) {
        final options = pollOptionsRaw
            .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
            .toList();
        final expireStr = data['poll_expire_time'];
        return PollData(
          pollId: pollId is int ? pollId : int.tryParse(pollId.toString()),
          options: options,
          totalVotes: data['poll_total_votes'] ?? 0,
          expireTime: expireStr != null
              ? DateTime.tryParse(expireStr.toString())
              : null,
          userVotedOptionId: data['poll_user_voted_option_id'] is int
              ? data['poll_user_voted_option_id']
              : null,
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
  // Edit-related fields (POST /post/{post_id})
  final bool isEdited;
  final int editCount;
  final DateTime? lastEditTime;
  // Sensitive content fields
  final bool isSensitive;
  final String? contentWarning;

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
    this.isEdited = false,
    this.editCount = 0,
    this.lastEditTime,
    this.isSensitive = false,
    this.contentWarning,
  });

  /// First image URL from mediaList, or null
  String? get imageUrl => mediaList
      .where((m) => m.mediaType == 1 && m.url.isNotEmpty)
      .map((m) => _resolveImageUrl(m.url))
      .firstOrNull;

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
      profilePic =
          userObj['avatar'] ?? userObj['profile_pic'] ?? userObj['profilePic'];
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
      mediaList = mediaRaw
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      mediaList = [];
    }

    // Parse created_at / create_time
    final createdAtStr = json['created_at'] ??
        json['createdAt'] ??
        json['create_time'] ??
        json['createTime'];
    final createdAt = createdAtStr != null
        ? _parseUtc(createdAtStr.toString())
        : DateTime.now();

    // Parse poll data
    final pollOptionsRaw = json['poll_options'];
    final pollId = json['poll_id'];
    PollData? pollData;
    if (pollId != null && pollOptionsRaw is List && pollOptionsRaw.isNotEmpty) {
      final options = pollOptionsRaw
          .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
          .toList();
      final expireStr = json['poll_expire_time'];
      pollData = PollData(
        pollId: pollId is int ? pollId : int.tryParse(pollId.toString()),
        options: options,
        totalVotes: json['poll_total_votes'] ?? 0,
        expireTime:
            expireStr != null ? DateTime.tryParse(expireStr.toString()) : null,
        userVotedOptionId: json['poll_user_voted_option_id'] is int
            ? json['poll_user_voted_option_id']
            : null,
      );
    }

    // Parse topic_ids
    final topicIdsRaw = json['topic_ids'] ?? json['topicIds'];
    final List<int> topicIds;
    if (topicIdsRaw is List) {
      topicIds = topicIdsRaw
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    } else {
      topicIds = [];
    }

    // Parse thread_post_ids
    final threadPostIdsRaw = json['thread_post_ids'] ?? json['threadPostIds'];
    final List<int> threadPostIds;
    if (threadPostIdsRaw is List) {
      threadPostIds = threadPostIdsRaw
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    } else {
      threadPostIds = [];
    }

    // Parse thread_posts
    final threadPostsRaw = json['thread_posts'] ?? json['threadPosts'];
    final List<Post> threadPosts;
    if (threadPostsRaw is List) {
      threadPosts = threadPostsRaw
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      threadPosts = [];
    }

    // Parse quote_post (recursive)
    final quotePostRaw = json['quote_post'] ?? json['quotePost'];
    final Post? quotePost = quotePostRaw != null
        ? Post.fromJson(quotePostRaw as Map<String, dynamic>)
        : null;

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
      replyTo:
          json['reply_to'] != null ? Post.fromJson(json['reply_to']) : null,
      replyToReply: json['reply_to_reply'] != null
          ? Reply.fromJson(json['reply_to_reply'])
          : null,
      // P3 fields
      location: json['location'],
      topicIds: topicIds,
      isGhost: json['is_ghost'] ?? json['isGhost'] ?? false,
      communityId: json['community_id'] ?? json['communityId'],
      replySettings: json['reply_settings'] ?? json['replySettings'],
      quoteRepostId: json['quote_repost_id'] ??
          json['quoteRepostId'] ??
          json['quote_post_id'] ??
          json['quotePostId'],
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
      // Edit-related fields
      isEdited: json['is_edited'] ?? json['isEdited'] ?? false,
      editCount: json['edit_count'] ?? json['editCount'] ?? 0,
      lastEditTime:
          json['last_edit_time'] != null || json['lastEditTime'] != null
              ? _parseUtc(
                  (json['last_edit_time'] ?? json['lastEditTime']).toString())
              : null,
      // Sensitive content fields
      isSensitive: json['is_sensitive'] ?? json['isSensitive'] ?? false,
      contentWarning: json['content_warning'] ?? json['contentWarning'],
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
  bool get isExpired =>
      expireTime != null && DateTime.now().isAfter(expireTime!);

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
  final int? width;
  final int? height;
  // 视频 / 语音时长（秒）。后端 schema 已支持，前端此前未透传。
  final int? duration;

  MediaItem({
    this.id = 0,
    this.mediaType = 1,
    this.url = '',
    this.thumbUrl = '',
    this.width,
    this.height,
    this.duration,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return MediaItem(
      id: json['id'] ?? 0,
      mediaType: json['media_type'] ?? json['mediaType'] ?? 1,
      url: json['url'] ?? '',
      thumbUrl: json['thumb_url'] ?? json['thumbUrl'] ?? '',
      width: parseInt(json['width']),
      height: parseInt(json['height']),
      duration: parseInt(json['duration']),
    );
  }

  /// 转换为 UI 层 PostModel 使用的 MediaItemModel。
  /// 缺失字段以 null 透传，便于 UI 兜底。
  MediaItemModel toMediaItemModel() {
    return MediaItemModel(
      id: id == 0 ? null : id,
      mediaType: mediaType,
      url: url.isEmpty ? null : url,
      thumbUrl: thumbUrl.isEmpty ? null : thumbUrl,
      width: width,
      height: height,
      duration: duration,
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
  // 嵌套回复相关字段
  /// 父回复 ID;为 null 表示该回复是帖子的直接（一级）回复，非 null 表示这是某个回复的子（二级）回复。
  final String? parentId;

  /// 子回复总数（仅一级回复使用，二级回复此字段恒为 0）。
  final int repliesCount;

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
    this.parentId,
    this.repliesCount = 0,
  });

  /// 局部更新 Reply 字段;未传入的参数保持原值。
  /// 用于乐观更新(点赞/置顶/计数),避免在 13+ 字段下逐一重写。
  Reply copyWith({
    String? id,
    String? postId,
    int? userId,
    String? username,
    String? displayName,
    String? profilePic,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    int? likesCount,
    bool? isLiked,
    bool? isPinned,
    bool? isHidden,
    String? parentId,
    bool clearParentId = false,
    int? repliesCount,
  }) {
    return Reply(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profilePic: profilePic ?? this.profilePic,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      repliesCount: repliesCount ?? this.repliesCount,
    );
  }

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
      profilePic =
          userObj['avatar'] ?? userObj['profile_pic'] ?? userObj['profilePic'];
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
    final createdAtStr = json['create_time'] ??
        json['created_at'] ??
        json['createdAt'] ??
        json['createTime'];
    final createdAt = createdAtStr != null
        ? _parseUtc(createdAtStr.toString())
        : DateTime.now();

    // Parse parent_id (支持 snake_case / camelCase;post.json 中 schema 是 int?,此处统一转 String)
    final parentIdRaw = json['parent_id'] ?? json['parentId'];
    final String? parentId =
        parentIdRaw != null ? parentIdRaw.toString() : null;

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
      parentId: parentId,
      repliesCount: json['replies_count'] ?? json['repliesCount'] ?? 0,
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

/// 编辑历史记录（GET /post/{post_id}/edit-history）
///
/// API schema: id, post_id, old_content, new_content, edit_count, create_time
class EditHistory {
  final int id;
  final int postId;
  final String oldContent;
  final String newContent;
  final int editCount;
  final DateTime editedAt;

  EditHistory({
    required this.id,
    required this.postId,
    required this.oldContent,
    required this.newContent,
    required this.editCount,
    required this.editedAt,
  });

  factory EditHistory.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final editedAtStr =
        json['create_time'] ?? json['edited_at'] ?? json['editedAt'];
    return EditHistory(
      id: parseInt(json['id']),
      postId: parseInt(json['post_id'] ?? json['postId']),
      oldContent: json['old_content']?.toString() ?? '',
      newContent: json['new_content']?.toString() ?? '',
      editCount: parseInt(json['edit_count'] ?? json['editCount']),
      editedAt: editedAtStr != null
          ? _parseUtc(editedAtStr.toString())
          : DateTime.now(),
    );
  }
}
