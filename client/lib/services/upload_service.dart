import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import '../model/post.module.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  // 文件大小上限（按媒体类型区分）— 严格对齐服务端 openapi_docs/_misc.json
  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10MB（图片）
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB（视频）
  static const int _maxGifSizeBytes = 10 * 1024 * 1024; // 10MB（GIF）
  static const int _maxVoiceOrTextSizeBytes = 10 * 1024 * 1024; // 10MB（语音 / 文本附件）

  /// 一站式上传媒体（图片 / 视频 / GIF / 语音 / 文本附件）：获取预签名 URL → 流式 PUT 文件 → 返回 COS 访问地址
  ///
  /// - 对视频 / GIF 等大文件采用 `file.openRead()` 流式上传，避免一次性读入内存导致 OOM
  /// - 自动按 [mediaType] 校验文件大小上限
  /// - [durationMs] 视频 / 语音的时长（**毫秒**，与 `MediaDraftItem` 一致），仅在 [mediaType] 为视频或语音时
  ///   转换为秒并透传给 `/upload/presigned_url`（对齐 `openapi_docs/_misc.json` 的契约）
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

      // 3) 获取预签名 URL：视频 / 语音按接口契约透传 duration（单位：秒）
      final durationSeconds =
          _isPlayableMedia(mediaType) && durationMs != null
              ? durationMs ~/ 1000
              : null;

      // 4) 获取预签名 URL + 流式 PUT 上传（预签名 URL 过期时自动重试 1 次）
      return await _uploadWithPresignedUrlRetry(
        filename: filename,
        contentType: contentType,
        fileSize: fileSize,
        duration: durationSeconds,
        file: file,
        onProgress: onProgress,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log('❌ uploadMedia 失败: $e\n$stackTrace', name: 'UploadService');
      throw ApiException(message: '上传媒体失败: $e');
    }
  }

  /// 申请预签名 URL 并流式 PUT，命中「URL 过期」时自动重试 1 次。
  ///
  /// 对齐服务端规范：预签名 URL 有效期 600 秒，大文件（视频 100MB）流式上传
  /// 在弱网下可能超过 10 分钟，PUT 阶段会拿到 401/403（body 含 `expired` /
  /// `AccessDenied`）。这种情况自动重新申请一次 URL 后再 PUT。
  Future<String> _uploadWithPresignedUrlRetry({
    required String filename,
    required String contentType,
    required int fileSize,
    required int? duration,
    required File file,
    void Function(double)? onProgress,
  }) async {
    const maxAttempts = 2; // 1 原始 + 1 重试
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final presigned = await getPresignedUrl(
        filename: filename,
        contentType: contentType,
        fileSize: fileSize,
        duration: duration,
      );
      try {
        await _streamPut(
          uploadUrl: presigned.uploadUrl,
          file: file,
          contentType: contentType,
          onProgress: onProgress,
        );
        return presigned.cosUrl;
      } on ApiException catch (e) {
        if (attempt < maxAttempts && _isExpiredPresignedUrlError(e)) {
          developer.log(
            '⚠️ 预签名 URL 过期，自动重新申请并重试 (attempt $attempt/$maxAttempts)',
            name: 'UploadService',
          );
          continue;
        }
        rethrow;
      }
    }
    // 理论上不会到达这里（maxAttempts 次后必然抛错或成功）
    throw ApiException(message: '上传失败：预签名 URL 多次过期');
  }

  /// 判断是否是「预签名 URL 过期」错误。
  /// COS 预签名 URL 过期通常返回 401/403，body 包含 `expired` / `AccessDenied`。
  bool _isExpiredPresignedUrlError(ApiException e) {
    final msg = e.message.toLowerCase();
    final hasExpiredStatus =
        msg.contains('http 401') || msg.contains('http 403');
    final hasExpiredBody = msg.contains('expired') ||
        msg.contains('accessdenied') ||
        msg.contains('access denied');
    return hasExpiredStatus && hasExpiredBody;
  }

  /// 是否是带时长的媒体（视频 / 语音），与 `openapi_docs/_misc.json` 中
  /// `duration: int?, 视频/语音时长（秒）, optional` 的语义保持一致。
  bool _isPlayableMedia(int mediaType) {
    return mediaType == MediaType.video || mediaType == MediaType.voice;
  }

  /// 向后兼容的图片上传别名。
  /// 新代码请使用 [uploadMedia] 并显式传 [mediaType]。
  @Deprecated('Use uploadMedia with explicit mediaType')
  Future<String> uploadImage(File file) {
    return uploadMedia(file, mediaType: MediaType.image);
  }

  /// 分步上传：步骤1 — 获取预签名 URL
  ///
  /// 严格对齐 `openapi_docs/_misc.json` 中 `POST /upload/presigned_url` 的请求体：
  /// `filename` / `content_type` / `file_size` 必传；`duration` 仅在视频 / 语音时透传（单位：秒）。
  Future<PresignedUrlResponse> getPresignedUrl({
    required String filename,
    required String contentType,
    required int fileSize,
    int? duration,
  }) async {
    try {
      final body = <String, dynamic>{
        'filename': filename,
        'content_type': contentType,
        'file_size': fileSize,
      };
      if (duration != null) {
        body['duration'] = duration;
      }
      final response = await _apiClient.post(
        'upload/presigned_url',
        body: body,
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
      final kindName = _kindName(mediaType);
      throw ApiException(
        message: '$kindName文件超过 ${limitMB}MB 上限（当前 ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB）',
      );
    }
  }

  String _kindName(int mediaType) {
    switch (mediaType) {
      case MediaType.video:
        return '视频';
      case MediaType.gif:
        return 'GIF';
      case MediaType.voice:
        return '语音';
      case MediaType.textAttachment:
        return '文本';
      case MediaType.image:
      default:
        return '图片';
    }
  }

  int _sizeLimitFor(int mediaType) {
    switch (mediaType) {
      case MediaType.video:
        return _maxVideoSizeBytes;
      case MediaType.gif:
        return _maxGifSizeBytes;
      case MediaType.voice:
      case MediaType.textAttachment:
        return _maxVoiceOrTextSizeBytes;
      case MediaType.image:
      default:
        return _maxImageSizeBytes;
    }
  }

  /// 根据文件扩展名 + 媒体类型推断 MIME。
  /// - 视频：服务端白名单为 MP4 / MOV / M4V / 3GP，不含 hevc
  /// - GIF：固定 `image/gif`
  /// - 图片：服务端 `image/*` 不限；扩展名不在表内时 fallback 到 `image/jpeg`
  ///   （避免发 `application/octet-stream` 被服务端拒收）
  String _inferContentType(String path, {int? mediaType}) {
    final ext = path.split('.').last.toLowerCase();
    if (mediaType == MediaType.video) {
      const videoMime = {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        '3gp': 'video/3gpp',
        // hevc 不在服务端白名单，移除以免上传被拒
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
    return imageMime[ext] ?? 'image/jpeg';
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
