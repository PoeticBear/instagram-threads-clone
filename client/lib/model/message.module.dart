/// 消息模块数据模型
/// 包含：Conversation, ChatMessage, MessageReaction, GroupChat, GroupMember, MessageSettings

// ============================================================
// Conversation（会话模型）
// ============================================================

class Conversation {
  final int id;
  final int peerUserId;
  final String peerUsername;
  final String peerDisplayName;
  final String? peerAvatarUrl;
  final int conversationType; // 1=收件箱, 2=陌生人
  final String? lastMessageContent;
  final String? lastMessageTime;
  final int unreadCount;
  final bool isReplied;
  final bool isVerified;
  final bool isHidden;
  final bool isPinned;

  Conversation({
    required this.id,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerDisplayName,
    this.peerAvatarUrl,
    required this.conversationType,
    this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isReplied = false,
    this.isVerified = false,
    this.isHidden = false,
    this.isPinned = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? 0,
      peerUserId: json['peer_user_id'] ?? json['peerUserId'] ?? 0,
      peerUsername: json['peer_username'] ?? json['peerUsername'] ?? '',
      peerDisplayName: json['peer_display_name'] ?? json['peerDisplayName'] ?? '',
      peerAvatarUrl: json['peer_avatar_url'] ?? json['peerAvatarUrl'],
      conversationType: json['conversation_type'] ?? json['conversationType'] ?? 1,
      lastMessageContent: json['last_message_content'] ?? json['lastMessageContent'],
      lastMessageTime: json['last_message_time'] ?? json['lastMessageTime'],
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      isReplied: json['is_replied'] ?? json['isReplied'] ?? false,
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      isHidden: json['is_hidden'] ?? json['isHidden'] ?? false,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peer_user_id': peerUserId,
      'peer_username': peerUsername,
      'peer_display_name': peerDisplayName,
      'peer_avatar_url': peerAvatarUrl,
      'conversation_type': conversationType,
      'last_message_content': lastMessageContent,
      'last_message_time': lastMessageTime,
      'unread_count': unreadCount,
      'is_replied': isReplied,
      'is_verified': isVerified,
      'is_hidden': isHidden,
      'is_pinned': isPinned,
    };
  }
}

// ============================================================
// ChatMessage（消息模型）
// ============================================================

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final int mediaType; // 0=文本, 1=图片, 2=视频, 3=语音, 4=文件
  final String? mediaUrl;
  final bool isRead;
  final int deliveryStatus; // 1=发送中, 2=已送达, 3=发送失败
  final String? readTime;
  final int? quoteMessageId;
  final List<MessageReaction> reactions;
  final String createTime;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.mediaType = 0,
    this.mediaUrl,
    this.isRead = false,
    this.deliveryStatus = 1,
    this.readTime,
    this.quoteMessageId,
    this.reactions = const [],
    required this.createTime,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Parse reactions list
    final reactionsRaw = json['reactions'];
    final List<MessageReaction> reactions;
    if (reactionsRaw is List) {
      reactions = reactionsRaw
          .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      reactions = [];
    }

    return ChatMessage(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? json['senderId'] ?? 0,
      receiverId: json['receiver_id'] ?? json['receiverId'] ?? 0,
      content: json['content'] ?? '',
      mediaType: json['media_type'] ?? json['mediaType'] ?? 0,
      mediaUrl: json['media_url'] ?? json['mediaUrl'],
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      deliveryStatus: json['delivery_status'] ?? json['deliveryStatus'] ?? 1,
      readTime: json['read_time'] ?? json['readTime'],
      quoteMessageId: json['quote_message_id'] ?? json['quoteMessageId'],
      reactions: reactions,
      createTime: json['create_time'] ?? json['createTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'is_read': isRead,
      'delivery_status': deliveryStatus,
      'read_time': readTime,
      'quote_message_id': quoteMessageId,
      'reactions': reactions.map((e) => e.toJson()).toList(),
      'create_time': createTime,
    };
  }
}

// ============================================================
// MessageReaction（消息反应）
// ============================================================

class MessageReaction {
  final String emoji;
  final int userId;
  final String? createTime;

  MessageReaction({
    required this.emoji,
    required this.userId,
    this.createTime,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      emoji: json['emoji'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? 0,
      createTime: json['create_time'] ?? json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'user_id': userId,
      'create_time': createTime,
    };
  }
}

// ============================================================
// GroupChat（群聊模型）
// ============================================================

class GroupChat {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? inviteLink;
  final bool inviteLinkEnabled;
  final bool needApprove;
  final int membersCount;
  final String? lastMessageTime;
  final String? createTime;

  GroupChat({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.inviteLink,
    this.inviteLinkEnabled = false,
    this.needApprove = false,
    this.membersCount = 0,
    this.lastMessageTime,
    this.createTime,
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    return GroupChat(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      inviteLink: json['invite_link'] ?? json['inviteLink'],
      inviteLinkEnabled: json['invite_link_enabled'] ?? json['inviteLinkEnabled'] ?? false,
      needApprove: json['need_approve'] ?? json['needApprove'] ?? false,
      membersCount: json['members_count'] ?? json['membersCount'] ?? 0,
      lastMessageTime: json['last_message_time'] ?? json['lastMessageTime'],
      createTime: json['create_time'] ?? json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'invite_link': inviteLink,
      'invite_link_enabled': inviteLinkEnabled,
      'need_approve': needApprove,
      'members_count': membersCount,
      'last_message_time': lastMessageTime,
      'create_time': createTime,
    };
  }
}

// ============================================================
// GroupMember（群成员模型）
// ============================================================

class GroupMember {
  final int userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int role; // 1=成员, 2=管理员
  final String? joinTime;

  GroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.role = 1,
    this.joinTime,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      role: json['role'] ?? 1,
      joinTime: json['join_time'] ?? json['joinTime'],
    );
  }
}

// ============================================================
// MessageSettings（消息设置）
// ============================================================

class MessageSettings {
  final int messageRequestEnabled;
  final int messageRequestAllowType;

  MessageSettings({
    this.messageRequestEnabled = 1,
    this.messageRequestAllowType = 0,
  });

  factory MessageSettings.fromJson(Map<String, dynamic> json) {
    return MessageSettings(
      messageRequestEnabled: json['message_request_enabled'] ?? json['messageRequestEnabled'] ?? 1,
      messageRequestAllowType: json['message_request_allow_type'] ?? json['messageRequestAllowType'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_request_enabled': messageRequestEnabled,
      'message_request_allow_type': messageRequestAllowType,
    };
  }
}
