import '../network/api_client.dart';
import '../network/api_exception.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<NotificationItem>> getNotifications({
    int page = 1,
    int pageSize = 20,
    int? type,
  }) async {
    try {
      final response = await _apiClient.get(
        'notification/notifications',
        queryParameters: {
          'page': page.toString(),
          'size': pageSize.toString(),
          if (type != null) 'notif_type': type.toString(),
        },
      );
      final pageData = response['data'];
      final list = (pageData?['items'] as List?) ?? [];
      return list.map((e) => NotificationItem.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> markAsRead(List<String> notificationIds) async {
    try {
      await _apiClient.post(
        'notification/notifications/read',
        body: {'notification_ids': notificationIds},
      );
    } on ApiException {
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get('notification/notifications/unread-count');
      return (response['data'] as int?) ?? 0;
    } on ApiException {
      rethrow;
    }
  }
}

class NotificationItem {
  final String id;
  final String type;
  final String body;
  final String? fromUserId;
  final String? fromUsername;
  final String? fromDisplayName;
  final String? fromProfilePic;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.body,
    this.fromUserId,
    this.fromUsername,
    this.fromDisplayName,
    this.fromProfilePic,
    this.postId,
    this.isRead = false,
    required this.createdAt,
  });

  static String _typeIntToString(int? typeInt) {
    switch (typeInt) {
      case 1: return 'like';
      case 2: return 'reply';
      case 3: return 'follow';
      case 4: return 'mention';
      case 5: return 'repost';
      case 6: return 'quote';
      default: return 'unknown';
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: _typeIntToString(json['type'] as int?),
      body: json['content'] ?? '',
      fromUserId: sender?['id']?.toString(),
      fromUsername: sender?['username'] as String?,
      fromDisplayName: sender?['display_name'] as String?,
      fromProfilePic: sender?['avatar'] as String?,
      postId: json['object_type'] == 'post' || json['object_type'] == 'reply'
          ? json['object_id']?.toString()
          : null,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['create_time'] != null
          ? DateTime.parse(json['create_time'])
          : DateTime.now(),
    );
  }
}