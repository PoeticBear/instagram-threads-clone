# 搜索（Search Page）— 代码定位

> 本文档汇总 iOS 客户端「搜索」页面（底部导航栏第 2 个 Tab）涉及的所有源代码位置，包括主页面、搜索框 / Tab 切换 / 排序切换、空态（历史 / 热门话题 / 趋势帖）、4 个 Tab 的渲染、状态层、服务层、入口集成点、子组件复用点。
> 该页面是首页底部 5 个常驻 Tab 中的 **Tab 1**，挂在 `HomePage` 的 `IndexedStack` 中（详见 [`home-page.md`](home-page.md) §1.2）。
> 后续若收到「定位搜索页 / Search / 搜索历史 / 热门话题 / 搜索结果」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 `SearchPage` 主体

- **路径**：`client/lib/pages/search/search.dart`
- **行数**：568
- **核心类**：
  - `class SearchPage extends StatefulWidget`（`search.dart:13`）
  - `class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin`（`search.dart:20`）
- **挂载点**：`HomePage._pages[1]`（`client/lib/pages/home.dart:36`），由 `IndexedStack` 常驻不销毁。

### 1.2 状态字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `_textController` | `search.dart:21` | 搜索框输入控制器 |
| `_scrollController` | `search.dart:22` | 各 Tab 共享的滚动控制器（接近底部 80% 时触发 `loadMore`） |
| `_tabController` | `search.dart:23` | 4 个 Tab 的 TabController（Top / Users / Topics / Posts） |

### 1.3 生命周期

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `initState` | `search.dart:26-35` | 创建 `TabController(length: 4)`、注册 `_onTabChanged` / `_onScroll` 监听，**首屏 addPostFrameCallback 内触发 `state.loadEmptyStateData()`** 加载历史 / 热门 / 趋势 |
| `dispose` | `search.dart:54-61` | 移除监听并 dispose `_scrollController` / `_tabController` / `_textController` |

### 1.4 `build` 主体（`search.dart:64-97`）

`Scaffold` → `AppBar(title: 'Search')` → `body: Consumer<SearchState>` 内 `Column`：

| 区块 | 行号 | 条件 | 说明 |
| --- | --- | --- | --- |
| **搜索框** `_buildSearchField` | `search.dart:101-143` | 始终渲染 | 见 §1.5 |
| **排序 + TabBar** `_buildTabBar` | `search.dart:147-180` | `searchQuery.isNotEmpty` | 见 §1.6 |
| **结果区** `_buildSearchResults` | `search.dart:210-227` | `searchQuery.isNotEmpty` | 见 §1.7 |
| **空态** `_buildEmptyState` | `search.dart:418-452` | `searchQuery.isEmpty` | 见 §1.8 |

### 1.5 搜索框（`search.dart:101-143`）

`Container(horizontal 15, vertical 8)` → `TextField`：

- **prefixIcon**：`Iconsax.search_normal`（18px，`appColors.textSecondary`）
- **suffixIcon**：`searchQuery.isNotEmpty` 时显示 `Icons.close`（点击清空 + `onSearchChanged('')`）
- **fillColor**：`appColors.surface`
- **border**：透明 + 圆角 10（enabled / focused 一致）
- **hintText**：`AppLocalizations.search`（l10n key `search`）
- **onChanged**：直接转发 `state.onSearchChanged(value)`（SearchState 内 400ms debounce → `_performSearch()`）

### 1.6 排序 + TabBar（`search.dart:147-180`）

| 子区块 | 行号 | 说明 |
| --- | --- | --- |
| **Sort toggle**（Top / Recent） | `search.dart:153-162` | `_sortChip(state, 'top' / 'recent', l10n.sortTop / sortRecent, appColors)`，高亮态：`isActive` 时反色（背景 = `textPrimary`、字色 = `background`） |
| **TabBar**（Top / Users / Topics / Posts） | `search.dart:163-177` | `controller: _tabController`、`indicatorColor: textPrimary`、`indicatorSize: label`、4 个 `Tab(text: l10n.tabXxx)` |

