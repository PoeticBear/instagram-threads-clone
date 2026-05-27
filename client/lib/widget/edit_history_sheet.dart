import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.content,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            Utility.getdob(entry.editedAt.toIso8601String()),
            style: TextStyle(
              color: Color.fromARGB(255, 78, 78, 78),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
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
              color: Colors.grey[600],
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          Divider(
            color: Color.fromARGB(255, 46, 46, 46),
            height: 0.5,
          ),
          // History list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[600],
                    ),
                  )
                : _editHistory.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noPostsYet,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.grey[900],
                        onRefresh: _loadEditHistory,
                        child: ListView.separated(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: _editHistory.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Color.fromARGB(255, 46, 46, 46),
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
