# 首页（Home Page）— 代码定位

> 本文档汇总 iOS 客户端「首页」（含底部导航栏 + 5 个常驻 Tab）的所有源代码位置，包括主页面、各 Tab 子页、底部 Tab Bar、状态初始化以及登录后的跳转入口。
> 后续若收到「定位首页 / 底部导航 / 某个 Tab」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 首页主框架 `HomePage`

- **路径**：`client/lib/pages/home.dart`
- **行数**：170
- **核心组件**：
  - `class HomePage extends StatefulWidget`（`home.dart:17`）— 顶层 Scaffold 容器
  - `class _HomePageState extends State<HomePage> with TickerProviderStateMixin`（`home.dart:24`）— 主状态类
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | ComposePost 引用 | `_composePostKey = GlobalKey<ComposePostState>()` | `home.dart:25` |
  | Tab 页面常量列表 | `_pages`（5 个 Tab 页面，FeedPage / SearchPage / ComposePost / NotificationPage / MyProfilePage） | `home.dart:27, 32-42` |
  | 生命周期 | `initState`（首帧后初始化 Posts / Profile / Notifications） / `dispose` | `home.dart:30-53` |
  | 状态初始化 | `initProfile()` / `initPosts()` / `initNotifications()` | `home.dart:55-69` |
  | Tab 切换拦截（含草稿确认） | `_switchTab(int targetTab)` | `home.dart:71-81` |
  | Tab Bar 单项构建 | `_tabBarItem({tabIndex, icon, appColors, isActive, badge})` | `home.dart:87-115` |
  | 底部导航栏 | `bottomNavBar()` | `home.dart:117-154` |
  | 当前 Tab 索引 | `int tab = 0` | `home.dart:156` |
  | 渲染 | `build`（`Scaffold` + `IndexedStack` 常驻 5 页） | `home.dart:158-169` |
  | 图标尺寸常量 | `_iconSize = 30.0` | `home.dart:85` |

### 1.2 5 个常驻 Tab 页面（IndexedStack children）

| Tab 索引 | 页面 | 路径 | 说明 |
| --- | --- | --- | --- |
| 0 | `FeedPage` | `client/lib/pages/feed/feed.dart` | Feed 流（帖子列表 + 滚动加载 + 顶部 Community / Message 入口） |
| 1 | `SearchPage` | `client/lib/pages/search/search.dart` | 搜索页 |
| 2 | `ComposePost` | `client/lib/pages/composePost/post.dart` | 发帖页（含编辑模式）；离开发帖 Tab 时由 `_switchTab` 触发 `handleTabSwitch` 草稿确认 |
| 3 | `NotificationPage` | `client/lib/pages/notification/notification.dart` | 通知列表；底部 Tab Bar 红点来自 `NotificationState.unreadCount` |
| 4 | `MyProfilePage` | `client/lib/pages/profile/myprofile.dart` | 个人中心（本地创建 `ProfileState`） |

> 详见「2. Tab 子页代码定位」一节。

---

## 2. Tab 子页代码定位

### 2.1 Feed（Tab 0）

- **页面**：`client/lib/pages/feed/feed.dart`
- **核心组件**：`class FeedPage`（`feed.dart:16`）+ `_FeedPageState`（`feed.dart:23`）
- **关键能力**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 滚动控制器 | `_scrollController` / `_onScroll`（接近底部自动 `PostState.loadMore()`） / `_scrollToTop` | `feed.dart:24-49` |
  | 跳转发帖 | `Navigator.push(... builder: (_) => ComposePost(...))` | `feed.dart:215-227` |
  | 帖子卡片组件 | `FeedPostWidget`（在 `client/lib/widget/feedpost.dart`） | — |
  | 顶部按钮 | 进入 `community_list_page.dart` / `message_page.dart` | `feed.dart:8-9` |
- **配套文件**：
  - 帖子详情页：`client/lib/pages/post/post_detail_page.dart`
  - 已保存 / 已调度：`client/lib/pages/post/saved_posts_page.dart` / `scheduled_posts_page.dart`
  - 媒体查看器：`client/lib/pages/media/media_viewer_page.dart`

