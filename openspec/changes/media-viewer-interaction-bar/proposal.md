## Why

用户在首页帖子信息流中点击图片进入全屏查看模式后，目前页面底部完全留白，只能看图。用户在「沉浸式看图」的场景下经常想顺手完成点赞、转发等互动，但当前必须先退出全屏模式回到信息流卡片才能操作。这个切换打断浏览节奏，体验不够顺滑。

需要做的：在全屏图片查看器底部新增一条互动统计横条，展示当前帖子所属的 4 个互动计数（点赞 / 回复 / 引用 / 转发），用户能直接在其中完成点赞 / 转发操作，其余两个动作跳转到对应详情页或写帖页。

## What Changes

- **新增**：在 `MediaViewerPage` 底部叠加一条互动统计横条（图标 + 数值）
- **新增**：横条内 4 个按钮中，**点赞** 和 **转发** 可直接交互，数字与激活态实时刷新；**回复** 跳转到 `PostDetailPage`；**引用** 跳转到 `ComposePost` 的引用模式
- **新增**：`MediaViewerPage` 新增必填 prop `PostModel postModel`，三处调用入口（FeedPost / PostDetailPage / Profile）同步传入
- **新增**：`MediaViewerPage` 订阅 `PostState.addListener`，根据 `postId` 拉取最新 PostModel 更新本地快照，保证数字与激活态实时同步
- **保护**：现有顶部浮层（X 按钮 + 页码）、右下角旋转按钮（仅视频）、PageView 多图滑动、`InteractiveViewer` 双指缩放、视频播放、横竖屏切换 全部保持不变
- **保护**：FeedPost 卡片原有的 4 个互动按钮（点赞 / 回复 / 转发 / 分享）保持原样，不被替代或迁移

## Capabilities

### New Capabilities
- `media-viewer`: 全屏图片/视频查看器（MediaViewerPage）的整体交互契约，包括 props、底部互动统计横条行为、状态订阅与同步、视觉规范

### Modified Capabilities
无（不修改现有 spec 的需求级别行为；`compose-post` 引用模式入口已存在，仅复用，不修改契约）

## Impact

**受影响代码**
- `client/lib/pages/media/media_viewer_page.dart` — 核心改动，新增底部横条 + props + 状态订阅
- `client/lib/widget/feedpost.dart` — `_openMediaViewer` 调用处传入 `widget.postModel`
- `client/lib/pages/post/post_detail_page.dart` — `_openMediaViewer` 调用处传入 `postModel`
- `client/lib/pages/profile/profile.dart` — 同上，传入 `postModel`

**不受影响**
- `client/lib/model/post.module.dart` — 不改字段，只读
- `client/lib/state/post.state.dart` — 复用现有 `likePost/unlikePost/repost/unrepost`，不新增方法
- 顶部浮层组件、右下角旋转按钮组件 — 保持原样
- 任何 Android 适配代码（本项目仅维护 iOS）

**新增依赖**
- 无（复用现有 `iconsax`、Provider、AppLocalizations、AppColorsExtension）

**i18n**
- 复用已有 key：`reply` / `quote` / `repost`（"点赞" 无 key，沿用 FeedPost 的直接渲染方式）
