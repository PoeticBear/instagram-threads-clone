import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_exception.dart';

class AuthService {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  AuthService({
    required ApiClient apiClient,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _prefs = prefs;

  Future<void> init() async {
    final accessToken = _prefs.getString(_accessTokenKey);
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (accessToken != null && refreshToken != null) {
      _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    }
  }

  bool get isLoggedIn => _prefs.getString(_accessTokenKey) != null;

  String? get currentUserId => _prefs.getString(_userIdKey);

  Future<LoginResponse> signIn({
    required String username,
    required String password,
    String? deviceOs,
    String? deviceName,
  }) async {
    try {
      final response = await _apiClient.post(
        'auth/username/signin',
        body: {
          'username': username,
          'password': password,
        },
        queryParameters: {
          if (deviceOs != null) 'device-os': deviceOs,
          if (deviceName != null) 'device-name': deviceName,
        },
      );

      final data = response['data'];
      await _saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        // 服务端 SigninResponse schema 字段名是 `id`，旧实现错写成 `user_id`
        userId: (data['user_id'] ?? data['id'])?.toString(),
      );

      return LoginResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '登录失败: $e');
    }
  }

  Future<RegisterResponse> register({
    required String username,
    required String password,
    required String confirmPassword,
    String? displayName,
    String? bio,
    String? deviceOs,
    String? deviceName,
  }) async {
    try {
      final response = await _apiClient.post(
        'auth/username/register',
        body: {
          'username': username,
          'password': password,
          'confirm_password': confirmPassword,
          if (displayName != null) 'display_name': displayName,
          if (bio != null) 'bio': bio,
        },
        queryParameters: {
          if (deviceOs != null) 'device-os': deviceOs,
          if (deviceName != null) 'device-name': deviceName,
        },
      );

      final data = response['data'];
      // 服务端 /user/register 不返回 token（仅返回 OKResponse）
      // 后续由调用方主动调用 signIn 获取 token
      if (data != null &&
          data['access_token'] != null &&
          data['refresh_token'] != null) {
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          // 与 signIn 对齐：兼容服务端字段名 `id` / `user_id` 两种
          userId: (data['user_id'] ?? data['id'])?.toString(),
        );
      }

      return RegisterResponse.fromJson(data ?? {});
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '注册失败: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.delete('auth/logout');
    } catch (_) {
      // Ignore errors during logout
    } finally {
      await _clearTokens();
    }
  }

  Future<UserInfo> getCurrentUser() async {
    try {
      final response = await _apiClient.get('user/me');
      debugPrint('auth_service.getCurrentUser raw response: $response');
      return UserInfo.fromJson(response['data']);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '获取用户信息失败: $e');
    }
  }

  Future<void> refreshToken() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (refreshToken == null) {
      throw AuthException(message: '无 refresh token');
    }

    try {
      final response = await _apiClient.post(
        'auth/token/refresh',
        body: {'refresh_token': refreshToken},
      );

      final data = response['data'];
      await _saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
    } on ApiException {
      await _clearTokens();
      rethrow;
    }
  }

  Future<void> modifyPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.put(
        'user/modify_password',
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
    } on ApiException {
      rethrow;
    }
  }

  // Register device token for push notifications
  Future<void> registerDeviceToken(String deviceToken) async {
    try {
      await _apiClient.post(
        'user/device-token/register',
        body: {'device_token': deviceToken},
      );
    } on ApiException {
      rethrow;
    }
  }

  // Deregister device token
  Future<void> deregisterDeviceToken(String deviceToken) async {
    try {
      await _apiClient.post(
        'user/device-token/deregister',
        body: {'device_token': deviceToken},
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<void> _saveTokens({
    String? accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    if (accessToken != null) {
      await _prefs.setString(_accessTokenKey, accessToken);
    }
    if (refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
    }
    if (userId != null) {
      await _prefs.setString(_userIdKey, userId);
    }
    if (accessToken != null && refreshToken != null) {
      _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    }
  }

  Future<void> _clearTokens() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_userIdKey);
    _apiClient.clearTokens();
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int? userId;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      // 兼容 SigninResponse schema（字段名 `id`）与旧版 `user_id`
      userId: json['user_id'] ?? json['id'],
    );
  }
}

class RegisterResponse {
  final String accessToken;
  final String refreshToken;
  final int? userId;

  RegisterResponse({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      // 兼容 schema 字段名 `id` / `user_id`
      userId: json['user_id'] ?? json['id'],
    );
  }
}

class UserInfo {
  final int userId;
  final String username;
  final String displayName;
  final String? bio;
  final String? profilePic;
  final String? link;
  final bool isPrivate;
  final int followersCount;
  final int followingCount;
  final String? pronouns;
  final int? gender;        // 1=Not set, 2=Male, 3=Female, 4=Other
  final String? location;
  final bool? isVerified;
  final int? accountType;   // 1=Personal, 2=Creator, 3=Business
  final int? postsCount;
  final bool isFollowing;
  final bool isMutual;

  UserInfo({
    required this.userId,
    required this.username,
    required this.displayName,
    this.bio,
    this.profilePic,
    this.link,
    this.isPrivate = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.pronouns,
    this.gender,
    this.location,
    this.isVerified,
    this.accountType,
    this.postsCount,
    this.isFollowing = false,
    this.isMutual = false,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    // Handle is_private being returned as int (0/1) instead of bool
    final isPrivateValue = json['is_private'] ?? json['isPrivate'] ?? false;
    final isPrivate = isPrivateValue is bool
        ? isPrivateValue
        : (isPrivateValue is int ? isPrivateValue != 0 : false);

    // Handle is_verified being returned as int (0/1) instead of bool
    final isVerifiedValue = json['is_verified'] ?? json['isVerified'];
    final isVerified = isVerifiedValue is bool
        ? isVerifiedValue
        : (isVerifiedValue is int ? isVerifiedValue != 0 : false);

    // Handle is_following being returned as int (0/1) instead of bool
    final isFollowingValue = json['is_following'] ?? json['isFollowing'] ?? 0;
    final isFollowing = isFollowingValue is bool
        ? isFollowingValue
        : (isFollowingValue is int ? isFollowingValue != 0 : false);

    // Handle is_mutual being returned as int (0/1) instead of bool
    final isMutualValue = json['is_mutual'] ?? json['isMutual'] ?? 0;
    final isMutual = isMutualValue is bool
        ? isMutualValue
        : (isMutualValue is int ? isMutualValue != 0 : false);

    return UserInfo(
      userId: json['user_id'] ?? json['id'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      bio: json['bio'],
      profilePic: json['avatar_url'] ?? json['profile_pic'] ?? json['profilePic'],
      link: json['website_url'] ?? json['link'],
      isPrivate: isPrivate,
      followersCount: json['followers_count'] ?? json['followersCount'] ?? 0,
      followingCount: json['following_count'] ?? json['followingCount'] ?? 0,
      pronouns: json['pronouns'],
      gender: json['gender'],
      location: json['location'],
      isVerified: isVerified,
      accountType: json['account_type'] ?? json['accountType'],
      postsCount: json['posts_count'] ?? json['postsCount'],
      isFollowing: isFollowing,
      isMutual: isMutual,
    );
  }
}