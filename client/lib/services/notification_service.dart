import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/ws_notification_mapping.dart';

/// 后端时间字符串是 naive 格式（无 `Z`/无 `+HH:MM`），实际语义为 UTC。
/// Dart `DateTime.parse` 对无时区后缀的字符串会按本地时区解析，
/// 在 +08:00 客户端上会出现 N 小时偏差。此处兜底为 UTC。
DateTime _parseUtc(String s) {
  final hasZone = s.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z');
}

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

  /// WS 事件来源标记:本地乐观插入的条目会带上归一化的 event_type
  /// (如 `'post_like'`),用于未来按细粒度事件渲染文案。
  /// HTTP 拉取的条目此字段为 null。
  final String? wsEventType;

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
    this.wsEventType,
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
          ? _parseUtc(json['create_time'].toString())
          : DateTime.now(),
    );
  }

  /// WS 通知事件 → 本地 `NotificationItem`(乐观插入路径)。
  ///
  /// 与 [fromJson] 的差异:WS 事件 schema 是平铺的 `{actor_id, actor_name, <context_id>}`,
  /// HTTP API schema 是 `{id, type, content, sender:{...}, object_type, object_id, ...}`,
  /// 两者完全不兼容,必须独立构造路径。
  ///
  /// 调用前必须先查 [WsNotificationMapping.specFor] 拿到 [spec];
  /// spec.needsLocalInsert=false 的事件(如 `notification_new`)不应走此 factory。
  ///
  /// 字段策略:
  /// - `id`:合成 `ws_${eventType}_${actorId}_${contextId}` —— 三元组保证唯一,
  ///   `ws_` 前缀便于排查;HTTP 对账后会被服务端真实 id 整体替换。
  /// - `type`:取自 [WsNotificationSpec.typeCode],UI switch 据此渲染 i18n 文案。
  /// - `body`:留空 —— UI 主文案靠 type 渲染,body 仅作辅助副文本,
  ///   服务端未下发,留空比硬编码中文更安全(项目规范禁止硬编码文案)。
  /// - `postId`:仅在 contextField='post_id' 时填充;reply_id / user_id 场景暂留空,
  ///   后续 step 决定是否新增字段。
  /// - `fromUserId` / `fromDisplayName`:来自 actor_id / actor_name。
  /// - `wsEventType`:原样保留归一化后的 event_type,供 UI 未来按细粒度渲染。
  factory NotificationItem.fromWsEvent(
    String eventType,
    Map<String, dynamic> json,
    WsNotificationSpec spec,
  ) {
    final actorId = (json['actor_id'] ?? json['actorId'] ?? '').toString();
    final actorName = (json['actor_name'] ?? json['actorName'] ?? '').toString();
    final contextId = (json[spec.contextField] ?? '').toString();
    return NotificationItem(
      id: 'ws_${eventType}_${actorId}_$contextId',
      type: spec.typeCode,
      body: '',
      fromUserId: actorId.isNotEmpty ? actorId : null,
      fromDisplayName: actorName.isNotEmpty ? actorName : null,
      postId:
          spec.contextField == 'post_id' && contextId.isNotEmpty ? contextId : null,
      isRead: false,
      createdAt: DateTime.now(),
      wsEventType: eventType,
    );
  }
}