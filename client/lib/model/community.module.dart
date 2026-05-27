/// 社区模块数据模型
/// 包含：CommunityInfo, CommunityMember

// ============================================================
// CommunityInfo（社区模型）
// ============================================================

class CommunityInfo {
  final int id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int membersCount;
  final int postsCount;
  final bool isJoined;
  final bool isChampion;
  final String? createTime;

  CommunityInfo({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.membersCount = 0,
    this.postsCount = 0,
    this.isJoined = false,
    this.isChampion = false,
    this.createTime,
  });

  factory CommunityInfo.fromJson(Map<String, dynamic> json) {
    return CommunityInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      coverUrl: json['cover_url'] ?? json['coverUrl'],
      membersCount: json['members_count'] ?? json['membersCount'] ?? 0,
      postsCount: json['posts_count'] ?? json['postsCount'] ?? 0,
      isJoined: json['is_joined'] ?? json['isJoined'] ?? false,
      isChampion: json['is_champion'] ?? json['isChampion'] ?? false,
      createTime: json['create_time'] ?? json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'members_count': membersCount,
      'posts_count': postsCount,
      'is_joined': isJoined,
      'is_champion': isChampion,
      'create_time': createTime,
    };
  }

  CommunityInfo copyWith({
    int? id,
    String? name,
    String? description,
    String? coverUrl,
    int? membersCount,
    int? postsCount,
    bool? isJoined,
    bool? isChampion,
    String? createTime,
  }) {
    return CommunityInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount ?? this.postsCount,
      isJoined: isJoined ?? this.isJoined,
      isChampion: isChampion ?? this.isChampion,
      createTime: createTime ?? this.createTime,
    );
  }
}

// ============================================================
// CommunityMember（社区成员模型）
// ============================================================

class CommunityMember {
  final int userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int role; // 1=成员, 2=管理员
  final bool isChampion;
  final String? joinTime;

  CommunityMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.role = 1,
    this.isChampion = false,
    this.joinTime,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      role: json['role'] ?? 1,
      isChampion: json['is_champion'] ?? json['isChampion'] ?? false,
      joinTime: json['join_time'] ?? json['joinTime'],
    );
  }
}
