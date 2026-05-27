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
/// To configure the locales supported by your app, you'll need to edit this
/// file.
///
/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project's Runner folder.
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

  String get appTitle;
  String get search;
  String get cancel;
  String get post;
  String get publishSuccess;
  String get publishFailed;
  String get noPostsYet;
  String get anonymousUser;
  String get whatsNew;
  String get whoCanReply;
  String get everyoneCanReply;
  String get followersCanReply;
  String get followingCanReply;
  String get mentionedCanReply;
  String get newPost;
  String get saySomething;
  String get addOption;
  String get removePoll;
  String optionLabel(int number);
  String get searchTop;
  String get searchUsers;
  String get searchTopics;
  String get searchPosts;
  String get noResultsFound;
  String get recent;
  String get clearAll;
  String get trendingTopics;
  String get trendingPosts;
  String get seeAllUsers;
  String get seeAllTopics;
  String get loginTitle;
  String get usernameHint;
  String get passwordHint;
  String get loginButton;
  String get or;
  String get loginWithInstagram;
  String get createNewAccount;
  String get pleaseEnterUsernameAndPassword;
  String get loginFailedCheckCredentials;
  String get settingsTitle;
  String get followAndInviteFriends;
  String get notifications;
  String get privacy;
  String get help;
  String get about;
  String get logOut;
  String get language;
  String get back;
  String get searchTitle;
  String get tabTop;
  String get tabUsers;
  String get tabTopics;
  String get tabPosts;
  String get sectionUsers;
  String get sectionTopics;
  String get sectionPosts;
  String get activityTitle;
  String get filterAll;
  String get filterReplies;
  String get filterMentions;
  String get filterVerify;
  String get noNotifications;
  String get editProfile;
  String get shareProfile;
  String get tabThreads;
  String get tabReplies;
  String get noThreadsYet;
  String get notificationSettings;
  String get notifyLikes;
  String get notifyReplies;
  String get notifyMentions;
  String get notifyFollows;
  String get notifyTrending;
  String get notifySystem;
  String get notifyGroupMessages;
  String get notifyQuotes;
  String get notifyReposts;
  String get notifyPolls;
  String get notifyCommunities;
  String get privacySettings;
  String get whoCanReplyToYou;
  String get whoCanMentionYou;
  String get messageRequests;
  String get messageRequestAllowType;
  String get interactionRestriction;
  String get showReadReceipts;
  String get showOnlineStatus;
  String get allowRecommend;
  String get hideLikesCount;
  String get silentMode;
  String get contentRating;
  String get replyEveryone;
  String get replyFollowers;
  String get replyPagesYouFollow;
  String get replyMentioned;
  String get mentionEveryone;
  String get mentionUsersYouFollow;
  String get mentionMutuals;
  String get msgReqAnyone;
  String get msgReqFollowedOnly;
  String get restrictionNone;
  String get restrictionFollowedOneWeek;
  String get restrictionMutualsOnly;
  String get ratingAll;
  String get ratingTeen;
  String get ratingAdult;
  String get on;
  String get off;
  String get replies;
  String get reply;
  String get repost;
  String get undoRepost;
  String get quote;
  String get save;
  String get unsave;
  String get share;
  String get copyLink;
  String get linkCopied;
  String get report;
  String get notInterested;
  String get follow;
  String get unfollow;
  String get followers;
  String get following;
  String get posts;
  String get linkCopiedToClipboard;
  String get replyToPost;
  String get commentsComingSoon;

  String get messages;
  String get allMessages;
  String get noConversations;
  String get noMessageRequests;
  String get newMessage;
  String get searchForUser;
  String get messagePlaceholder;
  String get noMessagesYet;
  String get quotedMessage;
  String get videoMessage;
  String get voiceMessage;
  String get fileMessage;
  String get createGroup;
  String get groupName;
  String get groupAvatar;
  String get needApprove;
  String get inviteLinkEnabled;
  String get create;
  String get groupInfo;
  String get members;
  String get copyInviteLink;
  String get leaveGroup;
  String get leaveGroupConfirm;
  String get joinRequests;
  String get noPendingRequests;
  String get approve;
  String get decline;
  String get removeMember;
  String get admin;
  String get member;
  String get groupCreated;
  String get editGroupName;

  String get topic;
  String get followTopic;
  String get unfollowTopic;
  String get hot;
  String get latest;
  String get relatedTopics;
  String get muteTopic;
  String get unmuteTopic;
  String get topicMuted;

  String get drafts;
  String get noDrafts;
  String get saveDraft;
  String get deleteDraft;
  String get deleteDraftConfirm;
  String get draftSaved;
  String get draftDeleted;
  String get loadDraft;

  String get communities;
  String get communityDetail;
  String get communityMembers;
  String get communityPosts;
  String get joinCommunity;
  String get leaveCommunity;
  String get leaveCommunityConfirm;
  String get noCommunities;
  String get noCommunityMembers;
  String get noCommunityPosts;
  String get setChampion;
  String get removeChampion;
  String get searchMembers;
  String get recentPosts;
  String get topPosts;
  String get accountControls;
  String get mutedUsers;
  String get restrictedUsers;
  String get blockedUsers;
  String get unmute;
  String get unrestrict;
  String get unblock;
  String get noMutedUsers;
  String get noRestrictedUsers;
  String get noBlockedUsers;
  String get collections;
  String get createCollection;
  String get collectionName;
  String get deleteCollection;
  String get deleteCollectionConfirm;
  String get noCollections;
  String get defaultCollection;
  String get hiddenWords;
  String get keywords;
  String get phrases;
  String get emoji;
  String get addWord;
  String get wordContent;
  String get wordType;
  String get deleteWord;
  String get deleteWordConfirm;
  String get noHiddenWords;
  String get links;
  String get addLink;
  String get editLink;
  String get linkTitle;
  String get linkUrl;
  String get deleteLink;
  String get deleteLinkConfirm;
  String get noLinks;
  String get guestReplyReviewTitle;
  String get reject;
  String get approved;
  String get rejected;
  String get addLocation;
  String get enterLocation;
  String get clearLocation;
  String get scheduledPosts;
  String get noScheduledPosts;
  String get cancelSchedule;
  String get editHistory;
  String get editPost;
  String get deletePost;
  String get deletePostConfirm;
  String get pinPost;
  String get unpinPost;
  String get postDeleted;
  String get postUpdated;
  String get nearbyPosts;
  String get savedPosts;
  String get noSavedPosts;
  String get postDetail;
  String get noRepliesYet;
  String get justNow;
  String minutesAgo(int count);
  String hoursAgo(int count);
  String daysAgo(int count);
  String get notifiedLikedPost;
  String get notifiedRepliedToYou;
  String get notifiedFollowedYou;
  String get notifiedMentionedYou;
  String get notifiedRepostedPost;
  String get notifiedQuotedPost;
  String get filterLikes;
  String get filterFollows;
  String get quoteRepost;
  String get quotePlaceholder;
  String get noThreadsYetOthers;
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
