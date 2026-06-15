import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/post.state.dart';

class EditHistorySheet extends StatefulWidget {
  final String postId;

  const EditHistorySheet({required this.postId, super.key});

  @override
  State<EditHistorySheet> createState() => _EditHistorySheetState();
}

class _EditHistorySheetState extends State<EditHistorySheet> {
  List<EditHistory> _editHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEditHistory();
  }

  Future<void> _loadEditHistory() async {
    try {
      final postService =
          Provider.of<PostState>(context, listen: false).postService;
      final history = await postService.getEditHistory(widget.postId);
      if (mounted) {
        setState(() {
          _editHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHistoryItem(EditHistory entry) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 编辑前
          if (entry.oldContent.isNotEmpty) ...[
            Text(
              entry.oldContent,
              style: TextStyle(
                color: appColors.textHint,
                fontSize: 13,
                decoration: TextDecoration.lineThrough,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
          ],
          // 编辑后
          Text(
            entry.newContent,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // 第 N 次编辑（API edit_count）
              Text(
                '#${entry.editCount}',
                style: TextStyle(
                  color: appColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Text(
                Utility.getdob(entry.editedAt.toIso8601String(), context: context),
                style: TextStyle(
                  color: appColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Top drag handle
          Container(
            margin: EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title row with close button
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.editHistory,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: appColors.textPrimary, size: 22),
                ),
              ],
            ),
          ),
          Divider(
            color: appColors.divider,
            height: 0.5,
          ),
          // History list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appColors.textSecondary,
                    ),
                  )
                : _editHistory.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noPostsYet,
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: appColors.textPrimary,
                        backgroundColor: appColors.surface,
                        onRefresh: _loadEditHistory,
                        child: ListView.separated(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: _editHistory.length,
                          separatorBuilder: (context, index) => Divider(
                            color: appColors.divider,
                            height: 0.5,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) =>
                              _buildHistoryItem(_editHistory[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
