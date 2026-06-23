import 'package:flutter/material.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/mention_list_item.dart';

/// @mention 用户选择面板容器。
///
/// 由 `ComposePostState` 通过 `OverlayEntry` 注入到根 Overlay，
/// 通过 `CompositedTransformFollower` + `LayerLink` 锚定到 TextField 下方。
///
/// 内部为 `Material(type: transparency)` + 圆角白底 + 轻阴影 + `maxHeight: 240` 的
/// `ListView.separated`。调用方在 `_filterAndShow` 中已保证传入的 [users] 非空，
/// 因此本组件不处理「无匹配」状态（空列表时调用方直接不显示 overlay）。
class MentionOverlay extends StatelessWidget {
  const MentionOverlay({
    super.key,
    required this.users,
    required this.onSelected,
  });

  final List<UserInfo> users;
  final void Function(UserInfo) onSelected;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: appColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appColors.divider, width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (_, __) => Divider(
            height: 0.5,
            thickness: 0.5,
            color: appColors.divider,
          ),
          itemBuilder: (_, i) => MentionListItem(
            user: users[i],
            onTap: () => onSelected(users[i]),
          ),
        ),
      ),
    );
  }
}
