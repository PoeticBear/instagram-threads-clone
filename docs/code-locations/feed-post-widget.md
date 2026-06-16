# FeedPostWidget（单个帖子组件）— 代码定位

> 本文档汇总 iOS 客户端「单个帖子卡片」组件 `FeedPostWidget` 的所有源代码位置，包括组件本身、其调用的子组件、状态方法、模型与跳转目标页面。
> 后续若收到「定位 Feed 帖子卡片 / 帖子详情里的卡片 / 转发/引用/媒体九宫格」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心组件（UI 层）

### 1.1 `FeedPostWidget` 主体

- **路径**：`client/lib/widget/feedpost.dart`
- **行数**：1535
- **核心类**：
  - `class FeedPostWidget extends StatefulWidget`（`feedpost.dart:29`）
  - `class _FeedPostWidgetState extends State<FeedPostWidget>`（`feedpost.dart:60`）
- **构造参数**：
  | 字段 | 行号 | 说明 |
  | --- | --- | --- |
  | `required PostModel postModel` | `feedpost.dart:30` | 帖子数据模型 |
  | `VoidCallback? onPostDeleted` | `feedpost.dart:36` | 删除成功后父级回调；用于 `ProfilePage._userPosts` 同步移除（详见「8. 调用点」） |
  | `bool isFirst = false` | `feedpost.dart:47` | 首页 Feed `false`；Threads Tab 第一项 `true`，跳过 0.2px 分割线 + 10px 间距 |

### 1.2 状态字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `PostModel? _fetchedQuotePost` | `feedpost.dart:61` | 引用帖子兜底拉取的本地缓存 |
| `bool _isFetchingQuote` | `feedpost.dart:62` | 引用帖子拉取中标记 |
| `bool _isTextExpanded` | `feedpost.dart:66` | 帖子正文展开/收起 |
| `static const int _kCollapsedMaxLines = 5` | `feedpost.dart:69` | 收起时最大行数 |

### 1.3 派生属性

- `PostModel? get _effectiveQuotePost`（`feedpost.dart:72`）— 优先返回 `postModel.quotePost`，否则返回 `_fetchedQuotePost`。

### 1.4 生命周期

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `initState` | `feedpost.dart:76` | 触发 `_maybeFetchQuotePost`；订阅 `VideoPlayerPool.version` |
| `dispose` | `feedpost.dart:84` | 取消 `VideoPlayerPool` 订阅 |
| `_onPoolChanged` | `feedpost.dart:89` | 池中 controller ready 后触发 `setState` |
| `_maybeFetchQuotePost` | `feedpost.dart:94` | `quote_post_id` 有值但 `quotePost` 为空时拉取被引用帖子 |

---

## 2. build 主体（`feedpost.dart:121-351`）

按从上到下的渲染顺序：

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| 顶部 0.2px 分割线 + 10px 间距 | `feedpost.dart:167-176` | `isFirst=false` 时显示 |
| 头部行：头像 / 显示名 / 时间戳 / 已编辑徽章 / 「更多」按钮 | `feedpost.dart:177-224` | 头像 / 显示名点击进入作者 Profile |
| 正文（`HitTestBehavior.opaque` 跳详情） | `feedpost.dart:225-232` | 调用 `_buildPostContent` |
| 引用帖子预览卡片 | `feedpost.dart:233-245` | 调用 `_buildQuoteCard` |
| 投票卡片 | `feedpost.dart:246-258` | `PollWidget`（来自 `widget/poll_widget.dart`）；目前其余走 `SizedBox.shrink()` |
| 媒体九宫格 | `feedpost.dart:259-264` | 调用 `_buildMediaGallery` |
| 互动按钮行（点赞 / 回复 / 转发 / 分享） | `feedpost.dart:268-343` | 每项 20px `Iconsax.*` + 计数 |

辅助函数：

- `Widget avatar(String url, double size)`（`feedpost.dart:134-154`）— 本地头像：空 URL 走 `Icons.person` 占位；有 URL 走 `CachedNetworkImage` + 100 圆角。
- `final displayName`（`feedpost.dart:124-126`）— 优先级 `displayName` → `userName` → `User{userId}` 兜底。

