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
  late String userId;
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

  /// Simple registration with username and password only
  Future<String?> register(
    String username,
    String password,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      final response = await authService.register(
        username: username,
        password: password,
        confirmPassword: password,
      );

      userId = response.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      // Load user profile after registration
      await getProfileUser();

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
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      String? avatarUrl;
      if (image != null) {
        avatarUrl = await uploadService.uploadImage(image);
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
      debugPrint('getProfileUser - got userId: $userId');

      // GET /user/me 只返回 id/username/avatar，需要再调完整资料接口
      final fullProfile = await userService.getUserProfile(userInfo.userId);
      debugPrint('getProfileUser - fullProfile: username=${fullProfile.username}, displayName=${fullProfile.displayName}, bio=${fullProfile.bio}, link=${fullProfile.link}');

      _userModel = UserModel(
        userId: fullProfile.userId,
        userName: fullProfile.username,
        displayName: fullProfile.displayName,
        bio: fullProfile.bio,
        profilePic: fullProfile.profilePic,
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

      debugPrint('getProfileUser - _userModel: displayName=${_userModel?.displayName}');

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