### 2.2 Search（Tab 1）

- **页面**：`client/lib/pages/search/search.dart`
- **职责**：关键词搜索用户 / 话题 / 帖子等。
- **配套**：`client/lib/pages/topic/topic_detail_page.dart`（话题详情）

### 2.3 ComposePost（Tab 2）

- **页面**：`client/lib/pages/composePost/post.dart`
- **行数**：1667
- **核心组件**：`class ComposePost`（`post.dart:23`）+ `class ComposePostState`（`post.dart:48`）
- **关键能力**：
  | 模块 | 行号 |
  | --- | --- |
  | 媒体草稿管理（增 / 删 / 替换） | `post.dart:239-264` |
  | 投票编辑器 | `post.dart:266-301` |
  | 相册选择（图片 / GIF / 视频） | `post.dart:305-403` |
  | 媒体选择底部 sheet | `post.dart:406-467` |
  | 草稿加载 / 保存 / 列表弹层 | `post.dart:510-684` |
  | 提交发布（区分新建 / 编辑） | `post.dart:688-798` |
  | 位置 / 定时 / 回复权限 / 敏感内容 | `post.dart:802-998` |
- **Tab 切换拦截钩子**：
  - `_HomePageState._switchTab` → `_composePostKey.currentState?.handleTabSwitch(...)`（`home.dart:71-81`）
  - `ComposePostState.handleTabSwitch`（`post.dart:170-202`）— 弹出草稿保存确认对话框
- **相机入口**：`_openCamera` → `ComposeCameraPage`（`client/lib/pages/composePost/compose_camera_page.dart`，669 行）

> 完整定位参考 [`docs/code-locations/publish-post.md`](publish-post.md)。

### 2.4 Notification（Tab 3）

- **页面**：`client/lib/pages/notification/notification.dart`
- **核心组件**：`class NotificationPage` + 通知列表
- **关键能力**：
  - 首屏数据：`NotificationState.loadNotifications()` + `fetchUnreadCount()`（`home.dart:65-69`）
  - 底部 Tab 红点：`Consumer<NotificationState>` 监听 `state.unreadCount > 0`（`home.dart:128-151`）

### 2.5 MyProfile（Tab 4）

- **页面**：`client/lib/pages/profile/myprofile.dart`
- **核心组件**：`class MyProfilePage` + **本地创建** `ProfileState`（`ProfileState` 非全局单例）
- **关键能力**：
  - 首屏数据：`AuthState.getProfileUser()`（`home.dart:55-58`）
  - 跳转编辑：`client/lib/pages/profile/edit.dart`
  - 分享 Profile：`client/lib/pages/profile/share_profile_sheet.dart`

---

## 3. 底部导航栏（Bottom Navigation Bar）

- **路径**：`client/lib/pages/home.dart`
- **关键行**：
  | 能力 | 行号 |
  | --- | --- |
  | 整体 Container + Row 布局 | `home.dart:117-124` |
  | Tab 0（首页 Feed）图标 `Iconsax.home` | `home.dart:125` |
  | Tab 1（搜索）图标 `Iconsax.search_normal` | `home.dart:126` |
  | Tab 2（发帖）图标 `Iconsax.edit` | `home.dart:127` |
  | Tab 3（通知）图标 `Iconsax.heart` + 红点 badge | `home.dart:128-151` |
  | Tab 4（个人中心）图标 `CupertinoIcons.person` | `home.dart:152` |
- **单项模板**：`_tabBarItem`（`home.dart:87-115`）— `Expanded` + `GestureDetector`（`HitTestBehavior.opaque`，整行可点）+ `SizedBox(height: 70)` + 居中 `Icon(size: 30)`
- **激活色**：`appColors.textPrimary` / 非激活 `appColors.textSecondary`（`home.dart:107`）
- **红点 badge**：`Positioned(right: 0, top: 8)` 的 8x8 圆点，色 `appColors.accent`（`home.dart:136-148`）

---

## 4. 状态层（Provider）

