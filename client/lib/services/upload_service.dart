import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import '../model/post.module.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  // 文件大小上限（按媒体类型区分）
  static const int _maxImageSizeBytes = 20 * 1024 * 1024; // 20MB
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int _maxGifSizeBytes = 20 * 1024 * 1024; // 20MB

  /// 一站式上传媒体（图片 / 视频 / GIF）：获取预签名 URL → 流式 PUT 文件 → 返回 COS 访问地址
  ///
  /// - 对视频 / GIF 等大文件采用 `file.openRead()` 流式上传，避免一次性读入内存导致 OOM
  /// - 自动按 [mediaType] 校验文件大小上限
  /// - [onProgress] 仅在流式上传场景下被调用（小文件 0..1 一次性刷新）
  Future<String> uploadMedia(
    File file, {
    required int mediaType,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 1) 文件大小校验
      final fileSize = await file.length();
      _validateSize(mediaType, fileSize);

      // 2) MIME 推断（按 mediaType 选择）
      final contentType = _inferContentType(file.path, mediaType: mediaType);
      final filename = file.path.split('/').last;

      // 3) 获取预签名 URL
      final presigned = await getPresignedUrl(
        filename: filename,
        contentType: contentType,
        fileSize: fileSize,
      );

      // 4) 流式 PUT 上传
      await _streamPut(
        uploadUrl: presigned.uploadUrl,
        file: file,
        contentType: contentType,
        onProgress: onProgress,
      );

      return presigned.cosUrl;
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ uploadMedia 失败: $e\n$stackTrace', name: 'UploadService');
      throw ApiException(message: '上传媒体失败: $e');
    }
  }

  /// 向后兼容的图片上传别名。
  /// 新代码请使用 [uploadMedia] 并显式传 [mediaType]。
  @Deprecated('Use uploadMedia with explicit mediaType')
  Future<String> uploadImage(File file) {
    return uploadMedia(file, mediaType: MediaType.image);
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

  /// 分步上传：步骤2 — 流式 PUT 文件到预签名 URL。
  /// 自动按 8KB chunk 写入并报告进度。
  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required File file,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _streamPut(
        uploadUrl: uploadUrl,
        file: file,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (e) {
      throw ApiException(message: '上传到预签名URL失败: $e');
    }
  }

  /// 流式 PUT 上传：使用 file.openRead() 边读边写，避免大文件 OOM。
  Future<void> _streamPut({
    required String uploadUrl,
    required File file,
    required String contentType,
    void Function(double)? onProgress,
  }) async {
    final fileSize = await file.length();
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(uploadUrl));
      request.headers.set('Content-Type', contentType);
      request.contentLength = fileSize;

      // 流式写入：通过 chunked write 包装原始 Stream
      // 进度通过监听 stream 的每个 chunk 累加上报
      if (onProgress != null) {
        final totalBytes = fileSize;
        var sentBytes = 0;
        final stream = file.openRead().map((chunk) {
          sentBytes += chunk.length;
          onProgress((sentBytes / totalBytes).clamp(0.0, 1.0));
          return chunk;
        });
        await request.addStream(stream);
      } else {
        await request.addStream(file.openRead());
      }

      final httpResponse = await request.close();
      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        // 读取错误体（限制 4KB）以辅助诊断
        final bodyBuf = <int>[];
        final sub = httpResponse.listen(
          bodyBuf.addAll,
          cancelOnError: false,
        );
        await sub.asFuture<void>();
        final bodyStr = String.fromCharCodes(bodyBuf.take(4096));
        throw ApiException(
          message: '上传失败: HTTP ${httpResponse.statusCode} ${bodyStr.isNotEmpty ? "· $bodyStr" : ""}',
        );
      }
      // 消费完响应流（保持连接干净关闭）
      await httpResponse.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  /// 按 mediaType 校验文件大小
  void _validateSize(int mediaType, int fileSize) {
    final limit = _sizeLimitFor(mediaType);
    if (fileSize > limit) {
      final limitMB = limit ~/ (1024 * 1024);
      final kindName = mediaType == MediaType.video ? '视频' : (mediaType == MediaType.gif ? 'GIF' : '图片');
      throw ApiException(
        message: '$kindName文件超过 ${limitMB}MB 上限（当前 ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB）',
      );
    }
  }

  int _sizeLimitFor(int mediaType) {
    switch (mediaType) {
      case MediaType.video:
        return _maxVideoSizeBytes;
      case MediaType.gif:
        return _maxGifSizeBytes;
      case MediaType.image:
      default:
        return _maxImageSizeBytes;
    }
  }

  /// 根据文件扩展名 + 媒体类型推断 MIME。
  /// 视频走 video/mp4 / video/quicktime / video/x-m4v；GIF 走 image/gif；图片走 image/*。
  String _inferContentType(String path, {int? mediaType}) {
    final ext = path.split('.').last.toLowerCase();
    if (mediaType == MediaType.video) {
      const videoMime = {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        '3gp': 'video/3gpp',
        'hevc': 'video/hevc',
      };
      return videoMime[ext] ?? 'video/mp4';
    }
    if (mediaType == MediaType.gif) {
      return 'image/gif';
    }
    const imageMime = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
    };
    return imageMime[ext] ?? 'application/octet-stream';
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
