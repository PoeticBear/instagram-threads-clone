import 'dart:convert';
import 'dart:developer' as developer;

import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_exception.dart';

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

      // Print raw API response for debugging
      developer.log('========== FEED RAW RESPONSE ==========');
      developer.log(const JsonEncoder.withIndent('  ').convert(response));
      developer.log('========================================');

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
      if (items.isNotEmpty) {
        developer.log('========== FIRST FEED ITEM RAW ==========');
        developer.log(JsonEncoder.withIndent('  ').convert(items.first));
        developer.log('==========================================');
      }
      final result = items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      if (result.isNotEmpty) {
        final p = result.first;
        developer.log('>>> PARSED Post: id=${p.id}, likes=${p.likesCount}, replies=${p.repliesCount}, reposts=${p.repostsCount}, shares=${p.sharesCount}');
      }
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
      final body = content != null ? {'content': content} : null;
      await _apiClient.post('post/repost/$postId', body: body);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> reportPost(String postId, {String? reason}) async {
    try {
      await _apiClient.post(
        'post/report',
        body: {
          'post_id': postId,
          if (reason != null) 'reason': reason,
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
        'post_id': postId,
        'content': content,
      };
      if (imageUrl != null) body['image_url'] = imageUrl;

      final response = await _apiClient.post('post/reply', body: body);
      return Reply.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<List<Reply>> getReplies(String postId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/reply/list/$postId',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((e) => Reply.fromJson(e)).toList();
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
      final list = response['data'] as List? ?? [];
      return list.map((e) => Post.fromJson(e)).toList();
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
      profilePic = userObj['profile_pic'] ?? userObj['profilePic'];
    } else {
      userId = json['user_id'] ?? json['userId'] ?? 0;
      username = json['username'] ?? '';
      displayName = json['display_name'] ?? json['displayName'] ?? '';
      profilePic = json['profile_pic'] ?? json['profilePic'];
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
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr.toString()) : DateTime.now();

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
    return Reply(
      id: json['id']?.toString() ?? json['reply_id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      profilePic: json['profile_pic'] ?? json['profilePic'],
      content: json['content'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
      likesCount: json['likes_count'] ?? json['likesCount'] ?? 0,
      isLiked: json['is_liked'] ?? json['isLiked'] ?? false,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      isHidden: json['is_hidden'] ?? json['isHidden'] ?? false,
    );
  }
}