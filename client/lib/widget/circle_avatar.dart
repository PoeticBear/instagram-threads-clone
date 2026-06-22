import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';

/// 项目级「纯圆形头像」组件。
///
/// 设计目的：统一 client/lib 内所有「裸头像」渲染点，防止不同页面写各自的
/// avatar() 闭包 / _buildAvatar() 方法时漏 `fit: BoxFit.cover`（导致长图
/// 横向拉伸为「胖」圆形）或漏 `placeholder` / `errorWidget`（导致加载中/
/// 失败时头像为空白）。
///
/// 与 `UserAvatarWithFollow` 的关系：
/// - [AppCircleAvatar]  = 基础圆形头像（只有图）
/// - [UserAvatarWithFollow] = AppCircleAvatar + 关注加号徽标 + 关注态管理
///
/// 视觉行为（与主帖头像保持一致）：
/// - URL 为空 → 灰色圆形 + 居中 `Icons.person` 占位
/// - 加载中  → 灰色圆形 + 居中 `CircularProgressIndicator`
/// - 加载失败 → 灰色圆形 + 居中 `Icons.person` 占位
/// - 加载成功 → `BoxFit.cover` 居中裁切（长图 / 横图都不变形）
class AppCircleAvatar extends StatelessWidget {
  const AppCircleAvatar({
    super.key,
    required this.avatarUrl,
    this.size = 35,
    this.onTap,
  });

  /// 头像图片 URL。空串走 `Icons.person` 占位。
  final String avatarUrl;

  /// 头像直径（正方形）。默认 35。
  final double size;

  /// 点击头像回调。`null` 时头像不可点击（由外层 GestureDetector 接管）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    final Widget content;
    if (avatarUrl.isEmpty) {
      // 无 URL：直接渲染占位
      content = _placeholder(appColors);
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: appColors.surface,
            alignment: Alignment.center,
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: appColors.textSecondary,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _placeholder(appColors),
        ),
      );
    }

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  /// 空 URL / 加载失败 时的统一降级占位：灰色圆形 + 居中 person 图标。
  Widget _placeholder(AppColors appColors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: appColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: appColors.textSecondary,
      ),
    );
  }
}
