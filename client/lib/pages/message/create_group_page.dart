import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/theme/app_colors.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Set<int> _selectedUserIds = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _needApprove = false;
  bool _inviteLinkEnabled = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadRecommendUsers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterGroupName),
          backgroundColor: appColors.destructive,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final state = Provider.of<MessageState>(context, listen: false);
    try {
      await state.createGroupChat(
        name,
        memberIds: _selectedUserIds.toList(),
        needApprove: _needApprove,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.showApiError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
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
        AppLocalizations.of(context)!.createGroup,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAvatarSection() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Center(
      child: GestureDetector(
        onTap: () {
          // TODO: Implement avatar picker
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: appColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.camera_alt_outlined,
            size: 32,
            color: appColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.groupName,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          maxLength: 50,
          style: TextStyle(color: appColors.textPrimary, fontSize: 16),
          cursorColor: appColors.textPrimary,
          decoration: InputDecoration(
            counterStyle: TextStyle(color: appColors.textMuted, fontSize: 12),
            hintText: AppLocalizations.of(context)!.enterGroupNamePlaceholder,
            hintStyle: TextStyle(color: appColors.textMuted),
            filled: true,
            fillColor: appColors.surface,
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
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
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
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: appColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: appColors.accent,
            activeThumbColor: appColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUsers() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected users chips
        if (_selectedUserIds.isNotEmpty) ...[
          Consumer<MessageState>(
            builder: (context, state, _) {
              final allUsers = [...state.recommendUsers, ..._searchResults];
              final selectedUsers = allUsers.where((u) {
                final id = u['user_id'] ?? u['userId'] ?? u['id'] ?? 0;
                return _selectedUserIds.contains(id is int ? id : int.tryParse(id.toString()) ?? 0);
              }).toList();
              return SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final user = selectedUsers[index];
                    final displayName = user['display_name'] ?? user['displayName'] ?? user['username'] ?? '';
                    final avatarUrl = user['avatar_url'] ?? user['avatarUrl'] as String?;
                    final userId = user['user_id'] ?? user['userId'] ?? user['id'] ?? 0;
                    final intUid = userId is int ? userId : int.tryParse(userId.toString()) ?? 0;
                    return Chip(
                      avatar: CircleAvatar(
                        radius: 14,
                        backgroundColor: appColors.surface,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: TextStyle(color: appColors.textPrimary, fontSize: 12))
                            : null,
                      ),
                      label: Text(displayName, style: TextStyle(color: appColors.textPrimary, fontSize: 13)),
                      backgroundColor: appColors.surface,
                      deleteIconColor: appColors.textSecondary,
                      onDeleted: () {
                        setState(() => _selectedUserIds.remove(intUid));
                      },
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        // Search field
        TextField(
          controller: _searchController,
          cursorColor: appColors.textPrimary,
          style: TextStyle(color: appColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20, color: appColors.textMuted),
            hintText: AppLocalizations.of(context)!.searchUsersHint,
            hintStyle: TextStyle(color: appColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: appColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 8),
        // Search results
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
          )
        else if (_searchResults.isNotEmpty)
          ..._searchResults.map((user) => _buildSearchResultTile(user)),
      ],
    );
  }

  Future<void> _onSearchChanged(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final state = Provider.of<MessageState>(context, listen: false);
    final results = await state.searchChatUsers(keyword);
    if (!mounted) return;
    if (_searchController.text.trim() == keyword) {
      setState(() { _searchResults = results; _isSearching = false; });
    }
  }

  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final userId = user['user_id'] ?? user['userId'] ?? user['id'] ?? 0;
    final intUid = userId is int ? userId : int.tryParse(userId.toString()) ?? 0;
    final username = user['username'] ?? '';
    final displayName = user['display_name'] ?? user['displayName'] ?? username;
    final avatarUrl = user['avatar_url'] ?? user['avatarUrl'] as String?;
    final isSelected = _selectedUserIds.contains(intUid);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: appColors.surface,
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(color: appColors.textPrimary, fontSize: 14))
            : null,
      ),
      title: Text(displayName, style: TextStyle(color: appColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: username.isNotEmpty ? Text('@$username', style: TextStyle(color: appColors.textMuted, fontSize: 12)) : null,
      trailing: Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedUserIds.add(intUid);
            } else {
              _selectedUserIds.remove(intUid);
            }
          });
        },
        activeColor: appColors.accent,
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedUserIds.remove(intUid);
          } else {
            _selectedUserIds.add(intUid);
          }
        });
      },
    );
  }

  Widget _buildCreateButton() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createGroup,
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors.accent,
          disabledBackgroundColor: appColors.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isCreating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: appColors.textPrimary,
                ),
              )
            : Text(
                AppLocalizations.of(context)!.create,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildAvatarSection(),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 16),
            Container(
              height: 0.5,
              color: appColors.divider,
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: AppLocalizations.of(context)!.requireApproval,
              subtitle: AppLocalizations.of(context)!.requireApprovalDesc,
              value: _needApprove,
              onChanged: (v) => setState(() => _needApprove = v),
            ),
            _buildSwitchTile(
              title: AppLocalizations.of(context)!.inviteLink,
              subtitle: AppLocalizations.of(context)!.inviteLinkDesc,
              value: _inviteLinkEnabled,
              onChanged: (v) => setState(() => _inviteLinkEnabled = v),
            ),
            Container(
              height: 0.5,
              color: appColors.divider,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.members,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildSelectedUsers(),
            const SizedBox(height: 24),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }
}
