import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/pages/message/chat_detail_page.dart';
import 'package:threads/pages/message/group_members_page.dart';
import 'package:threads/pages/message/join_requests_page.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class GroupChatDetailPage extends StatefulWidget {
  final int groupId;

  const GroupChatDetailPage({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupChatDetailPage> createState() => _GroupChatDetailPageState();
}

class _GroupChatDetailPageState extends State<GroupChatDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadGroupChatDetail(widget.groupId);
      state.loadGroupMembers(widget.groupId);
    });
  }

  void _showEditNameSheet(GroupChat group) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = TextEditingController(text: group.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.editGroupName,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 50,
                style: TextStyle(color: appColors.textPrimary),
                cursorColor: appColors.textPrimary,
                decoration: InputDecoration(
                  counterStyle:
                      TextStyle(color: appColors.textMuted, fontSize: 12),
                  hintText: AppLocalizations.of(context)!.groupName,
                  hintStyle: TextStyle(color: appColors.textMuted),
                  filled: true,
                  fillColor: appColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty && newName != group.name) {
                      final state = Provider.of<MessageState>(
                        context,
                        listen: false,
                      );
                      state.updateGroupChat(
                        widget.groupId,
                        name: newName,
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.save,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyInviteLink(String? link) {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noInviteLink),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.linkCopiedToClipboard)),
    );
  }

  void _confirmLeaveGroup() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surfaceSecondary,
        title: Text(
          AppLocalizations.of(context)!.leaveGroup,
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Text(
          AppLocalizations.of(context)!.leaveGroupConfirm,
          style: TextStyle(color: appColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: appColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final state =
                  Provider.of<MessageState>(this.context, listen: false);
              await state.leaveGroupChat(widget.groupId);
              if (mounted) {
                Navigator.of(this.context).pop();
              }
            },
            child: Text(
              AppLocalizations.of(context)!.leave,
              style: TextStyle(color: appColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(GroupChat group) {
    Navigator.push(
      context,
      ChatDetailPage.getRoute(
        conversationId: group.id,
        isGroupChat: true,
        groupId: group.id,
        peerUsername: group.name,
        peerDisplayName: group.name,
        peerAvatarUrl: group.avatarUrl,
      ),
    );
  }

  Widget _buildGroupAvatar(GroupChat? group) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final avatarUrl = group?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 80,
            height: 80,
            color: appColors.surface,
            child: Icon(Icons.group, size: 36, color: appColors.textSecondary),
          ),
          errorWidget: (context, url, error) => Container(
            width: 80,
            height: 80,
            color: appColors.surface,
            child: Icon(Icons.group, size: 36, color: appColors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.group, size: 36, color: appColors.textSecondary),
    );
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
        AppLocalizations.of(context)!.groupInfo,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          final group = state.currentGroupChat;
          if (group == null) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: appColors.textSecondary,
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Avatar
                _buildGroupAvatar(group),
                const SizedBox(height: 16),
                // Name (tappable to edit)
                GestureDetector(
                  onTap: () => _showEditNameSheet(group),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined,
                          size: 18, color: appColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.memberCount(group.membersCount),
                      style: TextStyle(
                          color: appColors.textSecondary, fontSize: 14),
                    ),
                    if (group.createTime != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                            color: appColors.textSecondary, fontSize: 14),
                      ),
                      Text(
                        AppLocalizations.of(context)!.createdDate(_formatDate(group.createTime)),
                        style: TextStyle(
                            color: appColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 0.5,
                  color: appColors.divider,
                ),
                const SizedBox(height: 8),
                // Settings switches
                _buildSwitchTile(
                  title: AppLocalizations.of(context)!.requireApproval,
                  subtitle: AppLocalizations.of(context)!.requireApprovalDesc,
                  value: group.needApprove,
                  onChanged: (v) {
                    state.updateGroupChatSettings(
                      widget.groupId,
                      needApprove: v,
                    );
                  },
                ),
                _buildSwitchTile(
                  title: AppLocalizations.of(context)!.inviteLink,
                  subtitle: AppLocalizations.of(context)!.inviteLinkDesc,
                  value: group.inviteLinkEnabled,
                  onChanged: (v) {
                    state.updateGroupChatSettings(
                      widget.groupId,
                      inviteLinkEnabled: v,
                    );
                  },
                ),
                Container(
                  height: 0.5,
                  color: appColors.divider,
                ),
                const SizedBox(height: 16),
                // Members preview
                _buildMembersPreview(state),
                const SizedBox(height: 16),
                // Action buttons
                _buildActionButtons(group),
                const SizedBox(height: 16),
                // Leave group
                GestureDetector(
                  onTap: _confirmLeaveGroup,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: appColors.divider,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.leaveGroup,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appColors.destructive,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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

  Widget _buildMembersPreview(MessageState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final members = state.groupMembers;
    final displayMembers = members.take(6).toList();
    final remaining = members.length - displayMembers.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupMembersPage(groupId: widget.groupId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: appColors.divider,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.members} (${members.length})',
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: appColors.textMuted),
              ],
            ),
            if (displayMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      displayMembers.length + (remaining > 0 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == displayMembers.length) {
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: appColors.surface,
                        child: Text(
                          '+$remaining',
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    final member = displayMembers[index];
                    return _buildMemberAvatar(member);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(GroupMember member) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final avatarUrl = member.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: appColors.surface,
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: TextStyle(color: appColors.textPrimary, fontSize: 14),
      ),
    );
  }

  Widget _buildActionButtons(GroupChat group) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      children: [
        // Message button — navigate to group chat
        GestureDetector(
          onTap: () => _navigateToChat(group),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: appColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 18, color: appColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.messageBtn,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (group.inviteLinkEnabled)
          GestureDetector(
            onTap: () => _copyInviteLink(group.inviteLink),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: appColors.divider,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 18, color: appColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.copyInviteLink,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (group.inviteLinkEnabled) const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GroupMembersPage(groupId: widget.groupId),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: appColors.divider,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 18, color: appColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.viewAllMembers,
                  style: TextStyle(
                    color: appColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (group.needApprove)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      JoinRequestsPage(groupId: widget.groupId),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: appColors.divider,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 18, color: appColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.joinRequests,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime;
    }
  }
}
