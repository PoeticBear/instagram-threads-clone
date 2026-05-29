// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Threads';

  @override
  String get search => 'Search';

  @override
  String get cancel => 'Cancel';

  @override
  String get post => 'Post';

  @override
  String get publishSuccess => 'Post successful';

  @override
  String get publishFailed => 'Post failed, please retry';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get anonymousUser => 'Anonymous user';

  @override
  String get whatsNew => 'What\'s new?';

  @override
  String get whoCanReply => 'Who can reply';

  @override
  String get everyoneCanReply => 'Everyone can reply';

  @override
  String get followersCanReply => 'Only followers can reply';

  @override
  String get followingCanReply => 'Only people you follow can reply';

  @override
  String get mentionedCanReply => 'Only mentioned people can reply';

  @override
  String get newPost => 'New post';

  @override
  String get saySomething => 'Say something...';

  @override
  String get addOption => 'Add option';

  @override
  String get removePoll => 'Remove poll';

  @override
  String optionLabel(int number) {
    return 'Option $number';
  }

  @override
  String get searchTop => 'Top';

  @override
  String get searchUsers => 'Users';

  @override
  String get searchTopics => 'Topics';

  @override
  String get searchPosts => 'Posts';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get recent => 'Recent';

  @override
  String get clearAll => 'Clear all';

  @override
  String get trendingTopics => 'Trending topics';

  @override
  String get trendingPosts => 'Trending posts';

  @override
  String get seeAllUsers => 'See all users';

  @override
  String get seeAllTopics => 'See all topics';

  @override
  String get loginTitle => 'Login';

  @override
  String get usernameHint => 'Username';

  @override
  String get passwordHint => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get or => 'or';

  @override
  String get loginWithInstagram => 'Login with Instagram';

  @override
  String get createNewAccount => 'Create new account';

  @override
  String get pleaseEnterUsernameAndPassword =>
      'Please enter username and password';

  @override
  String get loginFailedCheckCredentials =>
      'Login failed, please check username and password';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get followAndInviteFriends => 'Follow and invite friends';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacy => 'Privacy';

  @override
  String get help => 'Help';

  @override
  String get about => 'About';

  @override
  String get logOut => 'Log out';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get back => 'Back';

  @override
  String get searchTitle => 'Search';

  @override
  String get tabTop => 'Top';

  @override
  String get tabUsers => 'Users';

  @override
  String get tabTopics => 'Topics';

  @override
  String get tabPosts => 'Posts';

  @override
  String get sectionUsers => 'Users';

  @override
  String get sectionTopics => 'Topics';

  @override
  String get sectionPosts => 'Posts';

  @override
  String get activityTitle => 'Activity';

  @override
  String get filterAll => 'All';

  @override
  String get filterReplies => 'Replies';

  @override
  String get filterMentions => 'Mentions';

  @override
  String get filterVerify => 'Verify';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get shareProfile => 'Share profile';

  @override
  String get tabThreads => 'Threads';

  @override
  String get tabReplies => 'Replies';

  @override
  String get noThreadsYet => 'You haven\'t posted any threads yet.';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notifyLikes => 'Likes';

  @override
  String get notifyReplies => 'Replies';

  @override
  String get notifyMentions => 'Mentions';

  @override
  String get notifyFollows => 'Follows';

  @override
  String get notifyTrending => 'Trending';

  @override
  String get notifySystem => 'System';

  @override
  String get notifyGroupMessages => 'Group Messages';

  @override
  String get notifyQuotes => 'Quotes';

  @override
  String get notifyReposts => 'Reposts';

  @override
  String get notifyPolls => 'Polls';

  @override
  String get notifyCommunities => 'Communities';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get whoCanReplyToYou => 'Who can reply to you';

  @override
  String get whoCanMentionYou => 'Who can mention you';

  @override
  String get messageRequests => 'Message requests';

  @override
  String get messageRequestAllowType => 'Who can send message requests';

  @override
  String get interactionRestriction => 'Interaction restriction';

  @override
  String get showReadReceipts => 'Show read receipts';

  @override
  String get showOnlineStatus => 'Show online status';

  @override
  String get allowRecommend => 'Allow account recommendations';

  @override
  String get hideLikesCount => 'Hide likes count';

  @override
  String get silentMode => 'Silent mode';

  @override
  String get contentRating => 'Content rating';

  @override
  String get replyEveryone => 'Everyone';

  @override
  String get replyFollowers => 'Followers';

  @override
  String get replyPagesYouFollow => 'Pages you follow';

  @override
  String get replyMentioned => 'Mentioned only';

  @override
  String get mentionEveryone => 'Everyone';

  @override
  String get mentionUsersYouFollow => 'Users you follow';

  @override
  String get mentionMutuals => 'Mutuals only';

  @override
  String get msgReqAnyone => 'Anyone';

  @override
  String get msgReqFollowedOnly => 'Only users you follow';

  @override
  String get restrictionNone => 'None';

  @override
  String get restrictionFollowedOneWeek => 'Followed > 1 week';

  @override
  String get restrictionMutualsOnly => 'Mutuals only';

  @override
  String get ratingAll => 'All';

  @override
  String get ratingTeen => 'Teen';

  @override
  String get ratingAdult => 'Adult';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get replies => 'Replies';

  @override
  String get reply => 'Reply';

  @override
  String get repost => 'Repost';

  @override
  String get undoRepost => 'Undo repost';

  @override
  String get quote => 'Quote';

  @override
  String get save => 'Save';

  @override
  String get unsave => 'Unsave';

  @override
  String get share => 'Share';

  @override
  String get copyLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get report => 'Report';

  @override
  String get notInterested => 'Not interested';

  @override
  String get follow => 'Follow';

  @override
  String get unfollow => 'Unfollow';

  @override
  String get followers => 'Followers';

  @override
  String get following => 'Following';

  @override
  String get posts => 'Posts';

  @override
  String get linkCopiedToClipboard => 'Link copied to clipboard';

  @override
  String get replyToPost => 'Reply to post...';

  @override
  String get commentsComingSoon => 'Comments coming soon';

  @override
  String get messages => 'Messages';

  @override
  String get allMessages => 'All messages';

  @override
  String get noConversations => 'No conversations';

  @override
  String get noMessageRequests => 'No message requests';

  @override
  String get newMessage => 'New message';

  @override
  String get searchForUser => 'Search for a user to start chatting';

  @override
  String get messagePlaceholder => 'Message...';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get quotedMessage => 'Quoted message';

  @override
  String get videoMessage => 'Video message';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get fileMessage => 'File';

  @override
  String get createGroup => 'Create group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupAvatar => 'Group avatar';

  @override
  String get needApprove => 'Need approval';

  @override
  String get inviteLinkEnabled => 'Invite link enabled';

  @override
  String get create => 'Create';

  @override
  String get groupInfo => 'Group info';

  @override
  String get members => 'Members';

  @override
  String get copyInviteLink => 'Copy invite link';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveGroupConfirm => 'Are you sure you want to leave this group?';

  @override
  String get joinRequests => 'Join requests';

  @override
  String get noPendingRequests => 'No pending requests';

  @override
  String get approve => 'Approve';

  @override
  String get decline => 'Decline';

  @override
  String get removeMember => 'Remove member';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Member';

  @override
  String get groupCreated => 'Group created';

  @override
  String get editGroupName => 'Edit group name';

  @override
  String get topic => 'Topic';

  @override
  String get followTopic => 'Follow topic';

  @override
  String get unfollowTopic => 'Unfollow topic';

  @override
  String get hot => 'Hot';

  @override
  String get latest => 'Latest';

  @override
  String get relatedTopics => 'Related topics';

  @override
  String get muteTopic => 'Mute topic';

  @override
  String get unmuteTopic => 'Unmute topic';

  @override
  String get topicMuted => 'Topic muted';

  @override
  String get drafts => 'Drafts';

  @override
  String get noDrafts => 'No drafts';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get deleteDraft => 'Delete draft';

  @override
  String get deleteDraftConfirm =>
      'Are you sure you want to delete this draft?';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draftDeleted => 'Draft deleted';

  @override
  String get loadDraft => 'Load draft';

  @override
  String get communities => 'Communities';

  @override
  String get communityDetail => 'Community Detail';

  @override
  String get communityMembers => 'Members';

  @override
  String get communityPosts => 'Posts';

  @override
  String get joinCommunity => 'Join';

  @override
  String get leaveCommunity => 'Leave';

  @override
  String get leaveCommunityConfirm =>
      'Are you sure you want to leave this community?';

  @override
  String get noCommunities => 'No communities';

  @override
  String get noCommunityMembers => 'No members';

  @override
  String get noCommunityPosts => 'No posts yet';

  @override
  String get setChampion => 'Set as champion';

  @override
  String get removeChampion => 'Remove champion';

  @override
  String get searchMembers => 'Search members';

  @override
  String get recentPosts => 'Recent';

  @override
  String get topPosts => 'Top';

  @override
  String get accountControls => 'Account Controls';

  @override
  String get mutedUsers => 'Muted';

  @override
  String get restrictedUsers => 'Restricted';

  @override
  String get blockedUsers => 'Blocked';

  @override
  String get unmute => 'Unmute';

  @override
  String get unrestrict => 'Unrestrict';

  @override
  String get unblock => 'Unblock';

  @override
  String get noMutedUsers => 'No muted users';

  @override
  String get noRestrictedUsers => 'No restricted users';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String get collections => 'Collections';

  @override
  String get createCollection => 'Create collection';

  @override
  String get collectionName => 'Collection name';

  @override
  String get deleteCollection => 'Delete collection';

  @override
  String get deleteCollectionConfirm =>
      'Are you sure you want to delete this collection?';

  @override
  String get noCollections => 'No collections';

  @override
  String get defaultCollection => 'Default';

  @override
  String get hiddenWords => 'Hidden Words';

  @override
  String get keywords => 'Keywords';

  @override
  String get phrases => 'Phrases';

  @override
  String get emoji => 'Emoji';

  @override
  String get addWord => 'Add word';

  @override
  String get wordContent => 'Content';

  @override
  String get wordType => 'Type';

  @override
  String get deleteWord => 'Delete word';

  @override
  String get deleteWordConfirm =>
      'Are you sure you want to delete this hidden word?';

  @override
  String get noHiddenWords => 'No hidden words';

  @override
  String get links => 'Links';

  @override
  String get addLink => 'Add link';

  @override
  String get editLink => 'Edit link';

  @override
  String get linkTitle => 'Title';

  @override
  String get linkUrl => 'URL';

  @override
  String get deleteLink => 'Delete link';

  @override
  String get deleteLinkConfirm => 'Are you sure you want to delete this link?';

  @override
  String get noLinks => 'No links';

  @override
  String get guestReplyReviewTitle => 'Guest Replies';

  @override
  String get reject => 'Reject';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get addLocation => 'Add Location';

  @override
  String get enterLocation => 'Enter location name';

  @override
  String get clearLocation => 'Clear';

  @override
  String get scheduledPosts => 'Scheduled posts';

  @override
  String get noScheduledPosts => 'No scheduled posts';

  @override
  String get cancelSchedule => 'Cancel schedule';

  @override
  String get editHistory => 'Edit history';

  @override
  String get editPost => 'Edit';

  @override
  String get deletePost => 'Delete';

  @override
  String get deletePostConfirm => 'Are you sure you want to delete this post?';

  @override
  String get pinPost => 'Pin to profile';

  @override
  String get unpinPost => 'Unpin from profile';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get postUpdated => 'Post updated';

  @override
  String get nearbyPosts => 'Nearby posts';

  @override
  String get savedPosts => 'Saved posts';

  @override
  String get noSavedPosts => 'No saved posts';

  @override
  String get postDetail => 'Post';

  @override
  String get noRepliesYet => 'No replies yet';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h';
  }

  @override
  String daysAgo(int count) {
    return '${count}d';
  }

  @override
  String get notifiedLikedPost => 'liked your post';

  @override
  String get notifiedRepliedToYou => 'replied to you';

  @override
  String get notifiedFollowedYou => 'followed you';

  @override
  String get notifiedMentionedYou => 'mentioned you';

  @override
  String get notifiedRepostedPost => 'reposted your post';

  @override
  String get notifiedQuotedPost => 'quoted your post';

  @override
  String get filterLikes => 'Likes';

  @override
  String get filterFollows => 'Follows';

  @override
  String get quoteRepost => 'Quote this post';

  @override
  String get quotePlaceholder => 'Add a comment...';

  @override
  String get noThreadsYetOthers => 'No threads yet.';
}
