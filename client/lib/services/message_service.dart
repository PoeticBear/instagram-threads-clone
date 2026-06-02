import '../model/message.module.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class MessageService {
  final ApiClient _apiClient;

  MessageService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ==============================================================
  // 会话管理（6 个）
  // ==============================================================

  /// 获取会话列表
  Future<List<Conversation>> getConversations({
    int page = 1,
    int size = 20,
    int? conversationType,
    int? filterType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (conversationType != null) {
        queryParams['conversation_type'] = conversationType.toString();
      }
      if (filterType != null) {
        queryParams['filter_type'] = filterType.toString();
      }

      final response = await _apiClient.get(
        'message/conversations',
        queryParameters: queryParams,
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 获取会话中的消息列表
  Future<List<ChatMessage>> getMessages(
    int conversationId, {
    int page = 1,
    int size = 20,
    String? beforeTime,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (beforeTime != null) {
        queryParams['before_time'] = beforeTime;
      }

      final response = await _apiClient.get(
        'message/conversations/$conversationId/messages',
        queryParameters: queryParams,
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 隐藏会话
  Future<void> hideConversation(int conversationId) async {
    try {
      await _apiClient.post('message/conversations/$conversationId/hide');
    } on ApiException {
      rethrow;
    }
  }

  /// 认证会话（验证）
  Future<void> verifyConversation(int conversationId) async {
    try {
      await _apiClient.post('message/conversations/$conversationId/verify');
    } on ApiException {
      rethrow;
    }
  }

  /// 置顶会话
  Future<void> pinConversation(int conversationId) async {
    try {
      await _apiClient.post('message/conversations/$conversationId/pin');
    } on ApiException {
      rethrow;
    }
  }

  /// 取消置顶会话
  Future<void> unpinConversation(int conversationId) async {
    try {
      await _apiClient.delete('message/conversations/$conversationId/pin');
    } on ApiException {
      rethrow;
    }
  }

  // ==============================================================
  // 消息收发（2 个）
  // ==============================================================

  /// 发送消息
  Future<SendMessageResponse> sendMessage({
    required int receiverId,
    required String content,
    int mediaType = 0,
    String? mediaUrl,
    int? quoteMessageId,
  }) async {
    try {
      final body = <String, dynamic>{
        'receiver_id': receiverId,
        'content': content,
        'media_type': mediaType,
      };
      if (mediaUrl != null) body['media_url'] = mediaUrl;
      if (quoteMessageId != null) body['quote_message_id'] = quoteMessageId;

      final response = await _apiClient.post('message/messages', body: body);
      return SendMessageResponse.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 标记消息已读
  Future<void> markAsRead(List<int> messageIds) async {
    try {
      await _apiClient.post('message/messages/read', body: {
        'message_ids': messageIds,
      });
    } on ApiException {
      rethrow;
    }
  }

  // ==============================================================
  // 消息反应（2 个）
  // ==============================================================

  /// 添加消息反应
  Future<void> addReaction({
    required int messageId,
    required String emoji,
  }) async {
    try {
      await _apiClient.post(
        'message/messages/$messageId/reaction',
        body: {'reaction_type': emoji},
      );
    } on ApiException {
      rethrow;
    }
  }

  /// 移除消息反应
  Future<void> removeReaction({
    required int messageId,
    required String emoji,
  }) async {
    try {
      await _apiClient.delete('message/messages/$messageId/reaction');
    } on ApiException {
      rethrow;
    }
  }

  // ==============================================================
  // 群聊管理（12 个）
  // ==============================================================

  /// 创建群聊
  Future<GroupChat> createGroupChat({
    required String name,
    String? avatarUrl,
    List<int> memberIds = const [],
    bool needApprove = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'member_ids': memberIds,
        'need_approve': needApprove,
      };
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final response =
          await _apiClient.post('message/group-chats/with-link', body: body);
      return GroupChat.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 获取群聊列表
  Future<List<GroupChat>> getGroupChats({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/group-chats',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 获取群聊详情
  Future<GroupChat> getGroupChatDetail(int groupId) async {
    try {
      final response = await _apiClient.get('message/group-chats/$groupId');
      return GroupChat.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 更新群聊信息
  Future<GroupChat> updateGroupChat(
    int groupId, {
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final response =
          await _apiClient.patch('message/group-chats/$groupId', body: body);
      return GroupChat.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 获取群成员列表
  Future<List<GroupMember>> getGroupMembers(
    int groupId, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/group-chats/$groupId/members',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 移除群成员
  Future<void> removeGroupMember(int groupId, int userId) async {
    try {
      await _apiClient.delete('message/group-chats/$groupId/members/$userId');
    } on ApiException {
      rethrow;
    }
  }

  /// 通过邀请链接加入群聊
  Future<GroupChat> joinGroupChat({required String inviteLink}) async {
    try {
      final response = await _apiClient.post(
        'message/group-chats/join-by-link',
        body: {'invite_link': inviteLink},
      );
      return GroupChat.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 退出群聊
  Future<void> leaveGroupChat(int groupId) async {
    try {
      await _apiClient.post('message/group-chats/$groupId/leave');
    } on ApiException {
      rethrow;
    }
  }

  /// 获取入群申请列表
  Future<List<Map<String, dynamic>>> getJoinRequests(int groupId) async {
    try {
      final response = await _apiClient.get('message/group-chats/$groupId/join-requests');

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items.cast<Map<String, dynamic>>();
    } on ApiException {
      rethrow;
    }
  }

  /// 审批入群申请
  Future<void> approveJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    try {
      await _apiClient.post(
        'message/group-chats/$groupId/join-requests/$requestId/approve',
        body: {'action': 1},
      );
    } on ApiException {
      rethrow;
    }
  }

  /// 拒绝入群申请
  Future<void> rejectJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    try {
      await _apiClient.post(
        'message/group-chats/$groupId/join-requests/$requestId/approve',
        body: {'action': 2},
      );
    } on ApiException {
      rethrow;
    }
  }

  /// 更新群聊设置（开关等）
  Future<GroupChat> updateGroupChatSettings(
    int groupId, {
    bool? needApprove,
    bool? inviteLinkEnabled,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (needApprove != null) body['need_approve'] = needApprove;
      if (inviteLinkEnabled != null) body['invite_link_enabled'] = inviteLinkEnabled;

      final response =
          await _apiClient.patch('message/group-chats/$groupId', body: body);
      return GroupChat.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 获取群聊消息列表
  /// GET /message/group-chats/{group_id}/messages
  Future<List<ChatMessage>> getGroupChatMessages(
    int groupId, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/group-chats/$groupId/messages',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 发送群聊消息
  /// POST /message/group-chats/{group_id}/messages
  Future<SendMessageResponse> sendGroupChatMessage({
    required int groupId,
    required String content,
    int mediaType = 0,
    String? mediaUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'group_id': groupId,
        'content': content,
        'media_type': mediaType,
      };
      if (mediaUrl != null) body['media_url'] = mediaUrl;

      final response = await _apiClient.post(
        'message/group-chats/$groupId/messages',
        body: body,
      );
      return SendMessageResponse.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  // ==============================================================
  // 搜索/设置/推荐（6 个）
  // ==============================================================

  /// 搜索消息
  Future<List<ChatMessage>> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/search',
        queryParameters: {
          'q': keyword,
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// 获取消息设置
  Future<MessageSettings> getMessageSettings() async {
    try {
      final response = await _apiClient.get('message/settings');
      return MessageSettings.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 更新消息设置
  Future<MessageSettings> updateMessageSettings(
      MessageSettings settings) async {
    try {
      final response = await _apiClient.post(
        'message/settings',
        body: settings.toJson(),
      );
      return MessageSettings.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 获取推荐用户
  Future<List<Map<String, dynamic>>> getRecommendUsers({
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/recommend-users',
        queryParameters: {
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items.cast<Map<String, dynamic>>();
    } on ApiException {
      rethrow;
    }
  }

  /// 搜索聊天用户
  Future<List<Map<String, dynamic>>> searchChatUsers({
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/search-users',
        queryParameters: {
          'q': keyword,
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items.cast<Map<String, dynamic>>();
    } on ApiException {
      rethrow;
    }
  }

  /// 获取隐藏的会话列表
  Future<List<Conversation>> getHiddenConversations({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        'message/hidden',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      final data = response['data'];
      List items;
      if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('items')) {
        items = data['items'] as List? ?? [];
      } else {
        items = [];
      }

      return items
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }
}