---

## 3. 子构建器（UI 内部件）

### 3.1 正文渲染（展开/收起）`_buildPostContent`

- **行号**：`feedpost.dart:364-423`
- **关键点**：
  - 用 `LayoutBuilder` + `TextPainter.didExceedMaxLines` 判断是否真的溢出，**避免短文本也显示「展开」按钮**。
  - 收起时 `maxLines: 5` + `TextOverflow.ellipsis`；展开时 `maxLines: null` + `TextOverflow.visible`。
  - 「展开全文 / 收起」按钮文案来自 `AppLocalizations.showMore` / `showLess`（`feedpost.dart:408-410`）。
  - 按钮 `behavior: HitTestBehavior.opaque` 防止冒泡到外层 `_navigateToPostDetail`（`feedpost.dart:404`）。

### 3.2 媒体画廊（九宫格）`_buildMediaGallery`

- **入口**：`feedpost.dart:433-447`
- **规则**（仿微博 / 朋友圈 / 小红书九宫格）：
  - 1 张：大图按 `width/height` 比例渲染，缺值 1:1 兜底
  - 2-4 张：2 列网格（2×2）
  - 5-9 张：3 列网格（3×3）
  - >9 张：显示前 9 个，最后一张叠 `+N` 半透明角标
- **子函数**：
  - `_buildSingleMedia`（`feedpost.dart:451-503`）— 单张大图；视频包 `VisibilityDetector`，可见时让 `VideoPlayerPool` 自动播放。
  - `_buildGridMedia`（`feedpost.dart:506-593`）— 多图网格；视频子项同样包 `VisibilityDetector`；最后一张用 `Colors.black54` + `Stack` 叠 `+N` 文字。
  - `_buildMediaImage`（`feedpost.dart:602-720`）— 通用单图块：图片 / GIF 走 `CachedNetworkImage`；视频走 `CachedNetworkImage` + 池中 `VideoPlayer` 叠加 + 右下角「时长 + 音频开关」。

### 3.3 视频池集成

- **池实现**：`client/lib/widget/video_player_pool.dart`（被 `feedpost.dart:20` 引用）。
- **关键调用**：
  - `VideoPlayerPool.instance.acquire(mediaKey, videoUrl)`（`feedpost.dart:494, 570`）
  - `VideoPlayerPool.instance.playVisible(mediaKey)` / `pauseVisible(mediaKey)`（`feedpost.dart:495-498, 571-574`）
  - `VideoPlayerPool.instance.pauseAll()`（`feedpost.dart:486, 584`）— 进入大图前暂停。
  - `VideoPlayerPool.instance.controllerOf(mediaKey)`（`feedpost.dart:618`）— 取出已就绪 controller。
  - `VideoPlayerPool.instance.toggleMute(mediaKey)`（`feedpost.dart:677`）— 音频开关。
- **`mediaKey` 命名**：`feed_video_${postId}_${index}`（`feedpost.dart:463, 536`）— 多图网格里同一帖子可能有多段视频，必须用 `postId + mediaIndex` 唯一定位。

### 3.4 引用帖子卡片 `_buildQuoteCard`

- **行号**：`feedpost.dart:724-864`
- **三种渲染**：
  - **情况 1**：有完整 `quotePost` 数据 → 渲染作者信息行 + 正文（`maxLines: 4`）+ 首图（高度 150，cover）。
  - **情况 2**：`_isFetchingQuote == true` → 渲染 16×16 loading + "Loading..."。
  - **情况 3**：加载失败 / 原帖不可用 → "This post is unavailable"。

---

## 4. 页面跳转（`feedpost.dart:866-927`）

