import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  String? key;
  String? email;
  int? userId;  // Changed from String? to int? for API compatibility
  String? bio;
  String? link;
  String? userName;
  String? displayName;
  String? profilePic;
  String? createAt;
  bool? isPrivate;  // Changed from isprivate (snake_case for API)
  String? fcmToken;
  List<String>? followersList;
  List<String>? followingList;
  int? followersCount;  // Added for API
  int? followingCount;  // Added for API
  String? pronouns;
  int? gender;        // 1=Not set, 2=Male, 3=Female, 4=Other
  String? location;
  bool? isVerified;
  int? accountType;   // 1=Personal, 2=Creator, 3=Business
  int? postsCount;
  String? lastActiveTime;

  UserModel({
    this.email,
    this.key,
    this.userName,
    this.link,
    this.bio,
    this.userId,
    this.isPrivate,
    this.displayName,
    this.profilePic,
    this.createAt,
    this.followingList,
    this.followersList,
    this.fcmToken,
    this.followersCount,
    this.followingCount,
    this.pronouns,
    this.gender,
    this.location,
    this.isVerified,
    this.accountType,
    this.postsCount,
    this.lastActiveTime,
  });

  // Support both Firebase format (camelCase) and API format (snake_case)
  factory UserModel.fromJson(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return UserModel();
    }

    return UserModel(
      key: map['key']?.toString() ?? map['user_id']?.toString(),
      email: map['email'],
      // Handle both String and int userId
      userId: map['userId'] is int
          ? map['userId']
          : (map['userId'] != null ? int.tryParse(map['userId'].toString()) : null) ??
            (map['user_id'] is int ? map['user_id'] : (map['user_id'] != null ? int.tryParse(map['user_id'].toString()) : null)),
      userName: map['userName'] ?? map['username'] ?? map['user_name'],
      bio: map['bio'],
      link: map['link'],
      displayName: map['displayName'] ?? map['display_name'],
      profilePic: map['profilePic'] ?? map['profile_pic'],
      createAt: map['createAt'] ?? map['create_at'] ?? map['createdAt'],
      isPrivate: _parseBool(map['isprivate'] ?? map['is_private'] ?? map['isPrivate']),
      fcmToken: map['fcmToken'] ?? map['fcm_token'],
      followersCount: map['followersCount'] ?? map['followers_count'],
      followingCount: map['followingCount'] ?? map['following_count'],
      followersList: _parseStringList(map['followerList'] ?? map['followersList']),
      followingList: _parseStringList(map['followingList'] ?? map['followingList']),
      pronouns: map['pronouns'],
      gender: map['gender'],
      location: map['location'],
      isVerified: _parseBool(map['is_verified'] ?? map['isVerified']),
      accountType: map['account_type'] ?? map['accountType'],
      postsCount: map['posts_count'] ?? map['postsCount'],
      lastActiveTime: map['last_active_time'] ?? map['lastActiveTime'],
    );
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    return null;
  }

  static List<String>? _parseStringList(dynamic list) {
    if (list == null) return null;
    if (list is List) {
      return list.map((e) => e?.toString() ?? '').toList();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'userId': userId?.toString(),
      'username': userName,
      'bio': bio,
      'is_private': isPrivate,
      'link': link,
      'email': email,
      'display_name': displayName,
      'create_at': createAt,
      'profile_pic': profilePic,
      'fcm_token': fcmToken,
      'follower_list': followersList,
      'following_list': followingList,
      'followers_count': followersCount,
      'following_count': followingCount,
      'pronouns': pronouns,
      'gender': gender,
      'location': location,
      'is_verified': isVerified,
      'account_type': accountType,
      'posts_count': postsCount,
      'last_active_time': lastActiveTime,
    };
  }

  // Convert from API UserInfo to UserModel
  factory UserModel.fromApiUser(Map<String, dynamic> json) {
    return UserModel(
      key: json['user_id']?.toString() ?? json['id']?.toString(),
      userId: json['user_id'] ?? json['id'],
      userName: json['username'],
      displayName: json['display_name'] ?? json['displayName'],
      bio: json['bio'],
      profilePic: json['profile_pic'] ?? json['profilePic'],
      isPrivate: _parseBool(json['is_private'] ?? json['isPrivate']),
      followersCount: json['followers_count'] ?? json['followersCount'],
      followingCount: json['following_count'] ?? json['followingCount'],
      link: json['link'],
      email: json['email'],
    );
  }

  UserModel copyWith({
    String? email,
    int? userId,
    String? userName,
    String? displayName,
    String? profilePic,
    String? createAt,
    String? bio,
    String? link,
    String? key,
    String? fcmToken,
    bool? isPrivate,
    List<String>? followingList,
    List<String>? followersList,
    int? followersCount,
    int? followingCount,
    String? pronouns,
    int? gender,
    String? location,
    bool? isVerified,
    int? accountType,
    int? postsCount,
    String? lastActiveTime,
  }) {
    return UserModel(
      email: email ?? this.email,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      displayName: displayName ?? this.displayName,
      profilePic: profilePic ?? this.profilePic,
      createAt: createAt ?? this.createAt,
      bio: bio ?? this.bio,
      isPrivate: isPrivate ?? this.isPrivate,
      link: link ?? this.link,
      key: key ?? this.key,
      fcmToken: fcmToken ?? this.fcmToken,
      followersList: followersList ?? this.followersList,
      followingList: followingList ?? this.followingList,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      pronouns: pronouns ?? this.pronouns,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      accountType: accountType ?? this.accountType,
      postsCount: postsCount ?? this.postsCount,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
    );
  }

  // Create a simple user ID string for Firebase compatibility
  String get userIdString => userId?.toString() ?? '';

  @override
  List<Object?> get props => [
        key,
        email,
        bio,
        link,
        userName,
        isPrivate,
        userId,
        createAt,
        displayName,
        fcmToken,
        profilePic,
        followersList,
        followingList,
        followersCount,
        followingCount,
        pronouns,
        gender,
        location,
        isVerified,
        accountType,
        postsCount,
        lastActiveTime,
      ];
}