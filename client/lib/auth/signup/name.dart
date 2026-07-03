import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:threads/auth/signup/register.dart';
import 'package:threads/auth/username_setup_dialog.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/pages/home.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/services/google_oauth_config.dart';
import 'package:threads/network/api_config.dart';

class NamePage extends StatefulWidget {
  final VoidCallback? loginCallback;
  const NamePage({Key? key, this.loginCallback}) : super(key: key);

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterUsernameAndPassword)),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authState = Provider.of<AuthState>(context, listen: false);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final result = await authState.signIn(
      username,
      password,
      context,
      scaffoldKey: scaffoldKey,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result != null) {
      debugPrint('[SignIn] name.dart 出口: result=$result, '
          'needsUsernameSetup=${authState.needsUsernameSetup} → '
          '${authState.needsUsernameSetup ? "弹窗" : "直接进首页"}');
      // username 兜底：登录后若服务端 username 为空，强制补填才放行进首页
      if (authState.needsUsernameSetup) {
        await UsernameSetupDialog.show(context, authState);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      // signIn 内部已通过 NetworkErrorNotifier 弹过具体错误 SnackBar。
      // 此处仅作为兜底，避免重复弹框。
      debugPrint('[SignIn] authState.signIn 返回 null（具体原因见 NetworkErrorNotifier 日志）');
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final authState = Provider.of<AuthState>(context, listen: false);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    String? result;

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (!mounted) return;

      // 不再打印 authorizationCode / identityToken 全量到日志，避免开发期泄露。
      // userIdentifier 是 Apple 稳定 sub，相对不敏感，但仍只截前 8 位。
      final sub = credential.userIdentifier;
      final subPreview = sub == null
          ? 'null'
          : (sub.length <= 8 ? sub : '${sub.substring(0, 8)}...');
      debugPrint('[Apple SignIn] userIdentifier=$subPreview '
          'hasEmail=${credential.email != null} '
          'hasToken=${credential.identityToken != null}');

      // sign_in_with_apple 6.x 中 authorizationCode 是非空 String，
      // 直接使用即可，identityToken 仍可能为 null（如 Web / 旧 iOS）。
      result = await authState.signInWithApple(
        credential.authorizationCode,
        context,
        scaffoldKey: scaffoldKey,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.appleSignInFailed}: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.appleSignInFailed}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) return;

    if (result != null) {
      debugPrint('[AppleLogin] name.dart 出口: result=$result, '
          'needsUsernameSetup=${authState.needsUsernameSetup} → '
          '${authState.needsUsernameSetup ? "弹窗" : "直接进首页"}');
      // username 兜底：Apple 登录后若服务端 username 为空，强制补填才放行进首页
      if (authState.needsUsernameSetup) {
        await UsernameSetupDialog.show(context, authState);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final authState = Provider.of<AuthState>(context, listen: false);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    String? result;

    try {
      // 前置检查：GoogleSignIn 7.x 必须先 initialize（main.dart 启动时已尝试）。
      // 占位凭据 / 缺 GoogleService-Info.plist 时 isInitialized=false，这里兜底提示。
      if (!GoogleOAuth.isInitialized) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.googleSignInFailed),
          ),
        );
        return;
      }

      // 唤起 Google 登录面板（interactive sign-in），失败抛 GoogleSignInException
      final account = await GoogleSignIn.instance.authenticate();

      if (!mounted) return;

      final idToken = account.authentication.idToken;

      // dev 环境:打印联调日志(含 idToken 等凭证),便于整段复制发给服务端联调。
      // prod 不打印(idToken 是敏感凭证,泄露可被冒用)。
      if (ApiConfig.environment == 'dev') {
        debugPrint('╔═══════════════════════════════════════════════════════════');
        debugPrint('║ [Google 登录 · 客户端联调日志 · 可直接发给服务端]');
        debugPrint('╠═══════════════════════════════════════════════════════════');
        debugPrint('║ [idToken] ← 服务端用此向 Google 验签(约 1 小时过期,尽快验)');
        debugPrint('║   $idToken');
        debugPrint('║ [Google 用户信息]');
        debugPrint('║   id (sub)    : ${account.id}');
        debugPrint('║   email       : ${account.email}');
        debugPrint('║   displayName : ${account.displayName}');
        debugPrint('║   photoUrl    : ${account.photoUrl}');
        debugPrint('║ [即将发往后端]');
        debugPrint('║   POST auth/google/login');
        debugPrint('║   body: { "id_token": "<上面的 idToken>" }');
        debugPrint('╚═══════════════════════════════════════════════════════════');
      }

      if (idToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.googleSignInFailed),
          ),
        );
        return;
      }

      result = await authState.signInWithGoogle(
        idToken,
        context,
        scaffoldKey: scaffoldKey,
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      // 用户取消登录不弹错误（与 Apple 登录取消一致）
      debugPrint('[Google SignIn] exception: ${e.code}');
      if (e.code != GoogleSignInExceptionCode.canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.googleSignInFailed}: ${e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.googleSignInFailed}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) return;

    if (result != null) {
      debugPrint('[GoogleLogin] name.dart 出口: result=$result, '
          'needsUsernameSetup=${authState.needsUsernameSetup} → '
          '${authState.needsUsernameSetup ? "弹窗" : "直接进首页"}');
      // username 兜底：Google 登录后若服务端 username 为空，强制补填才放行进首页
      if (authState.needsUsernameSetup) {
        await UsernameSetupDialog.show(context, authState);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Tweet',
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Text(
                AppLocalizations.of(context)!.loginTitle,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                style: TextStyle(color: appColors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.usernameHint,
                  hintStyle: TextStyle(color: appColors.textHint),
                  filled: true,
                  fillColor: appColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: appColors.textPrimary),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.passwordHint,
                  hintStyle: TextStyle(color: appColors.textHint),
                  filled: true,
                  fillColor: appColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.textPrimary,
                    foregroundColor: appColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: appColors.background)
                      : Text(
                          AppLocalizations.of(context)!.loginButton,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: Divider(color: appColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      AppLocalizations.of(context)!.or,
                      style: TextStyle(color: appColors.textSecondary),
                    ),
                  ),
                  Expanded(child: Divider(color: appColors.divider)),
                ],
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _isLoading ? null : _handleAppleSignIn,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.loginWithApple,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isLoading ? null : _handleGoogleSignIn,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFF747775), width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.loginWithGoogle,
                        style: const TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterPage()),
                  );
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: appColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_outlined,
                          color: appColors.textSecondary, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.createNewAccount,
                        style: TextStyle(
                          color: appColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
