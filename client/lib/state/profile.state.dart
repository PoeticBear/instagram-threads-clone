import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

class ProfileState extends ChangeNotifier {
  final String profileId;

  ProfileState(this.profileId) {
    _init();
  }

  late String userId;

  late UserModel _userModel;
  UserModel get userModel => _userModel;

  late UserModel _profileUserModel;
  UserModel get profileUserModel => _profileUserModel;

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

  Future<void> _init() async {
    await _getProfileUser(profileId);
  }

  bool get isMyProfile => profileId == userId;

  Future<void> _getloggedInUserProfile(String userIdStr) async {
    try {
      final userIdInt = int.tryParse(userIdStr);
      if (userIdInt == null) return;

      final userInfo = await userService.getUserProfile(userIdInt);
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
      notifyListeners();
    } catch (error) {
      // Handle error
    }
  }

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
      );

      loading = false;
      notifyListeners();
    } catch (error) {
      loading = false;
    }
  }

  Future<void> followUser({bool removeFollower = false}) async {
    try {
      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) return;

      if (removeFollower) {
        await followService.unfollowUser(profileUserId);
        _profileUserModel.followersList?.remove(userId);
        _userModel.followingList?.remove(profileId);
      } else {
        await followService.followUser(profileUserId);
        _profileUserModel.followersList ??= [];
        _profileUserModel.followersList!.add(userId);
        _userModel.followingList ??= [];
        _userModel.followingList!.add(profileId);
      }

      notifyListeners();
    } catch (error) {
      // Handle error
    }
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
      final profileUserId = int.tryParse(profileId);
      if (profileUserId == null) return [];

      final following = await followService.getFollowing(profileUserId, page: page);
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

  @override
  void dispose() {
    super.dispose();
  }
}