import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/draft.module.dart';
import '../state/draft.state.dart';
import '../theme/app_colors.dart';

class DraftListSheet extends StatelessWidget {
  final Function(DraftInfo) onDraftSelected;

  const DraftListSheet({super.key, required this.onDraftSelected});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: appColors.divider, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Drafts', style: TextStyle(color: appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: appColors.textPrimary),
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
                    child: Text('No drafts', style: TextStyle(color: appColors.textSecondary, fontSize: 16)),
                  ),
                );
              }
              return Expanded(
                child: ListView.separated(
                  itemCount: state.drafts.length,
                  separatorBuilder: (_, __) => Divider(color: appColors.divider, height: 0.5),
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Dismissible(
      key: Key('draft_${draft.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: appColors.destructive,
        child: Icon(Icons.delete_outline, color: appColors.textPrimary),
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
                style: TextStyle(color: appColors.textPrimary, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                draft.createTime,
                style: TextStyle(color: appColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
