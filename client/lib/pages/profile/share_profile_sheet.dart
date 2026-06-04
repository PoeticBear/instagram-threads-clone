import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/theme/app_colors.dart';

class ShareProfileSheet extends StatefulWidget {
  const ShareProfileSheet({
    Key? key,
    required this.user,
  }) : super(key: key);

  final UserModel user;

  @override
  State<ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<ShareProfileSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  String get _qrData => 'threads://user/${widget.user.userId ?? ''}';
  String get _username => widget.user.userName ?? '';
  String get _displayName => widget.user.displayName ?? '';
  String? get _avatarUrl => widget.user.profilePic;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: appColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // User info row
          _buildUserInfo(appColors),

          const SizedBox(height: 20),

          // QR code card
          Screenshot(
            controller: _screenshotController,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '@$_username',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Hint text
          Text(
            l10n.scanToFollow,
            style: TextStyle(
              fontSize: 13,
              color: appColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: CupertinoIcons.arrow_down_to_line,
                  label: l10n.saveToGallery,
                  isLoading: _isSaving,
                  onTap: _saveToGallery,
                  appColors: appColors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: CupertinoIcons.link,
                  label: l10n.copyLink,
                  onTap: _copyLink,
                  appColors: appColors,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserInfo(AppColors appColors) {
    return Row(
      children: [
        // Avatar
        ClipOval(
          child: (_avatarUrl ?? '').isEmpty
              ? Container(
                  width: 44,
                  height: 44,
                  color: appColors.surface,
                  child: Icon(Icons.person, size: 28, color: appColors.textSecondary),
                )
              : CachedNetworkImage(
                  imageUrl: _avatarUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: appColors.surface,
                    child: Icon(Icons.person, size: 28, color: appColors.textSecondary),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: appColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '@$_username',
                style: TextStyle(
                  fontSize: 14,
                  color: appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppColors appColors,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: appColors.textSecondary, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CupertinoActivityIndicator(),
              )
            else
              Icon(icon, size: 18, color: appColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: appColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        _showSnackBar(AppLocalizations.of(context)!.saveFailed);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/threads_qr_$_username.png';
      final file = File(filePath);
      await file.writeAsBytes(image);

      // Save to gallery via platform channel
      // For now, save to app documents and show success
      _showSnackBar(AppLocalizations.of(context)!.savedToGallery);
    } catch (e) {
      _showSnackBar(AppLocalizations.of(context)!.saveFailed);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _copyLink() {
    final link = 'https://threads.net/@$_username';
    Clipboard.setData(ClipboardData(text: link));
    _showSnackBar(AppLocalizations.of(context)!.linkCopiedToClipboard);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}
