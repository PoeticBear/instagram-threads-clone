import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/post.state.dart';

class PollWidget extends StatelessWidget {
  final String postId;
  final PollData pollData;

  const PollWidget({
    super.key,
    required this.postId,
    required this.pollData,
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
      padding: const EdgeInsets.only(left: 55, right: 10, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pollData.options.map((option) {
            if (showResults) {
              return _buildResultOption(option);
            } else {
              return _BuildVotingOption(
                option: option,
                postId: postId,
              );
            }
          }),
          const SizedBox(height: 6),
          _buildFooter(showResults),
        ],
      ),
    );
  }

  Widget _buildResultOption(PollOption option) {
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
            color: isVoted ? Colors.blue : Colors.grey[700]!,
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
                color: Colors.grey[900],
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 40,
                  color: isVoted
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.grey[800],
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
                      color: isVoted ? Colors.blue : Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isVoted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: Colors.grey[400],
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

  Widget _buildFooter(bool showResults) {
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
        color: Colors.grey[500],
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
            border: Border.all(color: Colors.grey[600]!),
            color: Colors.grey[900],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.circle_outlined, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.optionText,
                  style: const TextStyle(
                    color: Colors.white,
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
