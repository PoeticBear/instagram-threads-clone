import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/helper/shared_prefrence_helper.dart';
import 'package:threads/common/locator.dart';

class ProfileState extends ChangeNotifier {
  final String profileId;

  ProfileState(this.profileId) {
    _init();
  }

  String? userId;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  UserModel? _profileUserModel;
  UserModel? get profileUserModel => _profileUserModel;

  bool _isBusy = true;
  bool get isbusy => _isBusy;
  set loading(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  UserService? _userService;
  FollowService? _followService;

  UserService get userService {
    _userService ??= UserService(apiClient: getIt());
    return _userService!;
  }

  FollowService get followService {
    _followService ??= FollowService(apiClient: getIt());
    return _followService!;
  }

  bool _isFollowing = false;
  bool get isFollowing => _isFollowing;

  bool _isFollowLoading = false;
  bool get isFollowLoading => _isFollowLoading;

  FollowStats _followStats = FollowStats();
  FollowStats get followStats => _followStats;

  Future<void> _init() async {
    await _loadCurrentUser();
    await _getProfileUser(profileId);
    await _loadFollowStats();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final cachedUser = getIt<SharedPreferenceHelper>().getUserProfile();
      if (cachedUser != null && cachedUser.userId != null) {
        userId = cachedUser.userId.toString();
        _userModel = cachedUser;
      }
    } catch (_) {
      // SharedPreferences not available, userId remains null
    }
  }

  bool get isMyProfile => userId != null && profileId == userId;

  Future<void> _getProfileUser(String? userProfileId) async {
    if (userProfileId == null) return;

    try {
      loading = true;

      final userIdInt = int.tryParse(userProfileId);
      if (userIdInt == null) {
        loading = false;
        return;
      }

      final userInfo = await userService.getUserProfile(userIdInt);

      _profileUserModel = UserModel(
        userId: userInfo.userId,
        userName: userInfo.username,
        displayName: userInfo.displayName,
        bio: userInfo.bio,
        profilePic: userInfo.profilePic,
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

      debugPrint('ProfileState._getProfileUser: followersCount=${userInfo.followersCount}, followingCount=${userInfo.followingCount}');
      debugPrint('ProfileState._getProfileUser: profilePic=${_profileUserModel?.profilePic}');

      loading = false;
      notifyListeners();
    } catch (error) {
      loading = false;
    }
  }

  Future<void> followUser({bool removeFollower = false}) async {
    if (_isFollowLoading) return;
    try {
      if (_userModel == null || _profileUserModel == null) return;

      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) return;

      _isFollowLoading = true;
      // Optimistic update
      _isFollowing = !removeFollower;
      notifyListeners();

      if (removeFollower) {
        await followService.unfollowUser(profileUserId);
      } else {
        await followService.followUser(profileUserId);
      }

      // Refresh stats after follow/unfollow
      await _loadFollowStats();
    } catch (error) {
      // Rollback on error
      _isFollowing = !removeFollower;
      notifyListeners();
    } finally {
      _isFollowLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFollowStats() async {
    try {
      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) return;
      _followStats = await followService.getFollowStats(profileUserId);
      debugPrint('ProfileState._loadFollowStats: followers=${_followStats.followersCount}, following=${_followStats.followingCount}, isFollowing=${_followStats.isFollowing}');
      _isFollowing = _followStats.isFollowing;
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileState._loadFollowStats failed: $e');
    }
  }

  Future<void> refresh() async {
    await _getProfileUser(profileId);
    await _loadFollowStats();
  }

  Future<FollowStats> getFollowStats() async {
    try {
      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) {
        return FollowStats();
      }
      return await followService.getFollowStats(profileUserId);
    } catch (error) {
      return FollowStats();
    }
  }

  Future<List<UserModel>> getFollowers({int page = 1}) async {
    try {
      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) return [];

      final followers = await followService.getFollowers(profileUserId, page: page);
      return followers.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();
    } catch (error) {
      return [];
    }
  }

  Future<List<UserModel>> getFollowing({int page = 1}) async {
    try {
      final following = await followService.getFollowing(page: page);
      return following.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();
    } catch (error) {
      return [];
    }
  }
}