| 方法 | 行号 | 目标 |
| --- | --- | --- |
| `_navigateToProfile` | `feedpost.dart:868` | `ProfilePage.getRoute(profileId, username)` |
| `_navigateToPostDetail` | `feedpost.dart:878` | `PostDetailPage(postId, postModel)`（`CupertinoPageRoute`） |
| `_navigateToQuotedPostDetail` | `feedpost.dart:890` | `PostDetailPage(quotePost.id, quotePost)` |
| `_navigateToQuotedUserProfile` | `feedpost.dart:902` | `ProfilePage.getRoute(...)` |
| `_openMediaViewer` | `feedpost.dart:914` | `MediaViewerPage(mediaItems, initialIndex)`（`MaterialPageRoute`），`tappedIndex.clamp(0, items.length-1)` 兜底 |

### 4.1 跳转目标页面

| 跳转 | 路径 |
| --- | --- |
| 帖子详情 | `client/lib/pages/post/post_detail_page.dart` |
| 用户主页 | `client/lib/pages/profile/profile.dart`（通过 `ProfilePage.getRoute` 工厂方法） |
| 媒体查看器 | `client/lib/pages/media/media_viewer_page.dart` |

---

## 5. 底部 Sheet 弹层（`feedpost.dart:929-1533`）

| Sheet | 触发方法 | 行号 | 关键逻辑 |
| --- | --- | --- | --- |
| **Repost Sheet** | `_showRepostSheet` | `feedpost.dart:961-1011` | 转发 / 引用（跳 `_showQuoteSheet`）/ 撤销转发 |
| **Quote Sheet** | `_showQuoteSheet` | `feedpost.dart:1015-1138` | 顶部关闭 + 引用预览 + 3 行输入框 + 「发布」按钮（调 `PostState.createPost(postModel, quoteRepostId: ...)`） |
| **Share Sheet** | `_showShareSheet` | `feedpost.dart:1142-1187` | 复制链接（`${ApiConfig.baseUrl}t/$postId` → `Clipboard.setData` + `SnackBar`）/ 分享（调 `PostState.sharePost(postId)`） |
| **More Menu** | `_showMoreMenu` | `feedpost.dart:1191-1414` | 综合菜单（编辑 / 删除 / 置顶 / 收藏 / 静音 / 限制 / 拉黑 / 举报 / 编辑历史 / 不感兴趣），详见下方表格 |
| **Report Menu** | `_showReportMenu` | `feedpost.dart:1447-1533` | 9 种举报类型（Spam / Harassment / Hate Speech / Self-harm / Violence / Privacy / Misinformation / IP / Other），调 `PostState.reportContent(targetType: 1, targetId, reportType)` |

### 5.1 More Menu 决策点

| 条件 | 出现项 | 行号 |
| --- | --- | --- |
| `isOwnPost == true` 且 `canEdit == true` | 编辑（跳 `ComposePost(editingPostId, ...)`） | `feedpost.dart:1228-1250` |
| `isOwnPost == true` | 删除（确认弹窗 + `PostState.deletePost` + `widget.onPostDeleted?.call()`） | `feedpost.dart:1252-1295` |
| `isOwnPost == true` | 置顶 / 取消置顶（`PostState.pinPost` / `unpinPost`） | `feedpost.dart:1296-1307` |
| 始终 | 收藏 / 取消收藏（`PostState.savePost` / `unsavePost`） | `feedpost.dart:1308-1319` |
| `isOwnPost == false` | 静音 / 限制 / 拉黑（调 `_handleRelationControl`，`controlType: 1/2/3`） | `feedpost.dart:1320-1380` |
| `isOwnPost == false` | 举报（跳 `_showReportMenu`） | `feedpost.dart:1381-1390` |
| 始终 | 编辑历史（弹 `EditHistorySheet`） | `feedpost.dart:1391-1403` |
| 始终 | 不感兴趣（暂无实际动作） | `feedpost.dart:1404-1409` |

### 5.2 编辑权限判定（`feedpost.dart:1204-1213`）

```dart
bool canEdit = isOwnPost
    && createdAt != null
    && DateTime.now().difference(createdAt) < const Duration(minutes: 15)
    && editCount < 5;
```

服务端约束：帖子发布后 15 分钟内 + 最多 5 次编辑。前端预判用于隐藏入口。

