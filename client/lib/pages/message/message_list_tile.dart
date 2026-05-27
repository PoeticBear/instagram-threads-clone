import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/model/message.module.dart';

class MessageListTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;

  const MessageListTile({
    super.key,
    required this.conversation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (conversation.peerAvatarUrl ?? '').isNotEmpty;
    final displayName = conversation.peerDisplayName.isNotEmpty
        ? conversation.peerDisplayName
        : conversation.peerUsername;
    final lastMessage = conversation.lastMessageContent ?? '';
    final unreadCount = conversation.unreadCount;
    final isPinned = conversation.isPinned;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(hasAvatar),
            const SizedBox(width: 12),
            // Middle: name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPinned) ...[
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                    style: TextStyle(
                      color: lastMessage.isNotEmpty
                          ? Colors.grey
                          : Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right: time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageTime != null)
                  Text(
                    _formatTime(conversation.lastMessageTime!),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 4),
                if (unreadCount > 0) _buildUnreadBadge(unreadCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool hasAvatar) {
    return SizedBox(
      width: 50,
      height: 50,
      child: hasAvatar
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: conversation.peerAvatarUrl!,
                fit: BoxFit.cover,
                width: 50,
                height: 50,
                errorWidget: (_, __, ___) => _defaultAvatar(),
              ),
            )
          : _defaultAvatar(),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 28, color: Colors.grey[600]),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
