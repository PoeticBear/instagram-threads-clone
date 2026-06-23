import 'package:flutter/foundation.dart';

/// 服务端下推的一条 WebSocket 事件。
///
/// - [type]:已归一化的小写 event_type(如 `'message_typing'`),
///   由 `WebSocketService._onData` 在收到原始帧后 `toLowerCase()` 得到,
///   保证 snake_case / SCREAMING_SNAKE 两种服务端 casing 都能路由。
/// - [raw]:整帧 JSON(含 event_type 本身、actor_id、post_id 等所有字段)。
/// - [receivedAt]:本端收到时间(本地时钟),用于过期判断(如 typing 3s 失效)。
@immutable
class WsEvent {
  final String type;
  final Map<String, dynamic> raw;
  final DateTime receivedAt;

  const WsEvent({
    required this.type,
    required this.raw,
    required this.receivedAt,
  });

  /// 多候选 key + 大小写无关取值。
  ///
  /// 服务端契约未定(snake / camel / 不同别名),handler 取字段一律走这里。
  /// 整数/浮点做了 num 互转兜底:JSON 整数解码后是 int,handler 声明 double 时
  /// 自动 `toDouble()`,反之亦然。
  ///
  /// 示例:
  /// ```
  /// final convId = event.field<int>(['conversation_id', 'conversationId', 'cid']);
  /// final emoji = event.field<String>(['emoji']);
  /// ```
  T? field<T>(List<String> keys) {
    for (final k in keys) {
      final lower = k.toLowerCase();
      for (final entry in raw.entries) {
        if (entry.key.toLowerCase() != lower) continue;
        final v = entry.value;
        if (v == null) continue;
        if (v is T) return v;
        // int / double 互转兜底
        if (T == int && v is num) return v.toInt() as T;
        if (T == double && v is num) return v.toDouble() as T;
      }
    }
    return null;
  }

  /// envelope 平铺 vs `{data:{}}` 嵌套两路都取。
  /// 服务端最终用哪种尚未确认,优先 data,回退平铺。
  Map<String, dynamic> get payload {
    final data = raw['data'];
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return raw;
  }
}

/// Handler 签名:接收归一化后的 [WsEvent],无返回值。
///
/// 异常由 `WebSocketService._onData` 兜住并打 log,Handler 内不需要 try/catch。
typedef EventHandler = void Function(WsEvent event);