### 5.3 关系控制 `_handleRelationControl`（`feedpost.dart:1416-1445`）

- 走 `UserService.addRelationControl(targetUserId, controlType)`（`client/lib/services/user_service.dart`）。
- `controlType` 含义：`1=静音 / 2=限制 / 3=拉黑`。

---

## 6. 状态层（Provider）调用汇总

| 状态 / 服务 | 调用位置（行号） | 方法 |
| --- | --- | --- |
| `PostState` | `feedpost.dart:102, 277, 966, 1112, 1146, 1215` | `fetchQuotePostDetail(qid)` / `likePost` / `unlikePost` / `repost` / `unrepost` / `createPost` / `sharePost` / `savePost` / `unsavePost` / `pinPost` / `unpinPost` / `deletePost` / `reportContent` |
| `AuthState` | `feedpost.dart:1113, 1199` | `userId` / `userModel`（用于 `Quote Sheet` 发布人身份与 `isOwnPost` 判定） |
| `UserService` | `feedpost.dart:1424` | `addRelationControl`（静音 / 限制 / 拉黑） |

`PostState` / `AuthState` 均通过 `Provider.of<PostState>(context, listen: false)` / `Provider.of<AuthState>(context, listen: false)` 取，**不订阅变更**——状态更新由父级 `Consumer<PostState>` 重建驱动。

---

## 7. 数据模型

| 模型 | 路径 | 关键字段 |
| --- | --- | --- |
| `PostModel` | `client/lib/model/post.module.dart` | `id` / `bio`（正文） / `createdAt` / `isEdited` / `editCount` / `isLiked` / `likesCount` / `repliesCount` / `isReposted` / `repostsCount` / `sharesCount` / `isSaved` / `isPinned` / `isSensitive` / `contentWarning` / `user` / `pollData` / `quoteRepostId` / `quotePost` / `effectiveMediaItems` / `hasMedia` |
| `UserModel` | `client/lib/model/user.module.dart` | `userId` / `userName` / `displayName` / `profilePic` |
| `MediaItemModel` | `client/lib/model/post.module.dart` | `url` / `thumbUrl` / `width` / `height` / `isVideo` / `durationLabel` |

> ⚠️ 文件命名带 `.module` 后缀（项目历史命名），不是 `.model`。

---

## 8. 调用点（谁在用 `FeedPostWidget`）

| 调用方 | 路径 | 是否传 `isFirst` / `onPostDeleted` |
| --- | --- | --- |
| 首页 Feed | `client/lib/pages/feed/feed.dart:176-178` | 都用默认值（`isFirst: false`，无 `onPostDeleted`） |
| Profile Threads Tab | `client/lib/pages/profile/profile.dart` | `isFirst: true` 跳过首项 10px 间距；通常会传 `onPostDeleted` |
| 话题详情 | `client/lib/pages/topic/topic_detail_page.dart` | 默认值 |
| 社区详情 | `client/lib/pages/community/community_detail_page.dart` | 默认值 |
| 收藏列表 | `client/lib/pages/post/saved_posts_page.dart` | 默认值 |
| 定时发布列表 | `client/lib/pages/post/scheduled_posts_page.dart` | 默认值 |

> Feed 流本身的滚动加载（`_onScroll` + `state.loadMore()`）、下拉刷新（`state.refresh()`）、空态文案（`noPostsYet`）在 `feed.dart:32-180`，详见 [`docs/code-locations/home-page.md`](home-page.md) §2.1。

---

## 9. 关联子组件 / 弹层

