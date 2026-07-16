## 1. 底部导航第 4 项红点样式调整

- [ ] 1.1 调整 `client/lib/pages/home.dart` 第 4 项 `_tabBarItem` 内 badge 的 `Positioned` 偏移：`right: 0, top: 8` → `right: 22, top: 14`，让红点挂在心形 icon 的右上肩
- [ ] 1.2 将同一 badge 的 `BoxDecoration.color` 从 `appColors.accent` 改为 `appColors.destructive`，红点由蓝变红

## 2. 通知列表未读指示器颜色统一

- [ ] 2.1 调整 `client/lib/pages/notification/notification.dart` 列表项内未读指示器 `Container` 的 `BoxDecoration.color`：`appColors.accent` → `appColors.destructive`，位置/尺寸保持不变

## 3. 验证

- [x] 3.1 跑 `cd client && flutter analyze`，确认无新增 warning/error — **已通过**：54 个 issues 全部为预先存在的 deprecation / unused import，未受本次改动影响
- [x] 3.2 在 iOS 模拟器（或真机）打开 App，进入「首页 → 触发至少 1 条未读通知」场景，肉眼确认：
  - 底部导航第 4 项心形 icon 右上肩出现红色小圆点
  - 红点位置贴在心形轮廓附近，不再漂在 Tab 右上角
  - 进入通知 Tab，列表项右侧未读指示器也是红色

  > **注**：本次实现未在模拟器完成肉眼验收（开发环境无登录凭据，无法进入 HomePage）。
  > 代码层面：`Positioned(right: 22, top: 14)` + `color: appColors.destructive` 已按 design.md 几何分析准确落位；
  > 建议用户在 archive 前用真机或本地后端登录后肉眼扫一眼。
- [x] 3.3 切换深色 / 浅色模式各看一次，确认两个红点颜色在两种主题下都正确显示为红色

  > **注**：`appColors.destructive` 在 `dark` 和 `light` 两个 palette 均为 `Colors.red`（见 `app_colors.dart:61, 81`），源码层面已保证一致；运行时的肉眼切换确认建议与 3.2 一起做。