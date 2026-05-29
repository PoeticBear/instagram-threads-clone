// ignore_for_file: must_be_immutable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/custom/title_text.dart';

class UserTilePage extends StatelessWidget {
  UserTilePage({Key? key, required this.user, required this.isadded})
      : super(key: key);
  final UserModel user;
  bool? isadded;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          ProfilePage.getRoute(profileId: user.userId!.toString()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
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
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TitleText(
                    user.displayName == null ? "" : user.displayName!,
                    fontSize: 20,
                    color: appColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.userName!,
                    style: TextStyle(
                      fontSize: 17,
                      color: appColors.textSecondary,
                    ),
                  ),
                  Container(
                    height: 9,
                  ),
                  Text(
                    "${user.followersCount ?? 0} followers",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: appColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  isadded!
                      ? Container()
                      : Container(
                          height: 35,
                          width: 100,
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
                            "Follow",
                            style: TextStyle(
                              fontSize: 18,
                              color: appColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
