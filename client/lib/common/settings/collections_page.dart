import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/theme/app_colors.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<SaveCollection> _collections = [];
  bool _isLoading = true;
  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(apiClient: getIt());
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      final collections = await _userService.getCollections();
      if (mounted) {
        setState(() {
          _collections = collections;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createCollection(String name) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    try {
      final newCollection = await _userService.createCollection(name);
      setState(() {
        _collections.add(newCollection);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create collection.'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _deleteCollection(SaveCollection collection) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    try {
      await _userService.deleteCollection(collection.id);
      setState(() {
        _collections.removeWhere((c) => c.id == collection.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete collection.'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  void _showCreateDialog() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'New Collection',
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Collection name',
            placeholderStyle: TextStyle(color: appColors.textMuted),
            style: TextStyle(color: appColors.textPrimary),
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                _createCollection(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SaveCollection collection) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'Delete "${collection.name}"?',
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
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteCollection(collection);
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
          'Collections',
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: appColors.textPrimary, size: 26),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _collections.isEmpty
              ? Center(
                  child: Text(
                    'No collections yet',
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: appColors.surfaceSecondary,
                  color: appColors.textPrimary,
                  onRefresh: _loadCollections,
                  child: ListView.separated(
                    itemCount: _collections.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: appColors.divider,
                        height: 0.5,
                        thickness: 0.5,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final collection = _collections[index];
                      return _buildCollectionTile(collection);
                    },
                  ),
                ),
    );
  }

  Widget _buildCollectionTile(SaveCollection collection) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Dismissible(
      key: ValueKey(collection.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmDelete(collection);
        return false; // We handle deletion in the dialog callback
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appColors.destructive.withValues(alpha: 0.15),
        child: Icon(CupertinoIcons.delete, color: appColors.destructive, size: 24),
      ),
      child: GestureDetector(
        onLongPress: () => _confirmDelete(collection),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.folder,
                  color: appColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            collection.name,
                            style: TextStyle(
                              color: appColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (collection.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: appColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: appColors.dividerSecondary),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                color: appColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${collection.saveCount} saved',
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    if (collection.createTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          collection.createTime!,
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
