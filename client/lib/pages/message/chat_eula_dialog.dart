import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

/// 当前聊天使用协议版本。
/// 协议改版时 bump 这个常量，所有老用户会被强制重新同意。
const String kCurrentChatEulaVersion = '2026-07-21';

const String _kKeyAgreed = 'chat_eula_agreed';
const String _kKeyVersion = 'chat_eula_version';

/// 聊天使用协议「同意状态」的本地持久化与版本判断。
///
/// 零额外依赖：复用 GetIt 注入的 `SharedPreferences`（见 `common/locator.dart`）。
/// 将来若新增其它聊天入口（Profile 发私信、深链 / 推送直达），复用本类即可收敛拦截。
class ChatEulaConsent {
  static SharedPreferences _prefs() => getIt<SharedPreferences>();

  /// 是否需要展示协议弹窗：从未同意，或已同意的版本与当前版本不一致。
  static bool get needsAgreement {
    final agreed = _prefs().getBool(_kKeyAgreed) ?? false;
    if (!agreed) return true;
    final agreedVersion = _prefs().getString(_kKeyVersion) ?? '';
    return agreedVersion != kCurrentChatEulaVersion;
  }

  /// 记录「同意当前版本」。MUST NOT 在用户点「不同意」时调用。
  static void markAgreed() {
    _prefs().setBool(_kKeyAgreed, true);
    _prefs().setString(_kKeyVersion, kCurrentChatEulaVersion);
  }
}

/// 聊天使用协议同意弹窗（底部 sheet 形态）。
///
/// 通过 `showModalBottomSheet<bool>` 展示：
/// - 「同意并继续」→ `Navigator.pop(context, true)`
/// - 「不同意」→ `Navigator.pop(context, false)`
///
/// 调用方应设 `isDismissible: false` + `enableDrag: false`，使用户只能二选一；
/// sheet 被关闭（返回 null）时调用方按 false 处理（退回 Feed、不落库）。
///
/// 协议全文以国际化文案内置渲染（见 `AppLocalizations.chatEula*`），不依赖外链，
/// 离线可读、不被「专属 EULA URL 待法务提供」阻塞。
class ChatEulaDialog extends StatelessWidget {
  const ChatEulaDialog({super.key});

  Widget _section(AppColors colors, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final dividerColor = colors.divider;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chatEulaTitle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.chatEulaLastUpdated,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: dividerColor, height: 1),
              // 滚动正文（条款全文）
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chatEulaIntro,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _section(colors, l10n.chatEulaSection1Title, l10n.chatEulaSection1Body),
                      _section(colors, l10n.chatEulaSection2Title, l10n.chatEulaSection2Body),
                      _section(colors, l10n.chatEulaSection3Title, l10n.chatEulaSection3Body),
                      _section(colors, l10n.chatEulaSection4Title, l10n.chatEulaSection4Body),
                      _section(colors, l10n.chatEulaSection5Title, l10n.chatEulaSection5Body),
                      _section(colors, l10n.chatEulaSection6Title, l10n.chatEulaSection6Body),
                    ],
                  ),
                ),
              ),
              Divider(color: dividerColor, height: 1),
              // 底部按钮：主操作「同意并继续」全宽 + 次操作「不同意」
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.chatEulaAgree,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(l10n.chatEulaDisagree),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
