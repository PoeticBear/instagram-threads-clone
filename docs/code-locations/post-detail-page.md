# PostDetailPage（帖子详情页）— 代码定位

> 本文档汇总 iOS 客户端「帖子详情页」`PostDetailPage` 的所有源代码位置，包括页面主体、状态/服务调用、子组件、数据模型、调用点与跳转来源。
> 后续若收到「定位帖子详情 / 评论区 / 删除回复 / 回复输入栏」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 `PostDetailPage` 主体

- **路径**：`client/lib/pages/post/post_detail_page.dart`
- **行数**：1110
- **核心类**：
  - `class PostDetailPage extends StatefulWidget`（`post_detail_page.dart:18`）
  - `class _PostDetailPageState extends State<PostDetailPage>`（`post_detail_page.dart:28`）
- **构造参数**：
  | 字段 | 行号 | 说明 |
  | --- | --- | --- |
  | `required String postId` | `post_detail_page.dart:19` | 帖子 ID（必需） |
  | `PostModel? postModel` | `post_detail_page.dart:20` | 可选预置帖子数据；为 `null` 时进详情页会主动拉详情 |

### 1.2 状态字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `PostService? _postService` | `post_detail_page.dart:29` | 通过 `getIt()` 懒加载 |
| `PostModel? _post` | `post_detail_page.dart:35` | 当前帖子；`initState` 时先用 `widget.postModel`，否则拉接口填 |
| `List<Reply> _replies` | `post_detail_page.dart:36` | 一级回复列表 |
| `bool _isLoading` | `post_detail_page.dart:37` | 首屏 loading |
| `bool _isLoadingMore` | `post_detail_page.dart:38` | 翻页 loading |
| `bool _hasMore` | `post_detail_page.dart:39` | 是否还有更多一级回复 |
| `int _currentPage` | `post_detail_page.dart:40` | 分页游标 |
| `TextEditingController _replyController` | `post_detail_page.dart:42` | 底部回复输入框 controller |
| `FocusNode _replyFocusNode` | `post_detail_page.dart:43` | 输入框焦点 |
| `bool _isPosting` | `post_detail_page.dart:44` | 提交回复中标记 |

### 1.3 生命周期 / 关键方法

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `initState` | `post_detail_page.dart:54` | 预填 `_post = widget.postModel`，调 `_loadData()` |
| `dispose` | `post_detail_page.dart:46` | 释放 `_replyController` / `_replyFocusNode` |
| `_loadData` | `post_detail_page.dart:60` | 拉详情（若 `_post==null`）+ 拉一级回复 |
| `_loadReplies` | `post_detail_page.dart:100` | 拉一页一级回复并替换 `_replies` |
| `_loadMore` | `post_detail_page.dart:116` | 分页追加；`replies.length >= 20` 才继续翻 |

---

## 2. build 主结构（`post_detail_page.dart:135-228`）

页面整体 = `AppBar` + `Column { Expanded(_isLoading ? loading : RefreshIndicator+CustomScrollView), _buildReplyInputBar }`：

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| `AppBar` | `post_detail_page.dart:140-162` | 自定义返回箭头（`CupertinoIcons.back` + 「Back」文本）+ 居中标题 `postDetail` |
| `_isLoading` 圆形 loading | `post_detail_page.dart:166-167` | 首屏骨架 |
| `RefreshIndicator` 下拉刷新 | `post_detail_page.dart:168-175` | 重置分页并 `_loadData()` |
| `CustomScrollView` Sliver 列表 | `post_detail_page.dart:176-220` | 见 §2.1 |
| `_buildReplyInputBar` 底部输入栏 | `post_detail_page.dart:223` / `1004-1071` | 始终常驻（loading 也显示） |

### 2.1 Sliver 列表

| Sliver | 行号 | 内容 |
| --- | --- | --- |
| `SliverToBoxAdapter` 帖子主体 | `post_detail_page.dart:179` | `_buildPostContent` |
| `SliverToBoxAdapter` 分割线 | `post_detail_page.dart:181-183` | `Divider` 0.5px |
| `_replies.isEmpty` → `SliverFillRemaining` | `post_detail_page.dart:185-193` | 显示「noRepliesYet」 |
| `SliverList` 一级回复 | `post_detail_page.dart:194-218` | 子项 `_buildReplyWithChildren`；最后一项 `childCount+1` 作为翻页触发器 |

---

## 3. 子构建器

