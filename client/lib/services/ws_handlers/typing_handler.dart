import '../../network/ws_event.dart';
import '../../state/message.state.dart';

/// `message_typing` 事件:对端正在输入。
///
/// 协议假设(服务端契约待对齐):
/// ```
/// {event_type:'message_typing', conversation_id:123, user_id:456}
/// ```
///
/// 字段候选:[field] helper 多别名 + 大小写无关取值。
class TypingHandler {
  final MessageState _state;
  TypingHandler(this._state);

  /// 3 秒后自动清除 typing 状态(对端不再发 event 即视为停止输入)。
  static const Duration expireAfter = Duration(seconds: 3);

  void call(WsEvent event) {
    final convId = event.field<int>([
      'conversation_id',
      'conversationId',
      'cid',
    ]);
    final userId = event.field<int>([
      'user_id',
      'userId',
      'actor_id',
      'actorId',
    ]);
    if (convId == null || userId == null) return;
    _state.handleTypingEvent(
      conversationId: convId,
      userId: userId,
      expireAfter: expireAfter,
    );
  }
}
