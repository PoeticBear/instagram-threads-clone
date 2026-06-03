import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.isFollowing});

  final UserModel user;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          ProfilePage.getRoute(profileId: user.userId!.toString(), username: user.userName),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appColors.divider, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Avatar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: (user.profilePic ?? '').isEmpty
                    ? Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: appColors.surfaceSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 28, color: appColors.textSecondary),
                      )
                    : CachedNetworkImage(
                        imageUrl: user.profilePic!,
                        height: 56,
                        width: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: appColors.surfaceSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, size: 28, color: appColors.textSecondary),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              // ── Display Name ──
              Text(
                user.displayName ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: appColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // ── Username ──
              Text(
                user.userName ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: appColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // ── Followers ──
              Text(
                '${user.followersCount ?? 0} ${AppLocalizations.of(context)!.followers}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // ── Follow Button ──
              SizedBox(
                width: double.infinity,
                height: 34,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFollowing ? Colors.transparent : appColors.textPrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFollowing ? appColors.textSecondary : appColors.textPrimary,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    isFollowing
                        ? AppLocalizations.of(context)!.following
                        : AppLocalizations.of(context)!.follow,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isFollowing ? appColors.textPrimary : appColors.background,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
