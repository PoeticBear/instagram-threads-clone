import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/theme/app_colors.dart';

class SearchPostTile extends StatelessWidget {
  final SearchPostItem post;
  final VoidCallback? onTap;

  const SearchPostTile({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context, post.avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.displayName,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '@${post.username}',
                        style: TextStyle(
                          fontSize: 15,
                          color: appColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: appColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.favorite_outline, size: 14, color: appColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(fontSize: 13, color: appColors.textMuted),
                      ),
                      const SizedBox(width: 14),
                      Icon(Icons.chat_bubble_outline, size: 14, color: appColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${post.repliesCount}',
                        style: TextStyle(fontSize: 13, color: appColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? url) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    if (url == null || url.isEmpty) {
      return Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: appColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 24, color: appColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: CachedNetworkImage(imageUrl: url, height: 40, width: 40, fit: BoxFit.cover),
    );
  }
}
