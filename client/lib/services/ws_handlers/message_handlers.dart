import '../../network/ws_event.dart';
import '../../state/message.state.dart';

/// `message_read` 事件:对端读了我们发的消息。
///
/// 协议假设(服务端契约待对齐):
/// ```
/// {event_type:'message_read', message_id:123, conversation_id:456}
/// ```
class MessageReadHandler {
  final MessageState _state;
  MessageReadHandler(this._state);

  void call(WsEvent event) {
    final messageId = event.field<int>(['message_id', 'messageId']);
    final convId = event.field<int>([
      'conversation_id',
      'conversationId',
    ]);
    if (messageId == null) return;
    _state.handleReadEvent(
      messageId: messageId,
      conversationId: convId,
    );
  }
}

/// `message_reaction` 事件:对端对某条消息加减表情。
///
/// 协议假设(服务端契约待对齐):
/// ```
/// {event_type:'message_reaction', message_id:123, emoji:'👍',
///  action:'add'|'remove', user_id:456}
/// ```
class MessageReactionHandler {
  final MessageState _state;
  MessageReactionHandler(this._state);

  void call(WsEvent event) {
    final messageId = event.field<int>(['message_id', 'messageId']);
    final emoji = event.field<String>(['emoji']);
    final action = event.field<String>(['action']) ?? 'add';
    final userId = event.field<int>([
          'user_id',
          'userId',
          'actor_id',
          'actorId',
        ]) ??
        0;
    if (messageId == null || emoji == null) return;
    _state.handleReactionEvent(
      messageId: messageId,
      emoji: emoji,
      action: action,
      userId: userId,
    );
  }
}

/// `group_message` 事件:群里来新消息。
///
/// 协议假设(服务端契约待对齐):
///   嵌套形式:`{event_type:'group_message', group_id:123, message:{...}}`
///   平铺形式:`{event_type:'group_message', group_id:123, message_id:456,
///             sender_id:789, content:'...'}`
///
/// 两路都取:优先 `message` 字段,否则用整个 payload 当消息体。
class GroupMessageHandler {
  final MessageState _state;
  GroupMessageHandler(this._state);

  void call(WsEvent event) {
    final groupId = event.field<int>(['group_id', 'groupId']);
    if (groupId == null) return;
    final nested = event.field<Map<String, dynamic>>(['message']);
    final payload = nested ?? event.payload;
    _state.handleGroupMessageEvent(
      groupId: groupId,
      messageJson: payload,
    );
  }
}