| 状态 | 路径 | 注册方式 | 触发位置 |
| --- | --- | --- | --- |
| `AuthState` | `client/lib/state/auth.state.dart` | 全局单例 | `initProfile()` → `getProfileUser()`（`home.dart:55-58`） |
| `PostState` | `client/lib/state/post.state.dart` | 全局单例 | `initPosts()` → `getDataFromDatabase()`（`home.dart:60-63`） |
| `NotificationState` | `client/lib/state/notification.state.dart` | 全局单例 | `initNotifications()` → `loadNotifications()` + `fetchUnreadCount()`（`home.dart:65-69`） |
| `SearchState` | `client/lib/state/search.state.dart` | 全局单例 | 由 `SearchPage` 内部使用 |
| `DraftState` | `client/lib/state/draft.state.dart` | 全局单例 | 由 `ComposePost` 内部使用 |
| `ProfileState` | `client/lib/state/profile_state.dart` | **本地创建**（每个 `ProfilePage` 独立实例） | 由 `MyProfilePage` 内部创建 |

> 状态初始化统一在 `HomePage.initState` 的 `WidgetsBinding.instance.addPostFrameCallback` 内调用（`home.dart:43-47`），确保 Provider 树已挂载。

---

## 5. 入口集成点（页面路由）

### 5.1 登录后的根页面

- **路径**：登录成功（`signin`）后 `Navigator.pushAndRemoveUntil` 到 `HomePage`，具体由 `client/lib/auth/signin/signin_page.dart` 等入口控制。
- **关键检索**：`Navigator.push(... HomePage(` 或 `HomePage()` 作为目标页。

### 5.2 Splash → HomePage 跳转

- **路径**：`client/lib/pages/splash.dart` 或 `main.dart`（依据项目实际入口）。
- **作用**：根据 token 是否存在决定跳转 `HomePage` 还是 `SignInPage`。

---

## 6. 主题 / 颜色

- 底部 Tab Bar 颜色统一通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取（`home.dart:118`）。
- 入口：`client/lib/theme/app_colors.dart`（`AppColorsExtension` + `AppColors`）。
- 常用颜色字段：`textPrimary` / `textSecondary` / `background` / `accent`（红点）。

---

## 7. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **生成代码**：`client/lib/l10n/generated/app_localizations*.dart`
- **首页 Tab Bar 无文字**：仅图标 + 红点，文案零依赖（这是 iOS Threads 风格）。

---

## 8. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改首页整体框架 | `HomePage` / `_HomePageState` | `client/lib/pages/home.dart` |
| 修改底部 Tab Bar 样式 | `bottomNavBar` / `_tabBarItem` | `client/lib/pages/home.dart:87-154` |
| 修改 Tab 切换逻辑（含草稿拦截） | `_switchTab` / `handleTabSwitch` | `client/lib/pages/home.dart:71-81` + `client/lib/pages/composePost/post.dart:170-202` |
| 修改通知红点 | `NotificationState.unreadCount` / `_tabBarItem(badge:)` | `client/lib/pages/home.dart:128-151` + `client/lib/state/notification.state.dart` |
| 修改 Tab 页面挂载顺序 | `_pages = [` | `client/lib/pages/home.dart:32-42` |
| 修改 Feed 流 | `FeedPage` / `_onScroll` / `FeedPostWidget` | `client/lib/pages/feed/feed.dart` + `client/lib/widget/feedpost.dart` |
| 修改发帖 Tab | `ComposePost` / `ComposePostState` | `client/lib/pages/composePost/post.dart`（详见 `publish-post.md`） |
| 修改个人中心 Tab | `MyProfilePage` / `ProfileState` | `client/lib/pages/profile/myprofile.dart` + `client/lib/state/profile_state.dart` |
| 修改首屏初始化数据 | `initPosts` / `initProfile` / `initNotifications` | `client/lib/pages/home.dart:55-69` |
| 修改主题颜色（Tab 文字 / 红点） | `AppColorsExtension` | `client/lib/theme/app_colors.dart` |

---

_最后更新：2026-06-15 — 由 Claude 自动化梳理（基于代码静态分析）。_