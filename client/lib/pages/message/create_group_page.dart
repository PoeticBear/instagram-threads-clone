import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _needApprove = false;
  bool _inviteLinkEnabled = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
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
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedCreateGroup),
            backgroundColor: appColors.destructive,
          ),
        );
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
    return Consumer<MessageState>(
      builder: (context, state, _) {
        final appColors =
            Theme.of(context).extension<AppColorsExtension>()!.colors;
        final selectedUsers = state.recommendUsers;
        if (selectedUsers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 40, color: appColors.surface),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.searchSelectUsers,
                    style: TextStyle(color: appColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: selectedUsers.length,
            itemBuilder: (context, index) {
              final user = selectedUsers[index];
              final avatarUrl = user['avatarUrl'] as String? ??
                  user['avatar_url'] as String?;
              final displayName = user['displayName'] as String? ??
                  user['display_name'] as String? ??
                  user['username'] as String? ??
                  AppLocalizations.of(context)!.userFallback;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: appColors.surface,
                      backgroundImage: (avatarUrl != null &&
                              avatarUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              displayName[0].toUpperCase(),
                              style: TextStyle(
                                color: appColors.textPrimary,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
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
