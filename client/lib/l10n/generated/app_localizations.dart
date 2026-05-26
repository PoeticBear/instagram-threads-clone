import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get appTitle;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @publishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Post successful'**
  String get publishSuccess;

  /// No description provided for @publishFailed.
  ///
  /// In en, this message translates to:
  /// **'Post failed, please retry'**
  String get publishFailed;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @anonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous user'**
  String get anonymousUser;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new?'**
  String get whatsNew;

  /// No description provided for @whoCanReply.
  ///
  /// In en, this message translates to:
  /// **'Who can reply'**
  String get whoCanReply;

  /// No description provided for @everyoneCanReply.
  ///
  /// In en, this message translates to:
  /// **'Everyone can reply'**
  String get everyoneCanReply;

  /// No description provided for @followersCanReply.
  ///
  /// In en, this message translates to:
  /// **'Only followers can reply'**
  String get followersCanReply;

  /// No description provided for @followingCanReply.
  ///
  /// In en, this message translates to:
  /// **'Only people you follow can reply'**
  String get followingCanReply;

  /// No description provided for @mentionedCanReply.
  ///
  /// In en, this message translates to:
  /// **'Only mentioned people can reply'**
  String get mentionedCanReply;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// No description provided for @saySomething.
  ///
  /// In en, this message translates to:
  /// **'Say something...'**
  String get saySomething;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @removePoll.
  ///
  /// In en, this message translates to:
  /// **'Remove poll'**
  String get removePoll;

  /// No description provided for @optionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String optionLabel(int number);

  /// No description provided for @searchTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get searchTop;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get searchUsers;

  /// No description provided for @searchTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get searchTopics;

  /// No description provided for @searchPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get searchPosts;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @trendingTopics.
  ///
  /// In en, this message translates to:
  /// **'Trending topics'**
  String get trendingTopics;

  /// No description provided for @trendingPosts.
  ///
  /// In en, this message translates to:
  /// **'Trending posts'**
  String get trendingPosts;

  /// No description provided for @seeAllUsers.
  ///
  /// In en, this message translates to:
  /// **'See all users'**
  String get seeAllUsers;

  /// No description provided for @seeAllTopics.
  ///
  /// In en, this message translates to:
  /// **'See all topics'**
  String get seeAllTopics;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @loginWithInstagram.
  ///
  /// In en, this message translates to:
  /// **'Login with Instagram'**
  String get loginWithInstagram;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get createNewAccount;

  /// No description provided for @pleaseEnterUsernameAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter username and password'**
  String get pleaseEnterUsernameAndPassword;

  /// No description provided for @loginFailedCheckCredentials.
  ///
  /// In en, this message translates to:
  /// **'Login failed, please check username and password'**
  String get loginFailedCheckCredentials;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @followAndInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Follow and invite friends'**
  String get followAndInviteFriends;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @tabTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get tabTop;

  /// No description provided for @tabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get tabUsers;

  /// No description provided for @tabTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get tabTopics;

  /// No description provided for @tabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get tabPosts;

  /// No description provided for @sectionUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get sectionUsers;

  /// No description provided for @sectionTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get sectionTopics;

  /// No description provided for @sectionPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get sectionPosts;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get filterReplies;

  /// No description provided for @filterMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get filterMentions;

  /// No description provided for @filterVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get filterVerify;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @shareProfile.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfile;

  /// No description provided for @tabThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get tabThreads;

  /// No description provided for @tabReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get tabReplies;

  /// No description provided for @noThreadsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted any threads yet.'**
  String get noThreadsYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
