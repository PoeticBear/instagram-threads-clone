import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

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
    try {
      final newCollection = await _userService.createCollection(name);
      setState(() {
        _collections.add(newCollection);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create collection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCollection(SaveCollection collection) async {
    try {
      await _userService.deleteCollection(collection.id);
      setState(() {
        _collections.removeWhere((c) => c.id == collection.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete collection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text(
          'New Collection',
          style: TextStyle(color: Colors.white),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Collection name',
            placeholderStyle: const TextStyle(color: Color(0xff888888)),
            style: const TextStyle(color: Colors.white),
            decoration: BoxDecoration(
              color: const Color(0xff1a1a1a),
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
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'Delete "${collection.name}"?',
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
          'Collections',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 26),
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
                      color: const Color(0xff888888),
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  backgroundColor: const Color(0xff222222),
                  color: Colors.white,
                  onRefresh: _loadCollections,
                  child: ListView.separated(
                    itemCount: _collections.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        color: Color(0xff333333),
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
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(CupertinoIcons.delete, color: Colors.red, size: 24),
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
                  color: const Color(0xff1a1a1a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.folder,
                  color: Color(0xff888888),
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
                            style: const TextStyle(
                              color: Colors.white,
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
                              color: const Color(0xff1a1a1a),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xff444444)),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xff888888),
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
                      style: const TextStyle(
                        color: Color(0xff888888),
                        fontSize: 13,
                      ),
                    ),
                    if (collection.createTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          collection.createTime!,
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
