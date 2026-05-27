class TopicInfo {
  final int id;
  final String name;
  final String? description;
  final int postsCount;
  final int followersCount;
  final bool isFollowing;
  final bool isMuted;
  final String? coverUrl;
  final String? createTime;

  TopicInfo({
    required this.id,
    required this.name,
    this.description,
    this.postsCount = 0,
    this.followersCount = 0,
    this.isFollowing = false,
    this.isMuted = false,
    this.coverUrl,
    this.createTime,
  });

  factory TopicInfo.fromJson(Map<String, dynamic> json) {
    return TopicInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      postsCount: json['posts_count'] ?? json['postsCount'] ?? 0,
      followersCount: json['followers_count'] ?? json['followersCount'] ?? 0,
      isFollowing: json['is_following'] ?? json['isFollowing'] ?? false,
      isMuted: json['is_muted'] ?? json['isMuted'] ?? false,
      coverUrl: json['cover_url'] ?? json['coverUrl'],
      createTime: json['create_time'] ?? json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'posts_count': postsCount,
      'followers_count': followersCount,
      'is_following': isFollowing,
      'is_muted': isMuted,
      'cover_url': coverUrl,
      'create_time': createTime,
    };
  }

  TopicInfo copyWith({
    int? id,
    String? name,
    String? description,
    int? postsCount,
    int? followersCount,
    bool? isFollowing,
    bool? isMuted,
    String? coverUrl,
    String? createTime,
  }) {
    return TopicInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isMuted: isMuted ?? this.isMuted,
      coverUrl: coverUrl ?? this.coverUrl,
      createTime: createTime ?? this.createTime,
    );
  }
}
