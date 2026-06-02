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

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

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

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

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

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notifyLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notifyLikes;

  /// No description provided for @notifyReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get notifyReplies;

  /// No description provided for @notifyMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notifyMentions;

  /// No description provided for @notifyFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get notifyFollows;

  /// No description provided for @notifyTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get notifyTrending;

  /// No description provided for @notifySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notifySystem;

  /// No description provided for @notifyGroupMessages.
  ///
  /// In en, this message translates to:
  /// **'Group Messages'**
  String get notifyGroupMessages;

  /// No description provided for @notifyQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get notifyQuotes;

  /// No description provided for @notifyReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get notifyReposts;

  /// No description provided for @notifyPolls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get notifyPolls;

  /// No description provided for @notifyCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get notifyCommunities;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get privacySettings;

  /// No description provided for @whoCanReplyToYou.
  ///
  /// In en, this message translates to:
  /// **'Who can reply to you'**
  String get whoCanReplyToYou;

  /// No description provided for @whoCanMentionYou.
  ///
  /// In en, this message translates to:
  /// **'Who can mention you'**
  String get whoCanMentionYou;

  /// No description provided for @messageRequests.
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get messageRequests;

  /// No description provided for @messageRequestAllowType.
  ///
  /// In en, this message translates to:
  /// **'Who can send message requests'**
  String get messageRequestAllowType;

  /// No description provided for @interactionRestriction.
  ///
  /// In en, this message translates to:
  /// **'Interaction restriction'**
  String get interactionRestriction;

  /// No description provided for @showReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Show read receipts'**
  String get showReadReceipts;

  /// No description provided for @showOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Show online status'**
  String get showOnlineStatus;

  /// No description provided for @allowRecommend.
  ///
  /// In en, this message translates to:
  /// **'Allow account recommendations'**
  String get allowRecommend;

  /// No description provided for @hideLikesCount.
  ///
  /// In en, this message translates to:
  /// **'Hide likes count'**
  String get hideLikesCount;

  /// No description provided for @silentMode.
  ///
  /// In en, this message translates to:
  /// **'Silent mode'**
  String get silentMode;

  /// No description provided for @contentRating.
  ///
  /// In en, this message translates to:
  /// **'Content rating'**
  String get contentRating;

  /// No description provided for @replyEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get replyEveryone;

  /// No description provided for @replyFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get replyFollowers;

  /// No description provided for @replyPagesYouFollow.
  ///
  /// In en, this message translates to:
  /// **'Pages you follow'**
  String get replyPagesYouFollow;

  /// No description provided for @replyMentioned.
  ///
  /// In en, this message translates to:
  /// **'Mentioned only'**
  String get replyMentioned;

  /// No description provided for @mentionEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get mentionEveryone;

  /// No description provided for @mentionUsersYouFollow.
  ///
  /// In en, this message translates to:
  /// **'Users you follow'**
  String get mentionUsersYouFollow;

  /// No description provided for @mentionMutuals.
  ///
  /// In en, this message translates to:
  /// **'Mutuals only'**
  String get mentionMutuals;

  /// No description provided for @msgReqAnyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get msgReqAnyone;

  /// No description provided for @msgReqFollowedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only users you follow'**
  String get msgReqFollowedOnly;

  /// No description provided for @restrictionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get restrictionNone;

  /// No description provided for @restrictionFollowedOneWeek.
  ///
  /// In en, this message translates to:
  /// **'Followed > 1 week'**
  String get restrictionFollowedOneWeek;

  /// No description provided for @restrictionMutualsOnly.
  ///
  /// In en, this message translates to:
  /// **'Mutuals only'**
  String get restrictionMutualsOnly;

  /// No description provided for @ratingAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ratingAll;

  /// No description provided for @ratingTeen.
  ///
  /// In en, this message translates to:
  /// **'Teen'**
  String get ratingTeen;

  /// No description provided for @ratingAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get ratingAdult;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @repost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get repost;

  /// No description provided for @undoRepost.
  ///
  /// In en, this message translates to:
  /// **'Undo repost'**
  String get undoRepost;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @unsave.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get unsave;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopied;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @notInterested.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get notInterested;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @linkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopiedToClipboard;

  /// No description provided for @replyToPost.
  ///
  /// In en, this message translates to:
  /// **'Reply to post...'**
  String get replyToPost;

  /// No description provided for @commentsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Comments coming soon'**
  String get commentsComingSoon;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @allMessages.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get allMessages;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get noConversations;

  /// No description provided for @noMessageRequests.
  ///
  /// In en, this message translates to:
  /// **'No message requests'**
  String get noMessageRequests;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// No description provided for @searchForUser.
  ///
  /// In en, this message translates to:
  /// **'Search for a user to start chatting'**
  String get searchForUser;

  /// No description provided for @messagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get messagePlaceholder;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @quotedMessage.
  ///
  /// In en, this message translates to:
  /// **'Quoted message'**
  String get quotedMessage;

  /// No description provided for @videoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video message'**
  String get videoMessage;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @fileMessage.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMessage;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupAvatar.
  ///
  /// In en, this message translates to:
  /// **'Group avatar'**
  String get groupAvatar;

  /// No description provided for @needApprove.
  ///
  /// In en, this message translates to:
  /// **'Need approval'**
  String get needApprove;

  /// No description provided for @inviteLinkEnabled.
  ///
  /// In en, this message translates to:
  /// **'Invite link enabled'**
  String get inviteLinkEnabled;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @copyInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Copy invite link'**
  String get copyInviteLink;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get leaveGroupConfirm;

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get joinRequests;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get noPendingRequests;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get removeMember;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupCreated;

  /// No description provided for @editGroupName.
  ///
  /// In en, this message translates to:
  /// **'Edit group name'**
  String get editGroupName;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @followTopic.
  ///
  /// In en, this message translates to:
  /// **'Follow topic'**
  String get followTopic;

  /// No description provided for @unfollowTopic.
  ///
  /// In en, this message translates to:
  /// **'Unfollow topic'**
  String get unfollowTopic;

  /// No description provided for @hot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get hot;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @relatedTopics.
  ///
  /// In en, this message translates to:
  /// **'Related topics'**
  String get relatedTopics;

  /// No description provided for @muteTopic.
  ///
  /// In en, this message translates to:
  /// **'Mute topic'**
  String get muteTopic;

  /// No description provided for @unmuteTopic.
  ///
  /// In en, this message translates to:
  /// **'Unmute topic'**
  String get unmuteTopic;

  /// No description provided for @topicMuted.
  ///
  /// In en, this message translates to:
  /// **'Topic muted'**
  String get topicMuted;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @noDrafts.
  ///
  /// In en, this message translates to:
  /// **'No drafts'**
  String get noDrafts;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get deleteDraft;

  /// No description provided for @deleteDraftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this draft?'**
  String get deleteDraftConfirm;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @draftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get draftDeleted;

  /// No description provided for @loadDraft.
  ///
  /// In en, this message translates to:
  /// **'Load draft'**
  String get loadDraft;

  /// No description provided for @communities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get communities;

  /// No description provided for @communityDetail.
  ///
  /// In en, this message translates to:
  /// **'Community Detail'**
  String get communityDetail;

  /// No description provided for @communityMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembers;

  /// No description provided for @communityPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get communityPosts;

  /// No description provided for @joinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinCommunity;

  /// No description provided for @leaveCommunity.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveCommunity;

  /// No description provided for @leaveCommunityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this community?'**
  String get leaveCommunityConfirm;

  /// No description provided for @noCommunities.
  ///
  /// In en, this message translates to:
  /// **'No communities'**
  String get noCommunities;

  /// No description provided for @noCommunityMembers.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get noCommunityMembers;

  /// No description provided for @noCommunityPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noCommunityPosts;

  /// No description provided for @setChampion.
  ///
  /// In en, this message translates to:
  /// **'Set as champion'**
  String get setChampion;

  /// No description provided for @removeChampion.
  ///
  /// In en, this message translates to:
  /// **'Remove champion'**
  String get removeChampion;

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get searchMembers;

  /// No description provided for @recentPosts.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentPosts;

  /// No description provided for @topPosts.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get topPosts;

  /// No description provided for @accountControls.
  ///
  /// In en, this message translates to:
  /// **'Account Controls'**
  String get accountControls;

  /// No description provided for @mutedUsers.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get mutedUsers;

  /// No description provided for @restrictedUsers.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get restrictedUsers;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedUsers;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @unrestrict.
  ///
  /// In en, this message translates to:
  /// **'Unrestrict'**
  String get unrestrict;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @noMutedUsers.
  ///
  /// In en, this message translates to:
  /// **'No muted users'**
  String get noMutedUsers;

  /// No description provided for @noRestrictedUsers.
  ///
  /// In en, this message translates to:
  /// **'No restricted users'**
  String get noRestrictedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @createCollection.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get createCollection;

  /// No description provided for @collectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionName;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get deleteCollection;

  /// No description provided for @deleteCollectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this collection?'**
  String get deleteCollectionConfirm;

  /// No description provided for @noCollections.
  ///
  /// In en, this message translates to:
  /// **'No collections'**
  String get noCollections;

  /// No description provided for @defaultCollection.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultCollection;

  /// No description provided for @hiddenWords.
  ///
  /// In en, this message translates to:
  /// **'Hidden Words'**
  String get hiddenWords;

  /// No description provided for @keywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get keywords;

  /// No description provided for @phrases.
  ///
  /// In en, this message translates to:
  /// **'Phrases'**
  String get phrases;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @addWord.
  ///
  /// In en, this message translates to:
  /// **'Add word'**
  String get addWord;

  /// No description provided for @wordContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get wordContent;

  /// No description provided for @wordType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get wordType;

  /// No description provided for @deleteWord.
  ///
  /// In en, this message translates to:
  /// **'Delete word'**
  String get deleteWord;

  /// No description provided for @deleteWordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this hidden word?'**
  String get deleteWordConfirm;

  /// No description provided for @noHiddenWords.
  ///
  /// In en, this message translates to:
  /// **'No hidden words'**
  String get noHiddenWords;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLink;

  /// No description provided for @editLink.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get editLink;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get linkTitle;

  /// No description provided for @linkUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get linkUrl;

  /// No description provided for @deleteLink.
  ///
  /// In en, this message translates to:
  /// **'Delete link'**
  String get deleteLink;

  /// No description provided for @deleteLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this link?'**
  String get deleteLinkConfirm;

  /// No description provided for @noLinks.
  ///
  /// In en, this message translates to:
  /// **'No links'**
  String get noLinks;

  /// No description provided for @guestReplyReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest Replies'**
  String get guestReplyReviewTitle;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add Location'**
  String get addLocation;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter location name'**
  String get enterLocation;

  /// No description provided for @clearLocation.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLocation;

  /// No description provided for @scheduledPosts.
  ///
  /// In en, this message translates to:
  /// **'Scheduled posts'**
  String get scheduledPosts;

  /// No description provided for @noScheduledPosts.
  ///
  /// In en, this message translates to:
  /// **'No scheduled posts'**
  String get noScheduledPosts;

  /// No description provided for @cancelSchedule.
  ///
  /// In en, this message translates to:
  /// **'Cancel schedule'**
  String get cancelSchedule;

  /// No description provided for @editHistory.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get editHistory;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editPost;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deletePost;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post?'**
  String get deletePostConfirm;

  /// No description provided for @pinPost.
  ///
  /// In en, this message translates to:
  /// **'Pin to profile'**
  String get pinPost;

  /// No description provided for @unpinPost.
  ///
  /// In en, this message translates to:
  /// **'Unpin from profile'**
  String get unpinPost;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// No description provided for @postUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated'**
  String get postUpdated;

  /// No description provided for @nearbyPosts.
  ///
  /// In en, this message translates to:
  /// **'Nearby posts'**
  String get nearbyPosts;

  /// No description provided for @savedPosts.
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get savedPosts;

  /// No description provided for @noSavedPosts.
  ///
  /// In en, this message translates to:
  /// **'No saved posts'**
  String get noSavedPosts;

  /// No description provided for @postDetail.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postDetail;

  /// No description provided for @noRepliesYet.
  ///
  /// In en, this message translates to:
  /// **'No replies yet'**
  String get noRepliesYet;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String daysAgo(int count);

  /// No description provided for @notifiedLikedPost.
  ///
  /// In en, this message translates to:
  /// **'liked your post'**
  String get notifiedLikedPost;

  /// No description provided for @notifiedRepliedToYou.
  ///
  /// In en, this message translates to:
  /// **'replied to you'**
  String get notifiedRepliedToYou;

  /// No description provided for @notifiedFollowedYou.
  ///
  /// In en, this message translates to:
  /// **'followed you'**
  String get notifiedFollowedYou;

  /// No description provided for @notifiedMentionedYou.
  ///
  /// In en, this message translates to:
  /// **'mentioned you'**
  String get notifiedMentionedYou;

  /// No description provided for @notifiedRepostedPost.
  ///
  /// In en, this message translates to:
  /// **'reposted your post'**
  String get notifiedRepostedPost;

  /// No description provided for @notifiedQuotedPost.
  ///
  /// In en, this message translates to:
  /// **'quoted your post'**
  String get notifiedQuotedPost;

  /// No description provided for @filterLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get filterLikes;

  /// No description provided for @filterFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get filterFollows;

  /// No description provided for @quoteRepost.
  ///
  /// In en, this message translates to:
  /// **'Quote this post'**
  String get quoteRepost;

  /// No description provided for @quotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get quotePlaceholder;

  /// No description provided for @noThreadsYetOthers.
  ///
  /// In en, this message translates to:
  /// **'No threads yet.'**
  String get noThreadsYetOthers;

  /// No description provided for @nothingToSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save as draft'**
  String get nothingToSaveDraft;

  /// No description provided for @draftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save draft'**
  String get draftSaveFailed;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @saveDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Save this post as a draft or discard it?'**
  String get saveDraftHint;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @replyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} replies'**
  String replyCount(int count);

  /// No description provided for @repostCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reposts'**
  String repostCount(int count);

  /// No description provided for @failedApproveReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve reply.'**
  String get failedApproveReply;

  /// No description provided for @failedRejectReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject reply.'**
  String get failedRejectReply;

  /// No description provided for @pendingReplies.
  ///
  /// In en, this message translates to:
  /// **'Pending Replies'**
  String get pendingReplies;

  /// No description provided for @statFollowing.
  ///
  /// In en, this message translates to:
  /// **'following'**
  String get statFollowing;

  /// No description provided for @statFollowers.
  ///
  /// In en, this message translates to:
  /// **'followers'**
  String get statFollowers;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @addBio.
  ///
  /// In en, this message translates to:
  /// **'Add bio'**
  String get addBio;

  /// No description provided for @linkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkLabel;

  /// No description provided for @addLinkField.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLinkField;

  /// No description provided for @pronouns.
  ///
  /// In en, this message translates to:
  /// **'Pronouns'**
  String get pronouns;

  /// No description provided for @addPronouns.
  ///
  /// In en, this message translates to:
  /// **'Add pronouns'**
  String get addPronouns;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @addLocationField.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocationField;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @privateAccount.
  ///
  /// In en, this message translates to:
  /// **'Private Account'**
  String get privateAccount;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get changeAvatar;

  /// No description provided for @avatarVisibility.
  ///
  /// In en, this message translates to:
  /// **'Your avatar is visible to everyone'**
  String get avatarVisibility;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @cameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraLabel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @otherGender.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherGender;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @maxNameChars.
  ///
  /// In en, this message translates to:
  /// **'Max 100 characters'**
  String get maxNameChars;

  /// No description provided for @maxBioChars.
  ///
  /// In en, this message translates to:
  /// **'Max 500 characters for bio'**
  String get maxBioChars;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed, please retry'**
  String get updateFailed;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @groupChat.
  ///
  /// In en, this message translates to:
  /// **'Group Chat'**
  String get groupChat;

  /// No description provided for @pleaseEnterGroupName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get pleaseEnterGroupName;

  /// No description provided for @failedCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get failedCreateGroup;

  /// No description provided for @enterGroupNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get enterGroupNamePlaceholder;

  /// No description provided for @searchSelectUsers.
  ///
  /// In en, this message translates to:
  /// **'Search and select users to add'**
  String get searchSelectUsers;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @requireApproval.
  ///
  /// In en, this message translates to:
  /// **'Require Approval'**
  String get requireApproval;

  /// No description provided for @requireApprovalDesc.
  ///
  /// In en, this message translates to:
  /// **'New members need admin approval to join'**
  String get requireApprovalDesc;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite Link'**
  String get inviteLink;

  /// No description provided for @inviteLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow joining via an invite link'**
  String get inviteLinkDesc;

  /// No description provided for @noInviteLink.
  ///
  /// In en, this message translates to:
  /// **'No invite link available'**
  String get noInviteLink;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String memberCount(int count);

  /// No description provided for @createdDate.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String createdDate(String date);

  /// No description provided for @messageBtn.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageBtn;

  /// No description provided for @viewAllMembers.
  ///
  /// In en, this message translates to:
  /// **'View All Members'**
  String get viewAllMembers;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from this group?'**
  String removeMemberConfirm(String name);

  /// No description provided for @noMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get noMembersFound;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @requestedDate.
  ///
  /// In en, this message translates to:
  /// **'Requested {date}'**
  String requestedDate(String date);

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsersHint;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @noCommunitiesFound.
  ///
  /// In en, this message translates to:
  /// **'No communities found'**
  String get noCommunitiesFound;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirmUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteConfirmUndo;

  /// No description provided for @deleteNameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteNameConfirm(String name);

  /// No description provided for @failedCreateCollection.
  ///
  /// In en, this message translates to:
  /// **'Failed to create collection.'**
  String get failedCreateCollection;

  /// No description provided for @failedDeleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete collection.'**
  String get failedDeleteCollection;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New Collection'**
  String get newCollection;

  /// No description provided for @savedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String savedCount(int count);

  /// No description provided for @failedDeleteWord.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete word.'**
  String get failedDeleteWord;

  /// No description provided for @addHiddenWord.
  ///
  /// In en, this message translates to:
  /// **'Add Hidden Word'**
  String get addHiddenWord;

  /// No description provided for @keyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get keyword;

  /// No description provided for @phrase.
  ///
  /// In en, this message translates to:
  /// **'Phrase'**
  String get phrase;

  /// No description provided for @enterWordOrPhrase.
  ///
  /// In en, this message translates to:
  /// **'Enter word or phrase'**
  String get enterWordOrPhrase;

  /// No description provided for @failedAddWord.
  ///
  /// In en, this message translates to:
  /// **'Failed to add word.'**
  String get failedAddWord;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @failedDeleteLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete link.'**
  String get failedDeleteLink;

  /// No description provided for @failedAddLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to add link.'**
  String get failedAddLink;

  /// No description provided for @failedUpdateLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to update link.'**
  String get failedUpdateLink;

  /// No description provided for @failedRemoveUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove. Please try again.'**
  String get failedRemoveUser;

  /// No description provided for @mutedRestrictedBlocked.
  ///
  /// In en, this message translates to:
  /// **'Muted / Restricted / Blocked'**
  String get mutedRestrictedBlocked;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonLabel(String reason);

  /// No description provided for @seeAllMembers.
  ///
  /// In en, this message translates to:
  /// **'See all members'**
  String get seeAllMembers;

  /// No description provided for @noCollectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get noCollectionsYet;

  /// No description provided for @noLinksYet.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get noLinksYet;

  /// No description provided for @writeAReply.
  ///
  /// In en, this message translates to:
  /// **'Write a reply...'**
  String get writeAReply;

  /// No description provided for @pinReply.
  ///
  /// In en, this message translates to:
  /// **'Pin reply'**
  String get pinReply;

  /// No description provided for @unpinReply.
  ///
  /// In en, this message translates to:
  /// **'Unpin reply'**
  String get unpinReply;

  /// No description provided for @failedToPostReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to post reply'**
  String get failedToPostReply;

  /// No description provided for @failedToPinReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to pin reply'**
  String get failedToPinReply;

  /// No description provided for @failedToUnpinReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to unpin reply'**
  String get failedToUnpinReply;

  /// No description provided for @followRequests.
  ///
  /// In en, this message translates to:
  /// **'Follow Requests'**
  String get followRequests;

  /// No description provided for @noPendingFollowRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending follow requests'**
  String get noPendingFollowRequests;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;
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
