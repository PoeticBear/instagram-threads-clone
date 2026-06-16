# Threads Tab（个人中心 → Threads Tab）— 代码定位

> 本文档汇总 iOS 客户端「个人中心 → Threads Tab」涉及的所有源代码位置。
> 「Threads Tab」是 Profile 页面的子 Tab（与 Media Tab 并列，由 `TabController(length: 2)` 切换），用于展示该用户发布过的全部帖子（与 Feed 流共用 `FeedPostWidget` 渲染器）。
> 后续若收到「定位 Threads Tab / 个人中心帖子列表」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 父页面 `ProfilePage`

- **路径**：`client/lib/pages/profile/profile.dart`
- **行数**：912
- **核心组件**：`class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin`（`profile.dart:69-70`）
- **关键字段**（与 Threads Tab 相关）：
  | 字段 | 说明 | 行号 |
  | --- | --- | --- |
  | `_tabController` | `TabController(length: 2, vsync: this)` — 控制 Threads / Media 切换 | `profile.dart:71, 78` |
  | `_userPosts` | `List<PostModel>` — 该用户帖子本地缓存 | `profile.dart:72` |
  | `_isLoadingPosts` | 首次加载状态 | `profile.dart:73` |
- **TabBar / TabBarView 集成**（`profile.dart:404-453`）：
  - `TabBar`（`profile.dart:404-433`）— 两个 tab，标签从 `AppLocalizations` 取 `tabThreads` / `tabMedia`。
  - `TabBarView`（`profile.dart:447-453`）作为 `NestedScrollView.body`，`children[0] = _buildThreadsTab()`、`children[1] = _buildMediaTab()`。
  - 旧版本将 `TabBarView` 塞在头部 `Column` 里，会因无界垂直空间导致 `parentDataDirty` 渲染断言、个人中心整页空白；新版本用 `NestedScrollView` 提供有界高度才正常工作（见 `profile.dart:434-440` 注释）。

> Profile 页面整体定位见 [`docs/code-locations/profile-page.md`](profile-page.md)。

### 1.2 Threads Tab 渲染器 `_buildThreadsTab`

- **路径**：`client/lib/pages/profile/profile.dart`
- **行号**：459-484
- **签名**：`Widget _buildThreadsTab()`
- **职责**：
  1. 加载中 → 居中 `CircularProgressIndicator`（`profile.dart:461-465`）。
  2. 帖子列表为空 → 居中显示 `AppLocalizations.noThreadsYetOthers`（`profile.dart:466-473`）。
  3. 正常态 → `ListView.builder` + `AlwaysScrollableScrollPhysics`（`profile.dart:477-483`），每项用 `FeedPostWidget(postModel: _userPosts[index])`。
- **关键设计**：
  - 必须用普通 `ListView` + `AlwaysScrollableScrollPhysics`，**不能**加 `shrinkWrap: true`，否则 overscroll 不会传给 `NestedScrollView`，无法触发个人中心下拉刷新（`profile.dart:474-476` 注释）。
  - 数据全部来自 `_userPosts`（本地 `setState` 缓存），不直接订阅 `PostState.feedlist`，避免 Feed 流变更引起误刷新。

### 1.3 帖子卡片组件 `FeedPostWidget`

