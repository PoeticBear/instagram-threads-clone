import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/model/message.module.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? peerAvatarUrl;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.peerAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.7;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Quote message indicator
            if (message.quoteMessageId != null)
              Container(
                margin: EdgeInsets.only(
                  left: isMe ? 0 : 8,
                  right: isMe ? 8 : 0,
                  bottom: 4,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 50, 50, 50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Quoted message',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            // Message bubble
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: _bubblePadding,
              decoration: BoxDecoration(
                color: _bubbleColor,
                borderRadius: _borderRadius,
              ),
              child: _buildContent(context),
            ),
            // Reactions
            if (message.reactions.isNotEmpty)
              _buildReactions(context),
          ],
        ),
      ),
    );
  }

  EdgeInsets get _bubblePadding {
    if (message.mediaType == 1) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.all(12);
  }

  Color get _bubbleColor {
    if (isMe) return Colors.blue[700]!;
    return Colors.grey[800]!;
  }

  BorderRadius get _borderRadius {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe
          ? const Radius.circular(16)
          : const Radius.circular(4),
      bottomRight: isMe
          ? const Radius.circular(4)
          : const Radius.circular(16),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Main content
        _buildMediaContent(),
        // Timestamp and status row
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.createTime),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              _buildDeliveryStatus(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMediaContent() {
    switch (message.mediaType) {
      case 1:
        // Image message
        if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[700],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[700],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case 2:
        // Video message
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.videocam, color: Colors.white70, size: 20),
            SizedBox(width: 6),
            Text(
              'Video message',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        );
      case 3:
        // Voice message
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.mic, color: Colors.white70, size: 20),
            SizedBox(width: 6),
            Text(
              'Voice message',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        );
      case 4:
        // File message
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insert_drive_file, color: Colors.white70, size: 20),
            SizedBox(width: 6),
            Text(
              'File',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        );
      default:
        // Text message (mediaType == 0)
        return Text(
          message.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        );
    }
  }

  Widget _buildDeliveryStatus() {
    if (!isMe) return const SizedBox.shrink();

    switch (message.deliveryStatus) {
      case 1:
        // Sending
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.grey[500],
          ),
        );
      case 2:
        // Sent
        return Icon(Icons.check, size: 14, color: Colors.grey[500]);
      case 3:
        // Read
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: Colors.blue[300]),
            Transform.translate(
              offset: const Offset(-6, 0),
              child:
                  Icon(Icons.check, size: 12, color: Colors.blue[300]),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReactions(BuildContext context) {
    // Group reactions by emoji and count them
    final Map<String, int> emojiCounts = {};
    for (final reaction in message.reactions) {
      emojiCounts[reaction.emoji] =
          (emojiCounts[reaction.emoji] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 38, 38, 38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 60, 60, 60),
          width: 0.5,
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: emojiCounts.entries.map((entry) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 14)),
              if (entry.value > 1) ...[
                const SizedBox(width: 2),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}
