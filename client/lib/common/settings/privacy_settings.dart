import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/settings.state.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.privacySettings,
          style: const TextStyle(
            color: Colors.white,
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
              // -- Reply permission --
              _sectionHeader(l10n.whoCanReplyToYou),
              _buildSelectorRow(
                context: context,
                title: l10n.replyEveryone,
                isSelected: s.replyAllowType == 1,
                onTap: () => state.updateSetting('reply_allow_type', 1),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.replyFollowers,
                isSelected: s.replyAllowType == 2,
                onTap: () => state.updateSetting('reply_allow_type', 2),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.replyPagesYouFollow,
                isSelected: s.replyAllowType == 3,
                onTap: () => state.updateSetting('reply_allow_type', 3),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.replyMentioned,
                isSelected: s.replyAllowType == 4,
                onTap: () => state.updateSetting('reply_allow_type', 4),
              ),

              _buildSectionDivider(),

              // -- Mention permission --
              _sectionHeader(l10n.whoCanMentionYou),
              _buildSelectorRow(
                context: context,
                title: l10n.mentionEveryone,
                isSelected: s.mentionAllowType == 1,
                onTap: () => state.updateSetting('mention_allow_type', 1),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.mentionUsersYouFollow,
                isSelected: s.mentionAllowType == 2,
                onTap: () => state.updateSetting('mention_allow_type', 2),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.mentionMutuals,
                isSelected: s.mentionAllowType == 3,
                onTap: () => state.updateSetting('mention_allow_type', 3),
              ),

              _buildSectionDivider(),

              // -- Message requests --
              _buildToggleRow(
                context: context,
                title: l10n.messageRequests,
                value: s.messageRequestEnabled == 1,
                onChanged: (v) =>
                    state.updateSetting('message_request_enabled', v ? 1 : 0),
              ),
              _buildDivider(),
              _sectionHeader(l10n.messageRequestAllowType),
              _buildSelectorRow(
                context: context,
                title: l10n.msgReqAnyone,
                isSelected: s.messageRequestAllowType == 2,
                onTap: () =>
                    state.updateSetting('message_request_allow_type', 2),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.msgReqFollowedOnly,
                isSelected: s.messageRequestAllowType == 1,
                onTap: () =>
                    state.updateSetting('message_request_allow_type', 1),
              ),

              _buildSectionDivider(),

              // -- Interaction restriction --
              _sectionHeader(l10n.interactionRestriction),
              _buildSelectorRow(
                context: context,
                title: l10n.restrictionNone,
                isSelected: s.interactionRestrictionType == 1,
                onTap: () =>
                    state.updateSetting('interaction_restriction_type', 1),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.restrictionFollowedOneWeek,
                isSelected: s.interactionRestrictionType == 2,
                onTap: () =>
                    state.updateSetting('interaction_restriction_type', 2),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.restrictionMutualsOnly,
                isSelected: s.interactionRestrictionType == 3,
                onTap: () =>
                    state.updateSetting('interaction_restriction_type', 3),
              ),

              _buildSectionDivider(),

              // -- Display toggles --
              _buildToggleRow(
                context: context,
                title: l10n.showReadReceipts,
                value: s.showReadReceipts == 1,
                onChanged: (v) =>
                    state.updateSetting('show_read_receipts', v ? 1 : 0),
              ),
              _buildDivider(),
              _buildToggleRow(
                context: context,
                title: l10n.showOnlineStatus,
                value: s.showOnlineStatus == 1,
                onChanged: (v) =>
                    state.updateSetting('show_online_status', v ? 1 : 0),
              ),
              _buildDivider(),
              _buildToggleRow(
                context: context,
                title: l10n.allowRecommend,
                value: s.allowRecommend == 1,
                onChanged: (v) =>
                    state.updateSetting('allow_recommend', v ? 1 : 0),
              ),
              _buildDivider(),
              _buildToggleRow(
                context: context,
                title: l10n.hideLikesCount,
                value: s.hideLikesCount == 1,
                onChanged: (v) =>
                    state.updateSetting('hide_likes_count', v ? 1 : 0),
              ),
              _buildDivider(),
              _buildToggleRow(
                context: context,
                title: l10n.silentMode,
                value: s.silentMode == 1,
                onChanged: (v) =>
                    state.updateSetting('silent_mode', v ? 1 : 0),
              ),
              _buildDivider(),

              // -- Content rating --
              _sectionHeader(l10n.contentRating),
              _buildSelectorRow(
                context: context,
                title: l10n.ratingAll,
                isSelected: s.contentRating == 1,
                onTap: () => state.updateSetting('content_rating', 1),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.ratingTeen,
                isSelected: s.contentRating == 2,
                onTap: () => state.updateSetting('content_rating', 2),
              ),
              _buildSelectorRow(
                context: context,
                title: l10n.ratingAdult,
                isSelected: s.contentRating == 3,
                onTap: () => state.updateSetting('content_rating', 3),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelectorRow({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required BuildContext context,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.white,
            inactiveTrackColor: const Color(0xff444444),
            thumbColor: value ? Colors.black : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: Color(0xff333333),
        height: 0.5,
        thickness: 0.5,
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          height: 0.5,
          color: const Color(0xff444444),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