### 3.1 帖子主体 `_buildPostContent`（`post_detail_page.dart:230-314`）

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| 头像 + 显示名 | `post_detail_page.dart:247-258` | 头像 35px，显示名 `FontWeight.w700` |
| 正文 | `post_detail_page.dart:259-263` | `post.bio ?? ''` 16px |
| 投票 `PollWidget` | `post_detail_page.dart:264-284` | 仅在 `post.pollData != null` 时渲染；通过 `Consumer<PostState>` 优先取最新投票数据 |
| 媒体画廊 | `post_detail_page.dart:285-288` | 仅在 `hasMedia && pollData == null` 时渲染 |
| 定位 | `post_detail_page.dart:289-298` | `post.location` 非空时显示 |
| 点赞/回复/转发 计数 | `post_detail_page.dart:299-310` | 一行小字 |

### 3.2 媒体画廊 `_buildMediaGallery`（`post_detail_page.dart:321-341`）

- **规则**：1 张 → 单图铺满宽；多张 → 3 列 Grid（`childAspectRatio: 1`）
- **子函数**：
  - `_buildSingleMediaItem`（`post_detail_page.dart:343-405`）— 视频叠加 ▶ 角标 + 时长角标；点击 → `MediaViewerPage`
  - `_buildGridMediaItem`（`post_detail_page.dart:407-466`）— 多图网格单格；视频 ▶ 角标缩小到 24px、时长缩小到 9px
  - `_openMediaViewer`（`post_detail_page.dart:468-482`）— `MaterialPageRoute` → `MediaViewerPage`

### 3.3 一级回复项 `_buildReplyItem`（`post_detail_page.dart:484-605`）

- **结构**：头像 32 + 显示名/时间/`isPinned` + 正文 + 点赞心形 + 「查看 N 条回复 / 收起」按钮 + `Divider`
- **交互**：
  - `onTap`（仅一级）：`_openReplySheet` 弹出嵌套回复输入弹层
  - `onLongPress`（仅评论作者本人）：`_showReplyOptions` 弹出底部 Sheet（仅「删除」项）
  - 右上 `PopupMenuButton`（仅作者本人）：单项「删除」
- **删除入口**（与二级共用）：
  - `_showReplyOptions`（`post_detail_page.dart:855-907`）— 长按弹底部 Sheet
  - `_confirmDeleteReply`（`post_detail_page.dart:910-935`）— 二次确认 `AlertDialog`
  - `_deleteReply`（`post_detail_page.dart:939-973`）— 调 `postService.deleteReply` + 清理 `PostState` 缓存 + 成功/失败 SnackBar

### 3.4 二级回复项 `_buildChildReplyItem`（`post_detail_page.dart:770-852`）

- **结构**：左缩进 58 + 头像 26 + 显示名/时间 + 正文 + 点赞 + 右侧「···」（作者可见，点击 → `_confirmDeleteReply`）
- **硬约束**：不绑 `onTap`，不允许再被回复；不支持展开
- **嵌套规则**：左缩进 58 = 父 padding 16 + 父头像 32 + 父 gap 10，与父级 content 起始位置对齐

### 3.5 嵌套回复组装 `_buildReplyWithChildren`（`post_detail_page.dart:699-764`）

- 父项 + `Consumer<PostState>` 订阅「展开态 / 子回复列表 / 加载中 / 是否还有更多」
- 加载态 / 加载更多按钮 (`loadMoreReplies`) 见 `post_detail_page.dart:716-757`

### 3.6 查看/收起按钮 `_buildViewRepliesButton`（`post_detail_page.dart:610-645`）

- 一根 24×1 细线 + 回旋图标 + 文本（`viewReplies(n)` / `hideReplies`）
- 通过 `context.watch<PostState>()` 拿到最新展开态

### 3.7 切换展开 `_toggleChildReplies`（`post_detail_page.dart:648-669`）

- 已展开 → `collapseChildReplies(parent.id)`
- 未展开 → `loadChildReplies` 异步触发；失败 → SnackBar

### 3.8 嵌套回复弹层 `_openReplySheet`（`post_detail_page.dart:673-695`）

- `showModalBottomSheet<bool>` 弹 `ReplyBottomSheet(postId, parentReply)`
- 返回 `true` 表示新建成功，本地 `parent.repliesCount + 1`

### 3.9 删除回复流程（`post_detail_page.dart:854-973`）

| 函数 | 行号 | 说明 |
| --- | --- | --- |
| `_showReplyOptions` | `855-907` | 长按弹底部 Sheet（仅作者本人）；含 Cupertino 红色删除图标 + `deleteReply` 文案 |
| `_confirmDeleteReply` | `910-935` | `AlertDialog` 二次确认（cancel / 删除红色文本按钮） |
| `_deleteReply` | `939-973` | 调 `postService.deleteReply(reply.id)` → 成功 `setState` 移除本地项 → `postState.removeReply(reply.id)` 清理嵌套缓存 → 一级回复时 `postState.decrementReplyCount(widget.postId)` → SnackBar |

