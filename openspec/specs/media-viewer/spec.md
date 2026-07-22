# media-viewer Specification

## Purpose
TBD - created by archiving change media-viewer-interaction-bar. Update Purpose after archive.
## Requirements
### Requirement: MediaViewerPage 接受 PostModel 参数
`MediaViewerPage` MUST 接受一个必填的 `PostModel postModel` 参数，调用方在跳转前传入对应的 PostModel。

#### Scenario: 三处调用方均传入 postModel
- **WHEN** FeedPost / PostDetailPage / ProfilePage 任意一处调用 `Navigator.push(MediaViewerPage(...))`
- **THEN** 调用方 MUST 传入 `postModel: <对应的 PostModel 实例>`

### Requirement: 底部互动统计横条始终可见
进入全屏查看模式后，页面底部 MUST 持续显示一条互动统计横条，包含 4 个图标 + 数值的组合，按从左到右顺序排列为：点赞、回复、引用、转发。

#### Scenario: 加载完成后显示横条
- **WHEN** 用户从任意入口进入 `MediaViewerPage`
- **THEN** 页面底部 MUST 在主内容下方渲染 4 个等宽的图标 + 数值按钮

#### Scenario: PageView 滑动时横条不消失
- **WHEN** 用户在多图 PageView 中左右滑动切换图片
- **THEN** 底部横条 MUST 保持显示，数字不变（同一帖子多图）

#### Scenario: 数值兜底
- **WHEN** `PostModel` 的 `likesCount / repliesCount / quotesCount / repostsCount` 任意字段为 null
- **THEN** 对应按钮 MUST 显示数值 `0`

### Requirement: 点赞按钮可交互且实时刷新
底部横条中的点赞按钮 MUST 可点击：点击切换当前帖子的点赞状态，数字与图标 MUST 立即跟随 `PostState` 的最新值变化（无需退出全屏）。

#### Scenario: 未点赞 → 点击 → 已点赞
- **WHEN** 当前 PostModel 的 `isLiked == false`，用户点击点赞按钮
- **THEN** 系统 MUST 调用 `PostState.likePost(postId)`；按钮图标切换为已点赞样式（实心 heart），颜色切换为主题点赞色；数值 +1

#### Scenario: 已点赞 → 点击 → 取消点赞
- **WHEN** 当前 PostModel 的 `isLiked == true`，用户点击点赞按钮
- **THEN** 系统 MUST 调用 `PostState.unlikePost(postId)`；按钮图标切换为未点赞样式（空心 heart），颜色恢复为 textPrimary；数值 -1

#### Scenario: API 失败回滚
- **WHEN** 点赞 API 抛出异常
- **THEN** `PostState` MUST 回滚本地状态（数字与激活态复原），UI 同步恢复

### Requirement: 转发按钮可交互
底部横条中的转发按钮 MUST 可点击：点击 MUST 弹出已有的 `RepostSheet` 浮层，遵循现有转发确认流程；确认后数字 +1 且激活态变为主题转发色。

#### Scenario: 点击转发按钮
- **WHEN** 用户点击转发按钮
- **THEN** 系统 MUST 弹出 `RepostSheet`；用户取消时横条状态不变；用户确认后 MUST 调用 `PostState.repost(postId)`，数值 +1，按钮图标颜色切换为转发色

### Requirement: 回复按钮跳转帖子详情
底部横条中的回复按钮 MUST 跳转到 `PostDetailPage`（保持现有行为），不直接弹回复输入框。

#### Scenario: 点击回复按钮
- **WHEN** 用户点击回复按钮
- **THEN** 系统 MUST 关闭 `MediaViewerPage` 并 push `PostDetailPage(postId: ...)`；当前帖子的回复数通过 PostDetailPage 进入后展示

### Requirement: 引用按钮跳转写帖页引用模式
底部横条中的引用按钮 MUST 跳转到 `ComposePost` 的引用模式（保持现有行为），允许用户撰写带评论的转发。

#### Scenario: 点击引用按钮
- **WHEN** 用户点击引用按钮
- **THEN** 系统 MUST 关闭 `MediaViewerPage` 并 push `ComposePost` 的引用模式，预填当前帖子作为被引用对象

### Requirement: 状态订阅保证实时同步
`MediaViewerPage` MUST 在生命周期内订阅 `PostState` 的变更通知；当 `PostState` 中与 `postModel.id` 匹配的 PostModel 更新时，本地用于渲染横条的 PostModel 快照 MUST 同步刷新，保证数字与激活态与全局状态一致。

#### Scenario: 横条内点击点赞
- **WHEN** 用户在底部横条内点击点赞
- **THEN** 数字与激活态 MUST 在 `PostState` 通知后立即刷新（无需手动重渲染）

#### Scenario: 横条外全局状态变化（如详情页返回后）
- **WHEN** 用户从全屏跳转到 `PostDetailPage` 完成互动后返回
- **THEN** 横条数字与激活态 MUST 反映 PostState 中的最新状态

#### Scenario: 页面销毁时取消订阅
- **WHEN** `MediaViewerPage.dispose()` 被调用
- **THEN** MUST 移除对 `PostState` 的监听，防止内存泄漏

### Requirement: 视觉规范 — 黑色半透 + 模糊
底部横条 MUST 满足以下视觉规范：
- 背景：黑色（`Colors.black`）半透明（alpha ≈ 0.4）+ `BackdropFilter` 模糊效果
- 布局：4 个按钮等宽分布（`Row` + `Expanded` × 4），水平内边距 16，垂直内边距 12
- 安全区：横条 MUST 包在 `SafeArea(top: false)` 内，自动避让底部 home indicator
- 图标：使用 `iconsax` 包，size 22；激活态用主题色（点赞 `appColors.like`，转发 `appColors.repost`），未激活态用 `appColors.textPrimary`
- 数字：字号 13，颜色 `appColors.textSecondary`，紧跟图标右侧，间距 6
- 不阻挡：横条 MUST 不阻挡顶部浮层（X 按钮、页码）和右下角旋转按钮的显示与交互

#### Scenario: 黑色半透 + 模糊背景
- **WHEN** 任意图片或视频作为底部背景时
- **THEN** 底部横条 MUST 呈现深色半透 + 模糊效果，与图片内容视觉上有清晰分层

#### Scenario: 刘海屏安全区
- **WHEN** 设备有底部 home indicator（如 iPhone X 及以上）
- **THEN** 横条 MUST 与 home indicator 保持视觉距离，不被遮挡

### Requirement: 现有功能不受影响
以下现有功能 MUST 保持完全不变：
- 顶部浮层（X 按钮 + "n/N" 页码）
- 右下角旋转按钮（仅视频横屏模式）
- PageView 多图滑动
- `InteractiveViewer` 双指缩放 / 平移
- 视频播放与暂停
- 横竖屏切换

#### Scenario: 现有交互行为保留
- **WHEN** 用户点击顶部 X 按钮 / 滑动切换图片 / 双指缩放图片 / 点击旋转按钮
- **THEN** 所有原有交互行为 MUST 与改动前一致

