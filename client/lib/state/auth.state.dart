import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/helper/shared_prefrence_helper.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/network/api_exception.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/services/upload_service.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

class AuthState extends AppStates {
  AuthStatus authStatus = AuthStatus.NOT_DETERMINED;
  bool isSignInWithGoogle = false;
  // 默认空串，避免 late 未初始化访问抛 LateInitializationError。
  // 未登录时也允许被读取（结果为空串），上层据此决定是否渲染需登录态的页面。
  String userId = '';
  late AuthState authRepository;
  UserModel? _userModel;

  AuthService? _authService;
  UserService? _userService;
  UploadService? _uploadService;

  UserModel? get userModel => _userModel;
  UserModel? get profileUserModel => _userModel;

  AuthService get authService {
    _authService ??= AuthService(
      apiClient: getIt(),
      prefs: getIt<SharedPreferenceHelper>().prefs,
    );
    return _authService!;
  }

  UserService get userService {
    _userService ??= UserService(apiClient: getIt());
    return _userService!;
  }

  UploadService get uploadService {
    _uploadService ??= UploadService(apiClient: getIt());
    return _uploadService!;
  }

  Future<void> initAuthService() async {
    await authService.init();
    debugPrint('initAuthService - isLoggedIn: ${authService.isLoggedIn}');
    // Load cached user profile if available
    _userModel = getIt<SharedPreferenceHelper>().getUserProfile();
    debugPrint('initAuthService - loaded cached _userModel: ${_userModel?.displayName}');
    if (_userModel != null && authService.isLoggedIn) {
      userId = _userModel!.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;
      debugPrint('initAuthService - set LOGGED_IN from cache');
    } else {
      authStatus = AuthStatus.NOT_LOGGED_IN;
    }
  }

  void logoutCallback() async {
    authStatus = AuthStatus.NOT_LOGGED_IN;
    userId = '';
    _userModel = null;
    await authService.logout();
    notifyListeners();
    await getIt<SharedPreferenceHelper>().clearPreferenceValues();
  }