### 3.10 工具函数

| 函数 | 行号 | 说明 |
| --- | --- | --- |
| `_buildAvatar` | `post_detail_page.dart:975-992` | 空 URL → `Icons.person` 占位；有 URL → `CachedNetworkImage` 圆角 100 |
| `_formatTime` | `post_detail_page.dart:994-1002` | `<1min → justNow`；`<1h → minutesAgo`；`<24h → hoursAgo`；`<7d → daysAgo`；否则 `M/d` |

---

## 4. 底部回复输入栏 `_buildReplyInputBar`（`post_detail_page.dart:1004-1071`）

| 元素 | 行号 | 说明 |
| --- | --- | --- |
| 外层 Container + 顶部 border | `1006-1015` | 背景色 `background`，border 0.5px `divider` |
| `TextField` | `1020-1038` | `controller: _replyController`；hint = `writeAReply`；`textInputAction: send` → `_postReply` |
| 发送按钮 | `1041-1067` | `Iconsax.send_2`；`_isPosting` 时切换为 18×18 `CircularProgressIndicator` |
| 键盘弹起 padding | `1011` | `MediaQuery.of(context).viewInsets.bottom + 8` |

### 4.1 提交回复 `_postReply`（`post_detail_page.dart:1073-1108`）

1. `content.trim().isEmpty` → 直接返回
2. `setState(_isPosting = true)`
3. 调 `postService.createReply(postId, content)`（不带 `parentId` → 一级回复）
4. 成功后 `postState.incrementReplyCount(postId)` + `_replies.insert(0, newReply)` + 清空 controller + 本地 `_post.repliesCount + 1`
5. 失败 → SnackBar `failedToPostReply`

---

## 5. 页面跳转（调用点 / 谁在用 `PostDetailPage`）

| 来源 | 路径 | 行号 | 说明 |
| --- | --- | --- | --- |
| `FeedPostWidget` 正文 / 引用 | `client/lib/widget/feedpost.dart` | `882, 894` | `CupertinoPageRoute(builder: (_) => PostDetailPage(postId, postModel))` |
| 通知中心 | `client/lib/pages/notification/notification.dart` | `265` | `PostDetailPage(postId: item.postId!)`，无 `postModel` → 内部拉详情 |

---

## 6. 数据层（Service / State / Model）

### 6.1 Service（`client/lib/services/post_service.dart`）

| 方法 | 行号 | 对应 OpenAPI 端点 |
| --- | --- | --- |
| `getPostDetail(String postId)` | `81-87` | `GET /post/detail/{post_id}` |
| `createReply({postId, content, imageUrl?, parentId?})` | `276-305` | `POST /post/reply`（`parentId` 非空即嵌套回复） |
| `getReplies(postId, page, pageSize, parentId?)` | `307-362` | `GET /post/reply/list/{post_id}`（`parentId` 非空即二级回复） |
| `likeReply(replyId)` | `364-371` | `POST /post/reply/like/{reply_id}` |
| `unlikeReply(replyId)` | `372-378` | `DELETE /post/reply/like/{reply_id}` |
| `deleteReply(replyId)` | `431-433` | `DELETE /post/reply/{reply_id}`（当前实现为 `hideReply`，见 `docs/openapi/post.json:393-402`） |

### 6.2 State（`client/lib/state/post.state.dart`）

| 字段 / 方法 | 行号 | 用途 |
| --- | --- | --- |
| `_childRepliesByParent` | `34` | `parentReplyId -> List<Reply>` 缓存 |
| `_childHasMoreByParent` | `40` | `parentReplyId -> bool` |
| `_childLoadingByParent` | `41` | `parentReplyId -> bool` |
| `_expandedParentIds` | `42` | 已展开的父回复 ID 集合（持久化展开态） |
| `childRepliesFor(parentId)` | `55-56` | 取只读子回复列表 |
| `isParentExpanded(parentId)` | `59-60` | 是否已展开 |
| `isChildLoading(parentId)` | `63-64` | 是否正在加载 |
| `childHasMore(parentId)` | `67-68` | 是否还有更多 |
| `incrementReplyCount(postId)` | `723-737` | 同步 `_feedlist` / `_userPosts` 中的 `repliesCount + 1` |
| `decrementReplyCount(postId)` | `739-?` | 同步 `repliesCount - 1` |
| `loadChildReplies({postId, parentReplyId})` | `859-899` | 拉一页子回复并展开 |
| `loadMoreChildReplies({postId, parentReplyId})` | `901-?` | 翻页追加 |
| `collapseChildReplies(parentId)` | `937-?` | 收起（保留缓存，不发请求） |
| `removeReply(replyId)` | `1014-?` | 删除某条回复时清理其所有嵌套缓存 + 展开态 |

