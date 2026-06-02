import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/pages/message/chat_detail_page.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class MessageSearchPage extends StatefulWidget {
  const MessageSearchPage({super.key});

  @override
  State<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends State<MessageSearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() => _hasSearched = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _hasSearched = true);
      final state = Provider.of<MessageState>(context, listen: false);
      state.searchMessages(keyword);
    });
  }

  void _onMessageTapped(ChatMessage message) {
    // Use receiverId as conversationId for 1-on-1 chats.
    // If the message came from a search result the receiverId maps
    // to the conversation; otherwise the API will have returned
    // enough context to navigate.
    Navigator.push(
      context,
      ChatDetailPage.getRoute(
        conversationId: message.receiverId,
        peerUserId: message.senderId,
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
      if (diff.inMinutes < 60) {
        return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
      }
      if (diff.inHours < 24) {
        return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
      }
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    } catch (_) {
      return '';
    }
  }

  Widget _buildSenderAvatar(ChatMessage message) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    // The search result ChatMessage does not carry an avatar URL directly,
    // so we show a generic avatar based on senderId.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 22, color: appColors.textSecondary),
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
        AppLocalizations.of(context)!.searchMessages,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSearchField() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        cursorColor: appColors.textPrimary,
        style: TextStyle(color: appColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20, color: appColors.textMuted),
          hintText: AppLocalizations.of(context)!.searchMessagesHint,
          hintStyle: TextStyle(color: appColors.textMuted, fontSize: 15),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: appColors.textMuted),
          const SizedBox(height: 12),
          Text(
            _hasSearched
                ? AppLocalizations.of(context)!.noResultsFound
                : AppLocalizations.of(context)!.searchMessagesHint,
            style: TextStyle(
              color: appColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(ChatMessage message) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final timeText = _formatTime(message.createTime);
    final contentPreview = message.content.length > 80
        ? '${message.content.substring(0, 80)}...'
        : message.content;

    return InkWell(
      onTap: () => _onMessageTapped(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSenderAvatar(message),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context)!.userFallback} ${message.senderId}',
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: TextStyle(
                            color: appColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contentPreview,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          Container(
            height: 0.5,
            color: appColors.divider,
            margin: const EdgeInsets.only(top: 4),
          ),
          Expanded(
            child: Consumer<MessageState>(
              builder: (context, state, _) {
                if (state.isSearching) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appColors.textSecondary,
                    ),
                  );
                }

                if (state.searchResults.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: state.searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0.5,
                    color: appColors.divider,
                    indent: 72,
                  ),
                  itemBuilder: (context, index) {
                    return _buildResultItem(state.searchResults[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
