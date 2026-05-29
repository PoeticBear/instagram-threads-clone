import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/feedpost.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<PostState>(context, listen: false);
      state.loadSavedPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
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
          AppLocalizations.of(context)!.savedPosts,
          style: TextStyle(color: appColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: Consumer<PostState>(
        builder: (context, state, _) {
          if (state.isLoadingSavedPosts) {
            return Center(child: CircularProgressIndicator(color: appColors.textPrimary));
          }
          if (state.savedPosts.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noSavedPosts,
                style: TextStyle(color: appColors.textSecondary, fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.savedPosts.length,
            itemBuilder: (context, index) {
              return FeedPostWidget(postModel: state.savedPosts[index]);
            },
          );
        },
      ),
    );
  }
}