- **路径**：`client/lib/widget/feedpost.dart`
- **行数**：1532
- **核心组件**：`class FeedPostWidget extends StatefulWidget`（`feedpost.dart:29-35`）+ `_FeedPostWidgetState`（`feedpost.dart:37`）
- **职责**：复用 Feed 流卡片，渲染单条帖子（用户信息 / 正文 / 引用卡 / 投票 / 媒体 / 互动栏 / 折叠展开 / 菜单）。
- **关键字段**：
  | 字段 | 说明 | 行号 |
  | --- | --- | --- |
  | `postModel` | 必填 `PostModel` | `feedpost.dart:30-31` |
  | `_fetchedQuotePost` | 引用帖兜底（`quotePost` 为空时按 `quoteRepostId` 拉取） | `feedpost.dart:38` |
  | `_isFetchingQuote` | 引用帖加载中态 | `feedpost.dart:39` |
  | `_isTextExpanded` | 长文展开 / 收起（每条独立） | `feedpost.dart:43` |
  | `_kCollapsedMaxLines` | 收起最大行数 = 5 | `feedpost.dart:46` |
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 生命周期 / 引用帖兜底拉取 | `initState` → `_maybeFetchQuotePost` / `dispose` | `feedpost.dart:52-95` |
  | 视频池变更订阅 | `_onPoolChanged`（`VideoPlayerPool.version` 监听） | `feedpost.dart:57-68` |
  | 渲染：头像 / 标题 / 时间 / 更多 | `build` | `feedpost.dart:97-354` |
  | 文本折叠 / 展开按钮 | `_buildPostContent` | `feedpost.dart:367-426` |
  | 媒体多图网格（1/2-4/5-9/>9 宫格） | `_buildMediaGallery` / `_buildSingleMedia` / `_buildGridMedia` | `feedpost.dart:436-596` |
  | 单图块（缩略图 + 视频控制器 + 音频开关） | `_buildMediaImage` | `feedpost.dart:605-723` |
  | 引用帖卡片（有数据 / 加载中 / 失败三态） | `_buildQuoteCard` | `feedpost.dart:727-867` |
  | 跳他人 Profile | `_navigateToProfile` | `feedpost.dart:871-879` |
  | 跳帖子详情 | `_navigateToPostDetail` | `feedpost.dart:881-891` |
  | 跳引用帖 / 引用者 Profile | `_navigateToQuotedPostDetail` / `_navigateToQuotedUserProfile` | `feedpost.dart:893-914` |
  | 打开媒体查看器 | `_openMediaViewer` | `feedpost.dart:917-930` |
  | Sheet 通用行 / 分割线 | `_buildSheetOption` / `_buildSheetDivider` | `feedpost.dart:934-960` |
  | 转发 / 引用转发 sheet | `_showRepostSheet` / `_showQuoteSheet` | `feedpost.dart:964-1141` |
  | 分享 sheet（复制链接 / 分享计数） | `_showShareSheet` | `feedpost.dart:1145-1190` |
  | 更多菜单（编辑 / 删除 / 置顶 / 收藏 / 静音 / 限制 / 拉黑 / 举报 / 编辑历史 / 不感兴趣） | `_showMoreMenu` | `feedpost.dart:1194-1412` |
  | 关系控制（1=静音, 2=限制, 3=拉黑） | `_handleRelationControl`（`UserService.addRelationControl`） | `feedpost.dart:1414-1443` |
  | 举报菜单（9 种类型） | `_showReportMenu` | `feedpost.dart:1445-1531` |

### 1.4 帖子详情页 `PostDetailPage`（点击帖子后跳转）

- **路径**：`client/lib/pages/post/post_detail_page.dart`
- **关键能力**：单帖详情 + 一级回复列表 + 嵌套回复 + 发布回复。
- **触发位置**：`FeedPostWidget._navigateToPostDetail`（`feedpost.dart:881-891`）+ `_navigateToQuotedPostDetail`（`feedpost.dart:893-903`）。

### 1.5 相关 Widget

| Widget | 路径 | 用途 |
| --- | --- | --- |
| `ReplyBottomSheet` | `client/lib/widget/reply_bottom_sheet.dart` | 评论图标点击后弹出的回复编辑 sheet（`feedpost.dart:302-309`） |
| `EditHistorySheet` | `client/lib/widget/edit_history_sheet.dart` | 「编辑历史」菜单项（`feedpost.dart:1389-1400`） |
| `PollWidget` | `client/lib/widget/poll_widget.dart` | 投票帖子（`feedpost.dart:220-225`） |
| `VideoPlayerPool` | `client/lib/widget/video_player_pool.dart` | 视频自动播放池（`feedpost.dart:57, 484-505, 567-580, 620-702`） |
| `MediaViewerPage` | `client/lib/pages/media/media_viewer_page.dart` | 大图 / 视频预览（`feedpost.dart:917-930`） |

---

## 2. 入口集成点

### 2.1 Profile → Threads Tab 切换

- **位置**：`profile.dart:404-453`（`TabBar` + `TabBarView`）
- **l10n key**：`tabThreads`（`profile.dart:417`） / `tabMedia`（`profile.dart:425`）
- **样式**：`labelColor: appColors.textPrimary` / `unselectedLabelColor: appColors.textSecondary` / `indicatorColor: appColors.textPrimary` / `indicatorWeight: 1` / `fontSize: 15` / `FontWeight.w600`（`profile.dart:410-420`）

