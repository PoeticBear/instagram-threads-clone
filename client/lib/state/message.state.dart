import 'dart:async';

import 'package:flutter/material.dart';
import '../model/message.module.dart';
import '../services/message_service.dart';
import '../common/locator.dart';

class MessageState extends ChangeNotifier {
  MessageService? _messageService;
  MessageService get messageService {
    _messageService ??= MessageService(apiClient: getIt());
    return _messageService!;
  }

  // ========== 会话列表 ==========
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;
  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;
  int _conversationPage = 1;
  bool _hasMoreConversations = true;
  bool get hasMoreConversations => _hasMoreConversations;

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _conversationPage = 1;
    _hasMoreConversations = true;
    notifyListeners();
    try {
      _conversations = await messageService.getConversations(page: 1);
      _conversationPage = 1;
      if (_conversations.length < 20) _hasMoreConversations = false;
    } catch (_) {}
    _isLoadingConversations = false;
    notifyListeners();
  }

  Future<void> loadMoreConversations() async {
    if (_isLoadingConversations || !_hasMoreConversations) return;
    _isLoadingConversations = true;
    notifyListeners();
    try {
      _conversationPage++;
      final more =
          await messageService.getConversations(page: _conversationPage);
      if (more.isEmpty) {
        _hasMoreConversations = false;
        _conversationPage--;
      } else {
        _conversations.addAll(more);
      }
    } catch (_) {
      _conversationPage--;
    }
    _isLoadingConversations = false;
    notifyListeners();
  }

  // ========== 当前聊天消息 ==========
  List<ChatMessage> _currentMessages = [];
  List<ChatMessage> get currentMessages => _currentMessages;
  int _currentConversationId = 0;
  int get currentConversationId => _currentConversationId;
  bool _isLoadingMessages = false;
  bool get isLoadingMessages => _isLoadingMessages;
  int _messagePage = 1;
  bool _hasMoreMessages = true;
  bool get hasMoreMessages => _hasMoreMessages;

  Future<void> loadMessages(int conversationId) async {
    _isLoadingMessages = true;
    _currentConversationId = conversationId;
    _messagePage = 1;
    _hasMoreMessages = true;
    notifyListeners();
    try {
      _currentMessages =
          await messageService.getMessages(conversationId);
      if (_currentMessages.length < 20) _hasMoreMessages = false;
      // 自动标记已读（标记当前已加载消息的 ID）
      if (_currentMessages.isNotEmpty) {
        final messageIds =
            _currentMessages.map((m) => m.id).where((id) => id > 0).toList();
        if (messageIds.isNotEmpty) {
          messageService.markAsRead(messageIds);
        }
      }
      // 更新会话列表中对应会话的未读数
      final idx =
          _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        // unreadCount 不变（Conversation 是 immutable，不修改）
      }
    } catch (_) {}
    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<void> loadMoreMessages() async {
    if (_isLoadingMessages || !_hasMoreMessages) return;
    _isLoadingMessages = true;
    notifyListeners();
    try {
      _messagePage++;
      final more = await messageService.getMessages(
        _currentConversationId,
        page: _messagePage,
      );
      if (more.isEmpty) {
        _hasMoreMessages = false;
        _messagePage--;
      } else {
        _currentMessages.addAll(more);
      }
    } catch (_) {
      _messagePage--;
    }
    _isLoadingMessages = false;
    notifyListeners();
  }

  // ========== 发送消息（乐观更新）==========
  bool _isSending = false;
  bool get isSending => _isSending;

  Future<void> sendMessage({
    required int receiverId,
    required String content,
    int mediaType = 0,
    String? mediaUrl,
    int? quoteMessageId,
  }) async {
    _isSending = true;
    notifyListeners();

    // 乐观插入本地消息（deliveryStatus=1 发送中）
    final optimisticMsg = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch, // 临时负 ID
      senderId: 0, // 当前用户 ID 暂不填充
      receiverId: receiverId,
      content: content,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      deliveryStatus: 1,
      createTime: DateTime.now().toIso8601String(),
    );
    _currentMessages.insert(0, optimisticMsg);
    notifyListeners();

    try {
      final sentResponse = await messageService.sendMessage(
        receiverId: receiverId,
        content: content,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        quoteMessageId: quoteMessageId,
      );
      // 替换乐观消息：用服务端返回的 messageId 更新临时消息
      final idx = _currentMessages
          .indexWhere((m) => m.id == optimisticMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = ChatMessage(
          id: sentResponse.messageId,
          senderId: optimisticMsg.senderId,
          receiverId: receiverId,
          content: content,
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          deliveryStatus: 2, // 2=已送达
          createTime: optimisticMsg.createTime,
        );
      }
      // 新会话场景：用服务端返回的 conversationId 替换临时负 ID
      if (_currentConversationId < 0) {
        _currentConversationId = sentResponse.conversationId;
      }
    } catch (_) {
      // 标记发送失败
      final idx = _currentMessages
          .indexWhere((m) => m.id == optimisticMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = ChatMessage(
          id: optimisticMsg.id,
          senderId: optimisticMsg.senderId,
          receiverId: optimisticMsg.receiverId,
          content: optimisticMsg.content,
          mediaType: optimisticMsg.mediaType,
          deliveryStatus: 3, // 3=发送失败
          createTime: optimisticMsg.createTime,
        );
      }
    }
    _isSending = false;
    notifyListeners();
  }

  // ========== 消息反应 ==========
  Future<void> addReaction(int messageId, String emoji) async {
    try {
      await messageService.addReaction(
          messageId: messageId, emoji: emoji);
      // 乐观更新
      final idx =
          _currentMessages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        // 由于 ChatMessage 是 immutable，需要重建（简化处理）
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeReaction(int messageId, String emoji) async {
    try {
      await messageService.removeReaction(
          messageId: messageId, emoji: emoji);
    } catch (_) {}
    notifyListeners();
  }

  // ========== 陌生人消息 ==========
  List<Conversation> _strangerConversations = [];
  List<Conversation> get strangerConversations => _strangerConversations;
  bool _isLoadingStrangers = false;
  bool get isLoadingStrangers => _isLoadingStrangers;

  Future<void> loadStrangerConversations() async {
    _isLoadingStrangers = true;
    notifyListeners();
    try {
      _strangerConversations = await messageService.getConversations(
        conversationType: 2,
      );
    } catch (_) {
      _strangerConversations = [];
    }
    _isLoadingStrangers = false;
    notifyListeners();
  }

  // ========== 会话操作 ==========
  Future<void> verifyConversation(int conversationId) async {
    try {
      await messageService.verifyConversation(conversationId);
      // 更新本地会话列表中对应会话的 isVerified 状态
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        final old = _conversations[idx];
        _conversations[idx] = Conversation(
          id: old.id,
          peerUserId: old.peerUserId,
          peerUsername: old.peerUsername,
          peerDisplayName: old.peerDisplayName,
          peerAvatarUrl: old.peerAvatarUrl,
          conversationType: old.conversationType,
          lastMessageContent: old.lastMessageContent,
          lastMessageTime: old.lastMessageTime,
          unreadCount: old.unreadCount,
          isReplied: old.isReplied,
          isVerified: true,
          isHidden: old.isHidden,
          isPinned: old.isPinned,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pinConversation(int conversationId) async {
    try {
      await messageService.pinConversation(conversationId);
      await loadConversations(); // 刷新列表
    } catch (_) {}
  }

  Future<void> unpinConversation(int conversationId) async {
    try {
      await messageService.unpinConversation(conversationId);
      await loadConversations();
    } catch (_) {}
  }

  Future<void> hideConversation(int conversationId) async {
    try {
      await messageService.hideConversation(conversationId);
      _conversations
          .removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (_) {}
  }

  // ========== 群聊 ==========
  List<GroupChat> _groupChats = [];
  List<GroupChat> get groupChats => _groupChats;
  GroupChat? _currentGroupChat;
  GroupChat? get currentGroupChat => _currentGroupChat;
  List<GroupMember> _groupMembers = [];
  List<GroupMember> get groupMembers => _groupMembers;
  bool _isLoadingGroupMembers = false;
  bool get isLoadingGroupMembers => _isLoadingGroupMembers;

  Future<void> loadGroupChats() async {
    try {
      _groupChats = await messageService.getGroupChats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createGroupChat(String name,
      {String? avatarUrl, List<int> memberIds = const [], bool needApprove = false}) async {
    try {
      final group = await messageService.createGroupChat(
          name: name, avatarUrl: avatarUrl, memberIds: memberIds, needApprove: needApprove);
      _groupChats.insert(0, group);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadGroupDetail(int groupId) async {
    try {
      _currentGroupChat =
          await messageService.getGroupChatDetail(groupId);
      notifyListeners();
    } catch (_) {}
  }

  /// Alias for loadGroupDetail - loads group chat detail
  Future<void> loadGroupChatDetail(int groupId) async {
    await loadGroupDetail(groupId);
  }

  Future<void> updateGroupChat(
    int groupId, {
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final updated = await messageService.updateGroupChat(
        groupId,
        name: name,
        avatarUrl: avatarUrl,
      );
      _currentGroupChat = updated;
      final idx = _groupChats.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        _groupChats[idx] = updated;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateGroupChatSettings(
    int groupId, {
    bool? needApprove,
    bool? inviteLinkEnabled,
  }) async {
    try {
      final updated = await messageService.updateGroupChatSettings(
        groupId,
        needApprove: needApprove,
        inviteLinkEnabled: inviteLinkEnabled,
      );
      _currentGroupChat = updated;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadGroupMembers(int groupId) async {
    _isLoadingGroupMembers = true;
    notifyListeners();
    try {
      _groupMembers =
          await messageService.getGroupMembers(groupId);
    } catch (_) {
      _groupMembers = [];
    }
    _isLoadingGroupMembers = false;
    notifyListeners();
  }

  Future<void> removeGroupMember({
    required int groupId,
    required int userId,
  }) async {
    try {
      await messageService.removeGroupMember(groupId, userId);
      _groupMembers.removeWhere((m) => m.userId == userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> leaveGroupChat(int groupId) async {
    try {
      await messageService.leaveGroupChat(groupId);
      _groupChats.removeWhere((g) => g.id == groupId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> joinGroupChat({required String inviteLink}) async {
    try {
      final group = await messageService.joinGroupChat(inviteLink: inviteLink);
      _groupChats.insert(0, group);
      notifyListeners();
    } catch (_) {}
  }

  // ========== 群聊消息 ==========
  Future<void> loadGroupChatMessages(int groupId) async {
    _isLoadingMessages = true;
    _currentConversationId = groupId;
    _messagePage = 1;
    _hasMoreMessages = true;
    notifyListeners();
    try {
      _currentMessages = await messageService.getGroupChatMessages(groupId);
      if (_currentMessages.length < 20) _hasMoreMessages = false;
    } catch (_) {}
    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<void> loadMoreGroupChatMessages(int groupId) async {
    if (_isLoadingMessages || !_hasMoreMessages) return;
    _isLoadingMessages = true;
    notifyListeners();
    try {
      _messagePage++;
      final more = await messageService.getGroupChatMessages(
        groupId,
        page: _messagePage,
      );
      if (more.isEmpty) {
        _hasMoreMessages = false;
        _messagePage--;
      } else {
        _currentMessages.addAll(more);
      }
    } catch (_) {
      _messagePage--;
    }
    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<void> sendGroupChatMessage({
    required int groupId,
    required String content,
    int mediaType = 0,
    String? mediaUrl,
  }) async {
    _isSending = true;
    notifyListeners();

    final optimisticMsg = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      senderId: 0,
      receiverId: groupId,
      content: content,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      deliveryStatus: 1,
      createTime: DateTime.now().toIso8601String(),
    );
    _currentMessages.insert(0, optimisticMsg);
    notifyListeners();

    try {
      final sentResponse = await messageService.sendGroupChatMessage(
        groupId: groupId,
        content: content,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
      );
      final idx = _currentMessages
          .indexWhere((m) => m.id == optimisticMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = ChatMessage(
          id: sentResponse.messageId,
          senderId: optimisticMsg.senderId,
          receiverId: groupId,
          content: content,
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          deliveryStatus: 2,
          createTime: optimisticMsg.createTime,
        );
      }
    } catch (_) {
      final idx = _currentMessages
          .indexWhere((m) => m.id == optimisticMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = ChatMessage(
          id: optimisticMsg.id,
          senderId: optimisticMsg.senderId,
          receiverId: optimisticMsg.receiverId,
          content: optimisticMsg.content,
          mediaType: optimisticMsg.mediaType,
          deliveryStatus: 3,
          createTime: optimisticMsg.createTime,
        );
      }
    }
    _isSending = false;
    notifyListeners();
  }

  // ========== 入群申请 ==========
  List<Map<String, dynamic>> _joinRequests = [];
  List<Map<String, dynamic>> get joinRequests => _joinRequests;
  bool _isLoadingJoinRequests = false;
  bool get isLoadingJoinRequests => _isLoadingJoinRequests;

  Future<void> loadJoinRequests(int groupId) async {
    _isLoadingJoinRequests = true;
    notifyListeners();
    try {
      _joinRequests = await messageService.getJoinRequests(groupId);
    } catch (_) {
      _joinRequests = [];
    }
    _isLoadingJoinRequests = false;
    notifyListeners();
  }

  Future<void> approveJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    try {
      await messageService.approveJoinRequest(
          groupId: groupId, requestId: requestId);
      _joinRequests.removeWhere((r) => r['id'] == requestId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> rejectJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    try {
      await messageService.rejectJoinRequest(
          groupId: groupId, requestId: requestId);
      _joinRequests.removeWhere((r) => r['id'] == requestId);
      notifyListeners();
    } catch (_) {}
  }

  // ========== 消息搜索 ==========
  List<ChatMessage> _searchResults = [];
  List<ChatMessage> get searchResults => _searchResults;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  Future<void> searchMessages(String keyword) async {
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults =
          await messageService.searchMessages(keyword: keyword);
    } catch (_) {
      _searchResults = [];
    }
    _isSearching = false;
    notifyListeners();
  }

  // ========== 消息设置 ==========
  MessageSettings _messageSettings = MessageSettings();
  MessageSettings get messageSettings => _messageSettings;

  Future<void> loadMessageSettings() async {
    try {
      _messageSettings = await messageService.getMessageSettings();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateMessageSettings(MessageSettings settings) async {
    final old = _messageSettings;
    _messageSettings = settings;
    notifyListeners();
    try {
      await messageService.updateMessageSettings(settings);
    } catch (_) {
      _messageSettings = old;
      notifyListeners();
    }
  }

  // ========== 推荐用户 / 搜索用户 ==========
  List<Map<String, dynamic>> _recommendUsers = [];
  List<Map<String, dynamic>> get recommendUsers => _recommendUsers;

  Future<void> loadRecommendUsers() async {
    try {
      _recommendUsers = await messageService.getRecommendUsers();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> searchChatUsers(
      String keyword) async {
    try {
      return await messageService.searchChatUsers(
          keyword: keyword);
    } catch (_) {
      return [];
    }
  }

  // ========== 隐藏会话 ==========
  List<Conversation> _hiddenConversations = [];
  List<Conversation> get hiddenConversations =>
      _hiddenConversations;

  Future<void> loadHiddenConversations() async {
    try {
      _hiddenConversations =
          await messageService.getHiddenConversations();
      notifyListeners();
    } catch (_) {}
  }

  // ============================================================
  // WebSocket 事件入口(由 ws_handlers/ 调用)
  // ============================================================

  /// typing 状态:conversationId → 最近一次收到 typing event 的时间。
  /// UI 据此渲染"正在输入..."。3 秒无新 event 自动清空(由 [_typingCleanupTimer] 驱动)。
  final Map<int, DateTime> _typingByConversation = {};
  Map<int, DateTime> get typingByConversation => _typingByConversation;
  Timer? _typingCleanupTimer;

  /// `message_typing` 事件入口。
  /// 收到即刷新对应会话的 typing 时间戳;[expireAfter] 后无新 event 自动清空全部 typing。
  void handleTypingEvent({
    required int conversationId,
    required int userId,
    required Duration expireAfter,
  }) {
    _typingByConversation[conversationId] = DateTime.now();
    notifyListeners();
    _typingCleanupTimer?.cancel();
    _typingCleanupTimer = Timer(expireAfter, () {
      if (_typingByConversation.isEmpty) return;
      _typingByConversation.clear();
      notifyListeners();
    });
  }

  /// `message_read` 事件入口:对端读了我们发的消息。
  /// 把对应 message 的 isRead 置 true;会话未读数 -1(下限 0)。
  void handleReadEvent({required int messageId, int? conversationId}) {
    final idx = _currentMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final old = _currentMessages[idx];
      if (!old.isRead) {
        _currentMessages[idx] = ChatMessage(
          id: old.id,
          senderId: old.senderId,
          receiverId: old.receiverId,
          content: old.content,
          mediaType: old.mediaType,
          mediaUrl: old.mediaUrl,
          isRead: true,
          deliveryStatus: old.deliveryStatus,
          readTime: DateTime.now().toIso8601String(),
          quoteMessageId: old.quoteMessageId,
          reactions: old.reactions,
          createTime: old.createTime,
        );
      }
    }
    if (conversationId != null) {
      final cIdx = _conversations.indexWhere((c) => c.id == conversationId);
      if (cIdx != -1) {
        final old = _conversations[cIdx];
        if (old.unreadCount > 0) {
          _conversations[cIdx] = Conversation(
            id: old.id,
            peerUserId: old.peerUserId,
            peerUsername: old.peerUsername,
            peerDisplayName: old.peerDisplayName,
            peerAvatarUrl: old.peerAvatarUrl,
            conversationType: old.conversationType,
            lastMessageContent: old.lastMessageContent,
            lastMessageTime: old.lastMessageTime,
            unreadCount: old.unreadCount - 1,
            isReplied: old.isReplied,
            isVerified: old.isVerified,
            isHidden: old.isHidden,
            isPinned: old.isPinned,
          );
        }
      }
    }
    notifyListeners();
  }

  /// `message_reaction` 事件入口:对端加减 emoji 反应。
  /// action=='add' 时去重(同 user + 同 emoji 不重复加),其他情况视为 remove。
  void handleReactionEvent({
    required int messageId,
    required String emoji,
    required String action,
    required int userId,
  }) {
    final idx = _currentMessages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final old = _currentMessages[idx];
    final reactions = List<MessageReaction>.from(old.reactions);
    if (action == 'add') {
      final exists =
          reactions.any((r) => r.emoji == emoji && r.userId == userId);
      if (!exists) {
        reactions.add(MessageReaction(emoji: emoji, userId: userId));
      }
    } else {
      reactions.removeWhere((r) => r.emoji == emoji && r.userId == userId);
    }
    _currentMessages[idx] = ChatMessage(
      id: old.id,
      senderId: old.senderId,
      receiverId: old.receiverId,
      content: old.content,
      mediaType: old.mediaType,
      mediaUrl: old.mediaUrl,
      isRead: old.isRead,
      deliveryStatus: old.deliveryStatus,
      readTime: old.readTime,
      quoteMessageId: old.quoteMessageId,
      reactions: reactions,
      createTime: old.createTime,
    );
    notifyListeners();
  }

  /// `group_message` 事件入口:群里来新消息。
  ///
  /// 当前打开的群会话 → insert 到列表头;否则暂不增量未读(GroupChat 无 unreadCount 字段,
  /// TODO(ws): 等服务端给 GroupChat 加 unread_count,或本地维护 Map<int,int> groupIdToUnread)。
  void handleGroupMessageEvent({
    required int groupId,
    required Map<String, dynamic> messageJson,
  }) {
    try {
      final msg = ChatMessage.fromJson(messageJson);
      if (_currentConversationId == groupId) {
        _currentMessages.insert(0, msg);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('handleGroupMessageEvent parse failed: $e');
    }
  }

  @override
  void dispose() {
    _typingCleanupTimer?.cancel();
    super.dispose();
  }
}
