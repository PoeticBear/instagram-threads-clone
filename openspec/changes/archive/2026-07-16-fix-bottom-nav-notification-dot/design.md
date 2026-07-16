## Context

**当前状态**：
- 底部导航栏 5 个 Tab 由 `client/lib/pages/home.dart` 的 `_HomePageState.bottomNavBar()` 渲染。
- 第 4 项（`tabIndex: 3`）图标为 `Iconsax.heart`，未读小红点是一个 8×8 圆形 `Container`，挂在 `Stack(alignment: Alignment.center)` 里的 `Positioned(right: 0, top: 8)`，颜色取 `appColors.accent`（深色模式 `Colors.blue`，浅色模式 `0xff0064e0`）。
- `Stack` 配置 `clipBehavior: Clip.none`，因此 `Positioned` 可越过 Stack 边界。
- 通知列表 `client/lib/pages/notification/notification.dart` 第 422-431 行也有一个未读指示器（每条未读通知右侧的小圆点），尺寸同样是 8×8，颜色同样使用 `appColors.accent`。
- `appColors` 已存在 `destructive`（深色 / 浅色均为 `Colors.red`），并在消息列表的未读数字 badge（`message_list_tile.dart:139`）中作为"未读/提醒"语义使用。

**约束**：
- 只改样式层（颜色 + 位置），不动状态、不动 API、不动导航、不动主题 token 结构。
- 不引入新依赖，不新增颜色字段。
- iOS only（项目策略）。

**利益相关方**：产品（视觉一致性）、用户（更清晰的红点位置与色系辨识）。

## Goals / Non-Goals

**Goals：**
- 把底部导航第 4 项的红点位置从 `right:0, top:8` 调整为 `right:22, top:14`，视觉上挂在心形 icon 的右上肩。
- 把 Tab Bar 红点颜色从 `appColors.accent` 改为 `appColors.destructive`。
- 顺手把通知列表项里同色的未读小圆点也改为 `appColors.destructive`，统一 App 内"未读提醒"色系。
- 与消息列表的 `_buildUnreadBadge`（已用 `appColors.destructive`）保持同一视觉语言。

**Non-Goals：**
- 不新增颜色 token 或主题字段。
- 不调整红点尺寸（保持 8×8）。
- 不调整通知列表项的小圆点位置（只换色）。
- 不调整其他 Tab 项。
- 不引入自动化 UI 测试。

## Decisions

### Decision 1：颜色 token 选 `appColors.destructive` 而非 `appColors.like`

**取舍**：
- `appColors.like` 也是红色（深浅都 `Colors.red`），语义上"红点挂在心形上"听上去合理。
- 但 App 内已经有先例：**消息列表的未读数字 badge（`message_list_tile.dart:139`）使用的是 `appColors.destructive`**。Tab Bar 红点、消息列表红 badge、通知列表红点本质都是"未读/提醒"语义，统一到 `destructive` 更连贯。
- `like` 语义更贴近"心形 icon 本身的颜色"（如 feed 帖子的点赞按钮），而不是"提醒容器上的指示器"。

**结论**：用 `appColors.destructive`，与消息列表未读 badge 同色。

### Decision 2：Tab Bar 红点位置选 `top:14, right:22`

**几何分析**：
- Container 高度 90，`padding: EdgeInsets.only(bottom: 20)` → 有效高度 70。
- `SizedBox(height: 70)` 内 Stack `alignment: Alignment.center` → 心形 icon（30×30）中心约位于 `(cellWidth/2, 35)`。
- iPhone 屏宽 ≈ 390pt，每格 ≈ 78pt；icon 中心 x ≈ 39，icon 右边缘 x ≈ 54。
- 当前 `right:0, top:8` → 红点贴在单元格右上角，与 icon 右上边缘的水平距离 ≈ 24pt，垂直距离 ≈ 12pt。
- 目标 `right:22, top:14` → 红点中心约 `(cellWidth - 22 - 4, 14 + 4) = (52, 18)`，几乎贴在 icon 右上肩（约 icon 中心 1 点钟方向），与 icon 轮廓轻微重叠，符合主流 App 通知徽章惯例。

**为什么不是更激进的 `right:18, top:16`**：
- 仍需保留 `clipBehavior: Clip.none` 的越界余量，避免在更窄屏（如 iPhone SE）出现红点切到 icon 内部、影响辨识。
- `top:14` 让红点顶部与 icon 顶部（y≈20）有 6pt 重叠空间，足以"挂"在 icon 上但不会盖住 icon 主体。

**为什么不做响应式计算**：
- 项目内其他 Tab 项的位置/尺寸都是硬编码（如 icon size 30），没必要为单点引入 MediaQuery。
- `right:22, top:14` 在主流 iPhone 屏宽（375-430pt）下视觉一致。

### Decision 3：通知列表指示器只改色不改位

- 该指示器在通知项的右侧，与列表文本有固定间距约束，本身没有"漂出容器"的问题（不像 Tab Bar 那个远离 icon）。
- 保持位置不动可降低改动面，避免影响通知列表已有的视觉节奏。

## Risks / Trade-offs

- **跨屏宽一致性**：`right:22` 是固定值，在极端窄屏（如 iPhone SE 第一代 320pt）或宽屏（iPad）下与 icon 的相对位置会有 ~5pt 漂移。
  - **缓解**：项目策略只维护 iOS，且 iPhone SE 第一代已不在目标设备范围；iPad 不展示移动 Tab Bar，无影响。

- **色弱可达性**：纯色红点对红绿色盲用户辨识度尚可（红点形状独立、有尺寸差）。
  - **缓解**：保持圆形 8×8 不变，与既有 badge 风格一致；无需额外 outline。

- **回退成本**：纯样式改动，git revert 即可，零数据风险。

## Migration Plan

无 — 纯展示层调整，随下一次 TestFlight 发版自动生效。

## Open Questions

无。