> Sort toggle 切换 → `state.changeSortOrder(value)` → SearchState 立即调 `_performSearch()`（`search.state.dart:299-305`）。

### 1.7 搜索结果区（`search.dart:210-227`）

| 分支 | 行号 | 说明 |
| --- | --- | --- |
| **加载中（首屏）** | `search.dart:211-216` | `state.isSearching` 时居中 `CircularProgressIndicator` |
| **正常结果** | `search.dart:218-226` | `TabBarView(controller: _tabController)` 渲染 `_buildTopTab / UsersTab / TopicsTab / PostsTab` |

`_getHasMore(state, tab)`（`search.dart:229-240`）按当前 Tab 返回是否还有下一页：

| Tab | 判定 |
| --- | --- |
| `SearchTab.top` | `hasMoreUsers \|\| hasMorePosts \|\| hasMoreTopics` |
| `SearchTab.users` | `hasMoreUsers` |
| `SearchTab.topics` | `hasMoreTopics` |
| `SearchTab.posts` | `hasMorePosts` |

`_buildLoadingFooter(state, tab)`（`search.dart:242-258`）：仅 `isLoadingMore` 时渲染底部 20×20 spinner。

#### 1.7.1 Top Tab（`search.dart:260-307`）

混合视图，按区块拼装：

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| **用户水平列表** | `search.dart:272-291` | `_buildSectionHeader(sectionUsers, totalUsers)` + 横向 `ListView.separated`，每项 `SizedBox(140×210)` 渲染 `UserCard(user, isFollowing: u.isFollowing ?? false)` |
| **话题列表** | `search.dart:292-299` | `_buildSectionHeader(sectionTopics, totalTopics)` + `state.searchTopics.take(3).map(TopicTile)`；若 `totalTopics > 3` 末尾追加 `_buildSeeAllButton(seeAllTopics)`（点击 `_tabController.animateTo(2)`） |
| **帖子列表** | `search.dart:300-303` | `_buildSectionHeader(sectionPosts, totalPosts)` + `state.searchPosts.take(5).map(SearchPostTile)` |
| **加载 footer** | `search.dart:304` | `_buildLoadingFooter(state, SearchTab.top)` |

> 取 `take(3)` / `take(5)` 是 Top Tab 的「混排预览」策略 — 完整结果在 Users / Topics / Posts Tab。

#### 1.7.2 Users Tab（`search.dart:350-365`）

- 空态走 `_buildNoResults()`
- 否则 `ListView.separated(controller: _scrollController, itemCount: users.length + 1)`：前 N 项渲染 `UserTilePage(user, isFollowing: u.isFollowing ?? false)`，最后一项 `_buildLoadingFooter`
- 分隔线：`Divider(color: appColors.divider, indent: 65)`（对齐头像右沿）

#### 1.7.3 Topics Tab（`search.dart:367-381`）

结构同 Users Tab，每项 `TopicTile(trendingTopic: state.searchTopics[index])`。

#### 1.7.4 Posts Tab（`search.dart:383-397`）

结构同 Users Tab，每项 `SearchPostTile(post: state.searchPosts[index])`。

#### 1.7.5 空态文案 `_buildNoResults`（`search.dart:399-414`）

居中 `Iconsax.search_normal`（48px） + `AppLocalizations.noResultsFound`（18px）。

### 1.8 空态区 `_buildEmptyState`（`search.dart:418-452`）

`searchQuery.isEmpty` 时渲染，无输入框焦点。

| 区块 | 行号 | 说明 |
| --- | --- | --- |
| **加载中** | `search.dart:419-424` | `state.isLoadingEmptyState` 时居中 spinner |
| **搜索历史** | `search.dart:428-435` | `_buildEmptySectionHeader('Recent', actionText: 'Clear all', onAction: state.clearSearchHistory)` + 每项 `_buildHistoryItem`（`Dismissible` 右滑删除 + `deleteHistoryItem(item.id)`） |
| **热门话题** | `search.dart:436-445` | `_buildEmptySectionHeader('Trending topics')` + `TopicTile(trendingTopic, onTap: () { _textController.text = t.name; state.onSearchChanged(t.name); })`（点击直接填入搜索框） |
| **趋势帖** | `search.dart:446-449` | `_buildEmptySectionHeader('Trending posts')` + 每项 `SearchPostTile` |

