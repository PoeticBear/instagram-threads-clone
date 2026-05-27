import 'package:flutter/material.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

class SettingsState extends ChangeNotifier {
  UserSettings _settings = UserSettings();
  UserSettings get settings => _settings;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  UserService? _userService;
  UserService get userService {
    _userService ??= UserService(apiClient: getIt());
    return _userService!;
  }

  Future<void> loadSettings() async {
    try {
      _isBusy = true;
      notifyListeners();
      _settings = await userService.getSettings();
      _isBusy = false;
      notifyListeners();
    } catch (_) {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateSetting(String key, int value) async {
    try {
      // Optimistic update
      final newSettings = _copyWithKey(key, value);
      _settings = newSettings;
      notifyListeners();

      await userService.updateSettings(newSettings);
    } catch (_) {
      // Reload on error to revert
      await loadSettings();
    }
  }

  UserSettings _copyWithKey(String key, int value) {
    switch (key) {
      case 'reply_allow_type':
        return _settings.copyWith(replyAllowType: value);
      case 'mention_allow_type':
        return _settings.copyWith(mentionAllowType: value);
      case 'message_request_enabled':
        return _settings.copyWith(messageRequestEnabled: value);
      case 'message_request_allow_type':
        return _settings.copyWith(messageRequestAllowType: value);
      case 'notify_likes':
        return _settings.copyWith(notifyLikes: value);
      case 'notify_replies':
        return _settings.copyWith(notifyReplies: value);
      case 'notify_mentions':
        return _settings.copyWith(notifyMentions: value);
      case 'notify_follows':
        return _settings.copyWith(notifyFollows: value);
      case 'notify_trending':
        return _settings.copyWith(notifyTrending: value);
      case 'notify_system':
        return _settings.copyWith(notifySystem: value);
      case 'notify_group_messages':
        return _settings.copyWith(notifyGroupMessages: value);
      case 'notify_quotes':
        return _settings.copyWith(notifyQuotes: value);
      case 'notify_reposts':
        return _settings.copyWith(notifyReposts: value);
      case 'notify_polls':
        return _settings.copyWith(notifyPolls: value);
      case 'notify_communities':
        return _settings.copyWith(notifyCommunities: value);
      case 'show_read_receipts':
        return _settings.copyWith(showReadReceipts: value);
      case 'show_online_status':
        return _settings.copyWith(showOnlineStatus: value);
      case 'allow_recommend':
        return _settings.copyWith(allowRecommend: value);
      case 'hide_likes_count':
        return _settings.copyWith(hideLikesCount: value);
      case 'interaction_restriction_type':
        return _settings.copyWith(interactionRestrictionType: value);
      case 'silent_mode':
        return _settings.copyWith(silentMode: value);
      case 'content_rating':
        return _settings.copyWith(contentRating: value);
      default:
        return _settings;
    }
  }
}