### 2.2 加载流程

- **首次加载**：`initState` → `_loadUserPosts`（`profile.dart:76-80`）
- **下拉刷新**：`_refreshAll`（`profile.dart:96-109`）— `ProfileState.refresh()` 并行 + `_loadUserPosts()` + 自己是 Tab 时再 `AuthState.getProfileUser()`。

### 2.3 卡片内点击跳转

| 触发 | 跳转目标 | 代码位置 |
| --- | --- | --- |
| 点击头像 / 昵称 | `ProfilePage.getRoute(profileId, username)` | `feedpost.dart:151-169, 871-879` |
| 点击正文 / 引用卡 / 投票以外区域 | `PostDetailPage(postId, postModel)` | `feedpost.dart:197-204, 218-225, 881-891` |
| 点击引用帖卡片 | `PostDetailPage(quotePost.id, quotePost)` | `feedpost.dart:747-748, 893-903` |
| 点击引用帖作者头像 / 昵称 | `ProfilePage.getRoute(quotePost.user)` | `feedpost.dart:763-783, 905-914` |
| 点击媒体（图片 / 视频） | `MediaViewerPage(items, tappedIndex)` | `feedpost.dart:478-491, 583-592, 917-930` |
| 点击评论图标 | `showModalBottomSheet(... ReplyBottomSheet(postId))` | `feedpost.dart:302-309` |
| 点击转发图标 | `_showRepostSheet`（转发 / 引用 / 撤回） | `feedpost.dart:321-330, 964-1014` |
| 点击分享图标 | `_showShareSheet`（复制链接 / 分享） | `feedpost.dart:335-344, 1145-1190` |
| 点击 `Icons.more_horiz` | `_showMoreMenu` | `feedpost.dart:191-194, 1194-1412` |

---

## 3. 状态层（Provider）

### 3.1 `PostState`（全局单例）

- **路径**：`client/lib/state/post.state.dart`
- **行数**：1005
- **Threads Tab 相关**：
  | 字段 / 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `_userPosts` | 当前用户帖子列表 | `post.state.dart:21` |
  | `_isLoadingUserPosts` | 加载中态 | `post.state.dart:26, 46` |
  | `userPosts` (getter) | 只读快照 | `post.state.dart:48` |
  | `getUserPosts(int userId)` | 拉取并转换（`Post` → `PostModel`） | `post.state.dart:420-427` |
  | `loadUserPosts(int userId)` | 写入 `_userPosts` 缓存，触发 `notifyListeners` | `post.state.dart:430-444` |
  | `_apiPostToModel(Post)` | API DTO → UI `PostModel` 转换器（处理 quote / repost / thread / edit / sensitive 全字段） | `post.state.dart:92-140` |
  | `fetchQuotePostDetail(int)` | 引用帖兜底拉取 | `post.state.dart:481-489` |

> 注意：Profile → Threads Tab **没有**直接使用 `PostState.userPosts` 缓存（而是 `_loadUserPosts` 一次性拉到 `_userPosts` 本地状态）。这避免了 Feed 流刷新时 Threads Tab 出现「跳到顶部 / 内容错乱」的问题。`PostState.userPosts` 仍可作为其它场景的全局缓存使用。

### 3.2 `ProfileState`（本地创建）

- **路径**：`client/lib/state/profile.state.dart`
- **作用**：Threads Tab 不直接使用 `ProfileState`，但下拉刷新 `_refreshAll` 会调用 `ProfileState.refresh()`（`profile.dart:99`），从而同步头部的用户资料 / 关注统计。
- **完整定位**：见 [`docs/code-locations/profile-page.md`](profile-page.md) 第 3.1 节。

### 3.3 `AuthState`（全局单例）

- **路径**：`client/lib/state/auth.state.dart`
- **关键调用**：
  - `_showMoreMenu` 中通过 `authState.userId` 判定「是否自己的帖子」（`feedpost.dart:1202-1205`）。
  - `_showQuoteSheet` 中通过 `authState.userModel` 拿到当前用户信息（`feedpost.dart:1115-1127`）。
  - `_refreshAll` 在自己的 Tab 时调用 `getProfileUser()` 同步头部（`profile.dart:103-107`）。

