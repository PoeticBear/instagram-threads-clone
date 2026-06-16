import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/media_preferences.state.dart';
import 'package:threads/state/media_layout_preferences.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 媒体播放偏好（纯本地，不同步至服务端）
class MediaSettingsPage extends StatelessWidget {
  const MediaSettingsPage({super.key});

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
          l10n.mediaSettings,
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: Consumer2<MediaPreferences, MediaLayoutPreferences>(
        builder: (context, mediaPrefs, layoutPrefs, _) {
          return ListView(
            children: [
              _buildLayoutSegmentedRow(
                context: context,
                title: l10n.feedMediaLayoutMode,
                subtitle: l10n.feedMediaLayoutModeDesc,
                value: layoutPrefs.feedMediaLayoutMode,
                onChanged: (v) => layoutPrefs.setFeedMediaLayoutMode(v),
              ),
              _buildToggleRow(
                context: context,
                title: l10n.feedVideoAutoPlay,
                subtitle: l10n.feedVideoAutoPlayDesc,
                value: mediaPrefs.isFeedVideoAutoPlayEnabled,
                onChanged: (v) => mediaPrefs.setFeedVideoAutoPlay(v ? 1 : 0),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToggleRow({
    required BuildContext context,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: appColors.textPrimary,
            inactiveTrackColor: appColors.dividerSecondary,
            thumbColor: value ? appColors.background : appColors.textPrimary,
          ),
        ],
      ),
    );
  }

  /// 分段控件行：标题 + 可选副标题 + 全宽 iOS 风格 segmented control。
  /// [value] 为 0/1；[onChanged] 把新值回传给 state。
  Widget _buildLayoutSegmentedRow({
    required BuildContext context,
    required String title,
    String? subtitle,
    required int value, // 0 = grid, 1 = horizontal
    required ValueChanged<int> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: appColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: value,
              onValueChanged: (v) {
                if (v != null) onChanged(v);
              },
              backgroundColor: appColors.surface,
              thumbColor: appColors.background,
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Text(
                    l10n.feedMediaLayoutGrid,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Text(
                    l10n.feedMediaLayoutHorizontal,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
