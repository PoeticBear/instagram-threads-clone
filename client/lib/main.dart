import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/common/splash.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/network/api_logger.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/services/deep_link_service.dart';
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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init();
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStates>(create: (_) => AppStates()),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
        ChangeNotifierProvider<PostState>(create: (_) => PostState()),
        ChangeNotifierProvider<SearchState>(create: (_) => SearchState()),
        ChangeNotifierProvider<NotificationState>(create: (_) => NotificationState()),
        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()..loadSettings()),
        // ===== feed autoplay (pure client) =====
        ChangeNotifierProvider<MediaPreferences>(
          create: (_) => MediaPreferences(widget.sharedPreferences),
          lazy: false, // 关键：启动即构造，跑 _load() 把开关写入 VideoPlayerPool
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