#### 1.8.1 头部子件 `_buildEmptySectionHeader`（`search.dart:454-483`）

`Row.spaceBetween`：左标题（22px / w700 / textPrimary），右可选操作文案（`textMuted` / 16px，点击触发回调）。

#### 1.8.2 搜索历史项 `_buildHistoryItem`（`search.dart:504-567`）

- `Dismissible(direction: endToStart)`：背景 = `appColors.destructive` + 居右 `Icons.delete_outline`；onDismissed 触发 `state.deleteHistoryItem(item.id)`
- 主体：左侧 `_historyTypeIcon(item.searchType)`（searchType 2=user / 3=hashtag / 4=document / 默认=clock，详见 `search.dart:485-492`），中间列展示 `item.query` + `_formatTime(item.searchedAt)`（justNow / minutesAgo / hoursAgo / daysAgo / `MM/dd`），右侧可选结果显示数字 `item.resultCount` + `Icons.close` 删除
- **整体 onTap**：`_textController.text = item.query; state.onSearchChanged(item.query)`（点击即填充并触发搜索）

---

## 2. 子组件 / 复用件

| 组件 | 路径 | 行数 | 用途 |
| --- | --- | --- | --- |
| `SearchPostTile` | `client/lib/widget/search_post_tile.dart` | 120 | 搜索结果 / 趋势帖的单条帖子卡（头像 + displayName + @username + content 2 行 + ❤/💬 数） |
| `UserCard` | `client/lib/widget/user_card.dart` | 146 | Top Tab 用户横滑卡（56×56 头像 + displayName + verified + @username + 粉丝数 + Follow/Following 按钮），点击跳 `ProfilePage.getRoute` |
| `UserTilePage` | `client/lib/widget/list.dart` | 174 | Users Tab 单条用户行（40×40 头像 + displayName + verified + @username + bio + 粉丝数 + Follow/Following 按钮），头像 / 文本均可点跳 Profile |
| `TopicTile` | `client/lib/widget/topic_tile.dart` | 180 | 话题单行（#图标 + name + 帖子数 + Follow/Following 按钮），点击进 `TopicDetailPage.getRoute(topicId, topicName)`；支持 `trendingTopic` / `topicInfo` 两种数据源（命名构造 `TopicTile.fromTopicInfo`） |

> `UserCard` / `UserTilePage` 的 follow 按钮仅展示态，**未挂回调**（不带 `onFollowTap`）。若后续要从搜索结果触发关注，需要在这两个组件补 callback 参数。

---

## 3. 状态层（Provider）

### 3.1 `SearchState`（**全局单例**）

- **路径**：`client/lib/state/search.state.dart`
- **行数**：378
- **注册方式**：`MultiProvider` 全局单例（`client/lib/main.dart:236`，`ChangeNotifierProvider<SearchState>(create: (_) => SearchState())`）
- **服务依赖**（懒加载 `getIt()`，见 `search.state.dart:14-32`）：`SearchService` / `TopicService` / `FollowService`

#### 3.1.1 搜索结果字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `SearchTab currentTab` | `search.state.dart:35` | 当前 Tab（`SearchTab.top / users / topics / posts`） |
| `String searchQuery` | `search.state.dart:36` | 当前关键词 |
| `bool isSearching` | `search.state.dart:37` | 首屏 loading 标记（`_performSearch` 期间为 true） |
| `bool isLoadingMore` | `search.state.dart:38` | 加载下一页 |
| `int currentPage` | `search.state.dart:39` | 当前页码（从 1 开始） |
| `static const int pageSize = 20` | `search.state.dart:40` | 每页大小 |
| `String sortOrder` | `search.state.dart:41` | `'top'` 或 `'recent'` |
| `List<UserModel> searchUsers` | `search.state.dart:42` | 用户列表 |
| `List<SearchPostItem> searchPosts` | `search.state.dart:43` | 帖子列表 |
| `List<TrendingTopic> searchTopics` | `search.state.dart:44` | 话题列表 |
| `int totalUsers / totalPosts / totalTopics` | `search.state.dart:45-47` | 总数（用于 `hasMoreXxx` 判定） |
| `bool get hasMoreUsers / Posts / Topics` | `search.state.dart:49-51` | 已加载数 vs 总数 |

