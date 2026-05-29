import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/pages/message/chat_detail_page.dart';
import 'package:threads/pages/message/message_list_tile.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadConversations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<MessageState>();
      if (state.hasMoreConversations && !state.isLoadingConversations) {
        state.loadMoreConversations();
      }
    }
  }

  Future<void> _onRefresh() async {
    final state = context.read<MessageState>();
    await state.loadConversations();
  }

  void _showNewMessageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 28, 28, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _NewMessageBottomSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.messages,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showNewMessageSheet,
            icon: Icon(
              Icons.edit_outlined,
              color: appColors.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: appColors.textPrimary,
          unselectedLabelColor: appColors.textSecondary,
          indicatorColor: appColors.textPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          tabs: [
            Tab(text: AppLocalizations.of(context)!.filterAll),
            Tab(text: AppLocalizations.of(context)!.requests),
          ],
        ),
      ),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildConversationList(state),
              _buildStrangerRequests(state),
            ],
          );
        },
      ),
    );
  }

  // ── All conversations tab ──

  Widget _buildConversationList(MessageState state) {
    if (state.isLoadingConversations && state.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.noConversations,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.black,
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8),
        itemCount: state.conversations.length +
            (state.hasMoreConversations ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 0.5,
          color: const Color.fromARGB(255, 46, 46, 46),
          indent: 78,
        ),
        itemBuilder: (context, index) {
          if (index == state.conversations.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }

          final conversation = state.conversations[index];
          return MessageListTile(
            conversation: conversation,
            onTap: () => _onConversationTap(conversation),
          );
        },
      ),
    );
  }

  // ── Stranger / Requests tab ──

  Widget _buildStrangerRequests(MessageState state) {
    // Filter conversations with type 2 (stranger) from the main list
    // The state currently loads all conversations, so we filter here.
    final strangerConversations = state.conversations
        .where((c) => c.conversationType == 2)
        .toList();

    if (strangerConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.noMessageRequests,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: strangerConversations.length,
      separatorBuilder: (_, __) => Divider(
        height: 0.5,
        color: const Color.fromARGB(255, 46, 46, 46),
        indent: 78,
      ),
      itemBuilder: (context, index) {
        final conversation = strangerConversations[index];
        return MessageListTile(
          conversation: conversation,
          onTap: () => _onConversationTap(conversation),
        );
      },
    );
  }

  void _onConversationTap(Conversation conversation) {
    Navigator.push(
      context,
      ChatDetailPage.getRoute(
        conversationId: conversation.id,
        peerUserId: conversation.peerUserId,
        peerUsername: conversation.peerUsername,
        peerDisplayName: conversation.peerDisplayName,
        peerAvatarUrl: conversation.peerAvatarUrl,
      ),
    );
  }
}

// ── New Message Bottom Sheet ──

class _NewMessageBottomSheet extends StatefulWidget {
  const _NewMessageBottomSheet();

  @override
  State<_NewMessageBottomSheet> createState() =>
      _NewMessageBottomSheetState();
}

class _NewMessageBottomSheetState extends State<_NewMessageBottomSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      if (_searchResults.isNotEmpty || _isSearching) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);
    final state = Provider.of<MessageState>(context, listen: false);
    final results = await state.searchChatUsers(keyword);
    if (!mounted) return;
    // Only update if the search text hasn't changed while we were waiting
    if (_searchController.text.trim() == keyword) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _onUserTapped(Map<String, dynamic> user) {
    final userId = user['user_id'] ?? user['userId'] ?? user['id'] ?? 0;
    final username = user['username'] ?? '';
    final displayName = user['display_name'] ?? user['displayName'] ?? '';
    final avatarUrl = user['avatar_url'] ?? user['avatarUrl'] as String?;

    // For a new conversation we don't have a conversationId yet.
    // Use a temporary negative ID — the ChatDetailPage will create
    // the conversation on the first sendMessage call via the API.
    Navigator.pop(context); // close the bottom sheet
    Navigator.push(
      context,
      ChatDetailPage.getRoute(
        conversationId: -userId, // temporary ID; server will assign real one
        peerUserId: userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
        peerUsername: username,
        peerDisplayName: displayName,
        peerAvatarUrl: avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.newMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              cursorColor: Colors.white,
              keyboardAppearance: Brightness.dark,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
                hintText: AppLocalizations.of(context)!.searchUsersHint,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Colors.transparent, width: 0.7),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Colors.transparent, width: 0.7),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                fillColor: const Color.fromARGB(255, 48, 48, 48),
                filled: true,
                contentPadding: const EdgeInsets.only(left: 15, top: 5),
              ),
            ),
          ),
          // Search results or placeholder
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.searchForUser,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.noResultsFound,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 0.5,
        color: const Color.fromARGB(255, 46, 46, 46),
        indent: 78,
      ),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final username = user['username'] ?? '';
    final displayName = user['display_name'] ?? user['displayName'] ?? '';
    final avatarUrl = user['avatar_url'] ?? user['avatarUrl'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final showName = displayName.isNotEmpty ? displayName : username;

    return InkWell(
      onTap: () => _onUserTapped(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            SizedBox(
              width: 50,
              height: 50,
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                        errorWidget: (_, __, ___) => _defaultAvatar(),
                      ),
                    )
                  : _defaultAvatar(),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayName.isNotEmpty && username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
}
