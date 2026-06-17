import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/helper/shared_prefrence_helper.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/state/auth.state.dart';

class ProfileState extends ChangeNotifier {
  final String profileId;
  // 当前登录用户的 ID（由调用方显式传入，避免完全依赖缓存推断）。
  // 之所以需要它：AuthState.getProfileUser 写入缓存的 userId 在某些场景
  // （如 /user/profile/{id} 省略 user_id 字段）可能为 0，
  // 导致 isMyProfile 错误判定为 false，把"编辑资料"显示成"关注"。
  // 调用方（如 MyProfilePage）通过 Selector 拿到的是 AuthState.userId，
  // 这是当前登录态的权威来源，优先使用它来判断是否是自己的 profile。
  final String? currentUserId;

  // AuthState 引用：用于自己的 profile 时实时获取 username/displayName/profilePic
  // 兜底数据，修复「首次登录后立即打开个人中心，userName/displayName 显示空白」的时序竞态。
  //
  // 背景：/user/profile/{id} 接口的 schema 不返回 username 字段，
  //   旧实现用 SharedPreferences 缓存的 _userModel 兜底；
  // 但首次登录场景下 ProfileState 的创建会抢在 AuthState.getProfileUser
  //   写入 SharedPreferences 之前发起，缓存还没落盘，
  //   导致兜底数据为空、个人中心顶部名称显示为空白。
  //   重启 App 后缓存已存在，所以又「自动恢复」。
  // 现在 ProfileState 同时持有 AuthState 引用 ——
  //   1) _getProfileUser 兜底优先读 authState.userModel（实时，不等磁盘）
  //   2) 监听 authState，AuthState 拉到资料后立即把空字段同步过来
  // 这样无论谁先就绪，ProfileState 都能拿到完整数据。
  final AuthState? authState;

  VoidCallback? _authStateListener;

  ProfileState(
    this.profileId, {
    this.currentUserId,
    this.authState,
  }) {
    _init();
    _setupAuthStateFallbackSync();
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

  /// 监听 AuthState 变化，把自己 profile 的 username/displayName/profilePic
  /// 在以下场景下二次同步过来：
  ///   - _getProfileUser 网络请求返回时 AuthState.userModel 还没就绪，
  ///     导致 _profileUserModel 关键字段为空；
  ///   - 后续 AuthState.userModel 加载完成（登录流程尾段 / 下拉刷新触发
  ///     getProfileUser）后，由本回调补齐。
  /// 不会循环：本回调只 notify 自己的 listener，不写 AuthState。
  void _setupAuthStateFallbackSync() {
    final auth = authState;
    if (auth == null) return;

    _authStateListener = () {
      if (!isMyProfile) return;
      final authUser = auth.userModel;
      if (authUser == null) return;
      if (_profileUserModel == null) return;

      final currentUserName = _profileUserModel!.userName ?? '';
      final currentDisplayName = _profileUserModel!.displayName ?? '';
      final currentProfilePic = _profileUserModel!.profilePic ?? '';

      // 只在确实有空字段时才补 —— 避免无意义的 notifyListeners 引发额外重建。
      final userNameMissing = currentUserName.isEmpty;
      final displayNameMissing = currentDisplayName.isEmpty;
      final profilePicMissing = currentProfilePic.isEmpty;
      if (!userNameMissing && !displayNameMissing && !profilePicMissing) return;

      final newUserName = userNameMissing
          ? (authUser.userName ?? '')
          : currentUserName;
      final newDisplayName = displayNameMissing
          ? (authUser.displayName ?? '')
          : currentDisplayName;
      final newProfilePic = profilePicMissing
          ? (authUser.profilePic ?? '')
          : currentProfilePic;

      // 只补非空字段（copyWith 的 null 不会覆盖既有非空值）。
      _profileUserModel = _profileUserModel!.copyWith(
        userName: userNameMissing && newUserName.isNotEmpty ? newUserName : null,
        displayName: displayNameMissing && newDisplayName.isNotEmpty
            ? newDisplayName
            : null,
        profilePic: profilePicMissing && newProfilePic.isNotEmpty
            ? newProfilePic
            : null,
      );

      debugPrint('ProfileState._authStateFallbackSync: '
          'userName=$newUserName, displayName=$newDisplayName, profilePic=${newProfilePic.isNotEmpty}');
      notifyListeners();
    };

    auth.addListener(_authStateListener!);
  }

  @override
  void dispose() {
    if (_authStateListener != null && authState != null) {
      authState!.removeListener(_authStateListener!);
      _authStateListener = null;
    }
    super.dispose();
  }

  bool get isMyProfile {
    // 优先使用调用方显式传入的 currentUserId（来自 AuthState.userId，权威），
    // 回退到从缓存加载的 userId。
    // 这样在登录后第一次打开个人中心时，即使缓存的 userId 还没回填（或者像之前
    // 那样被错误地写成了 0），也能正确判定 profileId == currentUserId。
    final effectiveUserId = currentUserId ?? userId;
    return effectiveUserId != null && effectiveUserId.isNotEmpty && profileId == effectiveUserId;
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

      // 对于自己的 profile，/user/profile/{id} 接口的 schema 不返回 username 字段，
      // 需要从当前登录用户数据补全。
      // 兜底优先级（修复首次登录后立即打开个人中心、SharedPreferences 缓存
      // 尚未落盘导致兜底为空、顶部名称显示空白的时序竞态）：
      //   1) authState.userModel —— 实时数据源，登录流程拉到后即写入；
      //   2) _userModel —— SharedPreferences 缓存（旧数据，作为二次兜底）。
      final isOwnProfile = isMyProfile;
      final authUser = isOwnProfile ? authState?.userModel : null;
      final fallbackUserName = isOwnProfile
          ? (authUser?.userName ?? _userModel?.userName ?? '')
          : '';
      final fallbackDisplayName = isOwnProfile
          ? (authUser?.displayName ?? _userModel?.displayName ?? '')
          : '';
      final fallbackProfilePic = isOwnProfile
          ? (authUser?.profilePic ?? _userModel?.profilePic ?? '')
          : '';

      _profileUserModel = UserModel(
        userId: userInfo.userId,
        userName: userInfo.username.isNotEmpty
            ? userInfo.username
            : fallbackUserName,
        displayName: userInfo.displayName.isNotEmpty
            ? userInfo.displayName
            : fallbackDisplayName,
        bio: userInfo.bio,
        profilePic: (userInfo.profilePic?.isNotEmpty ?? false)
            ? userInfo.profilePic
            : fallbackProfilePic,
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

      debugPrint('ProfileState._getProfileUser: userName=${_profileUserModel?.userName}, displayName=${_profileUserModel?.displayName}, profilePic=${_profileUserModel?.profilePic}');

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

      final result = await followService.getFollowers(profileUserId, page: page);
      return result.users.map((info) => UserModel(
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

      final result = await followService.getFollowing(profileUserId, page: page);
      return result.users.map((info) => UserModel(
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