import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/locale.state.dart';
import 'package:threads/state/theme.state.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/common/settings/notification_settings.dart';
import 'package:threads/common/settings/privacy_settings.dart';
import 'package:threads/common/settings/relation_control_page.dart';
import 'package:threads/common/settings/collections_page.dart';
import 'package:threads/common/settings/hidden_words_page.dart';
import 'package:threads/common/settings/links_page.dart';
import 'package:threads/pages/community/community_list_page.dart';
import 'package:threads/pages/post/saved_posts_page.dart';
import 'package:threads/pages/post/scheduled_posts_page.dart';
import 'package:threads/pages/settings/follow_requests_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var authState = Provider.of<AuthState>(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: appColors.background,
      appBar: AppBar(
        flexibleSpace: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Container(height: 50),
                Row(
                  children: [
                    Stack(
                      children: [
                        BackButton(color: appColors.textPrimary),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 35, top: 12),
                            child: Text(
                              l10n.back,
                              style: TextStyle(
                                color: appColors.textPrimary,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        leading: Container(),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 27),
          child: Text(
            l10n.settingsTitle,
            style: TextStyle(
              color: appColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: ListView(
          children: [
            // Top divider
            Container(
              height: 0.5,
              color: appColors.divider,
              width: MediaQuery.of(context).size.width,
            ),
            const SizedBox(height: 20),

            // Follow & Invite Friends
            _buildMenuRow(
              icon: CupertinoIcons.person_add,
              title: l10n.followAndInviteFriends,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const FollowRequestsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Notifications
            _buildMenuRow(
              icon: CupertinoIcons.bell,
              title: l10n.notifications,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Privacy
            _buildMenuRow(
              icon: Icons.lock_outline,
              title: l10n.privacy,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const PrivacySettingsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Account Controls (Muted / Restricted / Blocked)
            _buildMenuRow(
              icon: CupertinoIcons.person_crop_circle_badge_xmark,
              title: l10n.accountControls,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const RelationControlPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Saved Collections
            _buildMenuRow(
              icon: CupertinoIcons.bookmark,
              title: l10n.collections,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const CollectionsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Saved Posts
            _buildMenuRow(
              icon: CupertinoIcons.bookmark_fill,
              title: l10n.savedPosts,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const SavedPostsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Scheduled Posts
            _buildMenuRow(
              icon: CupertinoIcons.clock,
              title: l10n.scheduledPosts,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const ScheduledPostsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Communities
            _buildMenuRow(
              icon: Icons.groups_outlined,
              title: l10n.communities,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const CommunityListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Hidden Words
            _buildMenuRow(
              icon: CupertinoIcons.eye_slash,
              title: l10n.hiddenWords,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const HiddenWordsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Links
            _buildMenuRow(
              icon: CupertinoIcons.link,
              title: l10n.links,
              showArrow: true,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const LinksPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Help
            _buildMenuRow(
              icon: Icons.help_outline,
              title: l10n.help,
              showArrow: true,
              onTap: () {
                // Placeholder
              },
            ),
            const SizedBox(height: 20),

            // About
            _buildMenuRow(
              icon: CupertinoIcons.info,
              title: l10n.about,
              showArrow: true,
              onTap: () {
                // Placeholder
              },
            ),

            const SizedBox(height: 15),

            // Divider before appearance
            Container(
              height: 0.5,
              color: appColors.divider,
              width: MediaQuery.of(context).size.width,
            ),
            const SizedBox(height: 5),

            // Appearance row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 20),
                Icon(CupertinoIcons.moon_stars, size: 30, color: appColors.textSecondary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.appearance,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: appColors.textPrimary,
                    ),
                  ),
                ),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return GestureDetector(
                      onTap: () => themeProvider.toggleTheme(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          themeProvider.themeMode == ThemeMode.dark ? l10n.themeDark : l10n.themeLight,
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
              ],
            ),

            const SizedBox(height: 15),

            // Language row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 20),
                Icon(CupertinoIcons.globe, size: 30, color: appColors.textSecondary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.language,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: appColors.textPrimary,
                    ),
                  ),
                ),
                Consumer<LocaleProvider>(
                  builder: (context, localeProvider, _) {
                    return GestureDetector(
                      onTap: () {
                        final newLocale =
                            localeProvider.locale.languageCode == 'en'
                                ? const Locale('zh')
                                : const Locale('en');
                        localeProvider.setLocale(newLocale);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: appColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          localeProvider.locale.languageCode == 'en'
                              ? 'English'
                              : '中文',
                          style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
              ],
            ),

            const SizedBox(height: 15),

            // Divider before logout
            Container(
              height: 0.5,
              color: appColors.divider,
              width: MediaQuery.of(context).size.width,
            ),
            const SizedBox(height: 5),

            // Log out
            GestureDetector(
              onTap: () {
                authState.logoutCallback();
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 50,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.logOut,
                      style: TextStyle(
                        color: appColors.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    bool showArrow = false,
    VoidCallback? onTap,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 30, color: appColors.textPrimary),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appColors.textPrimary,
                ),
              ),
            ),
            if (showArrow)
              Icon(
                CupertinoIcons.chevron_forward,
                color: appColors.textMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
