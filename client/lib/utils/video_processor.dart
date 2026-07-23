import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// 视频处理工具类：基于 `video_compress` 封装
/// - getMediaInfo：探测时长、宽高
/// - getThumbnail：生成首帧缩略图
/// - compress：压缩视频（中质量 / 720p / 30fps / 保留音轨）
class VideoProcessor {
  /// 视频时长上限（毫秒），超过则拒绝
  /// 与发布帖相机 / 上传链路保持一致：300 秒（5 分钟）。
  static const int defaultMaxDurationMs = 300 * 1000;

  /// 探测视频元信息（不压缩，不写文件）
  /// 失败时抛 [VideoProcessException]。
  static Future<VideoMeta> getMediaInfo(String path) async {
    try {
      final info = await VideoCompress.getMediaInfo(path);
      return VideoMeta(
        path: path,
        durationMs: info.duration?.toInt() ?? 0,
        width: info.width,
        height: info.height,
        // video_compress 的 MediaInfo 没有直接 fileSize 字段，需自行探测
        fileSize: await _safeFileSize(path),
      );
    } on VideoProcessException {
      rethrow;
    } catch (e, st) {
      developer.log('❌ getMediaInfo 失败: $e\n$st', name: 'VideoProcessor');
      throw VideoProcessException('读取视频信息失败: $e');
    }
  }

  /// 生成首帧缩略图（jpg）。返回临时文件 [File]。
  /// 调用方负责后续清理（路径在 app cache 目录）。
  static Future<File> getThumbnail(String videoPath, {int quality = 80}) async {
    try {
      final thumb = await VideoCompress.getFileThumbnail(videoPath, quality: quality);
      return thumb;
    } on VideoProcessException {
      rethrow;
    } catch (e, st) {
      developer.log('❌ getThumbnail 失败: $e\n$st', name: 'VideoProcessor');
      throw VideoProcessException('生成视频缩略图失败: $e');
    }
  }

  /// 压缩视频。中等质量 / 30fps / 保留音轨。
  /// 压缩前会先校验时长，超过 [maxDurationMs] 直接抛异常。
  /// 返回新文件路径（与原文件可能不同）。
  /// 压缩失败会抛 [VideoProcessException]，调用方可降级使用原文件。
  static Future<String> compress(
    String path, {
    int maxDurationMs = defaultMaxDurationMs,
    VideoQuality quality = VideoQuality.MediumQuality,
    bool includeAudio = true,
    int frameRate = 30,
    bool deleteOrigin = false,
    void Function(double progress)? onProgress,
  }) async {
    // 1) 时长校验
    final info = await getMediaInfo(path);
    if (info.durationMs > maxDurationMs) {
      throw VideoProcessException(
        '视频时长 ${(info.durationMs / 1000).toStringAsFixed(1)}s 超过 ${maxDurationMs ~/ 1000}s 上限',
      );
    }

    // 2) 压缩
    try {
      final subscription = onProgress != null
          ? VideoCompress.compressProgress$.subscribe((progress) {
              // progress is 0..1
              onProgress(progress.clamp(0.0, 1.0));
            })
          : null;

      try {
        final result = await VideoCompress.compressVideo(
          path,
          quality: quality,
          deleteOrigin: deleteOrigin,
          includeAudio: includeAudio,
          frameRate: frameRate,
        );
        if (result?.file == null) {
          throw const VideoProcessException('视频压缩失败');
        }
        return result!.file!.path;
      } finally {
        subscription?.unsubscribe();
      }
    } on VideoProcessException {
      rethrow;
    } catch (e, st) {
      developer.log('❌ compress 失败: $e\n$st', name: 'VideoProcessor');
      throw VideoProcessException('视频压缩失败: $e');
    }
  }

  /// 删除临时文件（缩略图 / 压缩产物），不存在则忽略。
  static Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // 静默：临时文件清理失败不影响主流程
    }
  }

  /// 取消正在进行的压缩任务（用于页面 dispose 时）
  static Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }

  /// 释放 video_compress 内部缓存（建议在退出发布页时调用）
  static Future<void> deleteAllCache() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {}
  }

  static Future<int> _safeFileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }
}

class VideoMeta {
  final String path;
  final int durationMs;
  final int? width;
  final int? height;
  final int fileSize;

  const VideoMeta({
    required this.path,
    required this.durationMs,
    this.width,
    this.height,
    this.fileSize = 0,
  });

  int get durationSeconds => durationMs ~/ 1000;
}

class VideoProcessException implements Exception {
  final String message;
  const VideoProcessException(this.message);

  @override
  String toString() => 'VideoProcessException: $message';
}
