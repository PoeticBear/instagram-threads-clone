import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';

class ReactionPicker extends StatelessWidget {
  final int messageId;
  final Function(String emoji) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.messageId,
    required this.onReactionSelected,
  });

  static final List<String> _reactions = [
    '\u2764\uFE0F',  // heart
    '\uD83D\uDC4D',  // thumbs up
    '\uD83D\uDE02',  // laugh
    '\uD83D\uDE2E',  // wow
    '\uD83D\uDE22',  // cry
    '\uD83D\uDD25',  // fire
  ];

  void _onTap(BuildContext context, String emoji) {
    onReactionSelected(emoji);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactions.map((emoji) {
              return GestureDetector(
                onTap: () => _onTap(context, emoji),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
