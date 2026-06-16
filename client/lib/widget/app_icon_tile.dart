import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';

/// 单个应用图标缩略图（设置页水平选择条的最小单元）。
///
/// 56×56 缩略图 + id 文字标签。选中态用 accent 边框 + 右下角勾标记。
/// 资源路径约定：assets/logos/logo_{NN}.JPG（NN 为两位数 id，1..25）。
class AppIconTile extends StatelessWidget {
  /// 1..25，对应 assets/logos/logo_{NN}.JPG
  final int id;
  final bool selected;
  final VoidCallback? onTap;

  const AppIconTile({
    super.key,
    required this.id,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Semantics(
      button: true,
      label: 'App icon $id',
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logos/logo_${id.toString().padLeft(2, '0')}.JPG',
                      fit: BoxFit.cover,
                      // 容错：素材若被移除，回退到一个浅色块
                      errorBuilder: (_, __, ___) => Container(
                        color: appColors.divider,
                        alignment: Alignment.center,
                        child: Text(
                          id.toString(),
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appColors.accent,
                          width: 2,
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: appColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.check_mark,
                          color: appColors.background,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              id.toString(),
              style: TextStyle(
                color: selected ? appColors.textPrimary : appColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}