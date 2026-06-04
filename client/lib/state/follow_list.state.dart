import 'package:flutter/foundation.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/common/locator.dart';

class FollowListState extends ChangeNotifier {
  final String profileId;

  FollowListState(this.profileId) {
    _init();
  }

  FollowService? _followService;
  FollowService get followService {
    _followService ??= FollowService(apiClient: getIt());
    return _followService!;
  }

  // --- Followers ---
  List<UserModel> _followers = [];
  List<UserModel> get followers => _followers;
  int _followersTotal = 0;
  int get followersTotal => _followersTotal;
  int _followersPage = 1;
  bool _hasMoreFollowers = true;
  bool get hasMoreFollowers => _hasMoreFollowers;

  // --- Following ---
  List<UserModel> _following = [];
  List<UserModel> get following => _following;
  int _followingTotal = 0;
  int get followingTotal => _followingTotal;
  int _followingPage = 1;
  bool _hasMoreFollowing = true;
  bool get hasMoreFollowing => _hasMoreFollowing;

  // --- Loading states ---
  bool _isLoadingFollowers = false;
  bool get isLoadingFollowers => _isLoadingFollowers;
  bool _isLoadingFollowing = false;
  bool get isLoadingFollowing => _isLoadingFollowing;

  // --- Search ---
  String _keyword = '';
  String get keyword => _keyword;

  // --- Follow/Unfollow loading per user ---
  final Set<int> _toggleLoadingIds = {};
  bool isToggleLoading(int userId) => _toggleLoadingIds.contains(userId);

  void _init() {
    loadFollowers();
    loadFollowing();
  }

  void setKeyword(String value) {
    if (_keyword == value) return;
    _keyword = value;
    _followers = [];
    _following = [];
    _followersPage = 1;
    _followingPage = 1;
    _hasMoreFollowers = true;
    _hasMoreFollowing = true;
    notifyListeners();
    loadFollowers();
    loadFollowing();
  }

  // ==================== Followers ====================

  Future<void> loadFollowers() async {
    if (_isLoadingFollowers) return;
    _isLoadingFollowers = true;
    notifyListeners();

    try {
      final userId = int.tryParse(profileId);
      if (userId == null) return;

      final result = await followService.getFollowers(
        userId,
        page: _followersPage,
        keyword: _keyword.isEmpty ? null : _keyword,
      );

      final newUsers = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
        isVerified: info.isVerified,
        isFollowing: info.isFollowing,
      )).toList();

      _followers = [..._followers, ...newUsers];
      _followersTotal = result.total;
      _hasMoreFollowers = _followers.length < result.total;
      _followersPage++;
    } catch (e) {
      debugPrint('FollowListState.loadFollowers failed: $e');
    } finally {
      _isLoadingFollowers = false;
      notifyListeners();
    }
  }

  Future<void> refreshFollowers() async {
    _followers = [];
    _followersPage = 1;
    _hasMoreFollowers = true;
    notifyListeners();
    await loadFollowers();
  }

  // ==================== Following ====================

  Future<void> loadFollowing() async {
    if (_isLoadingFollowing) return;
    _isLoadingFollowing = true;
    notifyListeners();

    try {
      final userId = int.tryParse(profileId);
      if (userId == null) return;

      final result = await followService.getFollowing(
        userId,
        page: _followingPage,
        keyword: _keyword.isEmpty ? null : _keyword,
      );

      final newUsers = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
        isVerified: info.isVerified,
        isFollowing: info.isFollowing,
      )).toList();

      _following = [..._following, ...newUsers];
      _followingTotal = result.total;
      _hasMoreFollowing = _following.length < result.total;
      _followingPage++;
    } catch (e) {
      debugPrint('FollowListState.loadFollowing failed: $e');
    } finally {
      _isLoadingFollowing = false;
      notifyListeners();
    }
  }

  Future<void> refreshFollowing() async {
    _following = [];
    _followingPage = 1;
    _hasMoreFollowing = true;
    notifyListeners();
    await loadFollowing();
  }

  // ==================== Follow / Unfollow ====================

  Future<void> toggleFollow(UserModel user, {required bool isCurrentlyFollowing}) async {
    if (_toggleLoadingIds.contains(user.userId)) return;
    _toggleLoadingIds.add(user.userId!);
    notifyListeners();

    try {
      if (isCurrentlyFollowing) {
        await followService.unfollowUser(user.userId!);
      } else {
        await followService.followUser(user.userId!);
      }

      // Update the user's following status in both lists
      _updateUserFollowStatus(user.userId!, !isCurrentlyFollowing);
    } catch (e) {
      debugPrint('FollowListState.toggleFollow failed: $e');
    } finally {
      _toggleLoadingIds.remove(user.userId);
      notifyListeners();
    }
  }

  void _updateUserFollowStatus(int userId, bool isNowFollowing) {
    _followers = _followers.map((u) {
      if (u.userId == userId) {
        return UserModel(
          userId: u.userId,
          userName: u.userName,
          displayName: u.displayName,
          bio: u.bio,
          profilePic: u.profilePic,
          isPrivate: u.isPrivate,
          followersCount: u.followersCount,
          followingCount: u.followingCount,
          pronouns: u.pronouns,
          gender: u.gender,
          location: u.location,
          isVerified: u.isVerified,
          accountType: u.accountType,
          postsCount: u.postsCount,
          isFollowing: isNowFollowing,
        );
      }
      return u;
    }).toList();

    _following = _following.map((u) {
      if (u.userId == userId) {
        return UserModel(
          userId: u.userId,
          userName: u.userName,
          displayName: u.displayName,
          bio: u.bio,
          profilePic: u.profilePic,
          isPrivate: u.isPrivate,
          followersCount: u.followersCount,
          followingCount: u.followingCount,
          pronouns: u.pronouns,
          gender: u.gender,
          location: u.location,
          isVerified: u.isVerified,
          accountType: u.accountType,
          postsCount: u.postsCount,
          isFollowing: isNowFollowing,
        );
      }
      return u;
    }).toList();
  }
}
