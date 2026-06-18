import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/message.state.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/theme/app_colors.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final TextEditingController _inviteLinkController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _inviteLinkController.dispose();
    super.dispose();
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
        AppLocalizations.of(context)!.joinGroupByLink,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildInviteLinkField() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _inviteLinkController,
          style: TextStyle(color: appColors.textPrimary, fontSize: 16),
          cursorColor: appColors.textPrimary,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterInviteLink,
            hintStyle: TextStyle(color: appColors.textMuted),
            filled: true,
            fillColor: appColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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

  Widget _buildJoinButton() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isJoining ? null : _onJoinPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors.accent,
          disabledBackgroundColor: appColors.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isJoining
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: appColors.textPrimary,
                ),
              )
            : Text(
                AppLocalizations.of(context)!.join,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _onJoinPressed() async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    final inviteLink = _inviteLinkController.text.trim();
    if (inviteLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterInviteLink),
          backgroundColor: appColors.destructive,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);

    final state = Provider.of<MessageState>(context, listen: false);
    try {
      await state.joinGroupChat(inviteLink: inviteLink);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.joined),
            backgroundColor: appColors.repost,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.showApiError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
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
            const SizedBox(height: 24),
            _buildInviteLinkField(),
            const SizedBox(height: 24),
            _buildJoinButton(),
          ],
        ),
      ),
    );
  }
}
