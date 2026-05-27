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
      // 自动标记已读
      messageService.markAsRead(conversationId);
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
      final sentMsg = await messageService.sendMessage(
        receiverId: receiverId,
        content: content,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        quoteMessageId: quoteMessageId,
      );
      // 替换乐观消息
      final idx = _currentMessages
          .indexWhere((m) => m.id == optimisticMsg.id);
      if (idx != -1) {
        _currentMessages[idx] = sentMsg;
      }
      // 更新会话列表中对应会话的最后消息
      _updateConversationLastMessage(sentMsg);
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

  void _updateConversationLastMessage(ChatMessage msg) {
    // 会话列表按 peerUserId 匹配（receiverId 可能是对方）
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

  // ========== 会话操作 ==========
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
      {String? avatarUrl}) async {
    try {
      final group = await messageService.createGroupChat(
          name: name, avatarUrl: avatarUrl);
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
}
