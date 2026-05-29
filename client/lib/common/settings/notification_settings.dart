import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/settings.state.dart';
import 'package:threads/theme/app_colors.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

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
          l10n.notificationSettings,
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: Consumer<SettingsState>(
        builder: (context, state, _) {
          if (state.isBusy) {
            return const Center(
              child: CupertinoActivityIndicator(),
            );
          }
          final s = state.settings;
          return ListView(
            children: [
              _buildToggleRow(
                context: context,
                title: l10n.notifyLikes,
                value: s.notifyLikes == 1,
                onChanged: (v) => state.updateSetting('notify_likes', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyReplies,
                value: s.notifyReplies == 1,
                onChanged: (v) => state.updateSetting('notify_replies', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyMentions,
                value: s.notifyMentions == 1,
                onChanged: (v) => state.updateSetting('notify_mentions', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyFollows,
                value: s.notifyFollows == 1,
                onChanged: (v) => state.updateSetting('notify_follows', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyTrending,
                value: s.notifyTrending == 1,
                onChanged: (v) => state.updateSetting('notify_trending', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifySystem,
                value: s.notifySystem == 1,
                onChanged: (v) => state.updateSetting('notify_system', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyGroupMessages,
                value: s.notifyGroupMessages == 1,
                onChanged: (v) => state.updateSetting('notify_group_messages', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyQuotes,
                value: s.notifyQuotes == 1,
                onChanged: (v) => state.updateSetting('notify_quotes', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyReposts,
                value: s.notifyReposts == 1,
                onChanged: (v) => state.updateSetting('notify_reposts', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyPolls,
                value: s.notifyPolls == 1,
                onChanged: (v) => state.updateSetting('notify_polls', v ? 1 : 0),
              ),
              _buildDivider(context),
              _buildToggleRow(
                context: context,
                title: l10n.notifyCommunities,
                value: s.notifyCommunities == 1,
                onChanged: (v) => state.updateSetting('notify_communities', v ? 1 : 0),
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
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
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

  Widget _buildDivider(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: appColors.divider,
        height: 0.5,
        thickness: 0.5,
      ),
    );
  }
}
