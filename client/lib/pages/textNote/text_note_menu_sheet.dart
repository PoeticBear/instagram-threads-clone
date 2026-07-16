import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 写文字 — "+" 按钮 Popup 菜单
// ─────────────────────────────────────────────────────────────────────────────
//
// 底部 Tab 中心 "+" 按钮点击后弹出此菜单。
// 菜单从下往上滑出，列出「写文字」「普通图文」两个入口。
// 点击后通过 Navigator.pop(context, mode) 返回 TextNoteMenuMode 枚举。
//
// 用法（home.dart）：
// ```dart
// final mode = await showModalBottomSheet<TextNoteMenuMode>(
//   context: context,
//   backgroundColor: Colors.transparent,
//   builder: (_) => const TextNoteMenuSheet(),
// );
// if (mode == TextNoteMenuMode.textNote) {
//   Navigator.push(... TextNotePage());
// } else if (mode == TextNoteMenuMode.normalPost) {
//   setState(() => tab = 2);  // 进入 ComposePost
// }
// ```
// ─────────────────────────────────────────────────────────────────────────────

/// Popup 菜单返回值枚举。
enum TextNoteMenuMode {
  /// 「写文字」入口
  textNote,

  /// 「普通图文」入口（走现有 ComposePost）
  normalPost,
}

class TextNoteMenuSheet extends StatelessWidget {
  const TextNoteMenuSheet({Key? key}) : super(key: key);

  static const double _itemHeight = 56;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: appColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: appColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 「写文字」入口
            _MenuItem(
              icon: Iconsax.document_text,
              label: l10n.writeText,
              onTap: () => Navigator.pop(context, TextNoteMenuMode.textNote),
              appColors: appColors,
            ),

            const Divider(height: 1),

            // 「普通图文」入口
            _MenuItem(
              icon: Iconsax.gallery,
              label: l10n.normalPost,
              onTap: () => Navigator.pop(context, TextNoteMenuMode.normalPost),
              appColors: appColors,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.appColors,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColors appColors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: TextNoteMenuSheet._itemHeight,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, size: 22, color: appColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: appColors.textMuted,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}