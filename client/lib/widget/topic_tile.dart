import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/model/topic.module.dart';
import 'package:threads/network/api_client.dart';
import 'package:threads/pages/topic/topic_detail_page.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/services/topic_service.dart';
import 'package:threads/theme/app_colors.dart';

class TopicTile extends StatefulWidget {
  final TrendingTopic? trendingTopic;
  final TopicInfo? topicInfo;
  final VoidCallback? onTap;

  const TopicTile({super.key, required this.trendingTopic, this.onTap})
      : topicInfo = null;

  const TopicTile.fromTopicInfo({super.key, required this.topicInfo, this.onTap})
      : trendingTopic = null;

  String get _name => trendingTopic?.name ?? topicInfo?.name ?? '';
  int get _postsCount => trendingTopic?.postsCount ?? topicInfo?.postsCount ?? 0;
  bool get _isFollowingInitial => trendingTopic?.isFollowing ?? topicInfo?.isFollowing ?? false;
  int? get _topicId {
    if (trendingTopic != null) return int.tryParse(trendingTopic!.id);
    if (topicInfo != null) return topicInfo!.id;
    return null;
  }

  @override
  State<TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<TopicTile> {
  late bool _isFollowing;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget._isFollowingInitial;
  }

  @override
  void didUpdateWidget(covariant TopicTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newFollowing = widget._isFollowingInitial;
    if (newFollowing != oldWidget._isFollowingInitial) {
      _isFollowing = newFollowing;
    }
  }

  void _navigateToDetail(BuildContext context) {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final topicId = widget._topicId;
    if (topicId == null) return;
    Navigator.push(
      context,
      TopicDetailPage.getRoute(
        topicId: topicId,
        topicName: widget._name,
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isToggling) return;
    final topicId = widget._topicId;
    if (topicId == null) return;

    setState(() {
      _isFollowing = !_isFollowing;
      _isToggling = true;
    });

    try {
      final service = TopicService(apiClient: getIt<ApiClient>());
      if (_isFollowing) {
        await service.followTopic(topicId);
      } else {
        await service.unfollowTopic(topicId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
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
                    widget._name,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget._postsCount} ${AppLocalizations.of(context)!.posts}',
                    style: TextStyle(
                      fontSize: 15,
                      color: appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleFollow,
              child: Container(
                height: 32,
                width: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: appColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColors.textSecondary, width: 0.5),
                ),
                child: _isToggling
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      )
                    : Text(
                        _isFollowing
                            ? AppLocalizations.of(context)!.following
                            : AppLocalizations.of(context)!.follow,
                        style: TextStyle(
                          fontSize: 15,
                          color: appColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
