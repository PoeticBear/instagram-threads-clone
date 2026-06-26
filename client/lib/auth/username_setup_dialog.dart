import 'package:flutter/material.dart';

import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/network/api_exception.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 登录后若服务端 username 为空，强制弹出此对话框补填。
///
/// username 是应用内的唯一身份标识、一旦设定不可修改，因此弹窗：
/// - 不可关闭（PopScope.canPop = false + barrierDismissible = false）；
/// - 带醒目「不可修改」提示；
/// - 仅当校验通过并成功写入服务端后才关闭。
class UsernameSetupDialog extends StatefulWidget {
  final AuthState authState;

  const UsernameSetupDialog({Key? key, required this.authState}) : super(key: key);

  /// 便捷入口：在「进入应用」的出口处，判定 needsUsernameSetup 为真后调用。
  /// 返回 true 表示用户已完成补填（弹窗正常关闭）。
  static Future<bool> show(BuildContext context, AuthState authState) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsernameSetupDialog(authState: authState),
    ).then((v) => v ?? false);
  }

  @override
  State<UsernameSetupDialog> createState() => _UsernameSetupDialogState();
}

class _UsernameSetupDialogState extends State<UsernameSetupDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final value = _controller.text.trim();

    if (value.isEmpty) {
      setState(() => _error = l10n.usernameSetupEmptyError);
      return;
    }
    if (value.length < 2) {
      setState(() => _error = l10n.usernameSetupTooShortError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.authState.setUsername(value);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.usernameSetupFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: appColors.background,
        title: Text(
          l10n.usernameSetupTitle,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 醒目「不可修改」提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: appColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: appColors.border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: appColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.usernameSetupWarning,
                      style: TextStyle(color: appColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: appColors.textPrimary),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.username,
                hintStyle: TextStyle(color: appColors.textHint),
                filled: true,
                fillColor: appColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                errorText: _error,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.textPrimary,
                foregroundColor: appColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appColors.background,
                      ),
                    )
                  : Text(
                      l10n.confirmButton,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