#### 3.1.2 空态字段

| 字段 | 行号 | 用途 |
| --- | --- | --- |
| `List<SearchHistoryItem> searchHistory` | `search.state.dart:54` | 搜索历史 |
| `int searchHistoryTotal` | `search.state.dart:55` | 历史总数 |
| `List<TrendingTopic> hotTopics` | `search.state.dart:56` | 热门话题 |
| `List<SearchPostItem> trendingPosts` | `search.state.dart:57` | 趋势帖 |
| `bool isLoadingEmptyState` | `search.state.dart:58` | 空态首屏 loading |

#### 3.1.3 关键方法

| 方法 | 行号 | 用途 |
| --- | --- | --- |
| `loadEmptyStateData()` | `search.state.dart:79-101` | 并发拉取 `getSearchHistory / getHotTopics / getTrendingPosts`；完成后后台 `_enrichFollowStatus(hotTopics)` 补全话题关注状态 |
| `_enrichFollowStatus(topics)` | `search.state.dart:104-136` | 通过 `topicService.getTopics(page:1, size:100)` 反查每个热门话题的关注态，更新 `TrendingTopic.isFollowing`（避免热门话题 Follow 按钮显示态不准） |
| `onSearchChanged(query)` | `search.state.dart:138-154` | 400ms debounce → `_performSearch()`；清空时复位 3 个列表并 `loadEmptyStateData()` |
| `changeTab(tab)` | `search.state.dart:156-165` | 切换 Tab 时 `currentPage = 1` + 重新 `_performSearch()`（searchQuery 非空时） |
| `_performSearch()` | `search.state.dart:167-201` | 按 `currentTab` 转 `searchType` → `searchService.search(...)`；后台并行 `_enrichFollowStatus(searchTopics)` + `_enrichUserFollowStatus(searchUsers)` |
| `loadMore()` | `search.state.dart:204-248` | 按 Tab 判定 `hasMoreXxx`；`currentPage++` → `searchService.search(page: currentPage)`；结果 append |
| `_mapUsers(infos)` | `search.state.dart:250-261` | `UserInfo` → `UserModel` 映射 |
| `_enrichUserFollowStatus(users)` | `search.state.dart:264-288` | 通过 `followService.getFollowStats(userId)` 并发批量查询每个搜索用户的关注态，更新 `UserModel.isFollowing` |
| `_tabToSearchType(tab)` | `search.state.dart:290-297` | top=1 / users=2 / topics=3 / posts=4（与服务端约定） |
| `changeSortOrder(sort)` | `search.state.dart:299-305` | 切换 sort，非空时立即 `_performSearch()` |
| `loadSearchHistory()` | `search.state.dart:309-316` | 仅刷新历史列表（不刷其他空态数据） |
| `deleteHistoryItem(id)` | `search.state.dart:318-324` | 服务端 `deleteSearchHistoryItem` + 本地过滤 |
| `clearSearchHistory()` | `search.state.dart:326-332` | 服务端 `clearSearchHistory` + 本地清空 |

#### 3.1.4 @-mention 兼容（客户端过滤）

- `getDataFromDatabase()`（`search.state.dart:336-355`）— 由 `ComposePostState.onDescriptionChanged`（`compose.state.dart:42`）触发，拉 `keyword=''` 的搜索作为 @ 备选池。
- `filterByUsername(name)` / `getuserDetail(userIds)`（`search.state.dart:357-377`）— 客户端按 username 模糊过滤 / 按 ID 取详情，**与搜索主流程解耦**。

---

## 4. 服务层（API）

