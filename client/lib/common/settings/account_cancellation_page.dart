import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/auth/signup/name.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 账号注销页（依据 feature-account-cancellation.md）。
/// 流程：注销须知展示 → 勾选「我已阅读并同意」门禁 → 「确认注销」→ 二次确认 alert
///      → 全屏「正在处理注销…」loading → AuthState.deleteAccount()
///      → 成功根路由自动回登录页 / 失败提示并保留登录态可重试。
class AccountCancellationPage extends StatefulWidget {
  const AccountCancellationPage({super.key});

  @override
  State<AccountCancellationPage> createState() =>
      _AccountCancellationPageState();
}

class _AccountCancellationPageState extends State<AccountCancellationPage> {
  bool _isAgreed = false;
  bool _isCancelling = false;

  /// 最终确认后的执行：调 AuthState.deleteAccount（POST /user/deactivate）。
  /// 成功 → AuthState flip 为 NOT_LOGGED_IN，根路由自动切回登录页，本页随之销毁。
  /// 失败 → 关闭 loading、提示 deleteAccountFailed，保留登录态可重试。
  Future<void> _performCancellation() async {
    setState(() => _isCancelling = true);
    final authState = Provider.of<AuthState>(context, listen: false);
    try {
      await authState.deleteAccount();
      // deleteAccount 仅清本地登录态（authStatus → NOT_LOGGED_IN）。SplashPage 虽会随之
      // 把 body 切成 NamePage，但本注销页叠在路由栈顶层，必须显式清栈才能回到登录页
      //（与 401 被动登出 forceSessionExpired 的导航方式一致）。
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NamePage()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.deleteAccountFailed)),
      );
    }
  }

  /// 二次确认 alert：勾选 + 点击「确认注销」后弹出，最终确认才执行。
  void _showConfirmAlert() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancellationConfirm),
        content: Text(l10n.cancellationConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // 关 alert
              _performCancellation(); // 切 loading + 执行
            },
            child: Text(l10n.cancellationConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: appColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.deleteAccount,
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      // 注销进行中：整页切换为 loading 视图，阻止重复操作。
      body: _isCancelling ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    const warnColor = Color(0xFFFF9500); // iOS system orange
    final notices = [
      l10n.cancellationNotice1,
      l10n.cancellationNotice2,
      l10n.cancellationNotice3,
      l10n.cancellationNotice4,
      l10n.cancellationNotice5,
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        const SizedBox(height: 16),
        const Icon(CupertinoIcons.exclamationmark_triangle_fill,
            color: warnColor, size: 56),
        const SizedBox(height: 20),
        Text(
          l10n.accountCancellationNoticeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        ...notices.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: warnColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      n,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
        // 「我已阅读并同意上述条款」勾选（门禁：未勾选则「确认注销」禁用）
        GestureDetector(
          onTap: () => setState(() => _isAgreed = !_isAgreed),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _isAgreed ? warnColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isAgreed ? warnColor : appColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: _isAgreed
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.cancellationAgree,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        // 「确认注销」：未勾选禁用
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isAgreed ? _showConfirmAlert : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              l10n.cancellationConfirm,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 「取消」：返回设置页
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(height: 16),
          Text(
            l10n.cancellationLoading,
            style: TextStyle(color: appColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
