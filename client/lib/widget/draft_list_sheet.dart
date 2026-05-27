import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/draft.module.dart';
import '../state/draft.state.dart';

class DraftListSheet extends StatelessWidget {
  final Function(DraftInfo) onDraftSelected;

  const DraftListSheet({super.key, required this.onDraftSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Drafts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Draft list
          Consumer<DraftState>(
            builder: (context, state, _) {
              if (state.isLoading) {
                return Expanded(child: Center(child: CupertinoActivityIndicator()));
              }
              if (state.drafts.isEmpty) {
                return Expanded(
                  child: Center(
                    child: Text('No drafts', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ),
                );
              }
              return Expanded(
                child: ListView.separated(
                  itemCount: state.drafts.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey[850], height: 0.5),
                  itemBuilder: (context, index) {
                    final draft = state.drafts[index];
                    return _buildDraftItem(context, draft, state);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraftItem(BuildContext context, DraftInfo draft, DraftState state) {
    return Dismissible(
      key: Key('draft_${draft.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red[800],
        child: Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteDraft(draft.id),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          onDraftSelected(draft);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.content.isEmpty ? '(empty)' : draft.content,
                style: TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                draft.createdAt,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
