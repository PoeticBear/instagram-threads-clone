import 'api_config.dart';

/// WebSocket 鉴权方式。
///
/// 服务端契约未定,默认 [WsAuthMode.both](header + query 双通道兜底)。
/// 服务端确认后改 [WsConfig.authMode] 一行即可。
enum WsAuthMode {
  /// 仅通过 HTTP header 传 token(标准 WS 不支持,需服务端配合)。
  headerOnly,
  /// 仅通过 URL query 传 token(最通用)。
  queryOnly,
  /// header + query 双通道兜底(默认)。
  both,
  /// 不鉴权(仅 dev/调试用)。
  none,
}

/// event_type 命名规范。
///
/// **仅影响 send 给服务端的方向**;接收方向一律 `toLowerCase()` 归一化,
/// 服务端 snake_case 与 SCREAMING_SNAKE 都能吃。
enum WsEventTypeCasing { snake, screaming, camel }

/// WebSocket 协议常量集中点。
///
/// 服务端 WS 契约几乎全缺(`openapi_docs/` 仅在两条 HTTP 接口描述里口头提到 WS),
/// 这里把所有"猜"的协议参数集中起来,服务端对齐后**改 const 值即可**,
/// 不需要动 `WebSocketService` / Handler。
///
/// 切换守则:
///  - URL:改 [_prodWsUrl] / [_devWsUrl]
///  - 鉴权:改 [authMode] + [authHeaderName] / [authQueryKey]
///  - 心跳:改 [pingInterval] / [appLayerPingPayload] / [pongWaitTimeout]
///  - 重连:改 [reconnectInitialDelay] / [reconnectMaxDelay] / [reconnectMaxAttempts]
///  - send 方向 event_type 命名:改 [eventTypeCasing]
class WsConfig {
  WsConfig._();

  // ── URL ──────────────────────────────────────────────────────
  // 与 ApiConfig.baseUrl 对齐:prod 走 wss,dev 走 ws。
  // 路径两端保持一致(/websocket/ws);服务端若调整路由再同步改这两行。
  static const String _prodWsUrl = 'wss://api.tweetcaht.com/websocket/ws';
  static const String _devWsUrl = 'ws://192.168.1.27:8005/websocket/ws';

  /// 运行时根据 [ApiConfig.environment] 选择,与 HTTP 同环境。
  /// 不引入 `--dart-define=WS_ENV`,避免 HTTP prod / WS dev 撕裂。
  static String get wsUrl =>
      ApiConfig.environment == 'dev' ? _devWsUrl : _prodWsUrl;

  // ── 鉴权 ──────────────────────────────────────────────────────
  /// 鉴权方式。服务端确认前双通道兜底。
  static const WsAuthMode authMode = WsAuthMode.both;

  /// Bearer header 名。默认 `Authorization`;
  /// 服务端用 `Sec-WebSocket-Protocol` 时改这里。
  static const String authHeaderName = 'Authorization';

  /// Header value 前缀。默认 `Bearer `;
  /// 服务端只要裸 token 时改成 `''`。
  static const String authHeaderPrefix = 'Bearer ';

  /// Query 参数名。默认 `token`;
  /// 服务端用 `access_token` 时改这里。
  static const String authQueryKey = 'access_token';

  // ── 心跳 ──────────────────────────────────────────────────────
  /// IOWebSocketChannel 自带的协议级 ping(RFC6455 control frame)。
  /// 多数服务端兼容;设 null 关闭。
  static const Duration pingInterval = Duration(seconds: 30);

  /// 应用层文本 ping。当服务端不响应 control frame ping 时启用。
  /// payload 跟服务端对齐(常见值:`'ping'` / `'{"type":"ping"}'` / `'1'`)。
  /// 设 null 关闭应用层 ping,只用协议级。
  static const String? appLayerPingPayload = 'ping';

  /// 发出应用层 ping 后等待 pong 的超时;
  /// 超时即认为连接死了,主动断开重连。
  static const Duration pongWaitTimeout = Duration(seconds: 10);

  // ── 重连(指数退避 + jitter) ─────────────────────────────────
  /// 退避起始延迟。
  static const Duration reconnectInitialDelay = Duration(seconds: 1);

  /// 退避最大延迟封顶。
  static const Duration reconnectMaxDelay = Duration(seconds: 30);

  /// 最大尝试次数;`-1` 表示无限重连。
  /// 服务端上线后建议改成有限值(如 10),避免失效 token 风暴。
  static const int reconnectMaxAttempts = -1;

  /// Jitter 比例(0~1),避免大量客户端同步重连风暴。`0.2` = ±20%。
  static const double reconnectJitter = 0.2;

  // ── event_type 命名(仅影响 send 方向) ─────────────────────
  static const WsEventTypeCasing eventTypeCasing = WsEventTypeCasing.snake;

  // ── 事件名常量(归一化后的小写形式) ─────────────────────────
  /// Handler 注册的 key 一律用这里的小写常量,避免散落字符串。
  /// 接收方向在 `WebSocketService._onData` 强制 `toLowerCase()` 归一化。
  //
  // 消息类(已实施)
  static const String evtMessageTyping = 'message_typing';
  static const String evtMessageRead = 'message_read';
  static const String evtMessageReaction = 'message_reaction';
  static const String evtGroupMessage = 'group_message';
  //
  // 通知类(12 个,文档 docs/event-types-doc.md 第一张表)
  static const String evtNotificationNew = 'notification_new';
  static const String evtPostLike = 'post_like';
  static const String evtReplyLike = 'reply_like';
  static const String evtPostMention = 'post_mention';
  static const String evtReplyMention = 'reply_mention';
  static const String evtPostReply = 'post_reply';
  static const String evtPostRepost = 'post_repost';
  static const String evtPostQuote = 'post_quote';
  static const String evtFollowRequest = 'follow_request';
  static const String evtFollowAccept = 'follow_accept';
  static const String evtNewFollower = 'new_follower';
  static const String evtFollowRequestDeclined = 'follow_request_declined';
}
