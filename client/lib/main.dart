import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/common/splash.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/locale.state.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/state/search.state.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/state/notification.state.dart';
import 'package:threads/state/settings.state.dart';
import 'package:threads/state/draft.state.dart';
import 'package:threads/state/community.state.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  runApp(MyApp(
    sharedPreferences: sharedPreferences,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.sharedPreferences}) : super(key: key);
  final SharedPreferences sharedPreferences;

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
        ChangeNotifierProvider<DraftState>(create: (_) => DraftState()),
        ChangeNotifierProvider<MessageState>(create: (_) => MessageState()),
        ChangeNotifierProvider<CommunityState>(create: (_) => CommunityState()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            theme: ThemeData(brightness: Brightness.dark),
            title: 'Threads',
            debugShowCheckedModeBanner: false,
            home: SplashPage(),
          );
        },
      ),
    );
  }
}