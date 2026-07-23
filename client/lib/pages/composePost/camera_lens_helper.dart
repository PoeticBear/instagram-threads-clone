import 'package:camera_platform_interface/camera_platform_interface.dart';

/// 物理镜头条目 + 用户可见的"倍率"标签。
class CameraLensInfo {
  final int cameraIndex;
  final CameraLensDirection direction;
  final CameraLensType lensType;

  /// UI 上显示的标签（如 "0.5×" / "1×" / "2×"），由 lensType 推导。
  final String label;

  const CameraLensInfo({
    required this.cameraIndex,
    required this.direction,
    required this.lensType,
    required this.label,
  });
}

/// 静态工具：枚举设备并按 lensType → label 排序输出后置镜头。
class CameraLensHelper {
  /// 后置镜头排序：ultraWide → wide → telephoto（缺啥不显示啥）。
  static List<CameraLensInfo> backLenses(List<CameraDescription> cameras) {
    final result = <CameraLensInfo>[];
    for (int i = 0; i < cameras.length; i++) {
      final c = cameras[i];
      if (c.lensDirection != CameraLensDirection.back) continue;
      final label = _labelFor(c.lensType);
      if (label == null) continue;
      result.add(CameraLensInfo(
        cameraIndex: i,
        direction: c.lensDirection,
        lensType: c.lensType,
        label: label,
      ));
    }
    result.sort((a, b) => _order(a.lensType).compareTo(_order(b.lensType)));
    return result;
  }

  /// 前置镜头：只列 1×。
  static List<CameraLensInfo> frontLenses(List<CameraDescription> cameras) {
    final result = <CameraLensInfo>[];
    for (int i = 0; i < cameras.length; i++) {
      final c = cameras[i];
      if (c.lensDirection != CameraLensDirection.front) continue;
      // 前置的 lensType 通常是 wide；若不存在 wide，则取第一个
      result.add(CameraLensInfo(
        cameraIndex: i,
        direction: c.lensDirection,
        lensType: c.lensType,
        label: '1×',
      ));
      break;
    }
    return result;
  }

  static String? _labelFor(CameraLensType type) {
    switch (type) {
      case CameraLensType.ultraWide:
        return '0.5×';
      case CameraLensType.wide:
        return '1×';
      case CameraLensType.telephoto:
        return '2×';
      case CameraLensType.unknown:
        return null;
    }
  }

  static int _order(CameraLensType type) {
    switch (type) {
      case CameraLensType.ultraWide:
        return 0;
      case CameraLensType.wide:
        return 1;
      case CameraLensType.telephoto:
        return 2;
      case CameraLensType.unknown:
        return 99;
    }
  }
}