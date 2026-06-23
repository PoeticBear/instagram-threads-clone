import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:threads/auth/signup/name.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/common/splash.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/network/api_logger.dart';
import 'package:threads/network/ws_config.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/services/deep_link_service.dart';
import 'package:threads/services/websocket_service.dart';
import 'package:threads/services/ws_handlers/message_handlers.dart';
import 'package:threads/services/ws_handlers/notification_handlers.dart';
import 'package:threads/services/ws_handlers/typing_handler.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/locale.state.dart';
import 'package:threads/state/theme.state.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/search.state.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/state/notification.state.dart';
import 'package:threads/state/settings.state.dart';
import 'package:threads/state/draft.state.dart';
import 'package:threads/state/community.state.dart';
import 'package:threads/state/follow_request.state.dart';
import 'package:threads/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threads/state/media_preferences.state.dart';
import 'package:threads/state/media_layout_preferences.state.dart';
import 'package:threads/state/app_icon_state.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Failed to initialize cameras: $e');
  }

  // Setup dependencies (async)
  await setupDependencies();

  // Initialize SharedPreferences (already done in setupDependencies)
  final sharedPreferences = getIt<SharedPreferences>();

  // Initialize API client
  final apiClient = ApiClient();
  getIt.registerSingleton<ApiClient>(apiClient);

  // Register WebSocket service (after ApiClient so it can read access token)
  getIt.registerSingleton<WebSocketService>(WebSocketService());

  // Initialize file logger
  ApiLogger.init();

  runApp(MyApp(
    sharedPreferences: sharedPreferences,
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key, required this.sharedPreferences}) : super(key: key);
  final SharedPreferences sharedPreferences;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  WebSocketService? _ws;
  StreamSubscription<AuthStatus>? _authStatusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // App 级 paused/resumed 钩子
    _ws = getIt<WebSocketService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init();
      _wireupApiClientCallbacks();
      _wireupWebSocket();
    });
  }

  /// App 生命周期:paused → 断开 WS(省电 + 避免弱网重连风暴);
  /// resumed → 若已登录则重连。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ws = _ws;
    if (ws == null) return;
    if (state == AppLifecycleState.paused) {
      ws.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      final auth = Provider.of<AuthState>(ctx, listen: false);
      if (auth.authStatus == AuthStatus.LOGGED_IN) {
        ws.connect();
      }
    }
  }

  /// 注册 WS event handler + 订阅 AuthState 变化驱动连接。
  /// 必须在 postFrameCallback 里调,保证 navigatorKey.currentContext 可用。
  void _wireupWebSocket() {
    final ws = _ws;
    final ctx = navigatorKey.currentContext;
    if (ws == null || ctx == null) return;
    final authState = Provider.of<AuthState>(ctx, listen: false);

    _wireupHandlers(ws, ctx);

    // 订阅 AuthState.authStatus:LOGGED_IN → connect;否则 disconnect。
    // forceSessionExpired / logoutCallback 会先调 disableForAuth 把 _authDisabled=true,
    // 这里随后调的 disconnect 是 no-op(已经断了);下次 connect() 入口会复位 _authDisabled。
    _authStatusSub = authState.onAuthChanged.listen((status) {
      if (status == AuthStatus.LOGGED_IN) {
        ws.connect();
      } else {
        ws.disconnect();
      }
    });

    // 启动时若是已登录态,主动连一次(Splash 恢复登录态的场景)
    if (authState.authStatus == AuthStatus.LOGGED_IN) {
      ws.connect();
    }
  }

  /// 注册 WS event handler(消息类 4 个 + 通知类 12 个 = 16 个)。
  /// handler 是 callable class(`void call(WsEvent)`),内部解析字段后调 State 类的公共方法。
  /// 异常由 WebSocketService._onData 兜住打 log,handler 内不需要 try/catch。
  void _wireupHandlers(WebSocketService ws, BuildContext ctx) {
    final msgState = ctx.read<MessageState>();
    final notifState = ctx.read<NotificationState>();

    // 消息类(4 个)
    ws.registerHandler(WsConfig.evtMessageTyping, TypingHandler(msgState).call);
    ws.registerHandler(WsConfig.evtMessageRead, MessageReadHandler(msgState).call);
    ws.registerHandler(
        WsConfig.evtMessageReaction, MessageReactionHandler(msgState).call);
    ws.registerHandler(WsConfig.evtGroupMessage, GroupMessageHandler(msgState).call);

    // 通知类(12 个)
    // - 先期 2 个用具名 handler(已注册,保留)
    ws.registerHandler(
        WsConfig.evtNotificationNew, NotificationNewHandler(notifState).call);
    ws.registerHandler(WsConfig.evtPostLike, PostLikeHandler(notifState).call);
    // - 其余 10 个共用 GenericNotificationHandler(行为一致,仅 event_type 不同)
    final genericNotifHandler = GenericNotificationHandler(notifState).call;
    ws.registerHandler(WsConfig.evtReplyLike, genericNotifHandler);
    ws.registerHandler(WsConfig.evtPostMention, genericNotifHandler);
    ws.registerHandler(WsConfig.evtReplyMention, genericNotifHandler);
    ws.registerHandler(WsConfig.evtPostReply, genericNotifHandler);
    ws.registerHandler(WsConfig.evtPostRepost, genericNotifHandler);
    ws.registerHandler(WsConfig.evtPostQuote, genericNotifHandler);
    ws.registerHandler(WsConfig.evtFollowRequest, genericNotifHandler);
    ws.registerHandler(WsConfig.evtFollowAccept, genericNotifHandler);
    ws.registerHandler(WsConfig.evtNewFollower, genericNotifHandler);
    ws.registerHandler(WsConfig.evtFollowRequestDeclined, genericNotifHandler);
  }

  /// 把 ApiClient 与 Provider 树桥接起来：
  /// - refreshTokensProvider：401 时由 ApiClient 调用，使用 refresh_token 换新 access_token
  /// - onSessionExpired：refresh 失败时由 ApiClient 调用，触发全局登出 + 跳转登录页
  ///
  /// 时序：_MyAppState.initState 在 SplashPage.initState 之前执行（root widget 先 init），
  /// 同一帧的 addPostFrameCallback 按 FIFO 注册顺序执行 → 本方法先于 Splash 的 timer()，
  /// 保证 Splash 拉 getProfileUser 时 ApiClient 已具备 refresh 能力。
  void _wireupApiClientCallbacks() {
    final apiClient = getIt<ApiClient>();
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final authState = Provider.of<AuthState>(ctx, listen: false);

    apiClient.refreshTokensProvider = () => authState.authService.tryRefreshTokens();

    apiClient.onSessionExpired = () {
      final currentCtx = navigatorKey.currentContext;
      if (currentCtx == null) return;
      currentCtx.read<AuthState>().forceSessionExpired();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NamePage()),
        (_) => false,
      );
    };
  }

  @override
  void dispose() {
    _authStatusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _ws?.disconnect();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStates>(create: (_) => AppStates()),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
        ChangeNotifierProvider<PostState>(
          // PostState 监听 AuthState：当前用户资料（头像/昵称/用户名）变化时，
          // 把 feedlist / userPosts / postDetail 等缓存中作者=自己的帖子同步刷新。
          // 注册顺序保证 AuthState 在 PostState 之前，create 时 context.read<AuthState>() 安全。
          create: (context) => PostState(context.read<AuthState>()),
        ),
        ChangeNotifierProvider<SearchState>(create: (_) => SearchState()),
        ChangeNotifierProvider<NotificationState>(create: (_) => NotificationState()),
        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()..loadSettings()),
        // ===== feed autoplay (pure client) =====
        ChangeNotifierProvider<MediaPreferences>(
          create: (_) => MediaPreferences(widget.sharedPreferences),
          lazy: false, // 关键：启动即构造，跑 _load() 把开关写入 VideoPlayerPool
        ),
        // ===== feed 媒体布局模式（纯客户端，九宫格 / 横向滑动） =====
        ChangeNotifierProvider<MediaLayoutPreferences>(
          create: (_) => MediaLayoutPreferences(widget.sharedPreferences),
          lazy: false,
        ),
        // ===== app icon (iOS 25 pre-bundled, Android no-op) =====
        ChangeNotifierProvider<AppIconState>(
          create: (_) => AppIconState(widget.sharedPreferences)..load(),
          lazy: false,
        ),
        // ======================================
        ChangeNotifierProvider<DraftState>(create: (_) => DraftState()),
        ChangeNotifierProvider<MessageState>(create: (_) => MessageState()),
        ChangeNotifierProvider<CommunityState>(create: (_) => CommunityState()),
        ChangeNotifierProvider<FollowRequestState>(create: (_) => FollowRequestState()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            title: 'Tweet',
            debugShowCheckedModeBanner: false,
            home: SplashPage(),
          );
        },
      ),
    );
  }
}
