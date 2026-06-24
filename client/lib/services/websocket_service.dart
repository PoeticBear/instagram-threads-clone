import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import '../common/locator.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/ws_config.dart';
import '../network/ws_event.dart';
import '../network/ws_logger.dart';

/// WebSocket 连接状态机。
///
/// ```
/// disconnected ──connect()──▶ connecting ──成功──▶ connected
///      ▲                           │                    │
///      │                           失败                onDone/onError
///      │                           ▼                    ▼
///      └──disableForAuth──▶ disabled ◀──重连耗尽    reconnecting ──退避后──▶ connecting
///                             (_authDisabled=true,             ▲
///                              等下一次显式                       │
///                              connect() 复位)              scheduleReconnect
/// ```
enum WsConnectionState {
  /// 从未连接或已主动 disconnect。
  disconnected,

  /// 正在握手。
  connecting,

  /// 已建立,可收发。
  connected,

  /// 异常断开,正在按指数退避重试。
  reconnecting,

  /// 鉴权失效 / 重连耗尽,不再重连,等下一次显式 connect()。
  disabled,
}

/// WebSocket 连接管理器:getIt 单例(在 `main()` 注册,与 ApiClient 同模式)。
///
/// 职责:
///  - 连接生命周期(connect / disconnect / reconnect)
///  - 鉴权(复用 ApiClient.accessToken,按 [WsConfig.authMode] 选 header/query)
///  - 心跳(双轨:协议级 IOWebSocketChannel.pingInterval + 应用层文本 ping + pong watchdog)
///  - 重连(指数退避 + jitter,见 [_computeBackoff])
///  - 事件路由(归一化 event_type 为小写,广播到 [events] stream + 同步调路由表 handler)
///
/// 不在 Provider 树里注册(避免 MultiProvider 膨胀),各 State 类直接 `getIt<WebSocketService>()`。
class WebSocketService with ChangeNotifier {
  WebSocketService();

  // ── 通道 / 订阅 ──────────────────────────────────────────────
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;

  // ── 心跳 Timer ───────────────────────────────────────────────
  Timer? _appLayerPingTimer;
  Timer? _pongWatchdog;

  // ── 重连 Timer ───────────────────────────────────────────────
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // ── 状态 ──────────────────────────────────────────────────────
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  /// 主动 disconnect 标记:为 true 时 onDone 不触发重连。
  bool _intentionalClose = false;

  /// 鉴权失效标记:disableForAuth 设为 true 后停止重连,
  /// 直到下次 connect() 入口复位(意味着上层重新登录/刷新了 token)。
  bool _authDisabled = false;

  // ── 事件分发 ──────────────────────────────────────────────────
  /// 广播流:State 类构造期可 `events.where(...).listen(...)` 订阅。
  final StreamController<WsEvent> _eventController =
      StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _eventController.stream;

  /// 路由表:key 是归一化(小写)后的 event_type。
  /// 与 [events] stream 双轨:handler 同步调,stream 异步广播。
  final Map<String, EventHandler> _handlers = {};

  // ════════════════════════════════════════════════════════════
  //  公共 API
  // ════════════════════════════════════════════════════════════

  /// 注册 handler。type 大小写无关,内部归一化为小写。
  void registerHandler(String type, EventHandler handler) {
    _handlers[type.toLowerCase()] = handler;
  }

  /// 注销 handler。
  void unregisterHandler(String type) {
    _handlers.remove(type.toLowerCase());
  }

