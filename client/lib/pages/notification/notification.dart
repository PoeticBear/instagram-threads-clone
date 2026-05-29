import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/pages/post/post_detail_page.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/state/notification.state.dart';
import 'package:threads/services/notification_service.dart';
import 'package:threads/theme/app_colors.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<NotificationState>();
      if (state.hasMore && !state.isLoadingMore) {
        state.loadMore();
      }
    }
  }

  Future<void> _onRefresh() async {
    final state = context.read<NotificationState>();
    await state.loadNotifications(refresh: true);
    await state.fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.activityTitle,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildFilterBar(context),
          const SizedBox(height: 12),
          Expanded(child: _buildNotificationList(context)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final state = context.watch<NotificationState>();
    return SizedBox(
      height: 36,
      width: MediaQuery.of(context).size.width,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 16),
          _filterChip(
            context: context,
            label: AppLocalizations.of(context)!.filterAll,
            type: null,
            currentType: state.filterType,
            onTap: () => state.setFilter(null),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: AppLocalizations.of(context)!.filterLikes,
            type: 1,
            currentType: state.filterType,
            onTap: () => state.setFilter(1),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: AppLocalizations.of(context)!.filterReplies,
            type: 2,
            currentType: state.filterType,
            onTap: () => state.setFilter(2),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: AppLocalizations.of(context)!.filterFollows,
            type: 3,
            currentType: state.filterType,
            onTap: () => state.setFilter(3),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context: context,
            label: AppLocalizations.of(context)!.filterMentions,
            type: 4,
            currentType: state.filterType,
            onTap: () => state.setFilter(4),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required int? type,
    required int? currentType,
    required VoidCallback onTap,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isActive = currentType == type;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? appColors.textPrimary : appColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? appColors.textPrimary : appColors.textSecondary,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? appColors.background : appColors.textPrimary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final state = context.watch<NotificationState>();

    if (state.isbusy && state.notifications.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: appColors.textPrimary),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noNotifications,
          style: TextStyle(color: appColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      color: appColors.textPrimary,
      backgroundColor: appColors.background,
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 0.5,
          color: appColors.divider,
          indent: 52,
        ),
        itemBuilder: (context, index) {
          if (index == state.notifications.length) {
            return Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: appColors.textPrimary,
                  ),
                ),
              ),
            );
          }
          return _NotificationTile(
            notification: state.notifications[index],
            onTap: () => _onNotificationTap(state, state.notifications[index]),
          );
        },
      ),
    );
  }

  void _onNotificationTap(NotificationState state, NotificationItem item) {
    if (!item.isRead) {
      state.markAsRead([item.id]);
    }
    if (item.postId != null && item.postId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: item.postId!),
        ),
      );
    } else if (item.fromUserId != null && item.fromUserId!.isNotEmpty) {
      Navigator.push(
        context,
        ProfilePage.getRoute(profileId: item.fromUserId!),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData _typeIcon() {
    switch (notification.type) {
      case 'like':
        return Icons.favorite;
      case 'reply':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_outlined;
      case 'mention':
        return Icons.alternate_email;
      case 'repost':
        return Icons.repeat;
      case 'quote':
        return Icons.format_quote;
      default:
        return Icons.notifications;
    }
  }

  String _typeText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (notification.type) {
      case 'like':
        return l10n.notifiedLikedPost;
      case 'reply':
        return l10n.notifiedRepliedToYou;
      case 'follow':
        return l10n.notifiedFollowedYou;
      case 'mention':
        return l10n.notifiedMentionedYou;
      case 'repost':
        return l10n.notifiedRepostedPost;
      case 'quote':
        return l10n.notifiedQuotedPost;
      default:
        return notification.body;
    }
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final hasAvatar = (notification.fromProfilePic ?? '').isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Opacity(
          opacity: notification.isRead ? 0.6 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              SizedBox(
                width: 40,
                height: 40,
                child: hasAvatar
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: notification.fromProfilePic!,
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorWidget: (_, __, ___) => _defaultAvatar(appColors),
                        ),
                      )
                    : _defaultAvatar(appColors),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon(), size: 14, color: appColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          notification.fromDisplayName ?? notification.fromUsername ?? '',
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _typeText(context),
                            style: TextStyle(
                              color: appColors.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (notification.body.isNotEmpty &&
                        notification.type != 'follow')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notification.body,
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatTime(context, notification.createdAt),
                        style: TextStyle(
                          color: appColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: appColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar(AppColors appColors) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 24, color: appColors.textSecondary),
    );
  }

}