---

## 4. 服务层（API）

### 4.1 `PostService`

- **路径**：`client/lib/services/post_service.dart`
- **行数**：704（服务） + 数据模型在文件内
- **Threads Tab 相关方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `getUserPosts(int userId, {page, size})` | 拉取指定用户帖子 → `GET post/user/{userId}/posts` | `post_service.dart:158-185` |
  | `getPostDetail(String postId)` | 单帖详情 → `GET post/detail/{postId}` | `post_service.dart:81-88` |
  | `getReplies(postId, {page, size, parentId})` | 回复分页 → `GET post/reply/list/{postId}` | `post_service.dart:307-362` |
  | `createReply({postId, content, imageUrl, parentId})` | 创建回复 → `POST post/reply` | `post_service.dart:276-305` |
  | `likePost` / `unlikePost` | 点赞 / 取消 → `POST/DELETE post/like/{id}` | `post_service.dart:187-201` |
  | `likeReply` / `unlikeReply` | 回复点赞 → `POST/DELETE post/reply/like/{id}` | `post_service.dart:364-378` |
  | `repost(postId, {content})` | 转发 → `POST post/repost/{postId}`（带 `repost_type: 1`） | `post_service.dart:203-213` |
  | `sharePost(postId)` | 分享计数 → `POST post/share/{postId}` | `post_service.dart:252-258` |
  | `savePost` / `unsavePost` | 收藏 → `POST/DELETE post/save/{postId}` | `post_service.dart:236-250` |
  | `pinPost` / `unpinPost` | 置顶 → `POST/DELETE post/pin/{postId}` | `post_service.dart:260-274` |
  | `pinReply` / `unpinReply` | 回复置顶 → `POST/DELETE post/reply/pin/{id}` | `post_service.dart:627-641` |
  | `reportContent({targetType, targetId, reportType, description})` | 举报 → `POST post/report` | `post_service.dart:215-234` |
  | `deletePost(postId)` | 删除 → `DELETE post/{postId}` | `post_service.dart:90-96` |
  | `updatePost({postId, content, isSensitive, contentWarning})` | 编辑 → `PUT post/{postId}`（15 分钟内 / 最多 5 次） | `post_service.dart:103-124` |
  | `votePoll(postId, optionId)` | 投票 → `POST post/poll/{postId}/vote` | `post_service.dart:405-407` |
  | `getEditHistory(postId)` | 编辑历史 → `GET post/{postId}/edit-history` | `post_service.dart:467-475` |
- **数据模型**（同文件内）：
  | 模型 | 关键字段 |
  | --- | --- |
  | `Post` | `id` / `userId` / `username` / `displayName` / `profilePic` / `content` / `mediaList` / `pollData` / `createdAt` / `likesCount` / `repliesCount` / `repostsCount` / `sharesCount` / `isLiked` / `isSaved` / `isReposted` / `quotePost` / `quoteContent` / `threadPosts` / `isPinned` / `isEdited` / `editCount` / `isSensitive` / `contentWarning` …（`post_service.dart:706-942`） |
  | `MediaItem` | `id` / `mediaType` (1=image, 2=video, 3=gif, 4=voice, 5=text) / `url` / `thumbUrl` / `width` / `height` / `duration`（`post_service.dart:999-1051`） |
  | `Reply` | `id` / `postId` / `userId` / `username` / `displayName` / `content` / `imageUrl` / `createdAt` / `likesCount` / `isLiked` / `isPinned` / `isHidden` / `parentId` / `repliesCount`（`post_service.dart:1067-1200`） |
  | `PollData` / `PollOption` | 投票数据 |
  | `EditHistory` | 编辑历史 |
  | `GuestReplyRequest` | 幽灵帖审核请求 |

### 4.2 `UserService`（间接调用）

- **路径**：`client/lib/services/user_service.dart`
- **Threads Tab 间接使用**：
  - `addRelationControl`（`feedpost.dart:1422-1426`）— 静音 / 限制 / 拉黑。
  - `getUserProfile` — `ProfileState._getProfileUser` 间接用，但 Threads Tab 自身不直接调用。

---

## 5. 数据模型

