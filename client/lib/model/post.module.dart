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
  bool? isLiked;
  bool? isSaved;
  String? postId;  // API uses post_id
  String? replyToPostId;
  String? replyToUserId;

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
    this.isLiked,
    this.isSaved,
    this.postId,
    this.replyToPostId,
    this.replyToUserId,
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
      replyToPostId: map['reply_to_post_id']?.toString(),
      replyToUserId: map['reply_to_user_id']?.toString(),
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
      'reply_to_post_id': replyToPostId,
      'reply_to_user_id': replyToUserId,
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
    bool? isLiked,
    bool? isSaved,
    String? postId,
    String? replyToPostId,
    String? replyToUserId,
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
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      postId: postId ?? this.postId,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      replyToUserId: replyToUserId ?? this.replyToUserId,
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