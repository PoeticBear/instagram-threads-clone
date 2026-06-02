import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class HiddenConversationsPage extends StatefulWidget {
  const HiddenConversationsPage({super.key});

  @override
  State<HiddenConversationsPage> createState() =>
      _HiddenConversationsPageState();
}

class _HiddenConversationsPageState extends State<HiddenConversationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadHiddenConversations();
    });
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
        AppLocalizations.of(context)!.hiddenConversations,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAvatar(String? avatarUrl, String fallbackInitial) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: appColors.surface,
      child: Text(
        fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : '?',
        style: TextStyle(color: appColors.textPrimary, fontSize: 18),
      ),
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final displayName = conversation.peerDisplayName.isNotEmpty
        ? conversation.peerDisplayName
        : conversation.peerUsername;
    final lastMessage = conversation.lastMessageContent ?? '';

    return ListTile(
      leading: _buildAvatar(conversation.peerAvatarUrl, displayName),
      title: Text(
        displayName,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: lastMessage.isNotEmpty
          ? Text(
              lastMessage,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
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
          final conversations = state.hiddenConversations;

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 48,
                    color: appColors.surface,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.noHiddenConversations,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: appColors.textPrimary,
            backgroundColor: appColors.surface,
            onRefresh: () => state.loadHiddenConversations(),
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: appColors.divider,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                return _buildConversationItem(conversations[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
