import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_service.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<NotificationItem>> getNotifications({
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    try {
      final response = await _apiClient.get(
        'notification/notifications',
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
          if (type != null) 'type': type,
        },
      );
      final list = response['data'] as List? ?? [];
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
      return response['data']?['count'] ?? 0;
    } on ApiException {
      rethrow;
    }
  }
}

class NotificationItem {
  final String id;
  final String type;
  final String title;
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
    required this.title,
    required this.body,
    this.fromUserId,
    this.fromUsername,
    this.fromDisplayName,
    this.fromProfilePic,
    this.postId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? json['notification_id']?.toString() ?? '',
      type: json['type'] ?? 'follow',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      fromUserId: json['from_user_id']?.toString(),
      fromUsername: json['from_username'],
      fromDisplayName: json['from_display_name'] ?? json['fromDisplayName'],
      fromProfilePic: json['from_profile_pic'] ?? json['fromProfilePic'],
      postId: json['post_id']?.toString(),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
    );
  }
}