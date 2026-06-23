import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ws_event.dart';

/// WebSocket 专属日志。
///
/// 与 [ApiLogger] 同风格但**独立** `ws_logs/` 目录(不强行把 WS 帧塞进 HTTP 日志格式)。
/// 同时输出到控制台(developer.log)和文件(完整),按日期命名,便于联调试抓问题。
///
/// token 脱敏:连接 URL 日志只打印 scheme+host+path,query 里的 token 一律不打印。
class WsLogger {
  WsLogger._();

  static File? _logFile;
  static bool _initialized = false;
  static bool _initFailed = false;

  /// 初始化日志文件。幂等,失败后不再重试。
  static Future<void> init() async {
    if (_initialized || _initFailed) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/ws_logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _logFile = File('${logDir.path}/ws_${_dateTag()}.log');
      _initialized = true;
    } catch (e) {
      _initFailed = true;
      developer.log('[WsLogger] init failed: $e', name: 'WsLogger');
    }
  }

  /// 普通文本日志(连接状态变化、心跳、重连、错误等)。
  static void log(String message) {
    final line = '[${_now()}] $message';
    developer.log('[WS] $line', name: 'WsLogger');
    _writeToFile(line);
  }

  /// 事件日志:打印 type + 完整 raw JSON(pretty)。
  static void logEvent(WsEvent event) {
    final String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(event.raw);
    } catch (_) {
      log('event type=${event.type} raw=<unencodable>');
      return;
    }
    log('event type=${event.type} raw=$pretty');
  }

  // ── 内部 ──────────────────────────────────────────────────────

  static void _writeToFile(String content) {
    final file = _logFile;
    if (file == null) {
      _initAndWrite(content);
      return;
    }
    try {
      file.writeAsStringSync(
        '$content\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // 写入失败不阻塞主流程
    }
  }

  static void _initAndWrite(String content) async {
    await init();
    final file = _logFile;
    if (file != null) {
      try {
        file.writeAsStringSync(
          '$content\n',
          mode: FileMode.append,
          flush: false,
        );
      } catch (_) {}
    }
  }

  static String _now() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _dateTag() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}';
  }
}
