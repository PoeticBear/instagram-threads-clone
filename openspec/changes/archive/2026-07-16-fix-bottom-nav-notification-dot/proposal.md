## Why

底部导航栏第 4 项（心形 Tab）的未读小红点当前贴在整个 Expanded 单元格的右上角，与心形 icon 距离过远，视觉上像漂在 Tab 之外；并且颜色使用品牌蓝（`appColors.accent`），与 App 内其他"未读提醒"语义（消息列表红 badge、通知列表小蓝点）颜色不一致，缺少统一的视觉语言。

本次调整让红点视觉上"挂在心形右上肩"，同时把 Tab Bar 红点和通知列表未读指示器统一为红色，与消息列表的未读 badge 形成一致的"未读/提醒"色系。

## What Changes

- **底部导航第 4 项红点位置调整**：从 `Positioned(right: 0, top: 8)` 调整为 `Positioned(right: 22, top: 14)`，使 8×8 红点靠在心形 icon 的右上肩。
- **底部导航红点颜色调整**：`color: appColors.accent`（蓝）改为 `color: appColors.destructive`（红）。
- **通知列表未读指示器颜色同步**：`client/lib/pages/notification/notification.dart` 列表项里的 8×8 未读小蓝点（`appColors.accent`）同步改为 `appColors.destructive`，位置/尺寸不动。
- 无 API、状态、导航、依赖变更。

## Capabilities

### New Capabilities

无新增 capability。本次为纯展示层视觉调整，不引入新的能力边界。

### Modified Capabilities

无现有 capability 的 REQUIREMENTS 被修改。涉及的两个文件均属现有页面（`home.dart`、`notification/notification.dart`）的内部样式细节，不构成 spec 级行为变更。

## Impact

- **修改文件**：
  - `client/lib/pages/home.dart`（`bottomNavBar()` 内第 4 项 `badge: Positioned(...)` 节点，约 170-183 行）
  - `client/lib/pages/notification/notification.dart`（列表项内未读指示器 `Container`，约 422-431 行）
- **改动量**：每个文件实质改动 ~1 行（外加调整 Positioned 偏移量）。
- **主题 / 颜色 token**：不新增字段，复用现有 `appColors.destructive`。
- **行为 / API / 状态 / 路由**：无影响。
- **测试**：无需新增自动化测试（视觉层），人工对照截图验收即可。
- **风险**：零，纯展示层，构建无影响。