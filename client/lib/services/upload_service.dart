import 'dart:io';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<String> uploadImage(File file, {
    String? folder,
    void Function(int, int)? onProgress,
  }) async {
    try {
      // Get presigned URL
      final presignedResponse = await _apiClient.post(
        'upload/upload/presigned_url',
        body: {
          'filename': file.path.split('/').last,
          if (folder != null) 'folder': folder,
        },
      );

      final presignedUrl = presignedResponse['data']['presigned_url'];
      final uploadUrl = presignedResponse['data']['upload_url'];

      // Upload to presigned URL
      final fileBytes = await file.readAsBytes();
      final request = await HttpClient().putUrl(Uri.parse(uploadUrl));

      // Set headers
      request.headers.set('Content-Type', 'image/*');
      request.add(fileBytes);

      final httpResponse = await request.close();

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        // Return the final URL where the file is accessible
        return presignedResponse['data']['url'] ?? presignedUrl;
      } else {
        throw ApiException(message: '上传失败: ${httpResponse.statusCode}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '上传图片失败: $e');
    }
  }

  Future<PresignedUrlResponse> getPresignedUrl({
    required String filename,
    String? folder,
    String? contentType,
  }) async {
    try {
      final response = await _apiClient.post(
        'upload/upload/presigned_url',
        body: {
          'filename': filename,
          if (folder != null) 'folder': folder,
          if (contentType != null) 'content_type': contentType,
        },
      );
      return PresignedUrlResponse.fromJson(response['data']);
    } on ApiException {
      rethrow;
    }
  }

  Future<String> uploadToPresignedUrl({
    required String uploadUrl,
    required File file,
    required String contentType,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final request = await HttpClient().putUrl(Uri.parse(uploadUrl));
      request.headers.set('Content-Type', contentType);

      final fileBytes = await file.readAsBytes();
      request.add(fileBytes);

      final httpResponse = await request.close();

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        return uploadUrl.split('?').first; // Remove query params
      } else {
        throw ApiException(message: '上传失败: ${httpResponse.statusCode}');
      }
    } catch (e) {
      throw ApiException(message: '上传到预签名URL失败: $e');
    }
  }
}

class PresignedUrlResponse {
  final String presignedUrl;
  final String uploadUrl;
  final String url;
  final String objectKey;

  PresignedUrlResponse({
    required this.presignedUrl,
    required this.uploadUrl,
    required this.url,
    required this.objectKey,
  });

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      presignedUrl: json['presigned_url'] ?? '',
      uploadUrl: json['upload_url'] ?? json['presigned_url'] ?? '',
      url: json['url'] ?? json['presigned_url'] ?? '',
      objectKey: json['object_key'] ?? json['key'] ?? '',
    );
  }
}