### 4.1 `SearchService`

- **路径**：`client/lib/services/search_service.dart`
- **行数**：264
- **依赖**：`ApiClient`（构造函数注入）
- **关键方法**：

| 方法 | 行号 | 用途 |
| --- | --- | --- |
| `search({keyword, searchType, sort, page, limit})` | `search_service.dart:11` | 主搜索接口；`search_type` 1=top / 2=users / 3=topics / 4=posts |
| `searchMentionUsers(keyword, {limit})` | `search_service.dart:39` | @mention 专用，单独传 `type=2&include_private=1`；**仅返回用户列表** |
| `getSearchHistory({limit = 10})` | `search_service.dart:56` | 兼容 `data` 为 `{items, total}` 或直接是 list 两种格式 |
| `clearSearchHistory()` | `search_service.dart:78` | `DELETE search/history` |
| `deleteSearchHistoryItem(historyId)` | `search_service.dart:86` | `DELETE search/history/{id}` |
| `getHotTopics({limit = 10})` | `search_service.dart:94` | `GET search/hot-topics` |
| `getTrendingPosts({limit = 10})` | `search_service.dart:109` | `GET search/trending` |

### 4.2 数据模型（均在 `search_service.dart` 内定义）

| 模型 | 行号 | 关键字段 |
| --- | --- | --- |
| `SearchResult` | `search_service.dart:125` | `keyword` / `users: List<UserInfo>` / `posts: List<SearchPostItem>` / `topics: List<TrendingTopic>` / `totalUsers / totalPosts / totalTopics` |
| `SearchPostItem` | `search_service.dart:157` | `id` / `userId` / `username` / `displayName` / `avatarUrl` / `content` / `mediaCount` / `likesCount` / `repliesCount` / `createTime` |
| `SearchHistoryItem` | `search_service.dart:198` | `id`（String） / `query` / `searchType` / `resultCount` / `searchedAt` |
| `SearchHistoryResponse` | `search_service.dart:226` | `items` / `total` |
| `TrendingTopic` | `search_service.dart:243` | `id`（String） / `name` / `postsCount` / `isFollowing` |

> `UserInfo` 在 `client/lib/services/user_service.dart` 内定义，被 `SearchResult.users` 复用。

---

## 5. 入口集成点（页面路由）

### 5.1 底部导航栏 Tab 1（搜索）

- **路径**：`client/lib/pages/home.dart`
- **关键行**：
  - 挂载页面：`_pages[1] = SearchPage()`（`home.dart:36`）
  - 切换：走通用 `_switchTab`（`home.dart:73-83`，不拦截）
  - 底部图标：`_tabBarItem(tabIndex: 1, icon: Iconsax.search_normal, ..., isActive: tab == 1)`（`home.dart:131`）
  - 初始数据：`HomePage.initState` → `addPostFrameCallback` 触发 `initPosts / initProfile / initNotifications`（`home.dart:45-49`），**但 `initSearch` 不在此**；`SearchPage.initState` 通过 `addPostFrameCallback` 自调 `state.loadEmptyStateData()`（`search.dart:31-34`）

### 5.2 跳转目标

| 跳转 | 触发位置 | 目标 |
| --- | --- | --- |
| **他人 Profile** | `UserCard.onTap`（`user_card.dart:20-25`） / `UserTilePage` 头像 + 文本 onTap（`list.dart:35-40, 75-80`） | `ProfilePage.getRoute(profileId, username)` |
| **话题详情** | `TopicTile._navigateToDetail`（`topic_tile.dart:55-69`，`onTap != null` 时优先调 `onTap`） | `TopicDetailPage.getRoute(topicId, topicName)` |
| **趋势话题 → 填入搜索框** | `_buildEmptyState` 中 `TopicTile.onTap`（`search.dart:440-443`） | `_textController.text = t.name; state.onSearchChanged(t.name)` |
| **历史项 → 填入搜索框** | `_buildHistoryItem` 整体 onTap（`search.dart:516-520`） | 同上 |
| **Top Tab「See all topics」** | `_buildSeeAllButton` onTap（`search.dart:296-298`） | `_tabController.animateTo(2)`（跳到 Topics Tab） |

