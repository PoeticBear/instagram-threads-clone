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
import 'package:threads/services/websocket_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

class AuthState extends AppStates {
  AuthState() {
    // 构造期不做 WS 订阅 —— _MyAppState._wireupWebSocket 负责,
    // 因为它需要 BuildContext 来读其他 Provider。
  }

  // ── authStatus:用 getter/setter 拦截赋值,自动广播到 onAuthChanged ──
  // 类内和类外任何 `authStatus = X` 都会走 setter,无需逐处改成 _setAuthStatus()。
  AuthStatus _authStatus = AuthStatus.NOT_DETERMINED;
  AuthStatus get authStatus => _authStatus;
  set authStatus(AuthStatus value) {
    final prev = _authStatus;
    _authStatus = value;
    if (prev != value) {
      _authStatusController.add(value);
    }
  }

  /// authStatus 变化广播(仅 status 真正切换时才发,不受 isBusy 噪音影响)。
  /// 由 `_MyAppState._wireupWebSocket` 订阅,驱动 WebSocketService connect/disconnect。
  final StreamController<AuthStatus> _authStatusController =
      StreamController<AuthStatus>.broadcast();
  Stream<AuthStatus> get onAuthChanged => _authStatusController.stream;

  bool isSignInWithGoogle = false;
  // 默认空串，避免 late 未初始化访问抛 LateInitializationError。
  // 未登录时也允许被读取（结果为空串），上层据此决定是否渲染需登录态的页面。
  String userId = '';

