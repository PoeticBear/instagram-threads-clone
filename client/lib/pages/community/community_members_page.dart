import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/community.module.dart';
import 'package:threads/state/community.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';

class CommunityMembersPage extends StatefulWidget {
  final int communityId;

  const CommunityMembersPage({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  static PageRouteBuilder getRoute({
    required int communityId,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return CommunityMembersPage(
          communityId: communityId,
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
  State<CommunityMembersPage> createState() => _CommunityMembersPageState();
}

class _CommunityMembersPageState extends State<CommunityMembersPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<CommunityState>(context, listen: false);
      state.loadMembers(widget.communityId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<CommunityState>();
      if (state.hasMoreMembers && !state.isLoadingMembers) {
        state.loadMoreMembers(widget.communityId);
      }
    }
  }

  Future<void> _onRefresh() async {
    final state = context.read<CommunityState>();
    await state.loadMembers(widget.communityId);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        title: Text(
          AppLocalizations.of(context)!.members,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildSearchField(appColors),
          Expanded(
            child: Consumer<CommunityState>(
              builder: (context, state, _) {
                if (state.isLoadingMembers && state.members.isEmpty) {
                  return const Center(
                    child: CupertinoActivityIndicator(),
                  );
                }

                final members = state.members;
                final filteredMembers = _searchQuery.isEmpty
                    ? members
                    : members.where((m) {
                        final name = m.displayName.toLowerCase();
                        final username = m.username.toLowerCase();
                        return name.contains(_searchQuery) ||
                            username.contains(_searchQuery);
                      }).toList();

                if (filteredMembers.isEmpty) {
                  return Center(
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
                  );
                }

                return RefreshIndicator(
                  color: appColors.textPrimary,
                  backgroundColor: appColors.background,
                  onRefresh: _onRefresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount:
                        filteredMembers.length + (state.hasMoreMembers ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      color: appColors.divider,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      if (index == filteredMembers.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CupertinoActivityIndicator()),
                        );
                      }
                      return _buildMemberItem(filteredMembers[index], appColors);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppColors appColors) {
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

  Widget _buildMemberItem(CommunityMember member, AppColors appColors) {
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;
    final isAdmin = member.role == 2;

    return GestureDetector(
      onLongPress: () => _showMemberOptions(member),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildMemberAvatar(member, appColors),
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
                      if (isAdmin) ...[
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
                  if (member.username.isNotEmpty)
                    Text(
                      '@${member.username}',
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            // Champion star icon
            if (member.isChampion)
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(CommunityMember member, AppColors appColors) {
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(member.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: appColors.divider,
      child: Text(
        (member.displayName.isNotEmpty
                ? member.displayName
                : member.username)[0]
            .toUpperCase(),
        style: TextStyle(color: appColors.textPrimary, fontSize: 16),
      ),
    );
  }

  // ==================== Member Options (Champion) ====================

  void _showMemberOptions(CommunityMember member) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Member name header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(
                  color: appColors.divider, height: 0.5),
              // Set / Remove champion
              if (member.isChampion)
                ListTile(
                  leading: const Icon(Icons.star_outline,
                      color: Colors.amber),
                  title: Text(
                    AppLocalizations.of(context)!.removeChampion,
                    style: TextStyle(color: appColors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final state =
                        Provider.of<CommunityState>(this.context,
                            listen: false);
                    state.removeChampion(
                        widget.communityId, member.userId);
                  },
                )
              else
                ListTile(
                  leading:
                      const Icon(Icons.star, color: Colors.amber),
                  title: Text(
                    AppLocalizations.of(context)!.setChampion,
                    style: TextStyle(color: appColors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final state =
                        Provider.of<CommunityState>(this.context,
                            listen: false);
                    state.setChampion(
                        widget.communityId, member.userId);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
