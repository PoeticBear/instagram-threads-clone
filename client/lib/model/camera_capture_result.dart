import 'dart:io';

/// 相机拍摄结果（统一照片和视频）
/// - 照片：[durationMs] = 0，[thumbnail] = null
/// - 视频：[durationMs] > 0，[thumbnail] 为首帧 jpg（生成失败时为 null，UI 兜底占位）
class CameraCaptureResult {
  /// 本地文件路径（jpg / mp4）
  final String path;

  /// 时长（毫秒）。照片 = 0
  final int durationMs;

  /// 视频首帧缩略图（jpg）。照片 = null；视频生成失败时也 = null
  final File? thumbnail;

  const CameraCaptureResult({
    required this.path,
    this.durationMs = 0,
    this.thumbnail,
  });

  /// 是否为视频
  bool get isVideo => durationMs > 0;

  /// 照片
  factory CameraCaptureResult.photo(String path) =>
      CameraCaptureResult(path: path, durationMs: 0, thumbnail: null);

  /// 视频
  factory CameraCaptureResult.video({
    required String path,
    required int durationMs,
    File? thumbnail,
  }) =>
      CameraCaptureResult(
        path: path,
        durationMs: durationMs,
        thumbnail: thumbnail,
      );
}
