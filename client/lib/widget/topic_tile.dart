import 'package:flutter/material.dart';
import 'package:threads/pages/topic/topic_detail_page.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/theme/app_colors.dart';

class TopicTile extends StatelessWidget {
  final TrendingTopic topic;
  final VoidCallback? onTap;

  const TopicTile({super.key, required this.topic, this.onTap});

  void _navigateToDetail(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    final topicId = int.tryParse(topic.id);
    if (topicId == null) return;
    Navigator.push(
      context,
      TopicDetailPage.getRoute(
        topicId: topicId,
        topicName: topic.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: appColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.tag, size: 22, color: appColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${topic.postsCount} posts',
                    style: TextStyle(
                      fontSize: 15,
                      color: appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (topic.isFollowing)
              Container()
            else
              Container(
                height: 32,
                width: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: appColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColors.textSecondary, width: 0.5),
                ),
                child: Text(
                  AppLocalizations.of(context)!.follow,
                  style: TextStyle(
                    fontSize: 15,
                    color: appColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