| 名称 | 路径 | 用途 |
| --- | --- | --- |
| `PollWidget` | `client/lib/widget/poll_widget.dart` | 投票卡片（`feedpost.dart:19` 引用） |
| `VideoPlayerPool` | `client/lib/widget/video_player_pool.dart` | 全局视频 controller 池（`feedpost.dart:20` 引用） |
| `EditHistorySheet` | `client/lib/widget/edit_history_sheet.dart` | 编辑历史弹层（`feedpost.dart:24` 引用） |
| `ReplyBottomSheet` | `client/lib/widget/reply_bottom_sheet.dart` | 回复弹层（`feedpost.dart:25, 305` 引用） |
| `MediaViewerPage` | `client/lib/pages/media/media_viewer_page.dart` | 媒体大图预览（`feedpost.dart:21` 引用） |
| `PostDetailPage` | `client/lib/pages/post/post_detail_page.dart` | 帖子详情（`feedpost.dart:23` 引用） |
| `ComposePost` | `client/lib/pages/composePost/post.dart` | 编辑模式入口（`feedpost.dart:12, 1237` 引用） |

---

## 10. 主题 / 颜色 / 国际化

- **颜色**：所有色值通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 取（`feedpost.dart:132, 932, 941, 962, ...`）。
- **常用色值**：`textPrimary` / `textSecondary` / `textMuted` / `textHint` / `background` / `surface` / `border` / `divider` / `accent` / `like` / `repost` / `destructive`。
- **国际化**：`client/lib/l10n/app_en.arb` + `client/lib/l10n/app_zh.arb`。
  - 文案键：`showMore` / `showLess` / `editedBadge` / `repost` / `quote` / `undoRepost` / `quoteRepost` / `quotePlaceholder` / `post` / `copyLink` / `linkCopiedToClipboard` / `share` / `editPost` / `deletePost` / `deletePostConfirm` / `postDeleted` / `pinPost` / `unpinPost` / `save` / `unsave` / `muteUsername(...)` / `restrictUsername(...)` / `blockUsername(...)` / `blockConfirmTitle` / `blockConfirmDesc` / `block` / `cancel` / `userMuted` / `userRestricted` / `userBlocked` / `report` / `reportPost` / `reportSpam` / `reportHarassment` / `reportHateSpeech` / `reportSelfHarm` / `reportViolence` / `reportPrivacyViolation` / `reportMisinformation` / `reportIntellectualProperty` / `reportOther` / `reportSuccess` / `reportFailed` / `editHistory` / `notInterested` / `operationFailed`。

---

## 11. 快速检索指引

| 需求 | 检索关键词 | 关键位置 |
| --- | --- | --- |
| 修改卡片整体布局 | `build(BuildContext context)` | `feedpost.dart:121-351` |
| 修改头像 / 显示名 / 时间戳 | 头部 `Row` | `feedpost.dart:177-224` |
| 修改正文展开 / 收起 | `_buildPostContent` / `_kCollapsedMaxLines` | `feedpost.dart:364-423` |
| 修改媒体九宫格 | `_buildMediaGallery` / `_buildSingleMedia` / `_buildGridMedia` | `feedpost.dart:433-593` |
| 修改视频播放 / 音频开关 | `VideoPlayerPool` / `VisibilityDetector` | `feedpost.dart:482-503, 563-578, 649-700` |
| 修改引用卡片 | `_buildQuoteCard` | `feedpost.dart:724-864` |
| 修改点赞 / 回复 / 转发 / 分享按钮 | 互动按钮 `Row` | `feedpost.dart:268-343` |
| 修改「更多」菜单 | `_showMoreMenu` | `feedpost.dart:1191-1414` |
| 修改举报菜单 | `_showReportMenu` | `feedpost.dart:1447-1533` |
| 修改复制链接 / 分享 | `_showShareSheet` | `feedpost.dart:1142-1187` |
| 修改转发 / 引用 | `_showRepostSheet` / `_showQuoteSheet` | `feedpost.dart:961-1138` |
| 修改静音 / 限制 / 拉黑 | `_handleRelationControl` | `feedpost.dart:1416-1445` |
| 修改删除逻辑（同步父列表） | `widget.onPostDeleted?.call()` | `feedpost.dart:1289` |
| 修改编辑入口判断 | `canEdit` | `feedpost.dart:1206-1213` |
| 父级怎么传 `isFirst` | `FeedPostWidget(isFirst: ...)` | `feedpost.dart:47-54`（构造） |

---

_最后更新：2026-06-16 — 由 Claude 自动化梳理（基于代码静态分析）。_
