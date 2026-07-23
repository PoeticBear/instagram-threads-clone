import 'dart:io';

import 'package:threads/model/camera_capture_result.dart';
import 'package:threads/utils/video_processor.dart';

/// 相机 / 相册拍摄结果的统一校验。
///
/// - 图片：≤ 10MB
/// - 视频：≤ 100MB 且实际时长 ≤ 300 秒（5 分钟）
/// - GIF：≤ 10MB（保留常量供未来使用，相机当前不产出 GIF）
///
/// 返回值：
/// - [ValidationResult.ok] 表示通过
/// - [ValidationResult.failed] 表示校验失败，`message` 是用户可读的提示
class CameraResultValidator {
  /// 图片上限：10MB
  static const int imageMaxBytes = 10 * 1024 * 1024;

  /// 视频上限：100MB
  static const int videoMaxBytes = 100 * 1024 * 1024;

  /// GIF 上限：10MB
  static const int gifMaxBytes = 10 * 1024 * 1024;

  /// 视频时长上限：300 秒
  static const int videoMaxDurationMs = 300 * 1000;

  /// 校验一个 [CameraCaptureResult]。
  ///
  /// 仅依赖本地文件大小与（视频）元信息探测；校验失败时直接返回错误，
  /// 调用方据此跳过该结果并 toast 错误。
  static Future<ValidationResult> validate(CameraCaptureResult result) async {
    final file = File(result.path);
    int size;
    try {
      size = await file.length();
    } catch (_) {
      return const ValidationResult.failed('文件不存在或不可读');
    }

    if (result.isVideo) {
      if (size > videoMaxBytes) {
        return ValidationResult.failed(
          '视频超过 ${videoMaxBytes ~/ (1024 * 1024)}MB 上限（当前 ${(size / 1024 / 1024).toStringAsFixed(1)}MB）',
        );
      }
      // 优先用媒体文件实际时长；探测失败 → 拒绝（避免上传到服务端才发现超长）
      try {
        final meta = await VideoProcessor.getMediaInfo(result.path);
        if (meta.durationMs <= 0 || meta.durationMs > videoMaxDurationMs) {
          return const ValidationResult.failed('视频时长无效');
        }
        return const ValidationResult.ok();
      } on VideoProcessException {
        return const ValidationResult.failed('视频时长无效');
      }
    }

    // 图片（含 GIF 走同一路径，相机不产 GIF，但保留入口）
    if (size > imageMaxBytes) {
      return ValidationResult.failed(
        '图片超过 ${imageMaxBytes ~/ (1024 * 1024)}MB 上限（当前 ${(size / 1024 / 1024).toStringAsFixed(1)}MB）',
      );
    }
    return const ValidationResult.ok();
  }
}

class ValidationResult {
  final bool ok;
  final String? message;

  const ValidationResult.ok()
      : ok = true,
        message = null;

  const ValidationResult.failed(String this.message) : ok = false;
}