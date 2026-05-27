import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

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
    try {
      await _userService.deleteLink(link.id);
      setState(() {
        _links.removeWhere((l) => l.id == link.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete link.'),
            backgroundColor: Colors.red,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add link.'),
                  backgroundColor: Colors.red,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to update link.'),
                  backgroundColor: Colors.red,
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
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: titleController,
                placeholder: 'Title',
                placeholderStyle: const TextStyle(color: Color(0xff888888)),
                style: const TextStyle(color: Colors.white),
                decoration: BoxDecoration(
                  color: const Color(0xff1a1a1a),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: urlController,
                placeholder: 'URL',
                placeholderStyle: const TextStyle(color: Color(0xff888888)),
                style: const TextStyle(color: Colors.white),
                decoration: BoxDecoration(
                  color: const Color(0xff1a1a1a),
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
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'Delete "${link.title}"?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'This action cannot be undone.',
            style: TextStyle(color: Color(0xff888888)),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Links',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 26),
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
                      color: const Color(0xff888888),
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: const Color(0xff222222),
                  color: Colors.white,
                  onRefresh: _loadLinks,
                  child: ListView.separated(
                    itemCount: _links.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: Color(0xff333333),
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
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(CupertinoIcons.delete, color: Colors.red, size: 24),
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
                  color: const Color(0xff1a1a1a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.link,
                  color: Color(0xff888888),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.url,
                      style: const TextStyle(
                        color: Color(0xff888888),
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
                          style: const TextStyle(
                            color: Color(0xff555555),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: Color(0xff444444),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
