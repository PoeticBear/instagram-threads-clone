import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/state/follow_request.state.dart';
import 'package:threads/theme/app_colors.dart';

class FollowRequestsPage extends StatefulWidget {
  const FollowRequestsPage({super.key});

  @override
  State<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends State<FollowRequestsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<FollowRequestState>();
      if (state.requests.isEmpty) {
        state.loadRequests();
      }
    });
  }

  Future<void> _onRefresh() async {
    final state = context.read<FollowRequestState>();
    await state.loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appColors.background,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        title: Text(
          l10n.followRequests,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<FollowRequestState>(
        builder: (context, state, _) {
          if (state.isbusy && state.requests.isEmpty) {
            return Center(
              child: CupertinoActivityIndicator(color: appColors.textPrimary),
            );
          }

          if (state.requests.isEmpty) {
            return Center(
              child: Text(
                l10n.noPendingFollowRequests,
                style: TextStyle(
                  color: appColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: appColors.textPrimary,
            backgroundColor: appColors.background,
            onRefresh: _onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.requests.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: appColors.divider,
                indent: 52,
              ),
              itemBuilder: (context, index) {
                return _FollowRequestTile(
                  request: state.requests[index],
                  isProcessing: state.isProcessing &&
                      state.processingId == state.requests[index].id,
                  onApprove: () => state.approve(state.requests[index].id),
                  onReject: () => state.reject(state.requests[index].id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FollowRequestTile extends StatelessWidget {
  final FollowRequest request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _FollowRequestTile({
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  String _formatTime(BuildContext context, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final dt = DateTime.tryParse(timeStr);
    if (dt == null) return '';
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
    final l10n = AppLocalizations.of(context)!;
    final hasAvatar = (request.requesterAvatar ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                ProfilePage.getRoute(
                  profileId: request.requesterId.toString(),
                  username: request.requesterUsername,
                ),
              );
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: request.requesterAvatar!,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                        errorWidget: (_, __, ___) =>
                            _defaultAvatar(appColors),
                      ),
                    )
                  : _defaultAvatar(appColors),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  ProfilePage.getRoute(
                    profileId: request.requesterId.toString(),
                    username: request.requesterUsername,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          request.requesterDisplayName ?? '',
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${request.requesterUsername ?? ''}',
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (request.createTime != null &&
                      request.createTime!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(context, request.createTime),
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          if (isProcessing)
            SizedBox(
              width: 18,
              height: 18,
              child: CupertinoActivityIndicator(
                color: appColors.textPrimary,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Confirm button (filled)
                GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: appColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.confirmButton,
                      style: TextStyle(
                        color: appColors.background,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Reject button (outlined)
                GestureDetector(
                  onTap: onReject,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: appColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: appColors.textSecondary,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      l10n.rejectButton,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(AppColors appColors) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 26, color: appColors.textSecondary),
    );
  }
}
