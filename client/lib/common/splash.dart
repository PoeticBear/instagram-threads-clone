import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/auth/signup/name.dart';
import 'package:threads/auth/username_setup_dialog.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/pages/home.dart';
import 'package:threads/services/deep_link_service.dart';
import 'package:threads/state/auth.state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      timer();
    });
    super.initState();
  }

  bool isAppUpdated = true;

  void timer() async {
    if (isAppUpdated) {
      try {
        var state = Provider.of<AuthState>(context, listen: false);
        await state.initAuthService();
        debugPrint('timer - after initAuthService, userModel: ${state.userModel?.displayName}');
        // getCurrentUser only returns basic info (no bio/link)
        // Use getProfileUser to get full profile including bio and link
        await state.getProfileUser();
        debugPrint('timer - after getProfileUser, userModel: ${state.userModel?.displayName}');
        // Process any pending deep link after login
        if (state.authStatus == AuthStatus.LOGGED_IN) {
          // username 兜底：自动登录恢复后若 username 为空，同样强制补填
          if (state.needsUsernameSetup) {
            await UsernameSetupDialog.show(context, state);
          }
          DeepLinkService.instance.processPendingLink();
        }
      } catch (e) {
        debugPrint('Splash initialization error: $e');
      }
    }
  }

  Widget _body() {
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AuthState>(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: state.authStatus == AuthStatus.NOT_DETERMINED
          ? _body()
          : state.authStatus == AuthStatus.NOT_LOGGED_IN
              ? const NamePage()
              : const HomePage(),
    );
  }
}
