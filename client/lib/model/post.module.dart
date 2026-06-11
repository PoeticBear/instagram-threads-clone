import 'package:threads/services/post_service.dart';
import 'user.module.dart';

/// 媒体类型常量
class MediaType {
  static const int image = 1;
  static const int video = 2;
  static const int gif = 3;
  static const int voice = 4;
  static const int textAttachment = 5;
}

/// 对应 API 的 MediaItem 结构
class MediaItemModel {
  final int? id;
  final int mediaType; // 1=图片, 2=视频, 3=GIF, 4=语音, 5=文本附件
  final String? url;
  final String? thumbUrl;
  final int? width;
  final int? height;

  const MediaItemModel({
    this.id,
    required this.mediaType,
    this.url,
    this.thumbUrl,
    this.width,
    this.height,
  });

  bool get isVideo => mediaType == MediaType.video;
  bool get isImage => mediaType == MediaType.image || mediaType == MediaType.gif;

  factory MediaItemModel.fromJson(Map<dynamic, dynamic> map) {
    return MediaItemModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      mediaType: map['media_type'] ?? map['mediaType'] ?? 1,
      url: map['url']?.toString(),
      thumbUrl: map['thumb_url']?.toString() ?? map['thumbUrl']?.toString(),
      width: map['width'] is int ? map['width'] : int.tryParse(map['width']?.toString() ?? ''),
      height: map['height'] is int ? map['height'] : int.tryParse(map['height']?.toString() ?? ''),
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
    };
  }
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
  String? postId;  // API uses post_id
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
    this.postId,
    this.replyToPostId,
    this.replyToUserId,
    this.pollData,
    this.location,
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
      threadPostIds = threadPostIdsRaw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
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
      key: map['key']?.toString() ?? map['id']?.toString() ?? map['post_id']?.toString(),
      postId: map['post_id']?.toString() ?? map['id']?.toString(),
      bio: map['bio'] ?? map['content'],
      createdAt: map['createdAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String(),
      imagePath: map['imagePath'] ?? map['image_url'] ?? map['imageUrl'],
      user: map['user'] != null ? UserModel.fromJson(map['user']) : null,
      comment: map['comment'] != null ? List<String?>.from(map['comment']) : null,
      likesCount: map['likesCount'] ?? map['likes_count'],
      repliesCount: map['repliesCount'] ?? map['replies_count'],
      repostsCount: map['repostsCount'] ?? map['reposts_count'],
      isLiked: _parseBool(map['isLiked'] ?? map['is_liked']),
      isSaved: _parseBool(map['isSaved'] ?? map['is_saved']),
      isReposted: _parseBool(map['isReposted'] ?? map['is_reposted']),
      replyToPostId: map['reply_to_post_id']?.toString(),
      replyToUserId: map['reply_to_user_id']?.toString(),
      location: map['location'],
      topicIds: map['topic_ids'] is List
          ? (map['topic_ids'] as List).map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList()
          : null,
      isGhost: _parseBool(map['is_ghost'] ?? map['isGhost']),
      communityId: map['community_id'] ?? map['communityId'],
      replySettings: map['reply_settings'] ?? map['replySettings'],
      quoteRepostId: map['quote_repost_id'] ?? map['quoteRepostId'] ?? map['quote_post_id'] ?? map['quotePostId'],
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
      'reply_to_post_id': replyToPostId,
      'reply_to_user_id': replyToUserId,
      'location': location,
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
    String? quoteContent,
    PostModel? quotePost,
    bool? isRepost,
    int? repostParentId,
    List<PostModel>? threadPosts,
    List<int>? threadPostIds,
    int? quotesCount,
    List<MediaItemModel>? mediaList,
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
      postId: postId ?? this.postId,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      pollData: pollData ?? this.pollData,
      location: location ?? this.location,
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