import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

class HiddenWordsPage extends StatefulWidget {
  const HiddenWordsPage({super.key});

  @override
  State<HiddenWordsPage> createState() => _HiddenWordsPageState();
}

class _HiddenWordsPageState extends State<HiddenWordsPage> {
  int _selectedType = 1; // 1=Keywords, 2=Phrases, 3=Emoji
  List<HiddenWord> _allWords = [];
  bool _isLoading = true;
  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(apiClient: getIt());
    _loadWords();
  }

  List<HiddenWord> get _filteredWords =>
      _allWords.where((w) => w.wordType == _selectedType).toList();

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final words = await _userService.getHiddenWords();
      if (mounted) {
        setState(() {
          _allWords = words;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteWord(HiddenWord word) async {
    try {
      await _userService.deleteHiddenWord(word.id);
      setState(() {
        _allWords.removeWhere((w) => w.id == word.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete word.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddDialog() {
    final contentController = TextEditingController();
    int selectedWordType = _selectedType;

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text(
                'Add Hidden Word',
                style: TextStyle(color: Colors.white),
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Word type selector
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: selectedWordType,
                        thumbColor: const Color(0xff333333),
                        backgroundColor: const Color(0xff1a1a1a),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        onValueChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedWordType = value);
                          }
                        },
                        children: {
                          1: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              'Keyword',
                              style: TextStyle(
                                color: selectedWordType == 1
                                    ? Colors.white
                                    : const Color(0xff888888),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          2: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              'Phrase',
                              style: TextStyle(
                                color: selectedWordType == 2
                                    ? Colors.white
                                    : const Color(0xff888888),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          3: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              'Emoji',
                              style: TextStyle(
                                color: selectedWordType == 3
                                    ? Colors.white
                                    : const Color(0xff888888),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: contentController,
                      placeholder: 'Enter word or phrase',
                      placeholderStyle: const TextStyle(color: Color(0xff888888)),
                      style: const TextStyle(color: Colors.white),
                      decoration: BoxDecoration(
                        color: const Color(0xff1a1a1a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isNotEmpty) {
                      Navigator.pop(dialogContext);
                      try {
                        await _userService.addHiddenWord(
                          wordType: selectedWordType,
                          content: content,
                        );
                        _loadWords();
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to add word.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredWords;

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
          'Hidden Words',
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
      body: Column(
        children: [
          // Segmented control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedType,
                thumbColor: const Color(0xff333333),
                backgroundColor: const Color(0xff1a1a1a),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onValueChanged: (value) {
                  if (value != null && value != _selectedType) {
                    setState(() => _selectedType = value);
                  }
                },
                children: {
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Keywords',
                      style: TextStyle(
                        color: _selectedType == 1 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Phrases',
                      style: TextStyle(
                        color: _selectedType == 2 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  3: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Emoji',
                      style: TextStyle(
                        color: _selectedType == 3 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
          const Divider(
            color: Color(0xff333333),
            height: 0.5,
            thickness: 0.5,
          ),
          // Word list
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No hidden words',
                          style: TextStyle(
                            color: const Color(0xff888888),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        backgroundColor: const Color(0xff222222),
                        color: Colors.white,
                        onRefresh: _loadWords,
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              color: Color(0xff333333),
                              height: 0.5,
                              thickness: 0.5,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final word = filtered[index];
                            return _buildWordTile(word);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordTile(HiddenWord word) {
    return Dismissible(
      key: ValueKey(word.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteWord(word),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(CupertinoIcons.delete, color: Colors.red, size: 24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Content display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (word.createTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        word.createTime!,
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
    );
  }
}
