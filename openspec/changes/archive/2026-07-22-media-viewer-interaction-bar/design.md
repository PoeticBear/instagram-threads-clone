## Context

`MediaViewerPage`（`client/lib/pages/media/media_viewer_page.dart`）目前是首页信息流、帖子详情页、个人主页三处图片点击入口共用的全屏查看组件。当前实现仅在 `Stack` 中渲染主内容（`PageView` + `InteractiveViewer`）、顶部浮层（X 按钮 + 页码）和右下角旋转按钮（仅视频），**底部完全是空的**，沉浸式浏览期间无法完成任何互动操作。

`PostModel`（`client/lib/model/post.module.dart`）已包含 `likesCount / repliesCount / quotesCount / repostsCount / sharesCount / isLiked / isReposted` 等互动字段（全部 `int?` / `bool?`）。`PostState` 已暴露 `likePost / unlikePost / repost / unrepost` 等 action。

`FeedPost`（`client/lib/widget/feedpost.dart` L285-360）已在卡片上实现了 4 个互动按钮（点赞 / 回复 / 转发 / 分享），但全屏查看器没复用这套 UI。

## Goals / Non-Goals

**Goals**
- 在 `MediaViewerPage` 底部新增一条互动统计横条，展示当前帖子的点赞 / 回复 / 引用 / 转发 4 个计数（图标 + 数值）
- 点赞 / 转发可在横条内直接交互，数字与激活态实时刷新
- 回复 / 引用点击后跳转对应页面（`PostDetailPage` / `ComposePost` 引用模式）
- `MediaViewerPage` 订阅 `PostState` 变更，本地快照实时同步
- 现有顶部浮层、旋转按钮、PageView 滑动、双指缩放、视频播放 全部保持原样

**Non-Goals**
- 不改动 `PostModel` 字段定义
- 不新增 `PostState` action（复用现有 `likePost/unlikePost/repost/unrepost`）
- 不改动 FeedPost 卡片已有的 4 个互动按钮
- 不修改 FeedPost / PostDetailPage / Profile 之外的任何调用方
- 不引入新的第三方依赖
- 不写 Android 适配（本项目仅维护 iOS）
- 不做"分享"按钮（用户明确指定"引用"替换"分享"）

## Decisions

### 决策 1：MediaViewerPage 接收整个 PostModel 而非 4 个独立字段

**选择**：`MediaViewerPage` 新增必填 prop `PostModel postModel`。

**理由**：
- 数字 + 激活态共 6 个字段（4 个 int + 2 个 bool），独立传参签名臃肿且不易扩展
- 整个 PostModel 已经在调用方存在，零额外查询成本
- 内部需要订阅 `PostState` 同步，拿到 PostModel 后可以基于 `id` 在 PostState 中查找最新值，比传 `postId` 字符串再二次查询更直接

**替代方案考虑**：
- 传 `postId` 字符串 → 调用方要二次从 PostState 查询当前 PostModel，多此一举
- 传 `Map<String, dynamic>` 快照 → 类型不安全，且与 PostModel 解耦后激活态判断变麻烦

### 决策 2：状态同步用 addListener 而非 Consumer / Selector

**选择**：在 `MediaViewerPage.initState` 中手动 `postState.addListener(_onPostStateChanged)`，在 `dispose` 中移除。

**理由**：
- `MediaViewerPage` 已经是 `StatefulWidget`，加 listener 是最小改动
- 我们只需要在 PostState 通知时同步内部快照，不需要整棵 widget tree 重建（Consumer 会导致子树重建）
- `dispose` 中移除 listener 可以避免内存泄漏

**替代方案考虑**：
- 用 `Consumer<PostState>` 包整个横条 → 横条子树会随 PostState 任何变更重建（不只是当前帖子），影响性能
- 用 `Selector<PostState, PostModel>` → 需要 selector 函数和 Provider.of 链路，对 MediaViewerPage 这种"接 props 进来"的组件不够自然

### 决策 3：横条视觉用 BackdropFilter 模糊 + 黑色半透