> `SearchPostTile` 当前未挂 `onTap`（`search_post_tile.dart:16`），点击搜索结果帖不跳转——若需要跳帖子详情，需要补 callback。

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **搜索页文案 key**：

| key | 用途 | 行号（en.arb） |
| --- | --- | --- |
| `search` | 搜索框 hint | — |
| `searchTitle` | AppBar 标题 | `app_en.arb:95` |
| `tabTop` / `tabUsers` / `tabTopics` / `tabPosts` | 4 个 Tab 标签 | `app_en.arb:?`（见 grep） |
| `sortTop` / `sortRecent` | 排序切换 | — |
| `sectionUsers` / `sectionTopics` / `sectionPosts` | Top Tab 区块标题 | `app_en.arb:100-102` |
| `seeAllTopics` | 「See all topics」按钮 | `app_en.arb:71` |
| `noResultsFound` | 空搜索结果 | `app_en.arb:65` |
| `recent` | 「Recent」历史标题 | — |
| `clearAll` | 清空历史 | — |
| `trendingTopics` / `trendingPosts` | 空态区块标题 | `app_en.arb:68-69` |
| `justNow` / `minutesAgo` / `hoursAgo` / `daysAgo` | 历史时间格式化 | — |

复用其他模块的 key：`followers` / `following` / `follow`（在 `UserCard` / `UserTilePage` / `TopicTile` 内）。

---

## 7. 主题 / 颜色

所有色值通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取（入口 `client/lib/theme/app_colors.dart`）。

| 字段 | 用途 | 关键位置 |
| --- | --- | --- |
| `background` | Scaffold / AppBar 背景、Sort chip 高亮态字色、UserCard/TopicTile 按钮字色 | `search.dart:67, 70, 199, 135（user_card）/ 153（topic_tile）` |
| `surface` | 搜索框 fillColor、Avatar 占位、Loading 转圈、TopicTile icon 背景 | `search.dart:129, 95（search_post_tile）/ 116（topic_tile）` |
| `surfaceSecondary` | UserCard 头像占位 | `user_card.dart:45, 59` |
| `textPrimary` | AppBar 标题、TabBar 选中、icon、displayName、UserCard / UserTilePage 文本 / 按钮底色 | `search.dart:75, 165, 188, 318` |
| `textSecondary` | TabBar 未选中、icon、username、content、Loading 转圈 | `search.dart:166, 254, 320` |
| `textMuted` | @username、统计数字、空态提示图标 + 文案、Like / Reply 图标、`@username`、时间戳 | `search.dart:44, 67, 75, 326, 405, 409, 541, 555` |
| `divider` | Users / Topics / Posts Tab 列表分隔线 | `search.dart:357, 373, 389` |
| `destructive` | 搜索历史右滑删除背景 | `search.dart:512` |

---

## 8. 关联清单

| 关联模块 | 清单 |
| --- | --- |
| 首页整体框架（底部导航 + 5 Tab） | [`home-page.md`](home-page.md) |
| 个人中心（搜索结果点击用户跳转目标） | [`profile-page.md`](profile-page.md) |
| 发布帖子（@-mention 复用 `SearchState.getDataFromDatabase`） | [`publish-post.md`](publish-post.md) |
| 单条帖子卡片 `FeedPostWidget`（搜索帖独立渲染 `SearchPostTile`，不复用 FeedPostWidget） | [`feed-post-widget.md`](feed-post-widget.md) |

---

## 9. 设计要点

### 9.1 常驻不销毁 + 自触发加载

`SearchPage` 挂在 `IndexedStack` 中，切换 Tab 不销毁重建——`_tabController` / `_scrollController` / `_textController` 全部保留。代价是首屏数据需要由 `SearchPage.initState` 内的 `addPostFrameCallback` 显式触发 `state.loadEmptyStateData()`，与 `FeedPage` 的设计一致。

### 9.2 输入与触发解耦（400ms debounce）

