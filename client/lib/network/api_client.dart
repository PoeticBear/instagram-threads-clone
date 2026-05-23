import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;

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
  }) async {
    return _request('GET', path, queryParameters: queryParameters);
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request('POST', path, body: body, queryParameters: queryParameters);
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request('PUT', path, body: body, queryParameters: queryParameters);
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request('PATCH', path, body: body, queryParameters: queryParameters);
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request('DELETE', path, body: body, queryParameters: queryParameters);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      Uri uri = Uri.parse('${ApiConfig.baseUrl}$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      // ── Request log ──
      final stopwatch = Stopwatch()..start();
      developer.log('');
      developer.log('┌── HTTP Request ─────────────────────────────────');
      developer.log('│ $method ${uri.toString()}');
      if (body != null) {
        developer.log('│ Body: ${_encodeBody(body)}');
      }
      developer.log('│ Headers: $_headers');
      developer.log('└─────────────────────────────────────────────────');

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

      // ── Response log ──
      developer.log('');
      developer.log('┌── HTTP Response ────────────────────────────────');
      developer.log('│ $method ${uri.toString()}');
      developer.log('│ Status: ${response.statusCode}  (${stopwatch.elapsedMilliseconds}ms)');
      try {
        final decoded = jsonDecode(response.body);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        for (final line in pretty.split('\n')) {
          developer.log('│ $line');
        }
      } catch (_) {
        developer.log('│ Body: ${response.body}');
      }
      developer.log('└─────────────────────────────────────────────────');
      developer.log('');

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(message: '网络连接失败，请检查网络');
    } on http.ClientException {
      throw NetworkException(message: '网络请求失败');
    } catch (e) {
      if (e is ApiException) rethrow;
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