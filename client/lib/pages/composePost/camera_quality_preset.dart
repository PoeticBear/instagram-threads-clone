import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

/// 受控画质档位：仅 720p/30fps 与 1080p/30fps；默认 1080p/30fps。
enum CameraQualityPreset {
  sd720p30,
  hd1080p30;

  /// 短标签用于 UI 显示
  String get shortLabel {
    switch (this) {
      case CameraQualityPreset.sd720p30:
        return '720p';
      case CameraQualityPreset.hd1080p30:
        return '1080p';
    }
  }

  /// 对应的 [ResolutionPreset]；底层允许回退，不做强制约束。
  ResolutionPreset get resolutionPreset {
    switch (this) {
      case CameraQualityPreset.sd720p30:
        return ResolutionPreset.medium;
      case CameraQualityPreset.hd1080p30:
        return ResolutionPreset.veryHigh;
    }
  }

  /// 固定 30fps；不暴露独立帧率选择
  int get fps => 30;
}