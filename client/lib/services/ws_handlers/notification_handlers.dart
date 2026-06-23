import '../../network/ws_event.dart';
import '../../state/notification.state.dart';

/// `notification_new` 事件:通用新通知 ping。
///
/// 字段仅 `notification_id`,无 actor / context —— 走 [NotificationState.handleWsEvent]
/// 统一入口,内部识别 `needsLocalInsert=false` → 跳过本地插入,仅 incrementUnread +
/// 防抖触发 HTTP `loadNotifications(refresh: true)` 拉完整列表。
///
/// 与 11 个细粒度通知事件可能并发推送,防抖合并避免重复 HTTP。
class NotificationNewHandler {
  final NotificationState _state;
  NotificationNewHandler(this._state);

  void call(WsEvent event) {
    _state.handleWsEvent(event.type, event.payload);
  }
}

/// `post_like` 事件:有人点赞我的帖子。
///
/// 协议(服务端文档 `docs/event-types-doc.md`):
/// ```
/// {event_type:'post_like', actor_id:123, actor_name:'张三', post_id:456}
/// ```
///
/// 走 [NotificationState.handleWsEvent] 统一入口,内部:
/// - 查 WsNotificationMapping 拿到 spec(typeCode='like', contextField='post_id')
/// - 本地构造 NotificationItem 插入列表头(乐观更新)
/// - incrementUnread + 防抖触发 HTTP refresh 对账
class PostLikeHandler {
  final NotificationState _state;
  PostLikeHandler(this._state);

  void call(WsEvent event) {
    _state.handleWsEvent(event.type, event.payload);
  }
}

/// 通用通知事件 handler(供 10 个细粒度通知事件共用)。
///
/// 覆盖事件:`reply_like` / `post_mention` / `reply_mention` / `post_reply` /
/// `post_repost` / `post_quote` / `follow_request` / `follow_accept` /
/// `new_follower` / `follow_request_declined`。
///
/// 这些事件的载荷结构一致(`{actor_id, actor_name, <context_id>}`),
/// 仅 event_type 与 context 字段名不同 —— 全部信息在 `WsNotificationMapping`
/// 映射表里,handler 本身无需 event-type-specific 逻辑,共用此类即可。
///
/// 与 [NotificationNewHandler] / [PostLikeHandler] 行为完全一致,保留那两个
/// 具名 class 仅因先期已注册,后续如需统一可全数替换为 GenericNotificationHandler。
class GenericNotificationHandler {
  final NotificationState _state;
  GenericNotificationHandler(this._state);

  void call(WsEvent event) {
    _state.handleWsEvent(event.type, event.payload);
  }
}