  /// 登录后若 username 为空，需强制补填。getProfileUser 判空置位，
  /// 各「进入应用」出口据此弹出 UsernameSetupDialog。
  bool needsUsernameSetup = false;

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
    // WS 兜底:失效 token 不应被重连机制拿去反复握手。
    // 正常路径下 _MyAppState 的 onAuthChanged 监听已会 disconnect,这是防御性双保险。
    if (getIt.isRegistered<WebSocketService>()) {
      getIt<WebSocketService>().disableForAuth();
    }
    authStatus = AuthStatus.NOT_LOGGED_IN;
    userId = '';
    _userModel = null;
    needsUsernameSetup = false;
    await authService.logout();
    notifyListeners();
    await getIt<SharedPreferenceHelper>().clearPreferenceValues();
  }

  /// 由 ApiClient.onSessionExpired 回调触发（被动登出）。
  /// 与 logoutCallback 的区别：
  ///   - 不调 authService.logout()（避免失效 token 再发请求触发新一轮 401）
  ///   - 直接 clearLocalSession + 清 prefs + 切状态
  /// 幂等：authStatus 已是 NOT_LOGGED_IN 时直接返回。
  void forceSessionExpired() {
    if (authStatus == AuthStatus.NOT_LOGGED_IN) return;
    // WS 兜底:失效 token 不应被重连机制拿去反复握手
    if (getIt.isRegistered<WebSocketService>()) {
      getIt<WebSocketService>().disableForAuth();
    }
    authStatus = AuthStatus.NOT_LOGGED_IN;
    userId = '';
    _userModel = null;
    needsUsernameSetup = false;
    isBusy = false; // 复位脏状态（getProfileUser 的 try 块可能已把 isBusy 设为 true）
    authService.clearLocalSession(); // 不 await
    getIt<SharedPreferenceHelper>().clearPreferenceValues();
    notifyListeners();
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

  /// Apple 登录流程：拿到的 authorizationCode → /auth/apple/login → 保存 token →
  /// 加载用户资料 → 设置 LOGGED_IN。失败一律走 scaffoldKey snackbar，与 signIn 行为一致。
  ///
  /// 状态机顺序（与 signIn 严格一致，避免 AuthState 与 HomePage 之间状态错乱）：
  ///   1) isBusy = true
  ///   2) 调 authService.signInWithApple(code)
  ///   3) userId = ...; authStatus = LOGGED_IN
  ///   4) await getProfileUser()
  ///   5) 防御：userId 为空则回退到 NOT_LOGGED_IN
  ///   6) notifyListeners(); return userId
  ///
  /// TODO(后端对齐): 首次 Apple 登录的 username 由后端自动生成（假设）。
  /// 若后端要求前端补填 username / displayName，需在 userId 非空但 username 为空
  /// 时路由到 "完善资料" 页。
  Future<String?> signInWithApple(
    String code,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      final response = await authService.signInWithApple(code: code);
      debugPrint('[AppleLogin] auth.state: /auth/apple/login 返回 userId=${response.userId}');

      userId = response.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      // Load user profile（与 signIn 行为一致，后续 getProfileUser 会拉 /user/me + /user/profile/{id}）
      debugPrint('[AppleLogin] auth.state: 调用 getProfileUser 拉取资料并判空...');
      await getProfileUser();
      debugPrint('[AppleLogin] auth.state: getProfileUser 完成 → '
          'needsUsernameSetup=$needsUsernameSetup, _userModel.userName="${_userModel?.userName}", userId=$userId');

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

  /// Google 登录流程：客户端拿到 Google idToken（在 name.dart 完成） →
  /// /auth/google/login → 保存 token → 加载用户资料 → 设置 LOGGED_IN。失败一律走
  /// scaffoldKey snackbar，与 signIn / signInWithApple 行为一致。
  ///
  /// 状态机顺序（与 signInWithApple 严格一致，避免状态错乱）：
  ///   1) isBusy = true
  ///   2) 调 authService.signInWithGoogle(idToken)
  ///   3) userId = ...; authStatus = LOGGED_IN
  ///   4) await getProfileUser()
  ///   5) 防御：userId 为空则回退到 NOT_LOGGED_IN
  ///   6) notifyListeners(); return userId
  ///
  /// TODO(后端对齐): 首次 Google 登录的 username 由后端自动生成（假设）。
  /// 若后端不自动生成，getProfileUser 会置位 needsUsernameSetup，name.dart
  /// 出口据此弹 UsernameSetupDialog（与 Apple 登录一致）。
  Future<String?> signInWithGoogle(
    String idToken,
    BuildContext context, {
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      final response = await authService.signInWithGoogle(idToken: idToken);
      debugPrint('[GoogleLogin] auth.state: /auth/google/login 返回 userId=${response.userId}');

      userId = response.userId?.toString() ?? '';
      authStatus = AuthStatus.LOGGED_IN;

      debugPrint('[GoogleLogin] auth.state: 调用 getProfileUser 拉取资料并判空...');
      await getProfileUser();
      debugPrint('[GoogleLogin] auth.state: getProfileUser 完成 → '
          'needsUsernameSetup=$needsUsernameSetup, _userModel.userName="${_userModel?.userName}", userId=$userId');

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
    } on AuthException {
      // ApiClient 已尝试过 refresh 且失败，会话已失效。
      // forceSessionExpired() 会由 onSessionExpired 回调异步触发导航。
      // 这里只兜底切状态，避免 UI 卡在 isBusy。
      authStatus = AuthStatus.NOT_LOGGED_IN;
      isBusy = false;
      notifyListeners();
      return null;
    } catch (error) {
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

      // username 为空 → 标记需强制补填，各「进入应用」出口据此弹窗。
      needsUsernameSetup = (_userModel?.userName ?? '').isEmpty;
      debugPrint('[AppleLogin] getProfileUser 判空: '
          'userName="${_userModel?.userName}", '
          'isEmpty=${(_userModel?.userName ?? '').isEmpty}, '
          'needsUsernameSetup=$needsUsernameSetup');

      isBusy = false;
      notifyListeners();
    } on AuthException {
      // 会话失效：ApiClient 已尝试 refresh 且失败，forceSessionExpired 会通过
      // onSessionExpired 回调异步触发导航。这里不重置 isBusy，避免 UI 闪烁
      //（forceSessionExpired 内部的 notifyListeners 会覆盖）。
      debugPrint('[AppleLogin] getProfileUser: 捕获 AuthException（会话失效）→ '
          'needsUsernameSetup 未被设置，当前=$needsUsernameSetup');
      debugPrint('getProfileUser - session expired, waiting for forceSessionExpired');
    } catch (error) {
      isBusy = false;
      notifyListeners();
      debugPrint('[AppleLogin] getProfileUser: 捕获异常 → $error '
          '（needsUsernameSetup 未被设置，当前=$needsUsernameSetup）');
      debugPrint('getProfileUser error: $error');
    }
  }

  /// 强制补填 username：调 PUT /user/username 存到服务端 → 刷新本地 _userModel → 清除标志。
  /// 失败时抛出异常（ApiException 携带后端原因）；调用方负责 catch 并向用户展示，
  /// 这样「username 已被占用」等后端错误能直接反馈给用户，而非笼统的「设置失败」。
  Future<void> setUsername(String username) async {
    isBusy = true;
    notifyListeners();
    try {
      await userService.setUsername(username);

      if (_userModel != null) {
        _userModel = _userModel!.copyWith(userName: username);
        getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
      }
      needsUsernameSetup = false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  bool get isLoggedIn => authService.isLoggedIn;
}