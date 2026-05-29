import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';

class ScheduledPostsPage extends StatefulWidget {
  const ScheduledPostsPage({super.key});

  @override
  State<ScheduledPostsPage> createState() => _ScheduledPostsPageState();
}

class _ScheduledPostsPageState extends State<ScheduledPostsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<PostState>(context, listen: false);
      state.loadScheduledPosts();
    });
  }

  Future<void> _onRefresh() async {
    final state = Provider.of<PostState>(context, listen: false);
    await state.loadScheduledPosts();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: appColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          l10n.scheduledPosts,
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<PostState>(
        builder: (context, state, _) {
          if (state.isLoadingScheduled) {
            return Center(
              child: CircularProgressIndicator(color: appColors.textPrimary),
            );
          }
          if (state.scheduledPosts.isEmpty) {
            return Center(
              child: Text(
                l10n.noScheduledPosts,
                style: TextStyle(color: appColors.textSecondary, fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            color: appColors.textPrimary,
            backgroundColor: appColors.background,
            onRefresh: _onRefresh,
            child: ListView.builder(
              itemCount: state.scheduledPosts.length,
              itemBuilder: (context, index) {
                final post = state.scheduledPosts[index];
                return Column(
                  children: [
                    FeedPostWidget(postModel: post),
                    if (post.scheduledTime != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: appColors.surface,
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.clock,
                              size: 16,
                              color: appColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatScheduledTime(post.scheduledTime!),
                                style: TextStyle(
                                  color: appColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final confirmed = await showCupertinoDialog<
                                    bool>(
                                  context: context,
                                  builder: (ctx) => CupertinoAlertDialog(
                                    title: Text(l10n.cancelSchedule),
                                    content: Text(
                                      '${l10n.cancelSchedule}?',
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: Text(l10n.cancel),
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        child: Text(l10n.cancelSchedule),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await state.cancelSchedule(post.id);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: appColors.destructive.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: appColors.destructive.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  l10n.cancelSchedule,
                                  style: TextStyle(
                                    color: appColors.destructive,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Divider(
                      height: 0.5,
                      color: appColors.divider,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatScheduledTime(String time) {
    try {
      final dt = DateTime.parse(time);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }
}
