import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/helper/shared_prefrence_helper.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/network/api_exception.dart';
import 'package:threads/services/auth_service.dart';
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

  Future<void> initAuthService() async {
    await authService.init();
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
        isPrivate: userInfo.isPrivate,
        followersCount: userInfo.followersCount,
        followingCount: userInfo.followingCount,
      );

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
      authStatus = AuthStatus.LOGGED_IN;

      isBusy = false;
      notifyListeners();
      return null;
    } catch (error) {
      isBusy = false;
      authStatus = AuthStatus.NOT_LOGGED_IN;
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

      if (image != null) {
        // Upload image first - this would use UploadService
        // For now, we skip image upload as it requires UploadService
      }

      if (userModel != null) {
        final updatedInfo = await userService.updateProfile(
          displayName: userModel.displayName,
          bio: userModel.bio,
          link: userModel.link,
          profilePic: userModel.profilePic,
        );

        _userModel = userModel.copyWith(
          displayName: updatedInfo.displayName,
          bio: updatedInfo.bio,
          profilePic: updatedInfo.profilePic,
        );
      }

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
      isBusy = false;
      notifyListeners();
    } catch (error) {
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

      _userModel = UserModel(
        userId: userInfo.userId,
        userName: userInfo.username,
        displayName: userInfo.displayName,
        bio: userInfo.bio,
        profilePic: userInfo.profilePic,
        isPrivate: userInfo.isPrivate,
        followersCount: userInfo.followersCount,
        followingCount: userInfo.followingCount,
      );

      getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);

      isBusy = false;
      notifyListeners();
    } catch (error) {
      isBusy = false;
      notifyListeners();
    }
  }

  bool get isLoggedIn => authService.isLoggedIn;
}