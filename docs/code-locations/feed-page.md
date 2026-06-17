# 首页 Feed 信息流（FeedPage）— 代码定位

> 本文档汇总 iOS 客户端「首页 → 帖子信息流」页面 `FeedPage` 的所有源代码位置，包括页面容器本身、顶部 Community / Message 入口行、`_buildQuickPostArea` 快捷发帖区、滚动加载 / 下拉刷新 / 返回顶部手势，以及数据来源 `PostState` / `PostService.getFeed`。
> 该页面是首页底部 5 个常驻 Tab 中的 **Tab 0**，挂在 `HomePage` 的 `IndexedStack` 中（详见 [`home-page.md`](home-page.md) §1.2）。
> 单条帖子卡片的渲染请参考 [`feed-post-widget.md`](feed-post-widget.md)；个人中心的「Threads Tab」虽然复用 `FeedPostWidget`，但与本页是不同的列表容器（详见 [`threads-tab.md`](threads-tab.md)）。
> 后续若收到「定位首页 Feed / 帖子信息流 / 顶部消息图标 / 快捷发帖入口 / 滚动加载」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 `FeedPage` 主体

- **路径**：`client/lib/pages/feed/feed.dart`
- **行数**：279
- **核心类**：
  - `class FeedPage extends StatefulWidget`（`feed.dart:16`）
  - `class _FeedPageState extends State<FeedPage> with TickerProviderStateMixin`（`feed.dart:23`）
- **挂载点**：`HomePage._pages[0]`（`client/lib/pages/home.dart:32-42` 内 `FeedPage()`），由 `IndexedStack` 常驻不销毁。

### 1.2 状态字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `ScrollController _scrollController` | `feed.dart:24` | 列表滚动控制器；监听接近底部自动 `loadMore()` |
| `static const double _scrollToTopThreshold = 200.0` | `feed.dart:52` | 顶部中间区域点击触发「返回顶部」的滚动阈值（仅当 `offset > 200` 时生效） |

### 1.3 生命周期

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `initState` | `feed.dart:26-30` | 注册 `_scrollController.addListener(_onScroll)` |
| `dispose` | `feed.dart:54-59` | 移除监听 + `_scrollController.dispose()` |

> **首屏数据加载不在本页内触发**：`FeedPage` 自身 `initState` 只挂滚动监听，真正拉取 Feed 数据的 `PostState.getDataFromDatabase()` 由 `HomePage.initState` 的 `addPostFrameCallback` → `initPosts()` 统一调用（`home.dart:44, 60-63`）。这样保证 Provider 树已挂载，且只在登录后进入 HomePage 时拉一次。

### 1.4 `build` 主体（`feed.dart:62-188`）

整体结构：`Scaffold(extendBody: true)` → `SafeArea(bottom: false)` → `Column`：

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| 背景色 | `feed.dart:64, 67` | `appColors.background` |
| **顶部 Community / Message 图标行** | `feed.dart:73-120` | 见 §1.5 |
| **Feed 列表区**（`Expanded` + `Consumer<PostState>`） | `feed.dart:122-183` | 见 §1.6 |

### 1.5 顶部图标行（`feed.dart:73-120`）

`Container(padding: horizontal 16, vertical 4)` + `Row`，从左到右：

| 元素 | 行号 | onTap 跳转 | 图标 / 样式 |
| --- | --- | --- | --- |
| Community 入口 | `feed.dart:77-90` | `CupertinoPageRoute → CommunityListPage()`（`client/lib/pages/community/community_list_page.dart`） | `Icons.groups_outlined`，size 28，`appColors.textPrimary` |
| 中间点击区（返回顶部） | `feed.dart:91-104` | `_scrollToTop()`（**仅当** `offset > _scrollToTopThreshold = 200` 才触发） | `GestureDetector(behavior: HitTestBehavior.opaque)` + `SizedBox(height: 36)` |
| Message 入口 | `feed.dart:105-117` | `CupertinoPageRoute → MessagePage()`（`client/lib/pages/message/message_page.dart`） | `Iconsax.message`，size 28，`appColors.textPrimary` |