`TextField.onChanged` 直接调 `state.onSearchChanged(value)`——后者在 `SearchState` 内做 400ms debounce，连续输入时不重复发请求。清空输入框时立即复位 3 个列表并触发 `loadEmptyStateData()` 还原空态。

### 9.3 Top Tab 的「混排预览」策略

`_buildTopTab` 不复用 UserCard 以外的列表组件，而是按 `用户（横滑）→ 话题（前 3 + See all）→ 帖子（前 5）` 的顺序拼装混合视图。这是搜索结果的「聚合总览」语义，与 Users / Topics / Posts 单 Tab 的纯列表不同。

### 9.4 关注态后台补全

搜索主流程返回的数据不带精确的 `isFollowing`（避免单接口冗余），`SearchState` 通过两类后台查询补全：
- **话题**：`_enrichFollowStatus` 调 `topicService.getTopics(page:1, size:100)`，批量反查关注态
- **用户**：`_enrichUserFollowStatus` 并发调 `followService.getFollowStats(userId)`，单条逐个查

补全完成后 `notifyListeners()` 触发局部重建，**不阻塞首屏渲染**。

### 9.5 单一 `ScrollController` 复用

`_scrollController` 在 4 个 Tab 的列表间共用（每个 Tab 内 `controller: _scrollController`），同时 `_onScroll` 内通过 `state.loadMore()` 配合当前 `_tabController.index` 对应的 `hasMoreXxx` 判定。切换 Tab 时**不重置**滚动位置——返回 Top Tab 时仍保留离开时的滚动 offset（视使用场景决定是否合理）。

### 9.6 搜索历史 = 服务端持久化

历史项保存在服务端（`search/history`），不存本地——这意味着切换设备登录会同步历史（取决于是否走相同用户体系）。本地只做「点击 / 右滑删除」的瞬时交互。

---

## 10. 快速检索指引

| 需求 | 检索关键词 | 关键位置 |
| --- | --- | --- |
| 修改搜索页整体布局 | `SearchPage` / `_SearchPageState` / `build` | `client/lib/pages/search/search.dart:64-97` |
| 修改搜索框 | `_buildSearchField` / `TextField` | `search.dart:101-143` |
| 修改排序切换 | `_sortChip` / `_buildTabBar` | `search.dart:147-206` |
| 修改 4 个 Tab 的内容 | `_buildTopTab / UsersTab / TopicsTab / PostsTab` | `search.dart:260-397` |
| 修改空态（历史 / 热门 / 趋势） | `_buildEmptyState` / `_buildHistoryItem` | `search.dart:418-567` |
| 修改 Top Tab「See all」行为 | `_buildSeeAllButton` | `search.dart:296-298, 333-348` |
| 修改搜索 API 请求 | `SearchService.search` | `client/lib/services/search_service.dart:11` |
| 修改搜索结果模型字段 | `SearchResult` / `SearchPostItem` / `TrendingTopic` | `client/lib/services/search_service.dart:125, 157, 243` |
| 修改搜索历史交互（删 / 清空） | `deleteHistoryItem` / `clearSearchHistory` | `search.state.dart:318-332` |
| 修改关注态补全逻辑 | `_enrichFollowStatus` / `_enrichUserFollowStatus` | `search.state.dart:104-136, 264-288` |
| 修改搜索页跳转到他人 Profile | `UserCard.onTap` / `UserTilePage` onTap | `client/lib/widget/user_card.dart:20-25` + `client/lib/widget/list.dart:35-40, 75-80` |
| 修改搜索结果帖卡片 | `SearchPostTile` | `client/lib/widget/search_post_tile.dart` |
| 修改 @-mention 客户端过滤 | `getDataFromDatabase` / `filterByUsername` | `search.state.dart:336-377` + `client/lib/state/compose.state.dart:42` |
| 添加 / 修改文案 | l10n key | `client/lib/l10n/app_en.arb` + `app_zh.arb` |

---

_最后更新：2026-07-15 — 由 Claude 自动化梳理（基于代码静态分析）。_