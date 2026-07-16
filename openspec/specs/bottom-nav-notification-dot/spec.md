## Purpose

`bottom-nav-notification-dot` capability 覆盖底部导航栏第 4 项（心形 Tab）未读红点与通知列表未读指示器的视觉规范——确保两个未读指示器视觉位置正确、颜色统一为红色,与消息列表未读 badge 形成一致的"未读/提醒"色系。

---

## ADDED Requirements

### Requirement: 底部导航第 4 项未读红点位置紧贴心形 icon

底部导航栏第 4 项（心形 Tab，`tabIndex: 3`）的未读小红点 MUST 视觉上挂在心形 icon 的右上肩附近，而非漂浮在 Tab 单元格的右上角。具体定位：8×8 圆形 `Container`，由 `Positioned` 锚定，`top: 14, right: 22`（与现行 `right: 0, top: 8` 对比，向左下贴近约 22pt / 6pt）。

#### Scenario: 未读时红点靠在心形右上肩

- **WHEN** `NotificationState.unreadCount > 0` 且底部导航渲染完成
- **THEN** 红点的视觉中心 MUST 大致位于心形 icon 中心右上 1 点钟方向，与 icon 轮廓轻微重叠

#### Scenario: 无未读时不渲染红点

- **WHEN** `NotificationState.unreadCount == 0`
- **THEN** MUST 不渲染红点 `Container`（badge 为 null）

### Requirement: 底部导航未读红点与通知列表未读指示器统一为红色

底部导航第 4 项红点 与 通知列表项内未读指示器 MUST 使用 `appColors.destructive`（红色）作为 `BoxDecoration.color`，不再使用 `appColors.accent`（蓝色）。

#### Scenario: 两种未读指示器在 App 中保持同一色系

- **WHEN** 用户在 App 任一主题下查看底部导航第 4 项红点 或 通知列表项未读指示器
- **THEN** MUST 渲染为红色（深色 / 浅色主题均为 `Colors.red`），与消息列表的未读数字 badge（`message_list_tile._buildUnreadBadge`）形成统一的"未读/提醒"色系

#### Scenario: 不新增颜色 token

- **WHEN** 实现本次颜色切换
- **THEN** MUST 直接复用现有 `appColors.destructive`；MUST NOT 在 `AppColors` 类中新增任何颜色字段