> 中间区域用 `HitTestBehavior.opaque` + 36px 高的 `SizedBox` 撑出可点击热区，避免左右两个图标之间出现点击盲区。

### 1.6 Feed 列表区（`feed.dart:122-183`）

`Expanded(child: Consumer<PostState>(builder: ...))`，渲染分支：

| 分支 | 条件 | 行号 | 渲染内容 |
| --- | --- | --- | --- |
| **加载中（首屏）** | `state.isBusy` | `feed.dart:124-128` | 居中 `CircularProgressIndicator(color: appColors.textPrimary)` |
| **空态** | `posts == null \|\| posts.isEmpty` | `feed.dart:130-136` | 居中 `Text(AppLocalizations.noPostsYet)`，`appColors.textSecondary` + 16px |
| **内容未填满自动加载** | `state.hasMore && !state.isLoadingMore` 且 `maxScrollExtent <= 0` | `feed.dart:138-146` | `addPostFrameCallback` 内调 `state.loadMore()`（避免首屏内容不足一屏时无法触发滚动加载） |
| **正常列表** | 默认 | `feed.dart:148-181` | `RefreshIndicator` + `ListView.builder`，详见 §1.7 |

数据源：`final posts = state.getPostList(authState.userModel)`（`feed.dart:130`）— 读 `PostState.feedlist`（详见 §2）。

### 1.7 `ListView.builder` 结构（`feed.dart:152-180`）

| 配置 | 值 | 行号 |
| --- | --- | --- |
| `controller` | `_scrollController` | `feed.dart:153` |
| `physics` | `AlwaysScrollableScrollPhysics()`（即使内容不足一屏也允许下拉） | `feed.dart:154` |
| `itemCount` | `posts.length + 1 + (state.isLoadingMore ? 1 : 0)` | `feed.dart:155` |
| 下拉刷新 | `RefreshIndicator(onRefresh: () => state.refresh())`，`color: appColors.textPrimary`，`backgroundColor: appColors.surface` | `feed.dart:148-151` |

`itemBuilder` 分支（`feed.dart:156-179`）：

| index | 渲染 | 行号 |
| --- | --- | --- |
| `0` | `_buildQuickPostArea(authState.userModel)` — 顶部快捷发帖区 | `feed.dart:157-159` |
| `postIndex == posts.length`（即倒数第二项，仅 `isLoadingMore` 时存在） | 底部加载 spinner（20×20，`strokeWidth: 2`，`appColors.textSecondary`） | `feed.dart:161-175` |
| 其他 | `FeedPostWidget(postModel: posts[postIndex])` | `feed.dart:176-178` |

> `FeedPostWidget` 在首页 Feed 中**不传** `isFirst` / `onPostDeleted`（都用默认值），与 Profile Threads Tab 的调用方式不同（详见 [`feed-post-widget.md`](feed-post-widget.md) §8）。

### 1.8 滚动控制

| 方法 | 行号 | 行为 |
| --- | --- | --- |
| `_onScroll` | `feed.dart:32-39` | 滚动到 `maxScrollExtent - 200` 以内时调 `state.loadMore()`（接近底部预加载） |
| `_scrollToTop` | `feed.dart:41-49` | `animateTo(0, duration: 350ms, curve: easeOut)`；若 `offset <= 0` 直接跳过 |

---

## 2. 快捷发帖区 `_buildQuickArea`（`feed.dart:190-278`）

Feed 列表 `index == 0` 的特殊项，用于展示当前用户头像 + 「有什么新鲜事？」入口。

### 2.1 内嵌 `avatar` 函数（`feed.dart:195-225`）

| 输入 | 渲染 |
| --- | --- |
| `url.isEmpty` | `Container(shape: circle, color: surface)` + `Icons.person`（size = `size * 0.6`，`appColors.textSecondary`） |
| 有 URL | `ClipRRect(borderRadius: 100)` + `CachedNetworkImage`；`errorWidget` 兜底回退到 person 图标 |

