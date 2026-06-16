import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/app_icon_state.dart';
import 'package:threads/theme/app_colors.dart';

/// 应用图标选择页（iOS 25 预打包 alternate；Android 显示不支持提示）。
class AppIconPage extends StatelessWidget {
  const AppIconPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        title: Text(
          l10n.appIcon,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<AppIconState>(
        builder: (context, state, _) {
          if (!state.isLoaded) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (!state.platformSupported) {
            return _UnsupportedView(message: l10n.appIconNotSupportedAndroid);
          }
          return _IconGrid(state: state, hint: l10n.appIconChangeHint);
        },
      ),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  final String message;
  const _UnsupportedView({required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: appColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  final AppIconState state;
  final String hint;
  const _IconGrid({required this.state, required this.hint});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final total = AppIconState.totalAlternates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: total,
            itemBuilder: (context, index) {
              final id = index + 1; // 1..25
              return _IconTile(
                id: id,
                selected: state.selectedId == id,
                appColors: appColors,
                onTap: () => state.setIcon(id),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: appColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final int id;
  final bool selected;
  final AppColors appColors;
  final VoidCallback onTap;
  const _IconTile({
    required this.id,
    required this.selected,
    required this.appColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/logos/logo_${id.toString().padLeft(2, '0')}.JPG',
                      fit: BoxFit.cover,
                      // 容错：素材若被移除，回退到一个浅色块
                      errorBuilder: (_, __, ___) => Container(
                        color: appColors.divider,
                        alignment: Alignment.center,
                        child: Text(
                          id.toString(),
                          style: TextStyle(color: appColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: appColors.accent,
                          width: 3,
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: appColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.check_mark,
                          color: appColors.background,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            id.toString(),
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
