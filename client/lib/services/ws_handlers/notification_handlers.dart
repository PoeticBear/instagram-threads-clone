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