### 2.2 主体（`feed.dart:227-278`）

- **点击跳转**（`feed.dart:227-244`）：`GestureDetector(behavior: HitTestBehavior.opaque)` → `CupertinoPageRoute → ComposePost(onPostSuccess, onCancel)`
  - `onPostSuccess`：`postState.getDataFromDatabase()` 重新拉取 Feed，然后 `Navigator.of(context).pop()` 回到 Feed。
  - `onCancel`：直接 `pop()`。
- **布局**：`Container(color: background, padding: horizontal 16 / vertical 12)` + `Row(crossAxisAlignment: start)`
  - 头像（size 40） + `SizedBox(width: 12)` + `Expanded(Column)`
  - 第一行：`displayName`（`w700 / 14px / textPrimary`）；为空回退 `userName` → `AppLocalizations.anonymousUser`（`feed.dart:259`）
  - 第二行：`AppLocalizations.whatsNew`（`textSecondary / 14px`）

> 这里走的是 `ComposePost` 的「弹层发帖」入口（与底部 Tab 2 的 ComposePost 是同一个组件，但通过 `onPostSuccess` / `onCancel` 注入回调）。完整发帖流程见 [`publish-post.md`](publish-post.md)。

---

## 3. 数据来源：`PostState`（全局单例）

- **路径**：`client/lib/state/post.state.dart`
- **注册**：`MultiProvider` 全局单例（见 [`home-page.md`](home-page.md) §4）。
- **Feed 相关字段 / 方法**：

| 字段 / 方法 | 行号 | 用途 |
| --- | --- | --- |
| `bool isBusy` | `post.state.dart:65` | 首屏全屏 loading 标记；`getDataFromDatabase` 期间为 `true` |
| `bool _hasMore = true` | `post.state.dart:76` | 是否还有更多页 |
| `bool _isLoadingMore = false` | `post.state.dart:77` | 加载更多中标记 |
| `bool get hasMore` | `post.state.dart:96` | `_hasMore` 只读 getter |
| `bool get isLoadingMore` | `post.state.dart:97` | `_isLoadingMore` 只读 getter |
| `List<PostModel>? feedlist`（getter） | — | Feed 缓存（`_feedlist`）；`getPostList` 内部读取 |
| `List<PostModel>? getPostList(UserModel?)` | `post.state.dart:396-408` | 返回 Feed 列表快照（`isBusy` 时返回 `null`）；目前 `where` 内 `return true`（占位，预留给未来按用户过滤） |
| `List<PostModel>? getPostListByFollower(UserModel?)` | `post.state.dart:374-394` | 变体：按 `userId` 或 `followingList` 过滤 |
| `Future<void> getDataFromDatabase()` | `post.state.dart:426-452` | **首屏 / 强刷**：清空 `_feedlist`、`isBusy = true`、`_currentPage = 1`、`_hasMore = true`，再调 `postService.getFeed()`，按 `createdAt` 降序排序 |
| `Future<void> refresh()` | `post.state.dart:455-...` | **下拉刷新**：不清空 `_feedlist`、不显示全屏 loading，直接拉第一页覆盖；按 `createdAt` 降序排序 |
| `Future<void> loadMore()` | `post.state.dart:545-568` | **加载更多**：`_currentPage++` → `getFeed(page: _currentPage)`；空列表 → `_hasMore = false`；失败回滚 `_currentPage--` 并 `_hasMore = false` |

### 3.1 `getDataFromDatabase` vs `refresh` 的区别

| 维度 | `getDataFromDatabase()` | `refresh()` |
| --- | --- | --- |
| 触发位置 | `HomePage.initPosts()`（`home.dart:60-63`） + `_buildQuickPostArea.onPostSuccess`（`feed.dart:235`） | `RefreshIndicator.onRefresh`（`feed.dart:151`） |
| 是否清空 `_feedlist` | ✅ 清空（先置 `null`） | ❌ 不清空 |
| 是否走全屏 loading | ✅ `isBusy = true` | ❌ 不改 `isBusy` |
| 适用场景 | 首次进入 / 发帖成功后强刷 | 用户主动下拉刷新（保留旧内容可见） |

