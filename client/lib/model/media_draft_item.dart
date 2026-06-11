import 'dart:io';

import '../model/post.module.dart';

/// 发布页本地草稿态的媒体类型（与后端 MediaType 1/2/3 对应）
enum DraftMediaType {
  image,
  video,
  gif;

  int get mediaTypeInt {
    switch (this) {
      case DraftMediaType.image:
        return MediaType.image;
      case DraftMediaType.video:
        return MediaType.video;
      case DraftMediaType.gif:
        return MediaType.gif;
    }
  }

  static DraftMediaType fromMediaTypeInt(int? value) {
    switch (value) {
      case MediaType.video:
        return DraftMediaType.video;
      case MediaType.gif:
        return DraftMediaType.gif;
      case MediaType.image:
      default:
        return DraftMediaType.image;
    }
  }
}

/// 发布页本地草稿态的单个媒体条目。
///
/// - `localFile` 与 `remoteUrl` 二选一：
///   - 用户新选的（图片 / 视频 / GIF）→ 仅 `localFile`
///   - 草稿恢复 / 草稿已上传保存后的 → 仅 `remoteUrl`
/// - `durationMs` 仅视频有意义（毫秒，UI 内部统一用 ms；显示时除以 1000）
class MediaDraftItem {
  /// 客户端 UUID（用于在 Widget 树中标识与区分）。
  /// 用 microsecondsSinceEpoch + 随机后缀生成，避免引入额外依赖。
  final String id;
  final DraftMediaType type;
  final File? localFile;
  final String? remoteUrl;
  final String? thumbPath;        // 本地缩略图路径（视频首帧 / GIF 首帧）
  final String? remoteThumbUrl;   // 服务端缩略图 URL（视频上传后由后端返回）
  final int? durationMs;          // 视频时长（毫秒）
  final int? fileSizeBytes;       // 本地文件大小（用于 100MB 校验提示）
  final int? width;
  final int? height;

  // 上传中间态
  final bool isUploading;
  final double? uploadProgress;   // 0..1
  final String? errorMessage;

  const MediaDraftItem({
    required this.id,
    required this.type,
    this.localFile,
    this.remoteUrl,
    this.thumbPath,
    this.remoteThumbUrl,
    this.durationMs,
    this.fileSizeBytes,
    this.width,
    this.height,
    this.isUploading = false,
    this.uploadProgress,
    this.errorMessage,
  });

  // 工厂：从本地图片
  factory MediaDraftItem.fromLocalImage(
    File file, {
    String? id,
    int? fileSizeBytes,
    int? width,
    int? height,
  }) {
    return MediaDraftItem(
      id: id ?? _genId(),
      type: DraftMediaType.image,
      localFile: file,
      fileSizeBytes: fileSizeBytes,
      width: width,
      height: height,
    );
  }

  // 工厂：从本地视频
  factory MediaDraftItem.fromLocalVideo(
    File file, {
    String? id,
    int? durationMs,
    String? thumbPath,
    int? fileSizeBytes,
    int? width,
    int? height,
  }) {
    return MediaDraftItem(
      id: id ?? _genId(),
      type: DraftMediaType.video,
      localFile: file,
      durationMs: durationMs,
      thumbPath: thumbPath,
      fileSizeBytes: fileSizeBytes,
      width: width,
      height: height,
    );
  }

  // 工厂：从本地 GIF
  factory MediaDraftItem.fromLocalGif(
    File file, {
    String? id,
    int? fileSizeBytes,
    int? width,
    int? height,
  }) {
    return MediaDraftItem(
      id: id ?? _genId(),
      type: DraftMediaType.gif,
      localFile: file,
      fileSizeBytes: fileSizeBytes,
      width: width,
      height: height,
    );
  }

  // 工厂：从已上传的远端 URL（草稿恢复 / 保存草稿后）
  factory MediaDraftItem.fromRemote({
    required String url,
    required DraftMediaType type,
    String? thumbPath,
    String? remoteThumbUrl,
    int? durationMs,
    int? width,
    int? height,
  }) {
    return MediaDraftItem(
      id: _genId(),
      type: type,
      remoteUrl: url,
      thumbPath: thumbPath,
      remoteThumbUrl: remoteThumbUrl,
      durationMs: durationMs,
      width: width,
      height: height,
    );
  }

  bool get isVideo => type == DraftMediaType.video;
  bool get isGif => type == DraftMediaType.gif;
  bool get isImage => type == DraftMediaType.image;

  /// 是否有本地未上传文件（需要走上传管线）
  bool get needsUpload => localFile != null;

  /// 是否有可显示的资源（本地或远端）
  bool get hasRenderable =>
      (localFile != null) ||
      (remoteUrl != null && remoteUrl!.isNotEmpty) ||
      (thumbPath != null) ||
      (remoteThumbUrl != null && remoteThumbUrl!.isNotEmpty);

  int get mediaTypeInt => type.mediaTypeInt;

  /// 时长（秒），仅视频有意义。无 duration 返回 0。
  int get durationSeconds => (durationMs ?? 0) ~/ 1000;

  /// 时长格式 "m:ss" / "h:mm:ss"
  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final s = durationSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  MediaDraftItem copyWith({
    String? id,
    DraftMediaType? type,
    File? localFile,
    String? remoteUrl,
    String? thumbPath,
    String? remoteThumbUrl,
    int? durationMs,
    int? fileSizeBytes,
    int? width,
    int? height,
    bool? isUploading,
    double? uploadProgress,
    String? errorMessage,
    bool clearError = false,
    bool clearThumb = false,
  }) {
    return MediaDraftItem(
      id: id ?? this.id,
      type: type ?? this.type,
      localFile: localFile ?? this.localFile,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbPath: clearThumb ? null : (thumbPath ?? this.thumbPath),
      remoteThumbUrl: remoteThumbUrl ?? this.remoteThumbUrl,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() => 'MediaDraftItem($id, $type, ${localFile?.path ?? remoteUrl})';
}

String _genId() {
  // microsecondsSinceEpoch + 4 位随机后缀，避免同一毫秒内冲突
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = (DateTime.now().millisecond * 31 + ts.hashCode).toRadixString(36);
  return '${ts}_$rnd';
}
