/// WS 通知类事件 → `NotificationItem` type code 的映射表。
///
/// 服务端下推的 event_type(如 `post_like` / `post_mention` / `follow_request`)
/// 与 HTTP API 返回的 `NotificationItem.type`(字符串 `'like'` / `'mention'` / ...)
/// 是两套标识体系。本表是两者之间的权威翻译层。
///
/// 新增事件时只需在 [_table] 加一行,无需改 handler / state 逻辑。
class WsNotificationSpec {
  /// 对应 `NotificationItem.type`(如 `'like'` / `'mention'` / `'follow'`),
  /// UI `_typeText` switch 据此渲染 i18n 文案。
  final String typeCode;

  /// 上下文 id 在 WS payload 里的字段名(如 `'post_id'` / `'reply_id'` / `'user_id'`)。
  /// 用于 `NotificationItem.fromWsEvent` 取出 context id 存入 NotificationItem。
  final String contextField;

  /// 是否本地乐观插入列表头。
  /// - `post_like` / `post_mention` 等 actor 齐全的事件 → true
  /// - `notification_new`(只有 notification_id,无 actor) → false,仅触发 HTTP 对账
  final bool needsLocalInsert;

  const WsNotificationSpec({
    required this.typeCode,
    required this.contextField,
    this.needsLocalInsert = true,
  });
}

class WsNotificationMapping {
  WsNotificationMapping._();

  /// event_type(已归一化为小写)→ Spec。
  ///
  /// Step 1 仅注册 `post_like` + `notification_new`,后续步骤增量补充:
  /// - Step 3:reply_like
  /// - Step 4:post_mention / reply_mention
  /// - Step 5:post_reply
  /// - Step 6:post_repost / post_quote
  /// - Step 7:follow_request / follow_accept / new_follower / follow_request_declined
  static const Map<String, WsNotificationSpec> _table = {
    'post_like': WsNotificationSpec(typeCode: 'like', contextField: 'post_id'),
    'notification_new': WsNotificationSpec(
      typeCode: '',
      contextField: '',
      needsLocalInsert: false,
    ),
  };

  /// 按 event_type 查 spec,event_type 内部 `toLowerCase()` 容错。
  /// 未注册的 event_type 返回 null(调用方决定如何兜底)。
  static WsNotificationSpec? specFor(String eventType) {
    if (eventType.isEmpty) return null;
    return _table[eventType.toLowerCase()];
  }
}
