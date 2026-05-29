import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

import 'chat_bubble.dart';
import 'group_chat_detail_page.dart';
import 'reaction_picker.dart';

class ChatDetailPage extends StatefulWidget {
  final int conversationId;
  final int? peerUserId;
  final String? peerUsername;
  final String? peerDisplayName;
  final String? peerAvatarUrl;
  final bool isGroupChat;
  final int? groupId;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.peerUserId,
    this.peerUsername,
    this.peerDisplayName,
    this.peerAvatarUrl,
    this.isGroupChat = false,
    this.groupId,
  });

  static PageRouteBuilder getRoute({
    required int conversationId,
    int? peerUserId,
    String? peerUsername,
    String? peerDisplayName,
    String? peerAvatarUrl,
    bool isGroupChat = false,
    int? groupId,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChatDetailPage(
          conversationId: conversationId,
          peerUserId: peerUserId,
          peerUsername: peerUsername,
          peerDisplayName: peerDisplayName,
          peerAvatarUrl: peerAvatarUrl,
          isGroupChat: isGroupChat,
          groupId: groupId,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final state = Provider.of<MessageState>(context, listen: false);
    await state.loadMessages(widget.conversationId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      final state = Provider.of<MessageState>(context, listen: false);
      if (state.hasMoreMessages && !state.isLoadingMessages) {
        state.loadMoreMessages();
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    _inputController.clear();

    final state = Provider.of<MessageState>(context, listen: false);
    await state.sendMessage(
      receiverId: _getPeerUserId(),
      content: content,
    );
  }

  int _getPeerUserId() {
    // Use explicitly passed peerUserId if available
    if (widget.peerUserId != null && widget.peerUserId != 0) {
      return widget.peerUserId!;
    }
    // For group chats, use groupId as receiver
    if (widget.isGroupChat && widget.groupId != null) {
      return widget.groupId!;
    }
    // Try to find the peer user ID from the current messages
    final state = Provider.of<MessageState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    final currentUserId = authState.userModel?.userId ?? 0;

    for (final msg in state.currentMessages) {
      if (msg.senderId != currentUserId && msg.senderId != 0) {
        return msg.senderId;
      }
    }
    // Fallback: look at receiverId in messages where sender is current user
    for (final msg in state.currentMessages) {
      if (msg.senderId == currentUserId && msg.receiverId != 0) {
        return msg.receiverId;
      }
    }
    return 0;
  }

  int? _getCurrentUserId() {
    final authState = Provider.of<AuthState>(context, listen: false);
    return authState.userModel?.userId;
  }

  void _showReactionPicker(int messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReactionPicker(
          messageId: messageId,
          onReactionSelected: (emoji) {
            final state =
                Provider.of<MessageState>(context, listen: false);
            state.addReaction(messageId, emoji);
          },
        );
      },
    );
  }

  Widget _buildPeerAvatar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (widget.peerAvatarUrl != null &&
        widget.peerAvatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CachedNetworkImage(
          imageUrl: widget.peerAvatarUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 32,
            height: 32,
            color: appColors.surface,
            child: Icon(Icons.person, size: 18, color: appColors.textSecondary),
          ),
          errorWidget: (context, url, error) => Container(
            width: 32,
            height: 32,
            color: appColors.surface,
            child: Icon(Icons.person, size: 18, color: appColors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 18, color: appColors.textSecondary),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final displayName = widget.isGroupChat
        ? (widget.peerDisplayName ?? widget.peerUsername ?? AppLocalizations.of(context)!.groupChat)
        : (widget.peerDisplayName?.isNotEmpty == true
            ? widget.peerDisplayName!
            : widget.peerUsername ?? '');

    return AppBar(
      backgroundColor: appColors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: appColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeerAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              displayName,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (widget.isGroupChat && widget.groupId != null)
          IconButton(
            icon: Icon(Icons.info_outline, color: appColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatDetailPage(
                    groupId: widget.groupId!,
                  ),
                ),
              );
            },
          )
        else
          IconButton(
            icon: Icon(Icons.more_horiz, color: appColors.textPrimary),
            onPressed: () {
              // TODO: Show conversation options
            },
          ),
      ],
    );
  }

  Widget _buildMessageItem(ChatMessage message, int currentUserId) {
    final isMe = message.senderId == currentUserId;

    return GestureDetector(
      onLongPress: () => _showReactionPicker(message.id),
      child: ChatBubble(
        message: message,
        isMe: isMe,
        peerAvatarUrl: widget.peerAvatarUrl,
      ),
    );
  }

  Widget _buildMessageList(int currentUserId) {
    return Consumer<MessageState>(
      builder: (context, state, _) {
        final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
        if (state.isLoadingMessages && state.currentMessages.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appColors.textSecondary,
            ),
          );
        }

        if (state.currentMessages.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noMessagesYet,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: appColors.textPrimary,
          backgroundColor: appColors.surface,
          onRefresh: () => state.loadMessages(widget.conversationId),
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.currentMessages.length +
                (state.isLoadingMessages ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.currentMessages.length) {
                // Loading indicator at the top (loading more)
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return _buildMessageItem(
                state.currentMessages[index],
                currentUserId,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      color: appColors.background,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              style: TextStyle(color: appColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.messagePlaceholder,
                hintStyle: TextStyle(color: appColors.textMuted),
                filled: true,
                fillColor: appColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: _inputController,
            builder: (context, _) {
              final hasText = _inputController.text.trim().isNotEmpty;
              return SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: hasText ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    size: 20,
                    color: hasText ? appColors.accent : appColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: hasText
                        ? appColors.surfaceTertiary
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final currentUserId = _getCurrentUserId() ?? 0;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(currentUserId)),
          Container(
            height: 0.5,
            color: appColors.divider,
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}
