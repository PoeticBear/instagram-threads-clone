import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/message.module.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appColors.surfaceSecondary,
        title: Text(
          AppLocalizations.of(context)!.removeMember,
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Text(
          AppLocalizations.of(context)!.removeMemberConfirm(member.displayName.isNotEmpty ? member.displayName : member.username),
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
              await state.removeGroupMember(
                groupId: widget.groupId,
                userId: member.userId,
              );
            },
            child: Text(
              AppLocalizations.of(context)!.remove,
              style: TextStyle(color: appColors.destructive),
            ),
          ),
        ],
      ),
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
        AppLocalizations.of(context)!.members,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: appColors.textPrimary),
        cursorColor: appColors.textPrimary,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20, color: appColors.textMuted),
          hintText: AppLocalizations.of(context)!.searchMembers,
          hintStyle: TextStyle(color: appColors.textMuted),
          filled: true,
          fillColor: appColors.surface,
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final avatarUrl = member.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: appColors.surface,
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: TextStyle(color: appColors.textPrimary, fontSize: 16),
      ),
    );
  }

  Widget _buildMemberItem(GroupMember member, bool isAdmin, int currentUserId) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
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
                        style: TextStyle(
                          color: appColors.textPrimary,
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
                          color: appColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.admin,
                          style: TextStyle(
                            color: appColors.accent,
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
                      color: appColors.textMuted,
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
                    color: appColors.divider,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.remove,
                  style: TextStyle(
                    color: appColors.destructive,
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final currentUserId =
        Provider.of<AuthState>(context, listen: false).userModel?.userId ?? 0;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          if (state.isLoadingGroupMembers && state.groupMembers.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: appColors.textSecondary,
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
                            size: 48, color: appColors.surface),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? AppLocalizations.of(context)!.noMembersFound
                              : AppLocalizations.of(context)!.noResultsFor(_searchQuery),
                          style: TextStyle(
                            color: appColors.textMuted,
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
                  color: appColors.textPrimary,
                  backgroundColor: appColors.surface,
                  onRefresh: () =>
                      state.loadGroupMembers(widget.groupId),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      color: appColors.divider,
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
