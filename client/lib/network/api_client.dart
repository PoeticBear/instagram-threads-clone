import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';
import 'api_logger.dart';
import 'package:threads/helper/network_error.dart';

class ApiClient {
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;

  // ── 401 自动 refresh + 全局登出机制 ──
  // 由 main.dart 在 _MyAppState.initState 注入；为 null 时退化为旧行为（直接抛 AuthException）。
  Future<String?> Function()? refreshTokensProvider;
  void Function()? onSessionExpired;
  // 并发 refresh 串行化：多个请求同时 401 时，只发一次 refresh，其他请求 await 同一个 Future。
  Future<String?>? _refreshInFlight;
  // 幂等保护：一次"会话失效事件"只通知一次，直到下次成功 refresh 后复位。
  bool _sessionExpiredNotified = false;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setTokens({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  String? get accessToken => _accessToken;

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': ApiConfig.contentType,
      'Accept': ApiConfig.contentType,
      'User-Agent': ApiConfig.userAgent,
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    return _request('GET', path,
        queryParameters: queryParameters, silent: silent);
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    return _request('POST', path,
        body: body, queryParameters: queryParameters, silent: silent);
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    return _request('PUT', path,
        body: body, queryParameters: queryParameters, silent: silent);
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    return _request('PATCH', path,
        body: body, queryParameters: queryParameters, silent: silent);
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    return _request('DELETE', path,
        body: body, queryParameters: queryParameters, silent: silent);
  }

  /// 外层请求编排：401 → refresh → 重试一次。
  /// - refresh / logout / signin 等端点本身的 401 不重试（避免递归）。
  /// - 已是重试的请求不再 refresh（避免无限循环）。
  /// - 没注入 refreshTokensProvider / 没有 access_token 时退化为旧行为（直接抛）。
  Future<dynamic> _request(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool isRetry = false,
    bool silent = false,
  }) async {
    try {
      return await _sendOnce(method, path,
          body: body, queryParameters: queryParameters, silent: silent);
    } on AuthException catch (e) {
      const skipPaths = [
        'auth/token/refresh',
        'auth/logout',
        'auth/username/signin',
        'auth/apple/login',
        'auth/google/login',
        'auth/sms/signin',
      ];
      final shouldSkip = isRetry ||
          refreshTokensProvider == null ||
          _accessToken == null ||
          skipPaths.any((p) => path.contains(p));
      if (shouldSkip) rethrow;

      final newToken = await _doRefresh();
      if (newToken == null) {
        // refresh 失败 → 清理本地 + 触发全局登出（幂等）+ 抛 AuthException
        clearTokens();
        _notifySessionExpired();
        throw AuthException(
          message: '会话已失效，请重新登录',
          statusCode: 401,
          data: e.data,
        );
      }

      // refresh 成功 → 重试一次原请求
      return _request(method, path,
          body: body,
          queryParameters: queryParameters,
          isRetry: true,
          silent: silent);
    }
  }

