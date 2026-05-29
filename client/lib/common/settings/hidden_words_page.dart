import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/theme/app_colors.dart';

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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    try {
      await _userService.deleteHiddenWord(word.id);
      setState(() {
        _allWords.removeWhere((w) => w.id == word.id);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedDeleteWord),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    }
  }

  void _showAddDialog() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final contentController = TextEditingController();
    int selectedWordType = _selectedType;

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(
                AppLocalizations.of(context)!.addHiddenWord,
                style: TextStyle(color: appColors.textPrimary),
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
                        thumbColor: appColors.divider,
                        backgroundColor: appColors.surface,
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
                              AppLocalizations.of(context)!.keyword,
                              style: TextStyle(
                                color: selectedWordType == 1
                                    ? appColors.textPrimary
                                    : appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          2: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              AppLocalizations.of(context)!.phrase,
                              style: TextStyle(
                                color: selectedWordType == 2
                                    ? appColors.textPrimary
                                    : appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          3: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              AppLocalizations.of(context)!.emoji,
                              style: TextStyle(
                                color: selectedWordType == 3
                                    ? appColors.textPrimary
                                    : appColors.textMuted,
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
                      placeholder: AppLocalizations.of(context)!.enterWordOrPhrase,
                      placeholderStyle: TextStyle(color: appColors.textMuted),
                      style: TextStyle(color: appColors.textPrimary),
                      decoration: BoxDecoration(
                        color: appColors.surface,
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
                  child: Text(AppLocalizations.of(context)!.cancel),
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
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.failedAddWord),
                              backgroundColor: appColors.destructive,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.add),
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final filtered = _filteredWords;

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
          l10n.hiddenWords,
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
      body: Column(
        children: [
          // Segmented control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedType,
                thumbColor: appColors.divider,
                backgroundColor: appColors.surface,
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
                      l10n.keywords,
                      style: TextStyle(
                        color: _selectedType == 1 ? appColors.textPrimary : appColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      l10n.phrases,
                      style: TextStyle(
                        color: _selectedType == 2 ? appColors.textPrimary : appColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  3: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      l10n.emoji,
                      style: TextStyle(
                        color: _selectedType == 3 ? appColors.textPrimary : appColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
          Divider(
            color: appColors.divider,
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
                          l10n.noHiddenWords,
                          style: TextStyle(
                            color: appColors.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        backgroundColor: appColors.surfaceSecondary,
                        color: appColors.textPrimary,
                        onRefresh: _loadWords,
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              color: appColors.divider,
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Dismissible(
      key: ValueKey(word.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteWord(word),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: appColors.destructive.withValues(alpha: 0.15),
        child: Icon(CupertinoIcons.delete, color: appColors.destructive, size: 24),
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
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (word.createTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        word.createTime!,
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
    );
  }
}