---

## 4. 服务层（API）

### 4.1 `PostService.getFeed`

- **路径**：`client/lib/services/post_service.dart:133`
- **签名**：`Future<List<Post>> getFeed({int page = 1, int size = 20})`
- **用途**：拉取 Feed 流（首页帖子列表），供 `getDataFromDatabase` / `refresh` / `loadMore` 调用。
- **完整服务层定位**：见 [`threads-tab.md`](threads-tab.md) §4.1（`PostService` 的其余方法都在同一文件内）。

---

## 5. 子组件 / 跳转目标

| 名称 | 路径 | 触发位置 |
| --- | --- | --- |
| `FeedPostWidget` | `client/lib/widget/feedpost.dart` | `feed.dart:176-178`（列表项渲染） — 详见 [`feed-post-widget.md`](feed-post-widget.md) |
| `CommunityListPage` | `client/lib/pages/community/community_list_page.dart` | `feed.dart:79-83`（顶部左图标） |
| `MessagePage` | `client/lib/pages/message/message_page.dart` | `feed.dart:107-110`（顶部右图标） |
| `ComposePost` | `client/lib/pages/composePost/post.dart` | `feed.dart:230-243`（快捷发帖区点击） — 详见 [`publish-post.md`](publish-post.md) |

---

## 6. 状态层（Provider）调用汇总

| 状态 | 调用位置（行号） | 用途 |
| --- | --- | --- |
| `PostState` | `feed.dart:36-37, 123, 130, 139-145, 151, 155, 161, 176, 229, 235` | `loadMore` / `Consumer` 订阅重建 / `getPostList` / `hasMore` / `isLoadingMore` / `refresh` / `getDataFromDatabase` |
| `AuthState` | `feed.dart:63, 130, 158, 190` | 取 `userModel`（快捷发帖区的头像 / 名称 + `getPostList` 的过滤参数） |

- `PostState` 通过 `Consumer<PostState>` 订阅变更（列表数据变化时自动重建）。
- `AuthState` 全部 `listen: false`，只读一次。

---

## 7. 主题 / 颜色 / 国际化

### 7.1 颜色

所有色值通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取（`feed.dart:64, 191`），入口 `client/lib/theme/app_colors.dart`。

| 字段 | 用途 | 位置 |
| --- | --- | --- |
| `background` | Scaffold / ListView 背景、快捷发帖区背景 | `feed.dart:67, 247` |
| `surface` | 空头像占位、`RefreshIndicator` 背景色、头像错误兜底 | `feed.dart:151, 201, 216` |
| `textPrimary` | 顶部图标、首屏 loading、`RefreshIndicator` 前景色、快捷发帖区 displayName | `feed.dart:88, 115, 126, 149, 261` |
| `textSecondary` | 空态文案、底部 loading spinner、头像兜底图标、快捷发帖区副标题 | `feed.dart:134, 170, 204, 220, 269` |

### 7.2 国际化

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **生成代码**：`client/lib/l10n/generated/app_localizations*.dart`（`feed.dart:7` 引用）
- **Feed 页文案 key**：

| key | 用途 | 位置 |
| --- | --- | --- |
| `noPostsYet` | 空态文案 | `feed.dart:133` |
| `whatsNew` | 快捷发帖区副标题 | `feed.dart:268` |
| `anonymousUser` | `displayName` / `userName` 都为空时的兜底 | `feed.dart:259` |

---

## 8. 关联清单

