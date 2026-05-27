import 'package:threads/services/post_service.dart';
import 'user.module.dart';

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
  });

  // Support both Firebase format (camelCase) and API format (snake_case)
  factory PostModel.fromJson(Map<dynamic, dynamic> map) {
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
      isLiked: map['isLiked'] ?? map['is_liked'],
      isSaved: map['isSaved'] ?? map['is_saved'],
      isReposted: map['isReposted'] ?? map['is_reposted'],
      replyToPostId: map['reply_to_post_id']?.toString(),
      replyToUserId: map['reply_to_user_id']?.toString(),
      location: map['location'],
      topicIds: map['topic_ids'] is List
          ? (map['topic_ids'] as List).map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList()
          : null,
      isGhost: map['is_ghost'] ?? map['isGhost'],
      communityId: map['community_id'] ?? map['communityId'],
      replySettings: map['reply_settings'] ?? map['replySettings'],
      quoteRepostId: map['quote_repost_id'] ?? map['quoteRepostId'],
      isPinned: map['is_pinned'] ?? map['isPinned'],
      scheduledTime: map['scheduled_time'] ?? map['scheduledTime'],
      isAi: map['is_ai'] ?? map['isAi'],
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
    );
  }

  // Get the primary key/id
  String get id => postId ?? key ?? '';

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