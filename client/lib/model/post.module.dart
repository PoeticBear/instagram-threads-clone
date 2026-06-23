import 'package:threads/services/post_service.dart';
import 'user.module.dart';

/// 媒体类型常量
class MediaType {
  static const int image = 1;
  static const int video = 2;
  static const int gif = 3;
  static const int voice = 4;
  static const int textAttachment = 5;
  // Phase 2 预留：实况动图（iOS Live Photo），本期末启用
  static const int livePhoto = 6;
}

/// 对应 API 的 MediaItem 结构
class MediaItemModel {
  final int? id;
  final int mediaType; // 1=图片, 2=视频, 3=GIF, 4=语音, 5=文本附件
  final String? url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  // 视频 / 语音时长（秒）。后端 schema 已支持，前端此前未透传。
  final int? duration;

  const MediaItemModel({
    this.id,
    required this.mediaType,
    this.url,
    this.thumbUrl,
    this.width,
    this.height,
    this.duration,
  });

  bool get isVideo => mediaType == MediaType.video;
  bool get isGif => mediaType == MediaType.gif;
  // 兼容旧渲染分支：gif 仍按 image 渲染走 CachedNetworkImage
  bool get isImage =>
      mediaType == MediaType.image || mediaType == MediaType.gif;
  // 可播放媒体（视频 / GIF），自动播放池用
  bool get isPlayable =>
      mediaType == MediaType.video || mediaType == MediaType.gif;