  /// 登录成功 / App resumed 时调用。
  ///
  /// 语义:上层主动调 connect() 意味着认为 token 已就绪,
  /// 因此**入口复位 [_authDisabled]**(允许 disableForAuth 后重新登录再连)。
  /// 幂等:已 connecting/connected 时 no-op。
  Future<void> connect() async {
    // 主动 connect 意味着上层认为 token 已就绪,清掉 disabled 标记
    _authDisabled = false;

    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }
    _intentionalClose = false;
    await _doConnect();
  }

  /// 主动断开,**不重连**(App paused / logout)。
  /// 不动 [_authDisabled](只在 [disableForAuth] / [connect] 里改)。
  Future<void> disconnect() async {
    _intentionalClose = true;
    _cancelReconnect();
    _cancelPing();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  /// 鉴权失效专用:断开 + 标记 [_authDisabled]=true,直到下次 [connect] 入口复位。
  ///
  /// 由 `AuthState.forceSessionExpired` / `logoutCallback` 调用,
  /// 确保失效 token 不会被重连机制拿去反复握手。
  Future<void> disableForAuth() async {
    _authDisabled = true;
    await disconnect();
    _setState(WsConnectionState.disabled);
  }

  /// 手动重连(重试按钮):disconnect + 清 _authDisabled + connect。
  Future<void> reconnect() async {
    await disconnect();
    _authDisabled = false;
    await connect();
  }

  /// 向服务端发文本消息(已连接时)。
  /// 返回 false 表示发送失败(未连接 / 序列化失败),上层可考虑重试。
  bool send(Map<String, dynamic> payload) {
    if (_channel == null || _state != WsConnectionState.connected) {
      return false;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
      return true;
    } catch (e) {
      WsLogger.log('send() failed: $e');
      return false;
    }
  }

  /// 订阅某类事件(语法糖,内部走 events.stream.where)。
  /// 注意:返回的 StreamSubscription 由调用方负责 cancel(在 State.dispose 里)。
  StreamSubscription<WsEvent> subscribeEvent(String type, EventHandler handler) {
    final normalized = type.toLowerCase();
    return events
        .where((e) => e.type == normalized)
        .listen((e) => handler(e));
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  内部:连接 / 鉴权 / 心跳
  // ════════════════════════════════════════════════════════════

  Future<void> _doConnect() async {
    final token = getIt.isRegistered<ApiClient>()
        ? getIt<ApiClient>().accessToken
        : null;
    if (token == null || token.isEmpty) {
      WsLogger.log('_doConnect aborted: no access token');
      _setState(WsConnectionState.disabled);
      return;
    }

    _setState(WsConnectionState.connecting);
    final uri = _buildAuthUri(token);
    // dev 排障:打印完整连接 URL(含 token),便于核对鉴权参数;
    // prod 仍脱敏,避免长期凭证写进日志文件泄露。
    final connectUrl = ApiConfig.environment == 'dev'
        ? uri.toString()
        : _maskUrl(uri);
    WsLogger.log('connecting → $connectUrl'
        '${ApiConfig.environment == 'dev' ? '' : ' (token masked)'}');

    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: _buildAuthHeaders(token),
        pingInterval: WsConfig.pingInterval,
        connectTimeout: const Duration(seconds: 10),
      );

      // channel.ready 在握手完成时完成,握手失败时抛出。
      try {
        await _channel!.ready;
      } catch (e) {
        _onError('handshake failed', e);
        return;
      }

      _socketSub = _channel!.stream.listen(
        _onData,
        onError: (Object e) => _onError('stream error', e),
        onDone: _onDone,
      );
      _startAppLayerPing();
      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      WsLogger.log('connected');
    } catch (e) {
      _onError('connect failed', e);
    }
  }

  Uri _buildAuthUri(String token) {
    final base = Uri.parse(WsConfig.wsUrl);
    switch (WsConfig.authMode) {
      case WsAuthMode.headerOnly:
      case WsAuthMode.none:
        return base;
      case WsAuthMode.queryOnly:
      case WsAuthMode.both:
        return base.replace(queryParameters: {
          ...base.queryParameters,
          WsConfig.authQueryKey: '${WsConfig.authHeaderPrefix}$token',
        });
    }
  }

  Map<String, String> _buildAuthHeaders(String token) {
    switch (WsConfig.authMode) {
      case WsAuthMode.queryOnly:
      case WsAuthMode.none:
        return {};
      case WsAuthMode.headerOnly:
      case WsAuthMode.both:
        return {
          WsConfig.authHeaderName: '${WsConfig.authHeaderPrefix}$token',
        };
    }
  }

  /// 日志里脱敏 URL:只打 scheme+host+path,去掉 query 里的 token。
  String _maskUrl(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    return uri.replace(queryParameters: {}).toString();
  }

  // ── 收消息 / 事件路由 ──────────────────────────────────────
  void _onData(dynamic raw) {
    // 应用层 pong 检测:收到即取消 watchdog(连接健康)
    if (raw is String && _maybePong(raw)) {
      _cancelPongWatchdog();
      WsLogger.log('pong received — heartbeat ok');
      return;
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) {
        WsLogger.log('non-map JSON frame ignored: $raw');
        return;
      }
      json = decoded;
    } catch (e) {
      WsLogger.log('non-JSON frame ignored: $raw ($e)');
      return;
    }

    // envelope 兼容:平铺 event_type,或嵌套 data.event_type
    final rawType = json['event_type'] ??
        json['type'] ??
        json['event'] ??
        (json['data'] is Map ? (json['data']['event_type'] ?? json['data']['type']) : null);
    if (rawType == null) {
      WsLogger.log('frame without event_type: $json');
      return;
    }
    final normalized = (rawType as String).toLowerCase();
    final event = WsEvent(
      type: normalized,
      raw: json,
      receivedAt: DateTime.now(),
    );

    WsLogger.logEvent(event);

    // 1) 广播给所有 StreamSubscription 订阅者
    _eventController.add(event);
    // 2) 同步路由表(主路径)
    final handler = _handlers[normalized];
    if (handler != null) {
      try {
        handler(event);
      } catch (e) {
        WsLogger.log('handler[$normalized] threw: $e');
      }
    } else {
      // 未注册事件(含剩余 20 个已知但未实现的事件),仅打 log
      WsLogger.log('no handler for $normalized');
    }
  }

  /// pong 帧检测:payload 因服务端而异,匹配常见几种。
  bool _maybePong(String raw) {
    final lower = raw.toLowerCase();
    return lower == 'pong' ||
        lower == '3' || // Socket.IO 风格 pong
        lower == '2' || // 某些实现用 '2' 作 pong
        lower.contains('"pong"') ||
        lower.contains('"type":"pong"');
  }

  // ── 心跳(应用层文本 ping) ───────────────────────────────
  void _startAppLayerPing() {
    _cancelPing();
    final payload = WsConfig.appLayerPingPayload;
    if (payload == null) return;
    _appLayerPingTimer = Timer.periodic(WsConfig.pingInterval, (_) {
      final channel = _channel;
      if (channel == null) return;
      try {
        channel.sink.add(payload);
      } catch (e) {
        WsLogger.log('app-layer ping send failed: $e');
        return;
      }
      WsLogger.log('app-layer ping sent');
      _startPongWatchdog();
    });
  }

  void _startPongWatchdog() {
    _cancelPongWatchdog();
    _pongWatchdog = Timer(WsConfig.pongWaitTimeout, () {
      WsLogger.log('pong watchdog triggered, forcing reconnect');
      // 主动关闭,触发 onDone → scheduleReconnect
      try {
        _channel?.sink.close(1006, 'pong timeout');
      } catch (_) {}
    });
  }

  void _cancelPing() {
    _appLayerPingTimer?.cancel();
    _appLayerPingTimer = null;
    _cancelPongWatchdog();
  }

  void _cancelPongWatchdog() {
    _pongWatchdog?.cancel();
    _pongWatchdog = null;
  }

  // ── 异常 / 断开 / 重连 ──────────────────────────────────────
  void _onError(String tag, Object e) {
    WsLogger.log('$tag: $e');
    _scheduleReconnect();
  }

  void _onDone() {
    WsLogger.log(
        'socket onDone (intentionalClose=$_intentionalClose, authDisabled=$_authDisabled)');
    _cancelPing();
    if (_intentionalClose || _authDisabled) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_authDisabled) return;
    if (WsConfig.reconnectMaxAttempts >= 0 &&
        _reconnectAttempts >= WsConfig.reconnectMaxAttempts) {
      WsLogger.log('reconnect attempts exhausted, giving up');
      _setState(WsConnectionState.disabled);
      return;
    }
    _setState(WsConnectionState.reconnecting);
    _reconnectAttempts++;
    final delay = _computeBackoff(_reconnectAttempts);
    WsLogger.log(
        'reconnect #$_reconnectAttempts in ${delay.inMilliseconds}ms');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _doConnect);
  }

  /// 指数退避 + jitter:
  /// `delay = min(maxDelay, initial * 2^(attempt-1)) * (1 ± jitter)`
  Duration _computeBackoff(int attempt) {
    final initial = WsConfig.reconnectInitialDelay.inMilliseconds;
    final maxMs = WsConfig.reconnectMaxDelay.inMilliseconds;
    final exp = initial * pow(2, attempt - 1);
    final capped = exp > maxMs ? maxMs.toDouble() : exp;
    final jitter =
        capped * WsConfig.reconnectJitter * (Random().nextDouble() * 2 - 1);
    return Duration(milliseconds: (capped + jitter).round());
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _setState(WsConnectionState next) {
    if (_state == next) return;
    _state = next;
    WsLogger.log('state → $next');
    notifyListeners();
  }
}
