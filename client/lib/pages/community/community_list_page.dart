import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/model/community.module.dart';
import 'package:threads/state/community.state.dart';
import 'package:threads/pages/community/community_detail_page.dart';
import 'package:threads/theme/app_colors.dart';

class CommunityListPage extends StatefulWidget {
  const CommunityListPage({Key? key}) : super(key: key);

  static PageRouteBuilder getRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return const CommunityListPage();
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<CommunityState>(context, listen: false);
      state.loadCommunities();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<CommunityState>();
      if (state.hasMoreCommunities && !state.isLoadingCommunities) {
        state.loadMoreCommunities();
      }
    }
  }

  Future<void> _onRefresh() async {
    final state = context.read<CommunityState>();
    await state.loadCommunities();
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
        title: Text(
          'Communities',
          style: TextStyle(
            color: appColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<CommunityState>(
        builder: (context, state, _) {
          if (state.isLoadingCommunities && state.communities.isEmpty) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (state.communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 48, color: appColors.surface),
                  const SizedBox(height: 12),
                  Text(
                    'No communities found',
                    style: TextStyle(
                      color: appColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: appColors.textPrimary,
            backgroundColor: appColors.background,
            onRefresh: _onRefresh,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: state.communities.length +
                  (state.hasMoreCommunities ? 1 : 0),
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: appColors.divider,
                indent: 78,
              ),
              itemBuilder: (context, index) {
                if (index == state.communities.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                final community = state.communities[index];
                return _buildCommunityItem(community, appColors);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityItem(CommunityInfo community, AppColors appColors) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CommunityDetailPage.getRoute(
            communityId: community.id,
            communityName: community.name,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            _buildCoverThumbnail(community, appColors),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row with joined badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          community.name,
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (community.isJoined) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: appColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Joined',
                            style: TextStyle(
                              color: appColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Description
                  if (community.description != null &&
                      community.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      community.description!,
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Stats row
                  Row(
                    children: [
                      Text(
                        '${community.membersCount}',
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' members',
                        style: TextStyle(
                          color: appColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${community.postsCount}',
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' posts',
                        style: TextStyle(
                          color: appColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right,
              color: appColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverThumbnail(CommunityInfo community, AppColors appColors) {
    if (community.coverUrl != null && community.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: community.coverUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildPlaceholderIcon(appColors),
        ),
      );
    }
    return _buildPlaceholderIcon(appColors);
  }

  Widget _buildPlaceholderIcon(AppColors appColors) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: appColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.groups_outlined,
        color: appColors.textSecondary,
        size: 26,
      ),
    );
  }
}
