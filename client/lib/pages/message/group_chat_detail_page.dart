import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/pages/message/chat_detail_page.dart';
import 'package:threads/pages/message/group_members_page.dart';
import 'package:threads/pages/message/join_requests_page.dart';
import 'package:threads/state/message.state.dart';

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
    final controller = TextEditingController(text: group.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 28, 28, 30),
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
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Group Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 50,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  counterStyle:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 22, 22, 22),
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
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
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
        const SnackBar(
          content: Text('No invite link available'),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 28, 28, 30),
        title: const Text(
          'Leave Group',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this group?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
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
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
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
            color: Colors.grey[800],
            child: Icon(Icons.group, size: 36, color: Colors.grey[600]),
          ),
          errorWidget: (context, url, error) => Container(
            width: 80,
            height: 80,
            color: Colors.grey[800],
            child: Icon(Icons.group, size: 36, color: Colors.grey[600]),
          ),
        ),
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.group, size: 36, color: Colors.grey[600]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Group Info',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          final group = state.currentGroupChat;
          if (group == null) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined,
                          size: 18, color: Colors.grey[500]),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${group.membersCount} members',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    if (group.createTime != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        'Created ${_formatDate(group.createTime)}',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 0.5,
                  color: const Color.fromARGB(255, 46, 46, 46),
                ),
                const SizedBox(height: 8),
                // Settings switches
                _buildSwitchTile(
                  title: 'Require Approval',
                  subtitle: 'New members need admin approval to join',
                  value: group.needApprove,
                  onChanged: (v) {
                    state.updateGroupChatSettings(
                      widget.groupId,
                      needApprove: v,
                    );
                  },
                ),
                _buildSwitchTile(
                  title: 'Invite Link',
                  subtitle: 'Allow joining via an invite link',
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
                  color: const Color.fromARGB(255, 46, 46, 46),
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
                        color: const Color.fromARGB(255, 46, 46, 46),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Leave Group',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.blue,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersPreview(MessageState state) {
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
            color: const Color.fromARGB(255, 46, 46, 46),
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
                  'Members (${members.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey[500]),
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
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          '+$remaining',
                          style: TextStyle(
                            color: Colors.grey[400],
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
    final avatarUrl = member.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[800],
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildActionButtons(GroupChat group) {
    return Column(
      children: [
        // Message button — navigate to group chat
        GestureDetector(
          onTap: () => _navigateToChat(group),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Message',
                  style: TextStyle(
                    color: Colors.white,
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
                  color: const Color.fromARGB(255, 46, 46, 46),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    'Copy Invite Link',
                    style: TextStyle(
                      color: Colors.grey[300],
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
                color: const Color.fromARGB(255, 46, 46, 46),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 18, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  'View All Members',
                  style: TextStyle(
                    color: Colors.grey[300],
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
                  color: const Color.fromARGB(255, 46, 46, 46),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    'Join Requests',
                    style: TextStyle(
                      color: Colors.grey[300],
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
