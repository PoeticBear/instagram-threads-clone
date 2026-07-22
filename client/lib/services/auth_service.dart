import 'dart:convert';

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

  /// 记录上次启动时的 APP_ENV。dev / prod 切换时，旧环境的 token 在新环境
  /// 无法使用，必须清掉，否则 ApiClient 会带着失效 token 一直 401。
  static const String _lastEnvKey = 'last_app_env';

  AuthService({
    required ApiClient apiClient,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _prefs = prefs;

  Future<void> init() async {
    // 环境变化时清掉旧 token（只在已有记录的环境下比对，避免首次启动误清）
    final lastEnv = _prefs.getString(_lastEnvKey);
    final currentEnv = ApiConfig.environment;
    if (lastEnv != null && lastEnv != currentEnv) {
      await _clearTokens();
    }
    await _prefs.setString(_lastEnvKey, currentEnv);

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

      // dev 环境打印完整登录响应，便于调试接口字段；prod 不打印以免泄露 token
      if (ApiConfig.environment == 'dev') {
        debugPrint('═══════════ [signIn] 服务端返回 ═══════════');
        debugPrint(const JsonEncoder.withIndent('  ').convert(response));
        debugPrint('═══════════════════════════════════════════');
      }

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

  /// Apple 登录：把插件拿到的 authorizationCode 交给后端兑换 access_token。
  /// 后端用 code + client_secret 与 Apple 走 server-to-server 流程，自行验签后
  /// 创建或查找账号，返回本应用的 token + 用户信息。客户端只持有短期 code，
  /// 无法重放，identityToken 不外发。
  ///
  /// 响应结构与 signIn 兼容（data.id / data.access_token / data.refresh_token），
  /// 因此直接复用 LoginResponse.fromJson。
  Future<LoginResponse> signInWithApple({required String code}) async {
    try {
      final response = await _apiClient.post(
        'auth/apple/login',
        body: {'code': code},
      );

      final data = response['data'];

      // dev 环境打印完整 Apple 登录响应，便于调试 username 是否为空；prod 不打印
      if (ApiConfig.environment == 'dev') {
        debugPrint('═══════════ [signInWithApple] 服务端返回 ═══════════');
        debugPrint(const JsonEncoder.withIndent('  ').convert(response));
        debugPrint('═══════════════════════════════════════════════════');
        // 显式提取 username 字段，一眼看出是否为空 / 字段名是否匹配
        debugPrint('[AppleLogin] /auth/apple/login → '
            'data.username="${data['username']}" (${data['username'].runtimeType}), '
            'id=${data['id']}, user_id=${data['user_id']}, '
            'hasAccessToken=${data['access_token'] != null}');
      }

      await _saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        // 与 signIn 保持一致的字段兼容：服务端 Apple 登录响应 schema 是 `id`
        userId: (data['user_id'] ?? data['id'])?.toString(),
      );

      return LoginResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Apple 登录失败: $e');
    }
  }

  /// Google 登录：客户端取 Google 签发的 idToken（JWT），以 {code: idToken} 交给后端。
  /// 后端用 Google 公钥验签 idToken、读取用户信息后创建或查找账号，返回本应用 token。
  /// 客户端不持有可长期复用的 Google 凭据（idToken 短时、可由 Google 验真）。
  ///
  /// ⚠️ 流程口径（见 google-oauth-login-guide.md）：后端是「直接验签 idToken」，**不是**
  /// 「授权码换取」。契约字段名仍叫 code（历史命名），内容实为 idToken JWT——原先发
  /// serverAuthCode（授权码、非 JWT）会被后端当 JWT 解码，报 101115 id_token decode error。
  ///
  /// 契约（openapi_docs/versions/openapi_20260708.json，POST /auth/google/login）：
  ///   - 请求体 {code: <idToken>}，code minLength 1
  ///   - 响应 SigninResponse：{id, username, avatar, access_token, refresh_token, display_name}
  ///
  /// 响应结构与 signIn / signInWithApple 兼容，复用 LoginResponse.fromJson。
  Future<LoginResponse> signInWithGoogle({required String idToken}) async {
    try {
      // dev 环境:打印请求 + idToken 长度(DEV ONLY)。不打印完整 JWT（携带身份+签名）。
      if (ApiConfig.environment == 'dev') {
        debugPrint('═══════════ [signInWithGoogle] 发往后端 ═══════════');
        debugPrint('  POST auth/google/login');
        debugPrint('  idToken 长度: ${idToken.length} chars');
        debugPrint('═══════════════════════════════════════════════════');
      }
      // 字段名 code 是契约历史命名；内容为 idToken JWT，后端按 idToken 验签。
      final response = await _apiClient.post(
        'auth/google/login',
        body: {'code': idToken},
      );

      final data = response['data'];

      // dev 环境打印完整响应便于调试；prod 不打印以免泄露 token
      if (ApiConfig.environment == 'dev') {
        debugPrint('═══════════ [signInWithGoogle] 服务端返回 ═══════════');
        debugPrint(const JsonEncoder.withIndent('  ').convert(response));
        debugPrint('═══════════════════════════════════════════════════');
      }

      await _saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: (data['user_id'] ?? data['id'])?.toString(),
      );

      return LoginResponse.fromJson(data);
    } on ApiException catch (e) {
      _logDevApiError('signInWithGoogle', e);
      rethrow;
    } catch (e) {
      debugPrint('[signInWithGoogle] 非 ApiException: ${e.runtimeType} → $e');
      throw ApiException(message: 'Google 登录失败: $e');
    }
  }

  /// 发送短信验证码。
  /// 契约（POST /auth/sms/send）：请求体 {phone_country_code(2–10), phone(1–20)}，
  /// 成功 data 为空对象 OKResponse，结果以顶层 code 判定（code == 0 成功）。
  /// 返回 true 表示发送成功；业务失败（code != 0）由 ApiClient 抛 ServerException
  /// 携带 msg，调用方 catch 后向用户展示。
  Future<bool> sendSmsCode({
    required String phoneCountryCode,
    required String phone,
  }) async {
    try {
      await _apiClient.post(
        'auth/sms/send',
        body: {
          'phone_country_code': phoneCountryCode,
          'phone': phone,
        },
      );
      return true;
    } on ApiException catch (e) {
      _logDevApiError('sendSmsCode', e);
      rethrow;
    } catch (e) {
      debugPrint('[sendSmsCode] 非 ApiException: ${e.runtimeType} → $e');
      throw ApiException(message: '发送验证码失败: $e');
    }
  }

  /// 短信验证码登录 / 注册。
  /// 契约（POST /auth/sms/signin）：请求体 {phone_country_code, phone, code(4–6)}，
  /// 可选设备头；成功 data 为 SigninResponse（结构同 google / apple 登录），
  /// 已注册用户直接登录、新用户自动注册。复用 LoginResponse.fromJson + _saveTokens。
  Future<LoginResponse> signInWithSms({
    required String phoneCountryCode,
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _apiClient.post(
        'auth/sms/signin',
        body: {
          'phone_country_code': phoneCountryCode,
          'phone': phone,
          'code': code,
        },
      );

      final data = response['data'];

      await _saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: (data['user_id'] ?? data['id'])?.toString(),
      );

      return LoginResponse.fromJson(data);
    } on ApiException catch (e) {
      _logDevApiError('signInWithSms', e);
      rethrow;
    } catch (e) {
      debugPrint('[signInWithSms] 非 ApiException: ${e.runtimeType} → $e');
      throw ApiException(message: '短信登录失败: $e');
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

  /// 注销当前用户账号（满足 App Store Review Guideline 5.1.1(v)）。调用 POST /user/deactivate。
  /// 成功：直接返回，本地登录态清理由 AuthState 负责（避免与 logout 行为耦合）。
  /// 失败：抛 ApiException，上层据以提示「删除失败」并保留登录态可重试。
  Future<void> deleteAccount() async {
    try {
      await _apiClient.post('user/deactivate', body: {});
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '删除账号失败: $e');
    }
  }

  Future<UserInfo> getCurrentUser() async {
    try {
      final response = await _apiClient.get('user/me');
      debugPrint('[AppleLogin] /user/me 完整响应: $response');
      final info = UserInfo.fromJson(response['data']);
      debugPrint('[AppleLogin] /user/me 解析: userId=${info.userId}, '
          'username="${info.username}" (len=${info.username.length})');
      return info;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '获取用户信息失败: $e');
    }
  }

  /// 供 ApiClient.refreshTokensProvider 调用。
  /// 成功：保存新 token 到 prefs + ApiClient，返回新 access_token。
  /// 失败：返回 null，不抛异常、不清 token（清理动作交给 ApiClient）。
  Future<String?> tryRefreshTokens() async {
    try {
      final refreshToken = _prefs.getString(_refreshTokenKey);
      if (refreshToken == null) return null;

      final response = await _apiClient.post(
        'auth/token/refresh',
        body: {'refresh_token': refreshToken},
      );

      final data = response['data'];
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      if (newAccess == null || newRefresh == null) return null;

      await _saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      return newAccess;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshToken() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (refreshToken == null) {
      throw AuthException(message: '无 refresh token');
    }

    // Note: 清理责任交给 tryRefreshTokens (供 ApiClient) 或 clearLocalSession (供主动登出)。
    // 这里仅做纯调用 + 抛异常，避免双重清理。
    final response = await _apiClient.post(
      'auth/token/refresh',
      body: {'refresh_token': refreshToken},
    );

    final data = response['data'];
    await _saveTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
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

  /// dev 环境：把 ApiException 的类型 / statusCode(或业务码) / message / 服务端
  /// 原始响应体完整打印出来，便于联调时定位「后端到底返回了什么」。prod 不打印。
  /// rethrow 后错误照常向上抛（SnackBar 等行为不变）。
  void _logDevApiError(String tag, ApiException e) {
    if (ApiConfig.environment != 'dev') return;
    String dataStr;
    try {
      dataStr = e.data == null ? 'null' : const JsonEncoder.withIndent('  ').convert(e.data);
    } catch (_) {
      dataStr = '${e.data}';
    }
    debugPrint('═══════════ [$tag] ❌ 请求失败 ═══════════');
    debugPrint('  异常类型           : ${e.runtimeType}');
    debugPrint('  statusCode/业务码 : ${e.statusCode}');
    debugPrint('  message           : ${e.message}');
    debugPrint('  服务端原始响应     : $dataStr');
    debugPrint('═══════════════════════════════════════════════════');
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

  /// 仅清理本地凭证（prefs + ApiClient 内存），不调服务端 DELETE auth/logout。
  /// 用于 token 已失效场景（避免失效 token 再发请求触发新一轮 401）。
  Future<void> clearLocalSession() async {
    await _clearTokens();
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