import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/theme/app_colors.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({super.key});

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  List<UserLink> _links = [];
  bool _isLoading = true;
  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(apiClient: getIt());
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await _userService.getLinks();
      if (mounted) {
        setState(() {
          _links = links;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteLink(UserLink link) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    try {
      await _userService.deleteLink(link.id);
      setState(() {
        _links.removeWhere((l) => l.id == link.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete link.'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    _showLinkDialog(
      title: 'Add Link',
      titleController: titleController,
      urlController: urlController,
      onConfirm: () async {
        final title = titleController.text.trim();
        final url = urlController.text.trim();
        if (title.isNotEmpty && url.isNotEmpty) {
          Navigator.pop(context);
          try {
            await _userService.addLink(title: title, url: url);
            _loadLinks();
          } catch (_) {
            if (mounted) {
              final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to add link.'),
                  backgroundColor: appColors.destructive,
                ),
              );
            }
          }
        }
      },
    );
  }

  void _showEditDialog(UserLink link) {
    final titleController = TextEditingController(text: link.title);
    final urlController = TextEditingController(text: link.url);
    _showLinkDialog(
      title: 'Edit Link',
      titleController: titleController,
      urlController: urlController,
      onConfirm: () async {
        final newTitle = titleController.text.trim();
        final newUrl = urlController.text.trim();
        if (newTitle.isNotEmpty && newUrl.isNotEmpty) {
          Navigator.pop(context);
          try {
            await _userService.updateLink(
              link.id,
              title: newTitle,
              url: newUrl,
            );
            _loadLinks();
          } catch (_) {
            if (mounted) {
              final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to update link.'),
                  backgroundColor: appColors.destructive,
                ),
              );
            }
          }
        }
      },
    );
  }

  void _showLinkDialog({
    required String title,
    required TextEditingController titleController,
    required TextEditingController urlController,
    required VoidCallback onConfirm,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: titleController,
                placeholder: 'Title',
                placeholderStyle: TextStyle(color: appColors.textMuted),
                style: TextStyle(color: appColors.textPrimary),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: urlController,
                placeholder: 'URL',
                placeholderStyle: TextStyle(color: appColors.textMuted),
                style: TextStyle(color: appColors.textPrimary),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: onConfirm,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(UserLink link) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'Delete "${link.title}"?',
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'This action cannot be undone.',
            style: TextStyle(color: appColors.textMuted),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteLink(link);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: appColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Links',
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: appColors.textPrimary, size: 26),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _links.isEmpty
              ? Center(
                  child: Text(
                    'No links yet',
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: appColors.surfaceSecondary,
                  color: appColors.textPrimary,
                  onRefresh: _loadLinks,
                  child: ListView.separated(
                    itemCount: _links.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: appColors.divider,
                        height: 0.5,
                        thickness: 0.5,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final link = _links[index];
                      return _buildLinkTile(link);
                    },
                  ),
                ),
    );
  }

  Widget _buildLinkTile(UserLink link) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Dismissible(
      key: ValueKey(link.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmDelete(link);
        return false; // Handled in dialog callback
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appColors.destructive.withValues(alpha: 0.15),
        child: Icon(CupertinoIcons.delete, color: appColors.destructive, size: 24),
      ),
      child: GestureDetector(
        onTap: () => _showEditDialog(link),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Link icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.link,
                  color: appColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.url,
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (link.createTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          link.createTime!,
                          style: TextStyle(
                            color: appColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                color: appColors.dividerSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
