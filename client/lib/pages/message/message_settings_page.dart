import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class MessageSettingsPage extends StatefulWidget {
  const MessageSettingsPage({super.key});

  @override
  State<MessageSettingsPage> createState() => _MessageSettingsPageState();
}

class _MessageSettingsPageState extends State<MessageSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadMessageSettings();
    });
  }

  void _onRequestEnabledChanged(bool value) {
    final state = Provider.of<MessageState>(context, listen: false);
    final current = state.messageSettings;
    final updated = MessageSettings(
      messageRequestEnabled: value ? 1 : 0,
      messageRequestAllowType: current.messageRequestAllowType,
    );
    state.updateMessageSettings(updated);
  }

  void _onAllowTypeChanged(int allowType) {
    final state = Provider.of<MessageState>(context, listen: false);
    final current = state.messageSettings;
    final updated = MessageSettings(
      messageRequestEnabled: current.messageRequestEnabled,
      messageRequestAllowType: allowType,
    );
    state.updateMessageSettings(updated);
  }

  PreferredSizeWidget _buildAppBar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return AppBar(
      backgroundColor: appColors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: appColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        AppLocalizations.of(context)!.messageSettings,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: appColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: appColors.accent,
            activeThumbColor: appColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required int value,
    required int groupValue,
    required ValueChanged<int?> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Radio<int>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: appColors.accent,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return appColors.accent;
                  }
                  return appColors.textMuted;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          final settings = state.messageSettings;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Message requests enabled switch ──
                _buildSwitchTile(
                  title: l10n.messageRequestsEnabled,
                  subtitle: l10n.messageRequestsEnabledDesc,
                  value: settings.messageRequestEnabled == 1,
                  onChanged: _onRequestEnabledChanged,
                ),
                Container(
                  height: 0.5,
                  color: appColors.divider,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                ),

                // ── Who can send message requests ──
                Text(
                  l10n.whoCanSendMessage,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  title: l10n.onlyFollowedUsers,
                  value: 1,
                  groupValue: settings.messageRequestAllowType,
                  onChanged: (v) => _onAllowTypeChanged(v ?? 1),
                ),
                _buildRadioOption(
                  title: l10n.anyone,
                  value: 2,
                  groupValue: settings.messageRequestAllowType,
                  onChanged: (v) => _onAllowTypeChanged(v ?? 2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