| 关联模块 | 清单 |
| --- | --- |
| 首页整体框架（底部导航 + 5 Tab） | [`home-page.md`](home-page.md) |
| 单条帖子卡片 `FeedPostWidget` | [`feed-post-widget.md`](feed-post-widget.md) |
| 个人中心 Threads Tab（同样使用 `FeedPostWidget`，但是独立列表容器） | [`threads-tab.md`](threads-tab.md) |
| 发帖流程（`ComposePost` 编辑 / 发布） | [`publish-post.md`](publish-post.md) |
| 帖子详情页（点击卡片跳转） | [`post-detail-page.md`](post-detail-page.md) |

---

## 9. 设计要点

### 9.1 常驻不销毁

`FeedPage` 挂在 `IndexedStack` 中，切换 Tab 不会销毁重建——滚动位置、`ScrollController`、`PostState.feedlist` 缓存全部保留。代价是首次进入需要由 `HomePage.initState` 显式触发 `getDataFromDatabase()`（`home.dart:60-63`）。

### 9.2 三层加载策略

| 场景 | 入口 | API |
| --- | --- | --- |
| 首屏 / 发帖成功强刷 | `HomePage.initPosts` / `onPostSuccess` | `getDataFromDatabase()`（清空 + 全屏 loading） |
| 用户下拉 | `RefreshIndicator.onRefresh` | `refresh()`（不清空、无全屏 loading） |
| 滚动接近底部 / 内容不足一屏 | `_onScroll` / `addPostFrameCallback` | `loadMore()`（增量拼接） |

### 9.3 内容不足一屏自动加载

`feed.dart:138-146` 用 `WidgetsBinding.instance.addPostFrameCallback` 检测 `maxScrollExtent <= 0`（即内容没填满视口），主动触发一次 `loadMore()`，避免短内容场景下用户无滚动可触发、看不到后续帖子。

### 9.4 返回顶部手势的阈值

顶部中间区域只在 `offset > 200` 时才响应点击返回顶部（`feed.dart:96-100`）。这样在内容未滚动时不会拦截误触，但又允许用户在长 Feed 中快速回到顶部。

### 9.5 `getPostList` 的过滤占位

当前 `getPostList`（`post.state.dart:396-408`）的 `where` 内是 `return true`（无过滤），与 `getPostListByFollower`（按 `followingList` 过滤）形成对比。占位钩子预留给未来按用户/可见性过滤。

---

## 10. 快速检索指引

| 需求 | 检索关键词 | 关键位置 |
| --- | --- | --- |
| 修改 Feed 页整体布局 | `FeedPage` / `_FeedPageState` / `build` | `client/lib/pages/feed/feed.dart:62-188` |
| 修改顶部 Community / Message 图标 | 顶部 `Row` | `feed.dart:73-120` |
| 修改顶部点击「返回顶部」手势 | `_scrollToTop` / `_scrollToTopThreshold` | `feed.dart:41-49, 52, 91-104` |
| 修改快捷发帖区（头像 + 「有什么新鲜事？」） | `_buildQuickPostArea` | `feed.dart:190-278` |
| 修改列表 / 空态 / 首屏 loading | `Consumer<PostState>` builder | `feed.dart:122-183` |
| 修改下拉刷新 | `RefreshIndicator` / `state.refresh()` | `feed.dart:148-151` |
| 修改滚动加载更多 | `_onScroll` / `state.loadMore()` | `feed.dart:32-39, 138-146` |
| 修改底部 loading spinner | `itemBuilder` 倒数第二项 | `feed.dart:161-175` |
| 修改首屏数据拉取（强刷） | `getDataFromDatabase` / `initPosts` | `client/lib/state/post.state.dart:426-452` + `client/lib/pages/home.dart:60-63` |
| 修改 Feed API（分页参数） | `PostService.getFeed` | `client/lib/services/post_service.dart:133` |
| 修改帖子卡片渲染（单条） | `FeedPostWidget` | 见 [`feed-post-widget.md`](feed-post-widget.md) |
| 修改空态 / 快捷发帖区文案 | `noPostsYet` / `whatsNew` / `anonymousUser` | `client/lib/l10n/app_en.arb` + `app_zh.arb` |

---

_最后更新：2026-06-17 — 由 Claude 自动化梳理（基于代码静态分析）。_
