import 'dart:developer' as developer;
import 'dart:io';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// 一站式上传：获取预签名 URL → PUT 文件 → 返回 COS 访问地址
  Future<String> uploadImage(File file) async {
    try {
      final contentType = _inferContentType(file.path);
      final fileSize = await file.length();
      final filename = file.path.split('/').last;

      // 1) 获取预签名 URL
      final presignedResponse = await _apiClient.post(
        'upload/presigned_url',
        body: {
          'filename': filename,
          'content_type': contentType,
          'file_size': fileSize,
        },
      );

      // 响应可能是 {data: {...}} 或直接 {...}
      final data = presignedResponse['data'] ?? presignedResponse;

      final uploadUrl = (data['upload_url'] ?? '') as String;
      final cosUrl = (data['cos_url'] ?? '') as String;

      if (uploadUrl.isEmpty) {
        throw ApiException(message: '预签名URL为空: $data');
      }

      // 2) PUT 文件到预签名 URL
      final fileBytes = await file.readAsBytes();
      final request = await HttpClient().putUrl(Uri.parse(uploadUrl));
      request.headers.set('Content-Type', contentType);
      request.add(fileBytes);

      final httpResponse = await request.close();

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        return cosUrl;
      } else {
        throw ApiException(message: '上传失败: ${httpResponse.statusCode}');
      }
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ uploadImage 失败: $e\n$stackTrace', name: 'UploadService');
      throw ApiException(message: '上传图片失败: $e');
    }
  }

  /// 分步上传：步骤1 — 获取预签名 URL
  Future<PresignedUrlResponse> getPresignedUrl({
    required String filename,
    required String contentType,
    required int fileSize,
  }) async {
    try {
      final response = await _apiClient.post(
        'upload/presigned_url',
        body: {
          'filename': filename,
          'content_type': contentType,
          'file_size': fileSize,
        },
      );
      return PresignedUrlResponse.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  /// 分步上传：步骤2 — PUT 文件到预签名 URL
  Future<String> uploadToPresignedUrl({
    required String uploadUrl,
    required File file,
    required String contentType,
  }) async {
    try {
      final request = await HttpClient().putUrl(Uri.parse(uploadUrl));
      request.headers.set('Content-Type', contentType);

      final fileBytes = await file.readAsBytes();
      request.add(fileBytes);

      final httpResponse = await request.close();

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        return uploadUrl.split('?').first;
      } else {
        throw ApiException(message: '上传失败: ${httpResponse.statusCode}');
      }
    } catch (e) {
      throw ApiException(message: '上传到预签名URL失败: $e');
    }
  }

  /// 根据文件扩展名推断 MIME 类型
  String _inferContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}

class PresignedUrlResponse {
  final String uploadUrl;
  final String cosUrl;
  final int expiresIn;

  PresignedUrlResponse({
    required this.uploadUrl,
    required this.cosUrl,
    required this.expiresIn,
  });

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      uploadUrl: json['upload_url'] ?? '',
      cosUrl: json['cos_url'] ?? '',
      expiresIn: json['expires_in'] ?? 600,
    );
  }
}