  /// 串行化 refresh：多个并发请求同时 401 时，复用同一个 Future。
  Future<String?> _doRefresh() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = _doRefreshInner();
    _refreshInFlight = future;
    future.whenComplete(() => _refreshInFlight = null);
    return future;
  }

  Future<String?> _doRefreshInner() async {
    try {
      final token = await refreshTokensProvider!();
      if (token != null) _sessionExpiredNotified = false; // 复位
      return token;
    } catch (_) {
      return null;
    }
  }

  /// 触发全局登出回调，推到下一帧执行避免在网络回调里同步改 Provider 状态。
  void _notifySessionExpired() {
    if (_sessionExpiredNotified) return;
    _sessionExpiredNotified = true;
    final cb = onSessionExpired;
    if (cb != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cb());
    }
  }

  /// 实际发请求 + 处理响应（原 _request 主体，逻辑不变）。
  Future<dynamic> _sendOnce(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool silent = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      Uri uri = Uri.parse('${ApiConfig.baseUrl}$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      // ── 打印请求日志 ──
      ApiLogger.logRequest(
        method: method,
        url: uri.toString(),
        headers: _headers,
        body: body,
      );

      http.Response response;

      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: _headers)
              .timeout(ApiConfig.connectTimeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: _headers, body: _encodeBody(body))
              .timeout(ApiConfig.connectTimeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: _headers, body: _encodeBody(body))
              .timeout(ApiConfig.connectTimeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: _headers, body: _encodeBody(body))
              .timeout(ApiConfig.connectTimeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: _headers, body: _encodeBody(body))
              .timeout(ApiConfig.connectTimeout);
          break;
        default:
          throw ApiException(message: 'Unsupported HTTP method: $method');
      }

      stopwatch.stop();

      // ── 打印响应日志 ──
      ApiLogger.logResponse(
        method: method,
        url: uri.toString(),
        statusCode: response.statusCode,
        body: response.body,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      ApiLogger.logError(
        method: method,
        url: '${ApiConfig.baseUrl}$path',
        statusCode: null,
        error: '网络连接失败: $e',
        elapsedMs: 0,
      );
      NetworkErrorNotifier.showNetworkError(e);
      throw NetworkException(message: '网络连接失败: $e');
    } on http.ClientException catch (e) {
      ApiLogger.logError(
        method: method,
        url: '${ApiConfig.baseUrl}$path',
        statusCode: null,
        error: '网络请求异常: $e',
        elapsedMs: 0,
      );
      NetworkErrorNotifier.showNetworkError(e);
      throw NetworkException(message: '网络请求异常: $e');
    } on TimeoutException catch (e) {
      ApiLogger.logError(
        method: method,
        url: '${ApiConfig.baseUrl}$path',
        statusCode: null,
        error: '请求超时: $e',
        elapsedMs: 0,
      );
      NetworkErrorNotifier.showTimeoutError(e);
      throw NetworkException(message: '请求超时: $e');
    } on ApiException catch (e) {
      ApiLogger.logError(
        method: method,
        url: '${ApiConfig.baseUrl}$path',
        statusCode: e.statusCode,
        error: e.message,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      // silent=true 时（如引用帖后台预取）抑制全局 SnackBar；ApiLogger 日志照打。
      if (e is ServerException && !silent) {
        NetworkErrorNotifier.showServerError(e);
      }
      rethrow;
    } catch (e) {
      ApiLogger.logError(
        method: method,
        url: '${ApiConfig.baseUrl}$path',
        statusCode: null,
        error: '请求失败: $e',
        elapsedMs: 0,
      );
      if (e is ApiException) rethrow;
      NetworkErrorNotifier.showNetworkError(e);
      throw ApiException(message: '请求失败: $e');
    }
  }

  String? _encodeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic data;

    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body);
      }
    } catch (_) {
      data = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      // Check for business-level error codes (e.g. {"code": 101001, "msg": "..."})
      if (data is Map<String, dynamic>) {
        final code = data['code'];
        if (code != null && code != 0 && code != 200) {
          final message = data['msg'] ?? data['message'] ?? '服务异常';
          throw ServerException(
            message: message,
            statusCode: code is int ? code : int.tryParse(code.toString()),
            data: data,
          );
        }
      }
      return data;
    }

    switch (statusCode) {
      case 400:
        throw ValidationException(
          message: _extractMessage(data) ?? '请求参数错误',
          statusCode: statusCode,
          data: data,
        );
      case 401:
        throw AuthException(
          message: _extractMessage(data) ?? '认证失败',
          statusCode: statusCode,
          data: data,
        );
      case 403:
        throw AuthException(
          message: _extractMessage(data) ?? '权限不足',
          statusCode: statusCode,
          data: data,
        );
      case 404:
        throw ApiException(
          message: _extractMessage(data) ?? '资源不存在',
          statusCode: statusCode,
          data: data,
        );
      case 422:
        throw ValidationException(
          message: _extractMessage(data) ?? '验证失败',
          statusCode: statusCode,
          data: data,
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          message: _extractMessage(data) ?? '服务器错误',
          statusCode: statusCode,
          data: data,
        );
      default:
        throw ApiException(
          message: _extractMessage(data) ?? '请求失败',
          statusCode: statusCode,
          data: data,
        );
    }
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      return data['message'] ?? data['detail'] ?? data['error'];
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}