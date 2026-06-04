// ignore_for_file: must_be_immutable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/widget/custom/title_text.dart';

class UserTilePage extends StatelessWidget {
  UserTilePage({
    Key? key,
    required this.user,
    required this.isFollowing,
    this.isLoading = false,
    this.onFollowTap,
  }) : super(key: key);

  final UserModel user;
  bool isFollowing;
  final bool isLoading;
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Avatar — tappable to profile
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                ProfilePage.getRoute(profileId: user.userId!.toString(), username: user.userName),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: (user.profilePic ?? '').isEmpty
                  ? Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, size: 24, color: appColors.textSecondary),
                    )
                  : CachedNetworkImage(
                      imageUrl: user.profilePic!,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 24, color: appColors.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // User info — tappable to profile
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  ProfilePage.getRoute(profileId: user.userId!.toString(), username: user.userName),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Flexible(
                        child: TitleText(
                          user.displayName ?? '',
                          fontSize: 15,
                          color: appColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified == true) ...[
                        SizedBox(width: 4),
                        Icon(CupertinoIcons.checkmark_seal_fill,
                            size: 14, color: CupertinoColors.activeBlue),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.userName ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: appColors.textSecondary,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: TextStyle(
                        fontSize: 13,
                        color: appColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    "${user.followersCount ?? 0} ${AppLocalizations.of(context)!.followers}",
                    style: TextStyle(
                      fontSize: 13,
                      color: appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Follow / Following button
          GestureDetector(
            onTap: isLoading ? null : onFollowTap,
            child: Container(
              height: 32,
              width: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFollowing ? appColors.background : appColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
                border: isFollowing
                    ? Border.all(color: appColors.textSecondary, width: 0.5)
                    : null,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CupertinoActivityIndicator(
                        color: isFollowing ? appColors.textPrimary : appColors.background,
                      ),
                    )
                  : Text(
                      isFollowing
                          ? AppLocalizations.of(context)!.following
                          : AppLocalizations.of(context)!.follow,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFollowing ? appColors.textPrimary : appColors.background,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
