import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';

class PollWidget extends StatelessWidget {
  final String postId;
  final PollData pollData;
  final EdgeInsetsGeometry padding;

  const PollWidget({
    super.key,
    required this.postId,
    required this.pollData,
    this.padding = const EdgeInsets.only(left: 55, right: 10, top: 8),
  });

  String _formatRemainingTime() {
    if (pollData.expireTime == null) return '';
    final remaining = pollData.expireTime!.difference(DateTime.now());
    if (remaining.isNegative) return '已结束';
    final hours = remaining.inHours;
    if (hours > 0) return '剩余 $hours 小时';
    final minutes = remaining.inMinutes;
    return '剩余 $minutes 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final showResults = pollData.hasVoted || pollData.isExpired;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pollData.options.map((option) {
            if (showResults) {
              return _buildResultOption(context, option);
            } else {
              return _BuildVotingOption(
                option: option,
                postId: postId,
              );
            }
          }),
          const SizedBox(height: 6),
          _buildFooter(context, showResults),
        ],
      ),
    );
  }

  Widget _buildResultOption(BuildContext context, PollOption option) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final totalVotes = pollData.totalVotes > 0 ? pollData.totalVotes : 1;
    final percentage = (option.votesCount / totalVotes * 100).round();
    final isVoted = pollData.userVotedOptionId == option.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isVoted ? appColors.textPrimary : appColors.border,
            width: isVoted ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background progress bar
              Container(
                width: double.infinity,
                height: 40,
                color: appColors.surface,
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 40,
                  color: appColors.surfaceSecondary,
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      isVoted ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isVoted ? appColors.textPrimary : appColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 14,
                          fontWeight: isVoted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool showResults) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final parts = <String>[
      '${pollData.totalVotes} 票',
    ];
    if (showResults && pollData.hasVoted) {
      parts.add('你已投票');
    }
    if (pollData.expireTime != null) {
      parts.add(_formatRemainingTime());
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(
        color: appColors.textMuted,
        fontSize: 12,
      ),
    );
  }
}

class _BuildVotingOption extends StatelessWidget {
  final PollOption option;
  final String postId;

  const _BuildVotingOption({
    required this.option,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          final state = Provider.of<PostState>(context, listen: false);
          state.voteOnPoll(postId, option.id);
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: appColors.border),
            color: appColors.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.circle_outlined, size: 16, color: appColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.optionText,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