| 模型 | 路径 | 关键字段（与 Threads Tab 相关） |
| --- | --- | --- |
| `PostModel` | `client/lib/model/post.module.dart` | `key` / `postId` / `bio` / `createdAt` / `user` / `imagePath` / `mediaList` / `pollData` / `likesCount` / `repliesCount` / `repostsCount` / `sharesCount` / `isLiked` / `isSaved` / `isReposted` / `quotePost` / `quoteRepostId` / `isRepost` / `repostParentId` / `threadPosts` / `isPinned` / `isEdited` / `editCount` / `lastEditTime` / `isSensitive` / `contentWarning` |
| `MediaItemModel` | `client/lib/model/post.module.dart` | `id` / `mediaType` / `url` / `thumbUrl` / `width` / `height` / `duration`（含 `isVideo` / `isGif` / `isImage` / `isPlayable` / `durationLabel` 派生 getter） |
| `UserModel` | `client/lib/model/user.module.dart` | `userId` / `userName` / `displayName` / `profilePic` / `bio` / `isVerified` / `isPrivate` |
| `Post` / `Reply` / `MediaItem` / `PollData` | `client/lib/services/post_service.dart` | API DTO（见 §4.1） |

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arab`、`client/lib/l10n/app_zh.arab`
- **Threads Tab / FeedPostWidget 常用 key**（部分）：

  | key | 用途 | 位置 |
  | --- | --- | --- |
  | `tabThreads` | Tab 标签 | `profile.dart:417` |
  | `noThreadsYetOthers` | 空态文案 | `profile.dart:469` |
  | `editedBadge` | 已编辑徽章 | `feedpost.dart:181` |
  | `showMore` / `showLess` | 长文展开 / 收起 | `feedpost.dart:412-413` |
  | `repost` / `undoRepost` / `quote` / `quoteRepost` / `quotePlaceholder` / `post` | 转发 / 引用 sheet | `feedpost.dart:984, 1002, 993, 1044, 1086, 1133` |
  | `copyLink` / `share` / `linkCopiedToClipboard` | 分享 sheet | `feedpost.dart:1163, 1180, 1171` |
  | `editPost` / `deletePost` / `deletePostConfirm` / `pinPost` / `unpinPost` | 更多菜单（自己） | `feedpost.dart:1234, 1256, 1265, 1294` |
  | `save` / `unsave` | 更多菜单（保存） | `feedpost.dart:1307` |
  | `muteUsername(u)` / `restrictUsername(u)` / `blockUsername(u)` / `blockConfirmTitle` / `blockConfirmDesc` / `block` | 更多菜单（关系控制） | `feedpost.dart:1320, 1333, 1346, 1354-1355, 1363` |
  | `report` / `reportPost` / `reportSpam` … `reportOther` / `reportSuccess` / `reportFailed` | 举报菜单 | `feedpost.dart:1380, 1453-1463, 1491, 1514, 1520` |
  | `editHistory` | 编辑历史入口 | `feedpost.dart:1390` |
  | `notInterested` | 不感兴趣 | `feedpost.dart:1403` |
  | `operationFailed` | 通用操作失败 | `feedpost.dart:1436` |
  | `postDeleted` | 删除成功 | `feedpost.dart:1283` |

---

## 7. 主题 / 颜色

- 颜色统一通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取，入口 `client/lib/theme/app_colors.dart`。
- **Threads Tab 常用色**：
  - Tab 标签：`appColors.textPrimary`（激活） / `appColors.textSecondary`（未激活） / 指示器 `appColors.textPrimary`（`profile.dart:410-412`）
  - 卡片背景：`appColors.background`（`feedpost.dart:136`）
  - 分割线：`appColors.divider` 0.2px（`feedpost.dart:144`）
  - 头像 / 引用卡底色：`appColors.surface`
  - 点赞红心：`appColors.like`（`feedpost.dart:294`）
  - 转发色：`appColors.repost`（`feedpost.dart:327`）
  - 引用卡边框：`appColors.border` 0.5px（`feedpost.dart:754`）
  - 销毁性操作：`appColors.destructive`（`feedpost.dart:1003, 1257, 1347, 1381, 1503`）

---

## 8. 关键依赖

- `cached_network_image` — 图片 / 缩略图（`feedpost.dart:1, 128, 706`）
- `provider` — `Provider.of<PostState>(context, listen: false)`（`feedpost.dart:280, 303, 322, 336, 1151`）
- `iconsax` — `heart` / `heart5` / `message` / `repeat` / `send_2`（`feedpost.dart:5, 290-291, 312, 324, 338`）
- `video_player` + `VideoPlayerPool`（`client/lib/widget/video_player_pool.dart`）— 视频自动播放 + 池管理
- `visibility_detector` — 视频可见性检测（`feedpost.dart:22, 492, 569`）
- `flutter/services.dart` — `Clipboard.setData`（`feedpost.dart:4, 1166`）

---

## 9. 设计要点

### 9.1 NestedScrollView 集成

- Threads Tab 是 `NestedScrollView.body` 中的 `TabBarView` 子项（`profile.dart:447-453`）。
- 自身使用普通 `ListView.builder` + `AlwaysScrollableScrollPhysics`（**不能** `shrinkWrap: true`），让 overscroll 传给 `NestedScrollView` 触发下拉刷新（`profile.dart:474-476, 512-513` 注释）。
- 旧版本「头部 `Column` 末尾嵌 `TabBarView`」会出现 `parentDataDirty` 断言 + 整页空白（`profile.dart:434-440` 注释）。

### 9.2 数据缓存策略

- Profile → Threads Tab **独立缓存** `_userPosts`（`profile.dart:72`），不直接订阅 `PostState.userPosts`。
- 原因：避免 Feed 流刷新（`PostState.loadUserPosts` / `getDataFromDatabase`）影响 Threads Tab 的滚动位置 / 内容。
- 代价：下拉刷新时需手动重跑 `_loadUserPosts()`（已由 `_refreshAll` 处理，`profile.dart:96-109`）。

### 9.3 引用帖兜底拉取

- 列表 API 在某些情况下只返回 `quoteRepostId` 而不带完整 `quotePost`。
- `_maybeFetchQuotePost`（`feedpost.dart:71-95`）在 `quotePost == null && quoteRepostId != null` 时调用 `PostState.fetchQuotePostDetail` 拉取并 setState。
- 卡片渲染时 `_effectiveQuotePost = postModel.quotePost ?? _fetchedQuotePost`（`feedpost.dart:49-50`）。

### 9.4 文本折叠（每条独立状态）

- 用 `TextPainter.didExceedMaxLines` 检测实际是否溢出，**仅溢出时才显示「展开全文」按钮**，避免短文也带按钮的尴尬（`feedpost.dart:381-386, 398-399`）。
- 折叠 / 展开 5 行 → 全展开（`feedpost.dart:391-396`）。
- 按钮 `behavior: HitTestBehavior.opaque` 消费 tap 事件，不冒泡触发跳转详情（`feedpost.dart:407`）。

### 9.5 视频自动播放

- 多图网格里同一帖子可能有多段视频，必须用 `mediaKey = 'feed_video_${postId}_$index'` 唯一定位（`feedpost.dart:466, 539, 619-621`）。
- `VisibilityDetector` 监听 `visibleFraction > 0.5` 时通过 `VideoPlayerPool.acquire + playVisible` 接管；离开时 `pauseVisible`（`feedpost.dart:494-501, 570-578`）。
- 进入 `MediaViewerPage` 之前先 `VideoPlayerPool.pauseAll()`（`feedpost.dart:489, 587`）。

### 9.6 乐观更新

- 点赞 / 收藏 / 转发 / 分享 全部走「先改本地状态 → 再调 API → 失败回滚」模式：
  - 点赞：`PostState.likePost` / `unlikePost`（`post.state.dart:446-476`）
  - 收藏：`PostState.savePost` / `unsavePost`（`post.state.dart:530-563`）
  - 转发：`PostState.repost` / `unrepost`（`post.state.dart:493-526`）— 失败不回滚（幂等）
  - 分享：`PostState.sharePost`（`post.state.dart:565-590`）
- 注意：当前 `_updatePostLikeStatus` 等方法**只改 `_feedlist`，不直接改 `_userPosts`**（`post.state.dart:464-476, 514-526, 554-563, 579-590`）。即：Feed 流中点赞 → Threads Tab 卡片需要重新加载（`_refreshAll` 触发）才能同步。若需要立即同步，可加一段 `_userPosts` 的同步逻辑。

### 9.7 编辑限制前端预判

- 服务端约束：帖子发布后 15 分钟内 + 最多 5 次编辑。
- 前端在 `_showMoreMenu` 入口处预判（`feedpost.dart:1208-1216`），**不满足时不渲染「编辑」按钮**，减少用户误操作。
- 实际请求服务端仍可能拒绝（编辑越界 / 计数不一致），由 `PostState.updatePost` 捕获并返回 `null`，UI 层可进一步提示（`post_service.dart:103-124, post.state.dart:640-660`）。

### 9.8 举报

- `targetType: 1 = Post`、`reportType: 1-9`（9 种类型，`feedpost.dart:1450-1463`）。
- 提交 `PostState.reportContent`（`post.state.dart:599-617`），UI 层 try / catch 弹 SnackBar。

### 9.9 关系控制

- `controlType: 1=静音, 2=限制, 3=拉黑`（`feedpost.dart:1326, 1338, 1371`）。
- 调 `UserService.addRelationControl`（`user_service.dart:102`）。
- 拉黑前有 `AlertDialog` 二次确认（`feedpost.dart:1350-1367`）。

---

## 10. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改 Threads Tab 整体布局 | `_buildThreadsTab` / `TabBarView` | `client/lib/pages/profile/profile.dart:447-484` |
| 修改帖子卡片渲染 | `FeedPostWidget` / `_FeedPostWidgetState` / `build` | `client/lib/widget/feedpost.dart` |
| 修改空态文案 | `noThreadsYetOthers` | `profile.dart:469` + `client/lib/l10n/app_zh.arab` + `app_en.arab` |
| 修改下拉刷新逻辑 | `_refreshAll` / `_loadUserPosts` | `client/lib/pages/profile/profile.dart:82-109` |
| 修改长文折叠 / 展开 | `_buildPostContent` / `_kCollapsedMaxLines` | `client/lib/widget/feedpost.dart:367-426` |
| 修改多图网格 | `_buildMediaGallery` / `_buildGridMedia` | `client/lib/widget/feedpost.dart:436-596` |
| 修改引用帖卡片 | `_buildQuoteCard` / `_maybeFetchQuotePost` | `client/lib/widget/feedpost.dart:71-95, 727-867` |
| 修改点赞 / 收藏 / 转发 / 分享 | `_updatePostLikeStatus` 等 + `FeedPostWidget` onTap | `client/lib/state/post.state.dart:446-590` + `client/lib/widget/feedpost.dart:278-344` |
| 修改更多菜单（编辑 / 删除 / 置顶 / 举报 / 关系控制） | `_showMoreMenu` / `_handleRelationControl` / `_showReportMenu` | `client/lib/widget/feedpost.dart:1194-1531` |
| 修改转发 / 引用转发 sheet | `_showRepostSheet` / `_showQuoteSheet` | `client/lib/widget/feedpost.dart:964-1141` |
| 修改引用帖兜底拉取 | `fetchQuotePostDetail` / `_maybeFetchQuotePost` | `client/lib/state/post.state.dart:481-489` + `client/lib/widget/feedpost.dart:71-95` |
| 修改帖子 API DTO | `Post.fromJson` / `Post.toMediaItemModel` | `client/lib/services/post_service.dart:805-942, 1040-1051` |
| 修改嵌套回复（子回复列表 / 展开态） | `loadChildReplies` / `childRepliesFor` / `isParentExpanded` | `client/lib/state/post.state.dart:825-1004` |
| 修改投票 | `PollWidget` / `voteOnPoll` | `client/lib/widget/poll_widget.dart` + `client/lib/state/post.state.dart:361-392` |
| 修改视频自动播放 | `VideoPlayerPool` / `VisibilityDetector` | `client/lib/widget/video_player_pool.dart` + `client/lib/widget/feedpost.dart:484-505, 567-580, 620-702` |
| 修改媒体查看器 | `MediaViewerPage` / `_openMediaViewer` | `client/lib/pages/media/media_viewer_page.dart` + `client/lib/widget/feedpost.dart:917-930` |
| 添加 / 修改文案 | l10n key | `client/lib/l10n/app_zh.arab` + `app_en.arab` |

---

_最后更新：2026-06-15 — 由 Claude 自动化梳理（基于代码静态分析）。_
