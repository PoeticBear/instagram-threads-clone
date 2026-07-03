import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google OAuth SDK 初始化封装。
///
/// google_sign_in 7.x 要求 [GoogleSignIn.instance.initialize] 在 app 生命周期内
/// 恰好调用一次，且其 future 完成后才能调 [GoogleSignIn.authenticate]。
/// 这里用静态 flag 保证幂等，失败不抛异常（不阻塞 app 启动）。
///
/// ⚠️ 为什么用「Dart 显式传 clientId」而非 Info.plist 的 GIDClientID：
/// google_sign_in_ios 6.x 插件构建 GIDConfiguration 时，clientID 来源优先级是
///   Dart runtime 参数 > bundle 里 GoogleService-Info.plist 的 CLIENT_ID
/// 且【不读】Info.plist 的 GIDClientID（见 FLTGoogleSignInPlugin.m
/// configurationWithClientIdentifier:）。
///
/// 本项目 assets/db/ 下存在一个原作者遗留的 GoogleService-Info.plist
/// （BUNDLE_ID=com.antoine-gonthier.threads，已登记进 Resources 会打进 bundle）。
/// 若不传 runtime clientId，插件会误用那个文件的 CLIENT_ID → 后端验签失败。
/// 所以这里必须显式传 clientId + serverClientId 把它盖掉。
class GoogleOAuth {
  /// iOS OAuth 客户端 ID（从 GoogleService-Info.plist 的 CLIENT_ID 抠出）。
  static const String iosClientId =
      '818599281759-s267l2ou3maiaa2vj9vr19d77bap3jec.apps.googleusercontent.com';

  /// Web OAuth 客户端 ID —— 后端校验 idToken 的 audience，必须用 Web 的、不是 iOS 的。
  static const String webClientId =
      '818599281759-g2selrt12levi6nme9v2gpkd4t76adoq.apps.googleusercontent.com';

  static bool _initialized = false;

  /// 幂等初始化 GoogleSignIn。应在 app 启动时（main.dart）调用一次。
  /// 同时传 clientId(iOS) + serverClientId(Web)，runtime 优先级最高，
  /// 盖过 bundle 里那个不应存在的 GoogleService-Info.plist。
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      _initialized = true;
      debugPrint('[GoogleOAuth] initialize 成功');
    } catch (e) {
      debugPrint('[GoogleOAuth] initialize 失败: $e');
    }
  }

  /// 是否已完成初始化（Google 登录可用的前置条件）。
  static bool get isInitialized => _initialized;
}
