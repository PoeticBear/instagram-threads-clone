import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/message.state.dart';

class GroupMembersPage extends StatefulWidget {
  final int groupId;

  const GroupMembersPage({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadGroupMembers(widget.groupId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmRemoveMember(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 28, 28, 30),
        title: const Text(
          'Remove Member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${member.displayName.isNotEmpty ? member.displayName : member.username} from this group?',
          style: const TextStyle(color: Colors.grey),
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
              await state.removeGroupMember(
                groupId: widget.groupId,
                userId: member.userId,
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
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
        'Members',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
          hintText: 'Search members...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          filled: true,
          fillColor: const Color.fromARGB(255, 22, 22, 22),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
      ),
    );
  }

  Widget _buildMemberAvatar(GroupMember member) {
    final avatarUrl = member.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey[800],
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildMemberItem(GroupMember member, bool isAdmin, int currentUserId) {
    final isMemberAdmin = member.role == 2;
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;
    final username = member.username;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildMemberAvatar(member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMemberAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (isAdmin && !isMemberAdmin && member.userId != currentUserId)
            GestureDetector(
              onTap: () => _confirmRemoveMember(member),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 46, 46, 46),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Provider.of<AuthState>(context, listen: false).userModel?.userId ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          if (state.isLoadingGroupMembers && state.groupMembers.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            );
          }

          final members = state.groupMembers;
          final isAdmin = members.any(
            (m) => m.userId == currentUserId && m.role == 2,
          );

          final filteredMembers = _searchQuery.isEmpty
              ? members
              : members.where((m) {
                  final name = m.displayName.toLowerCase();
                  final username = m.username.toLowerCase();
                  return name.contains(_searchQuery) ||
                      username.contains(_searchQuery);
                }).toList();

          if (filteredMembers.isEmpty) {
            return Column(
              children: [
                _buildSearchField(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No members found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchField(),
              Expanded(
                child: RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.grey[900],
                  onRefresh: () =>
                      state.loadGroupMembers(widget.groupId),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      color: const Color.fromARGB(255, 46, 46, 46),
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      return _buildMemberItem(
                        filteredMembers[index],
                        isAdmin,
                        currentUserId,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