  /// 时长格式化为 "m:ss" / "h:mm:ss"。无 duration 返回空串。
  String get durationLabel {
    if (duration == null || duration! <= 0) return '';
    final s = duration!;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  factory MediaItemModel.fromJson(Map<dynamic, dynamic> map) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return MediaItemModel(
      id: parseInt(map['id']),
      mediaType: parseInt(map['media_type']) ?? parseInt(map['mediaType']) ?? 1,
      url: map['url']?.toString(),
      thumbUrl: map['thumb_url']?.toString() ?? map['thumbUrl']?.toString(),
      width: parseInt(map['width']),
      height: parseInt(map['height']),
      duration: parseInt(map['duration']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_type': mediaType,
      'url': url,
      'thumb_url': thumbUrl,
      'width': width,
      'height': height,
      if (duration != null) 'duration': duration,
    };
  }
}

/// 帖子正文中被 @提及的用户快照。
///
/// 用于「正文 @username 可点击跳转」：客户端按 [username] 匹配正文里的
/// `@username` 文本片段，命中后用 [userId] 跳转该用户主页。
/// 服务端应返回发帖时的 username 快照（与正文里的 @username 字面量严格一致），
/// 这样即使被提及用户后续改名，跳转仍走原 userId，正文显示也不变。
class MentionedUser {
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const MentionedUser({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory MentionedUser.fromJson(Map<String, dynamic> json) {
    return MentionedUser(
      userId: json['user_id'] ?? json['userId'] ?? json['id'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'],
      avatarUrl:
          json['avatar_url'] ?? json['avatarUrl'] ?? json['profile_pic'],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
}

class PostModel {
  String? key;
  String? imagePath;
  String? bio;
  late String createdAt;
  UserModel? user;
  List<String?>? comment;
  // API fields
  int? likesCount;
  int? repliesCount;
  int? repostsCount;
  int? sharesCount;
  bool? isLiked;
  bool? isSaved;
  bool? isReposted;
  // 当前登录用户与作者的关注关系。
  // 注：API /post/feed 当前未返回 is_following 字段，此处为本地字段，
  // 默认 null 视为「未关注」。关注成功后通过 PostState._setFollowing 乐观更新。
  bool? isFollowing;
  String? postId; // API uses post_id
  String? replyToPostId;
  String? replyToUserId;
  PollData? pollData;
  // P3 additional fields
  String? location;
  List<int>? topicIds;
  bool? isGhost;
  int? communityId;
  int? replySettings;
  int? quoteRepostId;
  bool? isPinned;
  String? scheduledTime;
  bool? isAi;
  // 位置经纬度（与 location 配套；地图选址时由服务端可选使用）
  double? latitude;
  double? longitude;
  // Quote / Repost / Thread fields
  String? quoteContent;
  PostModel? quotePost;
  bool? isRepost;
  int? repostParentId;
  List<PostModel>? threadPosts;
  List<int>? threadPostIds;
  int? quotesCount;
  // Media list (from API media_list)
  List<MediaItemModel>? mediaList;
  // Edit-related fields (POST /post/{post_id})
  bool? isEdited;
  int? editCount;
  DateTime? lastEditTime;
  // Sensitive content fields
  bool? isSensitive;
  String? contentWarning;
  // ─── @mention 字段 ───
  // 发帖提交时随帖子发送的被提及用户 userId 列表（需求 1：身份绑定）。
  // 当前用户名是文本字面量，改名即失效；用 userId 持久化关联。
  List<int>? mentionedUserIds;
  // 帖子响应里附带的被提及用户快照（需求 2：正文点击跳转）。
  // 服务端返回 `mentioned_users` 数组，客户端按 username 匹配正文 @ 片段渲染。
  List<MentionedUser>? mentionedUsers;

  PostModel({
    this.key,
    this.imagePath,
    this.bio,
    required this.createdAt,
    this.user,
    this.comment,
    this.likesCount,
    this.repliesCount,
    this.repostsCount,
    this.sharesCount,
    this.isLiked,
    this.isSaved,
    this.isReposted,
    this.isFollowing,
    this.postId,
    this.replyToPostId,
    this.replyToUserId,
    this.pollData,
    this.location,
    this.latitude,
    this.longitude,
    this.topicIds,
    this.isGhost,
    this.communityId,
    this.replySettings,
    this.quoteRepostId,
    this.isPinned,
    this.scheduledTime,
    this.isAi,
    this.quoteContent,
    this.quotePost,
    this.isRepost,
    this.repostParentId,
    this.threadPosts,
    this.threadPostIds,
    this.quotesCount,
    this.mediaList,
    this.isEdited,
    this.editCount,
    this.lastEditTime,
    this.isSensitive,
    this.contentWarning,
    this.mentionedUserIds,
    this.mentionedUsers,
  });

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    return null;
  }

  // Support both Firebase format (camelCase) and API format (snake_case)
  factory PostModel.fromJson(Map<dynamic, dynamic> map) {
    // Parse quote_post recursively
    PostModel? quotePost;
    final quotePostRaw = map['quote_post'] ?? map['quotePost'];
    if (quotePostRaw != null) {
      quotePost = PostModel.fromJson(quotePostRaw);
    }

    // Parse thread_posts
    List<PostModel>? threadPosts;
    final threadPostsRaw = map['thread_posts'] ?? map['threadPosts'];
    if (threadPostsRaw is List) {
      threadPosts = threadPostsRaw.map((e) => PostModel.fromJson(e)).toList();
    }

    // Parse thread_post_ids
    List<int>? threadPostIds;
    final threadPostIdsRaw = map['thread_post_ids'] ?? map['threadPostIds'];
    if (threadPostIdsRaw is List) {
      threadPostIds = threadPostIdsRaw
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    }

    // Parse media_list
    List<MediaItemModel>? mediaList;
    final mediaListRaw = map['media_list'] ?? map['mediaList'];
    if (mediaListRaw is List) {
      mediaList = mediaListRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => MediaItemModel.fromJson(e))
          .toList();
    }

    return PostModel(
      key: map['key']?.toString() ??
          map['id']?.toString() ??
          map['post_id']?.toString(),
      postId: map['post_id']?.toString() ?? map['id']?.toString(),
      bio: map['bio'] ?? map['content'],
      createdAt: map['createdAt'] ??
          map['created_at'] ??
          DateTime.now().toIso8601String(),
      imagePath: map['imagePath'] ?? map['image_url'] ?? map['imageUrl'],
      user: map['user'] != null ? UserModel.fromJson(map['user']) : null,
      comment:
          map['comment'] != null ? List<String?>.from(map['comment']) : null,
      likesCount: map['likesCount'] ?? map['likes_count'],
      repliesCount: map['repliesCount'] ?? map['replies_count'],
      repostsCount: map['repostsCount'] ?? map['reposts_count'],
      isLiked: _parseBool(map['isLiked'] ?? map['is_liked']),
      isSaved: _parseBool(map['isSaved'] ?? map['is_saved']),
      isReposted: _parseBool(map['isReposted'] ?? map['is_reposted']),
      isFollowing: _parseBool(map['isFollowing'] ?? map['is_following']),
      replyToPostId: map['reply_to_post_id']?.toString(),
      replyToUserId: map['reply_to_user_id']?.toString(),
      location: map['location'],
      latitude: (map['latitude'] is num)
          ? (map['latitude'] as num).toDouble()
          : (map['latitude'] is String
              ? double.tryParse(map['latitude'] as String)
              : null),
      longitude: (map['longitude'] is num)
          ? (map['longitude'] as num).toDouble()
          : (map['longitude'] is String
              ? double.tryParse(map['longitude'] as String)
              : null),
      topicIds: map['topic_ids'] is List
          ? (map['topic_ids'] as List)
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .toList()
          : null,
      isGhost: _parseBool(map['is_ghost'] ?? map['isGhost']),
      communityId: map['community_id'] ?? map['communityId'],
      replySettings: map['reply_settings'] ?? map['replySettings'],
      quoteRepostId: map['quote_repost_id'] ??
          map['quoteRepostId'] ??
          map['quote_post_id'] ??
          map['quotePostId'],
      isPinned: _parseBool(map['is_pinned'] ?? map['isPinned']),
      scheduledTime: map['scheduled_time'] ?? map['scheduledTime'],
      isAi: _parseBool(map['is_ai'] ?? map['isAi']),
      quoteContent: map['quote_content'] ?? map['quoteContent'],
      quotePost: quotePost,
      isRepost: _parseBool(map['is_repost'] ?? map['isRepost']),
      repostParentId: map['repost_parent_id'] ?? map['repostParentId'],
      threadPosts: threadPosts,
      threadPostIds: threadPostIds,
      quotesCount: map['quotes_count'] ?? map['quotesCount'],
      mediaList: mediaList,
      // Edit-related fields
      isEdited: _parseBool(map['is_edited'] ?? map['isEdited']),
      editCount: map['edit_count'] ?? map['editCount'],
      lastEditTime: (map['last_edit_time'] ?? map['lastEditTime']) != null
          ? PostModel.parseTimestamp(
              map['last_edit_time'] ?? map['lastEditTime'])
          : null,
      // Sensitive content fields
      isSensitive: _parseBool(map['is_sensitive'] ?? map['isSensitive']),
      contentWarning: map['content_warning']?.toString() ??
          map['contentWarning']?.toString(),
      // @mention：优先从 mentioned_users 数组解析（含 username 快照），
      // 同时从 mentioned_user_ids 兜底（仅 id 列表，无 username）。
      mentionedUserIds: () {
        final users = map['mentioned_users'] ?? map['mentionedUsers'];
        if (users is List && users.isNotEmpty) {
          return users
              .whereType<Map>()
              .map((e) => e['user_id'] ?? e['userId'] ?? e['id'])
              .whereType<int>()
              .toList();
        }
        final ids = map['mentioned_user_ids'] ?? map['mentionedUserIds'];
        if (ids is List) {
          return ids
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .where((v) => v > 0)
              .toList();
        }
        return null;
      }(),
      mentionedUsers: () {
        final raw = map['mentioned_users'] ?? map['mentionedUsers'];
        if (raw is List && raw.isNotEmpty) {
          return raw
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => MentionedUser.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList();
        }
        return null;
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'post_id': postId ?? key,
      'bio': bio,
      'content': bio,
      'createdAt': createdAt,
      'created_at': createdAt,
      'imagePath': imagePath,
      'image_url': imagePath,
      'user': user == null ? null : user!.toJson(),
      'comment': comment,
      'likes_count': likesCount,
      'replies_count': repliesCount,
      'reposts_count': repostsCount,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'is_reposted': isReposted,
      'is_following': isFollowing,
      'reply_to_post_id': replyToPostId,
      'reply_to_user_id': replyToUserId,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'topic_ids': topicIds,
      'is_ghost': isGhost,
      'community_id': communityId,
      'reply_settings': replySettings,
      'quote_repost_id': quoteRepostId,
      'is_pinned': isPinned,
      'scheduled_time': scheduledTime,
      'is_ai': isAi,
      'quote_content': quoteContent,
      'quote_post': quotePost?.toJson(),
      'is_repost': isRepost,
      'repost_parent_id': repostParentId,
      'thread_posts': threadPosts?.map((e) => e.toJson()).toList(),
      'thread_post_ids': threadPostIds,
      'quotes_count': quotesCount,
      'media_list': mediaList?.map((e) => e.toJson()).toList(),
      // Edit-related fields
      'is_edited': isEdited,
      'edit_count': editCount,
      'last_edit_time': lastEditTime?.toIso8601String(),
      // Sensitive content fields
      'is_sensitive': isSensitive,
      'content_warning': contentWarning,
      if (mentionedUserIds != null && mentionedUserIds!.isNotEmpty)
        'mentioned_user_ids': mentionedUserIds,
      if (mentionedUsers != null && mentionedUsers!.isNotEmpty)
        'mentioned_users':
            mentionedUsers!.map((e) => e.toJson()).toList(),
    };
  }

  PostModel copyWith({
    String? key,
    String? imagePath,
    String? bio,
    String? createdAt,
    UserModel? user,
    List<String?>? comment,
    int? likesCount,
    int? repliesCount,
    int? repostsCount,
    int? sharesCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReposted,
    bool? isFollowing,
    String? postId,
    String? replyToPostId,
    String? replyToUserId,
    PollData? pollData,
    String? location,
    List<int>? topicIds,
    bool? isGhost,
    int? communityId,
    int? replySettings,
    int? quoteRepostId,
    bool? isPinned,
    String? scheduledTime,
    bool? isAi,
    double? latitude,
    double? longitude,
    String? quoteContent,
    PostModel? quotePost,
    bool? isRepost,
    int? repostParentId,
    List<PostModel>? threadPosts,
    List<int>? threadPostIds,
    int? quotesCount,
    List<MediaItemModel>? mediaList,
    bool? isEdited,
    int? editCount,
    DateTime? lastEditTime,
    bool? isSensitive,
    String? contentWarning,
    List<int>? mentionedUserIds,
    List<MentionedUser>? mentionedUsers,
  }) {
    return PostModel(
      key: key ?? this.key,
      imagePath: imagePath ?? this.imagePath,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      comment: comment ?? this.comment,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      repostsCount: repostsCount ?? this.repostsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReposted: isReposted ?? this.isReposted,
      isFollowing: isFollowing ?? this.isFollowing,
      postId: postId ?? this.postId,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      pollData: pollData ?? this.pollData,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      topicIds: topicIds ?? this.topicIds,
      isGhost: isGhost ?? this.isGhost,
      communityId: communityId ?? this.communityId,
      replySettings: replySettings ?? this.replySettings,
      quoteRepostId: quoteRepostId ?? this.quoteRepostId,
      isPinned: isPinned ?? this.isPinned,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isAi: isAi ?? this.isAi,
      quoteContent: quoteContent ?? this.quoteContent,
      quotePost: quotePost ?? this.quotePost,
      isRepost: isRepost ?? this.isRepost,
      repostParentId: repostParentId ?? this.repostParentId,
      threadPosts: threadPosts ?? this.threadPosts,
      threadPostIds: threadPostIds ?? this.threadPostIds,
      quotesCount: quotesCount ?? this.quotesCount,
      mediaList: mediaList ?? this.mediaList,
      // Edit-related fields
      isEdited: isEdited ?? this.isEdited,
      editCount: editCount ?? this.editCount,
      lastEditTime: lastEditTime ?? this.lastEditTime,
      // Sensitive content fields
      isSensitive: isSensitive ?? this.isSensitive,
      contentWarning: contentWarning ?? this.contentWarning,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
    );
  }

  // Get the primary key/id
  String get id => postId ?? key ?? '';

  /// 渲染用的有效媒体列表：
  /// 1. 优先返回 `mediaList`（多图）
  /// 2. 否则若 `imagePath` 非空，包装成 1-item list 兜底
  /// 3. 否则返回空列表
  /// 所有渲染分支（主帖 / 引用卡 / 大图预览）都应通过此 getter 取数据，
  /// 保证「单图老数据」与「多图新数据」统一入口。
  List<MediaItemModel> get effectiveMediaItems {
    if (mediaList != null && mediaList!.isNotEmpty) {
      return mediaList!;
    }
    if (imagePath != null && imagePath!.isNotEmpty) {
      return [
        MediaItemModel(mediaType: MediaType.image, url: imagePath),
      ];
    }
    return const [];
  }

  /// 是否有可渲染的媒体（主帖图片分支统一判断）
  bool get hasMedia => effectiveMediaItems.isNotEmpty;

  /// 首个可播放媒体（视频 / GIF），自动播放池用。无则返回 null。
  MediaItemModel? get firstPlayableMedia {
    for (final m in effectiveMediaItems) {
      if (m.isPlayable) return m;
    }
    return null;
  }

  /// 按索引取媒体，越界返回 null。
  MediaItemModel? getMediaItem(int index) {
    final items = effectiveMediaItems;
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  // Support both Firebase-style and API-style date parsing
  static String timestampToString(DateTime date) {
    return date.toUtc().toIso8601String();
  }

  static DateTime parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }
}

// Helper extension for DateTime
extension DateTimeExtension on DateTime {
  String toTimestampString() {
    return toUtc().toIso8601String();
  }
}
