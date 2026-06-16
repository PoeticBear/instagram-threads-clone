import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 需要在日志中脱敏的字段名（不区分大小写匹配）
const _sensitiveKeys = {'password', 'token', 'access_token', 'refresh_token'};

/// 统一的 API 请求/响应日志工具。
///
/// 日志同时输出到控制台（截断）和文件（完整）。
/// 文件存储在应用文档目录的 `api_logs/` 文件夹下，按日期命名。
/// 自动清理超过 7 天的旧日志文件。
class ApiLogger {
  ApiLogger._();

  static File? _logFile;
  static bool _initialized = false;
  static bool _initFailed = false;

  // ─── 初始化 ─────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized || _initFailed) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/api_logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _logFile = File('${logDir.path}/api_${_dateTag()}.log');
      _initialized = true;
      _cleanOldLogs(logDir);
    } catch (e) {
      _initFailed = true;
      developer.log('[ApiLogger] 初始化文件日志失败: $e', name: 'ApiLogger');
    }
  }

  /// 删除超过 7 天的旧日志文件。
  static void _cleanOldLogs(Directory logDir) {
    try {
      final threshold = DateTime.now().subtract(const Duration(days: 7));
      for (final entity in logDir.listSync()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = entity.statSync();
          if (stat.modified.isBefore(threshold)) {
            entity.deleteSync();
          }
        }
      }
    } catch (_) {}
  }

  // ─── Request ──────────────────────────────────────────────────

  static void logRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    dynamic body,
  }) {
    final timestamp = _now();
    final path = _extractPath(url);

    final buffer = StringBuffer();
    buffer.writeln('╔${'═' * 62}');
    buffer.writeln('║ REQUEST  $method $path');
    buffer.writeln('║ Time: $timestamp');
    buffer.writeln('╟${'─' * 62}');

    // Headers
    buffer.writeln('║ Headers:');
    for (final entry in headers.entries) {
      buffer.writeln('║   ${entry.key}: ${_maskHeader(entry.key, entry.value)}');
    }

    // Body (完整写入文件)
    if (body != null) {
      final bodyStr = _tryFormatJson(body, maskSensitive: true);
      buffer.writeln('║ Body:');
      for (final line in bodyStr.split('\n')) {
        buffer.writeln('║   $line');
      }
    }

    // Query string
    final uri = Uri.tryParse(url);
    if (uri != null && uri.query.isNotEmpty) {
      buffer.writeln('║ Query:');
      for (final entry in uri.queryParameters.entries) {
        buffer.writeln('║   ${entry.key}: ${_maskIfNeeded(entry.key, entry.value)}');
      }
    }

    buffer.writeln('╚${'═' * 62}');
    _output(buffer.toString());
  }

  // ─── Response (成功) ──────────────────────────────────────────

  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    required String body,
    required int elapsedMs,
  }) {
    final timestamp = _now();
    final path = _extractPath(url);

    // ── 文件：完整 body ──
    final fileBuffer = StringBuffer();
    fileBuffer.writeln('╔${'═' * 62}');
    fileBuffer.writeln('║ RESPONSE $method $path');
    fileBuffer.writeln('║ Time: $timestamp  ($elapsedMs ms)');
    fileBuffer.writeln('║ Status: $statusCode');
    fileBuffer.writeln('╟${'─' * 62}');
    fileBuffer.writeln('║ Body:');
    final fullBody = _formatResponseBodyFull(body);
    for (final line in fullBody.split('\n')) {
      fileBuffer.writeln('║   $line');
    }
    fileBuffer.writeln('╚${'═' * 62}');

    // ── 控制台：截断 body ──
    final consoleBuffer = StringBuffer();
    consoleBuffer.writeln('╔${'═' * 62}');
    consoleBuffer.writeln('║ RESPONSE $method $path');
    consoleBuffer.writeln('║ Time: $timestamp  ($elapsedMs ms)');
    consoleBuffer.writeln('║ Status: $statusCode');
    consoleBuffer.writeln('╟${'─' * 62}');
    consoleBuffer.writeln('║ Body:');
    final truncated = _formatResponseBodyTruncated(body);
    for (final line in truncated.split('\n')) {
      consoleBuffer.writeln('║   $line');
    }
    consoleBuffer.writeln('╚${'═' * 62}');

    _output(consoleBuffer.toString(), fileContent: fileBuffer.toString());
  }

  // ─── Response (失败/异常) ─────────────────────────────────────

  static void logError({
    required String method,
    required String url,
    required int? statusCode,
    required String error,
    required int elapsedMs,
  }) {
    final timestamp = _now();
    final path = _extractPath(url);

    final buffer = StringBuffer();
    buffer.writeln('╔${'═' * 62}');
    buffer.writeln('║ ERROR    $method $path');
    buffer.writeln('║ Time: $timestamp  ($elapsedMs ms)');
    buffer.writeln('║ Status: ${statusCode ?? "N/A"}');
    buffer.writeln('╟${'─' * 62}');
    buffer.writeln('║ Error: $error');
    buffer.writeln('╚${'═' * 62}');
    _output(buffer.toString());
  }

  // ─── 输出 ──────────────────────────────────────────────────

  /// 同时写入控制台和文件。
  /// [fileContent] 如果不为 null，则文件写入 fileContent（完整），
  /// 控制台输出 message（截断）；否则两者使用相同内容。
  static void _output(String message, {String? fileContent}) {
    // 控制台：在每条日志第一行加上 [API LOGS]: 前缀，便于在大量日志中识别
    // 使用 developer.log 而不是 print，避免 Flutter 自动添加 "flutter: " 前缀
    final firstLineEnd = message.indexOf('\n');
    final consoleMessage = firstLineEnd >= 0
        ? '[API LOGS]: ${message.substring(0, firstLineEnd)}${message.substring(firstLineEnd)}'
        : '[API LOGS]: $message';
    developer.log(consoleMessage, name: 'ApiLogger');

    // 文件（完整内容，不加前缀，便于后续解析/分享）
    _writeToFile(fileContent ?? message);
  }

  static void _writeToFile(String content) {
    final file = _logFile;
    if (file == null) {
      // 未初始化完成时异步初始化后写入
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

  // ─── Helpers ──────────────────────────────────────────────────

  /// 获取当前日志文件的路径（供外部读取/分享）。
  static Future<String?> getLogFilePath() async {
    await init();
    return _logFile?.path;
  }

  /// 获取日志目录下所有日志文件的路径列表。
  static Future<List<String>> getAllLogFiles() async {
    await init();
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/api_logs');
    if (!logDir.existsSync()) return [];
    return logDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // 最新的在前
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

  static String _extractPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.queryParameters.isNotEmpty) {
      return '${uri.path}?${uri.query}';
    }
    return uri.path;
  }

  /// 格式化 JSON body；如果 body 是字符串则先尝试 decode 再 re-encode。
  /// [maskSensitive] 为 true 时对敏感字段打码。
  static String _tryFormatJson(dynamic body, {bool maskSensitive = false}) {
    try {
      Map<String, dynamic> decoded;
      if (body is String) {
        decoded = jsonDecode(body) as Map<String, dynamic>;
      } else if (body is Map<String, dynamic>) {
        decoded = body;
      } else {
        return body.toString();
      }
      if (maskSensitive) decoded = _maskMap(decoded);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      final str = body?.toString() ?? '';
      if (str.length > 500) return '${str.substring(0, 500)}...  (truncated)';
      return str;
    }
  }

  /// 完整格式化响应 body（用于文件写入，不截断）。
  static String _formatResponseBodyFull(String body) {
    if (body.isEmpty) return '<empty>';
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }

  /// 截断格式化响应 body（用于控制台输出）。
  static String _formatResponseBodyTruncated(String body) {
    if (body.isEmpty) return '<empty>';
    try {
      final decoded = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      if (pretty.length > 2000) {
        return '${pretty.substring(0, 2000)}\n...  (truncated, total ${pretty.length} chars)';
      }
      return pretty;
    } catch (_) {
      if (body.length > 500) return '${body.substring(0, 500)}...  (truncated)';
      return body;
    }
  }

  /// 对 Map 中的敏感字段值替换为 ****。
  static Map<String, dynamic> _maskMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (_sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '****');
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _maskMap(value));
      }
      return MapEntry(key, value);
    });
  }

  /// 单个 key-value 脱敏。
  static String _maskIfNeeded(String key, String value) {
    if (_sensitiveKeys.contains(key.toLowerCase())) return '****';
    return value;
  }

  /// 对 Header 值做适度脱敏（截断过长的 token）。
  static String _maskHeader(String key, String value) {
    if (key.toLowerCase() == 'authorization' && value.length > 20) {
      return '${value.substring(0, 15)}...***';
    }
    return value;
  }
}
