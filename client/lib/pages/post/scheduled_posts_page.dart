import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/post.state.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.back, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          l10n.scheduledPosts,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<PostState>(
        builder: (context, state, _) {
          if (state.isLoadingScheduled) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (state.scheduledPosts.isEmpty) {
            return Center(
              child: Text(
                l10n.noScheduledPosts,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.black,
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
                        color: Color(0xff1a1a1a),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.clock,
                              size: 16,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatScheduledTime(post.scheduledTime!),
                                style: TextStyle(
                                  color: Colors.grey,
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
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  l10n.cancelSchedule,
                                  style: TextStyle(
                                    color: Colors.red,
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
                      color: Color(0xff333333),
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
