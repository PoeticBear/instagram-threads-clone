## 1. MediaViewerPage props 与状态订阅

- [x] 1.1 给 `MediaViewerPage` 添加必填 prop `final PostModel postModel;`，与现有 `mediaItems` / `initialIndex` 并列
- [x] 1.2 把 `MediaViewerPage` 改造为持有本地 `late PostModel _currentPost` 字段，初始值取自 widget.postModel
- [x] 1.3 在 `initState` 中 `Provider.of<PostState>(context, listen: false).addListener(_onPostStateChanged)` 订阅 PostState
- [x] 1.4 实现 `_onPostStateChanged()`：从 PostState 中按 `postId` 找到最新 PostModel 同步到 `_currentPost` 并 `setState`
- [x] 1.5 在 `dispose` 中移除监听，防止内存泄漏

## 2. 底部互动统计横条 UI

- [x] 2.1 在 `MediaViewerPage.body.Stack` 内新增 `Positioned(left: 0, right: 0, bottom: 0, ...)` 节点
- [x] 2.2 横条最外层用 `SafeArea(top: false, child: ...)` 包住，处理底部 home indicator
- [x] 2.3 容器实现：`ClipRRect` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))` + 黑色半透底（`Colors.black.withOpacity(0.4)`）
- [x] 2.4 内层 `Padding(horizontal: 16, vertical: 12)` + `Row(children: [Expanded × 4])` 实现 4 等分布局
- [x] 2.5 抽取私有 widget `_InteractionBarButton({required IconData icon, required int count, required Color color, required VoidCallback onTap})` 复用 4 个按钮的渲染

## 3. 4 个按钮的具体行为

- [x] 3.1 点赞按钮：`onTap` 内根据 `_currentPost.isLiked == true` 分支调用 `PostState.unlikePost(postId)` 或 `PostState.likePost(postId)`；图标用 `Iconsax.heart5`（已赞）或 `Iconsax.heart`（未赞）；激活色 `appColors.like`，未激活 `appColors.textPrimary`
- [x] 3.2 转发按钮：`onTap` 内弹 `RepostSheet`（参照 `FeedPost._showRepostSheet` 写法，传 `_currentPost.id`）；图标 `Iconsax.repeat`；激活色 `appColors.repost`（当 `isReposted == true`），未激活 `appColors.textPrimary`
- [x] 3.3 回复按钮：`onTap` 内 `Navigator.pop(context)` 后 `Navigator.push(PostDetailPage(postId: _currentPost.id))`；图标 `Iconsax.message`；颜色 `appColors.textPrimary`
- [x] 3.4 引用按钮：`onTap` 内跳到 `ComposePost` 的引用模式（参照现有引用入口的入参构造，预填当前 PostModel）；图标 `Iconsax.message_text_1` 或 `Iconsax.document_text`（实现时按视觉效果二选一）；颜色 `appColors.textPrimary`
- [x] 3.5 4 个数值兜底：渲染时全部用 `?? 0`，字号 13，颜色 `appColors.textSecondary`，紧跟图标右侧 6px

## 4. 三处调用方改动

- [x] 4.1 `client/lib/widget/feedpost.dart` 的 `_openMediaViewer` 中 `MaterialPageRoute(builder: ...)` 内 `MediaViewerPage(mediaItems: items, initialIndex: safeIndex)` 改为 `MediaViewerPage(mediaItems: items, initialIndex: safeIndex, postModel: widget.postModel)`
- [x] 4.2 `client/lib/pages/post/post_detail_page.dart` 的 `_openMediaViewer` 中传入 `postModel: <当前页面的 PostModel>`
- [x] 4.3 `client/lib/pages/profile/profile.dart` 的对应入口（如有）传入对应的 PostModel

## 5. 功能保护验证（确保不影响现有功能）

> §5.1–5.9 需在真机 / 模拟器上运行 App 才能验证；§5.10 已由 `flutter analyze` 通过（0 errors / 0 新增 warning）。

- [ ] 5.1 顶部浮层（X 按钮 + "n/N" 页码）点击 X 退出全屏、页码随 PageView 切换同步 — 行为不变
- [ ] 5.2 右下角旋转按钮（仅视频横屏）显示/隐藏、点击切换横竖屏 — 行为不变
- [ ] 5.3 PageView 多图滑动、双指缩放 InteractiveViewer、视频自动播放与暂停 — 全部正常
- [ ] 5.4 三个入口（FeedPost / PostDetailPage / Profile）均能进入 MediaViewerPage 且底部横条正确显示 4 个数值
- [ ] 5.5 在横条内点赞 → 数字立即 ±1 且图标激活态切换；跳详情再返回时数字与激活态保持同步
- [ ] 5.6 在横条内转发 → 弹出 RepostSheet → 确认后数字 +1 且颜色切换
- [ ] 5.7 在横条内点回复 → 关闭 MediaViewerPage → 跳转到 PostDetailPage
- [ ] 5.8 在横条内点引用 → 跳转到 ComposePost 引用模式
- [ ] 5.9 横条在 iPhone X 及以上机型底部不与 home indicator 重叠（SafeArea 生效）
- [x] 5.10 `flutter analyze` 无新增 warning；`flutter build ipa --release` 构建通过