**选择**：横条背景用 `Colors.black.withOpacity(0.4)` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))`。

**理由**：
- 与顶部浮层的黑色渐变形成视觉呼应（顶部是渐变到底透明，底部是半透 + 模糊）
- 模糊效果在彩色图片背景上仍能保证图标与数字可读性
- 比纯黑实色更轻量、不抢视觉重心

**替代方案考虑**：
- 纯黑实色 → 太重，与全屏沉浸风格冲突
- 完全透明（只显示图标 + 数字） → 在浅色图片背景上数字可读性差

### 决策 4：4 个按钮的交互边界

**选择**：
- **点赞** — 直接 `PostState.likePost/unlikePost` toggle，数字实时变
- **转发** — 弹 `RepostSheet`（复用 FeedPost 已有的 `_showRepostSheet` 模式）
- **回复** — `Navigator.push(PostDetailPage)`，因为全屏模式无回复输入框
- **引用** — `Navigator.push(ComposePost, 引用模式)`，复用现有引用入口

**理由**：
- 点赞不需要任何中间确认（行业惯例：直接 toggle）
- 转发可能带评论内容，必须有确认/编辑步骤
- 回复和引用都需要复杂输入界面，不适合在全屏图片上方弹层

**替代方案考虑**：
- 4 个全部跳详情页 → 失去"沉浸式快速互动"的核心价值
- 4 个全部在横条内交互 → 回复输入框无处安放；引用会创建新帖，需要更完整的编辑器

### 决策 5：数据字段选「引用」而非「分享」

**选择**：横条第 4 个图标数据用 `quotesCount`（引用数）。

**理由**：
- 用户明确指定「点赞、回复、引用、转发」
- `PostModel.quotesCount` 字段一直存在只是未在 UI 暴露，本次顺势暴露
- `sharesCount` 是"分享数"（复制链接 / 系统分享），与"引用"语义不同

### 决策 6：图标选择 — 引用按钮用什么 iconsax 图标？

**选择**：`Iconsax.message_text_1` 或 `Iconsax.document_text`（实现时根据视觉效果二选一）。

**理由**：
- "引用"在 Threads 上是"带评论转发"，视觉上需要一个能表示"文档 / 引用块"的图标
- FeedPost 已有 `Iconsax.message` 用于回复，避免两个相同图标相邻
- `document_text`（文档）和 `message_text_1`（消息带文本）都能表达"引用"语义

**替代方案考虑**：
- 复用 `Iconsax.message` → 与"回复"图标相同，视觉混淆
- `Iconsax.quote_left` / `Iconsax.quote_right` → iconsax 库未必提供
- 自定义图标 → 不必要，保持与 FeedPost 一致的图标体系

### 决策 7：横条布局 — Row + Expanded × 4 等宽

**选择**：横条用 `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [...])` 或 `Row(children: [Expanded(child: btn), Expanded(child: btn), ...])`。

**理由**：
- 4 个按钮等宽分布是最稳定的横条布局，不依赖具体数字宽度
- 不同数字位数（0 / 123 / 12.3k）不会让按钮位置跳动

**替代方案考虑**：
- 居左对齐（与 FeedPost 一致） → 数字长度变化时按钮位置漂移
- spaceBetween → 视觉重心不稳

### 决策 8：横条使用 SafeArea(top: false) 处理底部刘海

**选择**：横条外包 `SafeArea(top: false, child: ...)`。

**理由**：
- 顶部 SafeArea 已经被现有顶部浮层处理，底部横条只关心 bottom inset
- 自动避让 iPhone X 及以上机型的 home indicator
- 与现有右上角旋转按钮的 `SafeArea(top: false)` 写法一致

## Risks / Trade-offs

- **[Risk] BackdropFilter 在低端设备性能开销** → 横条只在 MediaViewerPage 存在，作用域小；如确有问题可降级为纯黑半透（去掉 BackdropFilter）
- **[Risk] PostState 中找不到对应 postId 的 PostModel** → 兜底：保留传入的初始 postModel 快照，不显示异常；这种情况通常发生在横条订阅期间 PostState 被整体重置（如切换账号），属于边缘场景
- **[Risk] 三处调用方遗漏传 postModel** → 编译期即可发现（必填 prop）；spec 已约束
- **[Trade-off] 横条增加页面层级** → 只增加一个 Positioned 子节点 + 内部 widget，对 PageView / InteractiveViewer 的渲染无影响
- **[Trade-off] 点赞和转发的实时反馈依赖 PostState.notifyListeners** → 现有 `likePost/unlikePost` 已经在 try/catch 内同步调用 `_updatePostLikeStatus` + `notifyListeners`，失败时回滚，行为正确
- **[Risk] 引用跳转 ComposePost 时如何回填 PostModel** → 复用 FeedPost 已有的引用模式入口（FeedPost 卡片上的引用按钮目前不存在，但 PostDetailPage 上有引用入口），实现时参照现有入口的入参构造