### 6.3 Model（`client/lib/model/post.module.dart`）

| 类 | 行号 | 关键字段 |
| --- | --- | --- |
| `MediaItemModel` | `16` | `url` / `thumbUrl` / `width` / `height` / `isVideo` / `durationLabel` |
| `PostModel` | `88` | `id` / `bio` / `createdAt` / `user` / `effectiveMediaItems` / `pollData` / `location` / `likesCount` / `repliesCount` / `repostsCount` / `isLiked` / `isSaved` / `isReposted` / `isPinned` |
| `Reply`（`client/lib/widget/reply_bottom_sheet.dart` / `client/lib/services/post_service.dart` / `client/lib/pages/post/reply_review_page.dart` 共用） | — | `id` / `userId` / `displayName` / `profilePic` / `content` / `createdAt` / `parentId` / `isLiked` / `likesCount` / `repliesCount` / `isPinned` |

> ⚠️ 文件命名带 `.module` 后缀（项目历史命名），不是 `.model`。

---

## 7. 关联子组件 / 弹层

| 名称 | 路径 | 用途 | 在本页引用处 |
| --- | --- | --- | --- |
| `PollWidget` | `client/lib/widget/poll_widget.dart` | 投票卡片 | `post_detail_page.dart:15, 277` |
| `ReplyBottomSheet` | `client/lib/widget/reply_bottom_sheet.dart` | 嵌套回复输入弹层 | `post_detail_page.dart:16, 679` |
| `MediaViewerPage` | `client/lib/pages/media/media_viewer_page.dart` | 媒体大图/视频预览 | `post_detail_page.dart:11, 476` |

---

## 8. 主题 / 颜色 / 国际化

- **颜色**：所有色值通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 取（`post_detail_page.dart:137, 231, 485, ...`）。
- **常用色值**：`textPrimary` / `textSecondary` / `textHint` / `textMuted` / `background` / `surface` / `divider` / `like` / `border`。
- **国际化**：`client/lib/l10n/app_en.arb` + `client/lib/l10n/app_zh.arb`。
  - 文案键：`back` / `postDetail` / `noRepliesYet` / `writeAReply` / `replyCount(n)` / `repostCount(n)` / `justNow` / `minutesAgo(n)` / `hoursAgo(n)` / `daysAgo(n)` / `viewReplies(n)` / `hideReplies` / `loadMoreReplies` / `deleteReply` / `deleteReplyConfirm` / `replyDeleted` / `failedToDeleteReply` / `failedToPostReply` / `cancel`。

---

## 9. 快速检索指引

| 需求 | 检索关键词 | 关键位置 |
| --- | --- | --- |
| 修改页面整体布局 | `build(BuildContext context)` | `post_detail_page.dart:135-228` |
| 修改返回按钮 / 标题 | `AppBar` | `post_detail_page.dart:140-162` |
| 修改帖子主体（头像/正文/投票/媒体/计数） | `_buildPostContent` | `post_detail_page.dart:230-314` |
| 修改媒体画廊 | `_buildMediaGallery` / `_buildSingleMediaItem` / `_buildGridMediaItem` | `post_detail_page.dart:321-466` |
| 修改一级回复项 | `_buildReplyItem` | `post_detail_page.dart:484-605` |
| 修改二级回复项 | `_buildChildReplyItem` | `post_detail_page.dart:770-852` |
| 修改嵌套回复组装 | `_buildReplyWithChildren` | `post_detail_page.dart:699-764` |
| 修改展开/收起按钮 | `_buildViewRepliesButton` / `_toggleChildReplies` | `post_detail_page.dart:610-669` |
| 修改嵌套回复弹层 | `_openReplySheet` | `post_detail_page.dart:673-695` |
| 修改底部输入栏 | `_buildReplyInputBar` | `post_detail_page.dart:1004-1071` |
| 修改提交一级回复 | `_postReply` | `post_detail_page.dart:1073-1108` |
| 修改删除回复（确认/弹层/接口调用） | `_showReplyOptions` / `_confirmDeleteReply` / `_deleteReply` | `post_detail_page.dart:854-973` |
| 修改点赞回复 | `onTap` 在 `_buildReplyItem` / `_buildChildReplyItem` | `post_detail_page.dart:535-545, 811-820` |
| 修改首屏加载 / 刷新 / 翻页 | `_loadData` / `_loadReplies` / `_loadMore` / `RefreshIndicator` | `post_detail_page.dart:60-133, 168-175` |

---

_最后更新：2026-06-16 — 由 Claude 自动化梳理（基于代码静态分析）。_