  Future<String?> signIn(
    String username,
    String password,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      final response = await authService.signIn(
        username: username,
        password: password,
      );

      userId = response.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      // Load user profile
      await getProfileUser();

      // 防御性校验：若服务端 SigninResponse 字段缺失，
      // 且 /user/me 兜底也失败，userId 仍可能为空——
      // 此时视为登录失败，避免把用户带到数据残缺的个人中心一片空白。
      if (userId.isEmpty) {
        authStatus = AuthStatus.NOT_LOGGED_IN;
        return null;
      }

      return userId;
    } on AuthException catch (error) {
      Utility.customSnackBar(scaffoldKey, error.message, context);
      return null;
    } catch (error) {
      Utility.customSnackBar(scaffoldKey, error.toString(), context);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> signUp(
    UserModel userModel,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
    required String password,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      final response = await authService.register(
        username: userModel.userName ?? userModel.email ?? '',
        password: password,
        confirmPassword: password,
        displayName: userModel.displayName ?? '',
        bio: userModel.bio,
      );

      userId = response.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      // Update local user model
      _userModel = userModel;
      _userModel!.userId = int.tryParse(userId);

      // Save to local storage
      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);

      return userId;
    } on ApiException catch (error) {
      Utility.customSnackBar(scaffoldKey, error.message, context);
      return null;
    } catch (error) {
      Utility.customSnackBar(scaffoldKey, error.toString(), context);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// 注册流程：先创建账号，注册成功后自动用相同凭证登录，
  /// 设置登录状态并加载用户资料，最后返回 userId。
  ///
  /// 执行顺序（严格按此顺序，否则会状态错乱）：
  ///   1) POST /user/register  (创建账号)
  ///   2) POST /user/signin    (拿 token，服务端会保存到本地 + ApiClient)
  ///   3) userId = ...; authStatus = LOGGED_IN  (设置登录态)
  ///   4) await getProfileUser()  (加载用户资料)
  ///   5) notifyListeners()       (通知 Provider 监听者)
  ///   6) return userId           (UI 收到后跳转到 HomePage)
  Future<String?> register(
    String username,
    String password,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      // 1) 创建账号
      await authService.register(
        username: username,
        password: password,
        confirmPassword: password,
      );

      // 2) 用相同凭证登录（注册接口不返回 token，需要再调一次 signin）
      final signInResult = await authService.signIn(
        username: username,
        password: password,
      );

      // 3) 设置登录态
      userId = signInResult.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      // 4) 加载用户资料
      await getProfileUser();

      // 5) 通知监听者（HomePage 挂载时才能读到正确的 authStatus）
      notifyListeners();

      return userId;
    } on ApiException catch (error) {
      Utility.customSnackBar(scaffoldKey, error.message, context);
      return null;
    } catch (error) {
      Utility.customSnackBar(scaffoldKey, error.toString(), context);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      isBusy = true;
      notifyListeners();

      if (!authService.isLoggedIn) {
        authStatus = AuthStatus.NOT_LOGGED_IN;
        isBusy = false;
        notifyListeners();
        return null;
      }

      // Get current user info from API
      final userInfo = await authService.getCurrentUser();
      userId = userInfo.userId.toString();

      _userModel = UserModel(
        userId: userInfo.userId,
        userName: userInfo.username,
        displayName: userInfo.displayName,
        bio: userInfo.bio,
        profilePic: userInfo.profilePic,
        link: userInfo.link,
        isPrivate: userInfo.isPrivate,
        followersCount: userInfo.followersCount,
        followingCount: userInfo.followingCount,
        pronouns: userInfo.pronouns,
        gender: userInfo.gender,
        location: userInfo.location,
        isVerified: userInfo.isVerified,
        accountType: userInfo.accountType,
        postsCount: userInfo.postsCount,
      );

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
      authStatus = AuthStatus.LOGGED_IN;

      isBusy = false;
      notifyListeners();
      return null;
    } catch (error) {
      // Access token 可能过期，尝试用 refresh token 刷新
      try {
        await authService.refreshToken();
        final userInfo = await authService.getCurrentUser();
        userId = userInfo.userId.toString();
        _userModel = UserModel(
          userId: userInfo.userId,
          userName: userInfo.username,
          displayName: userInfo.displayName,
          bio: userInfo.bio,
          profilePic: userInfo.profilePic,
          link: userInfo.link,
          isPrivate: userInfo.isPrivate,
          followersCount: userInfo.followersCount,
          followingCount: userInfo.followingCount,
          pronouns: userInfo.pronouns,
          gender: userInfo.gender,
          location: userInfo.location,
          isVerified: userInfo.isVerified,
          accountType: userInfo.accountType,
          postsCount: userInfo.postsCount,
        );
        getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
        authStatus = AuthStatus.LOGGED_IN;
      } catch (_) {
        authStatus = AuthStatus.NOT_LOGGED_IN;
      }
      isBusy = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> updateUserProfile(
    UserModel? userModel, {
    File? image,
    bool removeAvatar = false,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      String? avatarUrl;
      if (image != null) {
        avatarUrl = await uploadService.uploadImage(image);
      } else if (removeAvatar) {
        avatarUrl = '';
      }

      if (userModel != null) {
        final updatedInfo = await userService.updateProfile(
          displayName: userModel.displayName,
          bio: userModel.bio,
          websiteUrl: userModel.link,
          avatarUrl: avatarUrl ?? userModel.profilePic,
          pronouns: userModel.pronouns,
          gender: userModel.gender,
          location: userModel.location,
          isPrivate: userModel.isPrivate == true ? 1 : 0,
          accountType: userModel.accountType,
        );

        _userModel = userModel.copyWith(
          displayName: updatedInfo.displayName,
          bio: updatedInfo.bio,
          profilePic: updatedInfo.profilePic,
          link: updatedInfo.link,
          pronouns: updatedInfo.pronouns,
          gender: updatedInfo.gender,
          location: updatedInfo.location,
          isVerified: updatedInfo.isVerified,
          accountType: updatedInfo.accountType,
          postsCount: updatedInfo.postsCount,
        );
      }

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
    } catch (error) {
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<UserModel?> getUserDetail(String userIdStr) async {
    try {
      final userId = int.tryParse(userIdStr);
      if (userId == null) return null;

      final userInfo = await userService.getUserProfile(userId);
      return UserModel(
        userId: userInfo.userId,
        userName: userInfo.username,
        displayName: userInfo.displayName,
        bio: userInfo.bio,
        profilePic: userInfo.profilePic,
        isPrivate: userInfo.isPrivate,
        followersCount: userInfo.followersCount,
        followingCount: userInfo.followingCount,
        link: userInfo.link,
        pronouns: userInfo.pronouns,
        gender: userInfo.gender,
        location: userInfo.location,
        isVerified: userInfo.isVerified,
        accountType: userInfo.accountType,
        postsCount: userInfo.postsCount,
      );
    } catch (error) {
      return null;
    }
  }

  Future<void> getProfileUser({String? userProfileId}) async {
    try {
      isBusy = true;
      notifyListeners();

      final userInfo = await authService.getCurrentUser();
      userId = userInfo.userId.toString();
      debugPrint('getProfileUser - got userId: $userId, username=${userInfo.username}');

      // GET /user/me 只返回 id/username/avatar，需要再调完整资料接口
      final fullProfile = await userService.getUserProfile(userInfo.userId);
      debugPrint('getProfileUser - fullProfile: username=${fullProfile.username}, displayName=${fullProfile.displayName}, bio=${fullProfile.bio}, link=${fullProfile.link}');

      // 关键：/user/profile/{id} 接口的 schema 把 user_id 标记为 optional + default 0，
      // 服务端可能省略这个字段导致 fullProfile.userId = 0。
      // 如果拿 0 写进缓存，ProfileState._loadCurrentUser 读到 "0"，
      // isMyProfile 就会错误判定为 false，从而在个人中心页把"编辑资料"显示成"关注"。
      // 所以 userId 一律用 /user/me 返回的（schema 必返 id），这是当前登录态的权威来源。
      // 同样的，displayName/profilePic 在新用户未填写时为空，用 /user/me 的值补。
      // /user/profile/{id} 接口的 schema 不返回 username 字段，
      // 真正的 username 也来自 /user/me 的 userInfo.username。
      _userModel = UserModel(
        userId: userInfo.userId,
        userName: userInfo.username,
        displayName: fullProfile.displayName.isNotEmpty
            ? fullProfile.displayName
            : userInfo.displayName,
        bio: fullProfile.bio,
        profilePic: (fullProfile.profilePic?.isNotEmpty ?? false)
            ? fullProfile.profilePic
            : userInfo.profilePic,
        link: fullProfile.link,
        isPrivate: fullProfile.isPrivate,
        followersCount: fullProfile.followersCount,
        followingCount: fullProfile.followingCount,
        pronouns: fullProfile.pronouns,
        gender: fullProfile.gender,
        location: fullProfile.location,
        isVerified: fullProfile.isVerified,
        accountType: fullProfile.accountType,
        postsCount: fullProfile.postsCount,
      );

      debugPrint('getProfileUser - _userModel: userName=${_userModel?.userName}, displayName=${_userModel?.displayName}');

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);

      isBusy = false;
      notifyListeners();
    } catch (error) {
      isBusy = false;
      notifyListeners();
      debugPrint('getProfileUser error: $error');
    }
  }

  bool get isLoggedIn => authService.isLoggedIn;
}