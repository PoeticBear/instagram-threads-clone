import '../network/api_client.dart';
import '../network/api_exception.dart';

class PostService {
  final ApiClient _apiClient;

  PostService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Post> createPost({
    required String content,
    String? imageUrl,
    String? replyToPostId,
    int? replyToUserId,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
      };
      if (imageUrl != null) body['image_url'] = imageUrl;
      if (replyToPostId != null) body['reply_to_post_id'] = replyToPostId;
      if (replyToUserId != null) body['reply_to_user_id'] = replyToUserId;

      final response = await _apiClient.post('post/create', body: body);
      return Post.fromJson(response['data']);
    } on ApiException {
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

  Future<List<Post>> getFeed({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/feed',
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

  Future<List<Post>> getUserPosts(int userId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiClient.get(
        'post/user/$userId/posts',
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
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final int repliesCount;
  final int repostsCount;
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
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.repostsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isReposted = false,
    this.replyTo,
    this.replyToReply,
  });

  // Helper getter for compatibility with PostModel.user
  PostUser get user => PostUser(
    userId: userId,
    userName: username,
    displayName: displayName,
    profilePic: profilePic,
  );

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? json['post_id']?.toString() ?? '',
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
      repliesCount: json['replies_count'] ?? json['repliesCount'] ?? 0,
      repostsCount: json['reposts_count'] ?? json['repostsCount'] ?? 0,
      isLiked: json['is_liked'] ?? json['isLiked'] ?? false,
      isSaved: json['is_saved'] ?? json['isSaved'] ?? false,
      isReposted: json['is_reposted'] ?? json['isReposted'] ?? false,
      replyTo: json['reply_to'] != null ? Post.fromJson(json['reply_to']) : null,
      replyToReply: json['reply_to_reply'] != null ? Reply.fromJson(json['reply_to_reply']) : null,
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