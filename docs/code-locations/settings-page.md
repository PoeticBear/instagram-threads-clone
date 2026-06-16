# 设置页面（Settings Page）— 代码定位

> 本文档汇总 iOS 客户端「设置」页面（个人中心点击设置入口进入）涉及的所有源代码位置，包括主设置页、状态层、服务层、入口集成点、所有子页（通知 / 媒体 / 隐私 / 关系控制 / 收藏 / 隐藏词 / 链接 / 关注请求）、设置页内嵌的应用图标水平选择条。
> 后续若收到「定位设置页 / 设置 / Settings」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 主设置页 `SettingsPage`

- **路径**：`client/lib/common/settings.dart`
- **行数**：548
- **核心组件**：
  - `class SettingsPage extends StatefulWidget`（`settings.dart:24`）— 设置主页
  - `class _SettingsPageState extends State<SettingsPage>`（`settings.dart:31`）— 持有 `AuthState`
- **职责**：
  1. 自定义透明 `AppBar`（`settings.dart:40-66`），标题 `l10n.settingsTitle`，左上是「返回」图标。
  2. `ListView` 渲染菜单项，每行统一通过 `_buildMenuRow(...)` 私有方法（`settings.dart:509-545`）— 图标 + 标题 + 可选右箭头。
  3. 顶部内嵌「应用图标水平选择条」（详见 1.4）。
  4. 底部固定区：主题切换（`ThemeProvider.toggleTheme`）、语言切换（`LocaleProvider.setLocale`）、退出登录（`authState.logoutCallback`）。
- **菜单项与跳转**（按从上到下顺序）：

| # | 图标 | 标题（l10n key） | 目标页面 | 行号 |
| --- | --- | --- | --- | --- |
| 1 | `person_add` | `followAndInviteFriends` | `FollowRequestsPage` | `settings.dart:166-178` |
| 2 | `bell` | `notifications` | `NotificationSettingsPage` | `settings.dart:182-194` |
| 3 | `play_rectangle` | `mediaSettings` | `MediaSettingsPage`（纯本地偏好） | `settings.dart:199-211` |
| 4 | `lock_outline` | `privacy` | `PrivacySettingsPage` | `settings.dart:216-228` |
| 5 | `person_crop_circle_badge_xmark` | `accountControls` | `RelationControlPage` | `settings.dart:232-244` |
| 6 | `bookmark` | `collections` | `CollectionsPage` | `settings.dart:248-260` |
| 7 | `bookmark_fill` | `savedPosts` | `SavedPostsPage` | `settings.dart:264-276` |
| 8 | `clock` | `scheduledPosts` | `ScheduledPostsPage` | `settings.dart:280-292` |
| 9 | `groups_outlined` | `communities` | `CommunityListPage` | `settings.dart:296-308` |
| 10 | `eye_slash` | `hiddenWords` | `HiddenWordsPage` | `settings.dart:312-324` |
| 11 | `link` | `links` | `LinksPage` | `settings.dart:328-340` |
| 12 | `help_outline` | `help` | （占位，未实现） | `settings.dart:344-352` |
| 13 | `info` | `about` | （占位，未实现） | `settings.dart:355-363` |

> 跳转统一用 `Navigator.push(..., CupertinoPageRoute(...))`，与项目 iOS 风格一致。

### 1.2 子页（按菜单项顺序）

| 子页面 | 路径 | 行数 | 备注 |
| --- | --- | --- | --- |
| `FollowRequestsPage` | `client/lib/pages/settings/follow_requests_page.dart` | 303 | 关注请求列表 |
| `NotificationSettingsPage` | `client/lib/common/settings/notification_settings.dart` | 169 | 通知偏好，绑定 `SettingsState` |
| `MediaSettingsPage` | `client/lib/common/settings/media_settings.dart` | 187 | 媒体播放偏好（**纯本地**） |
| `PrivacySettingsPage` | `client/lib/common/settings/privacy_settings.dart` | 324 | 隐私偏好，绑定 `SettingsState` |
| `RelationControlPage` | `client/lib/common/settings/relation_control_page.dart` | 295 | 静音 / 限制 / 拉黑 列表 |
| `CollectionsPage` | `client/lib/common/settings/collections_page.dart` | 334 | 收藏合集 |
| `SavedPostsPage` | `client/lib/pages/post/saved_posts_page.dart` | — | 已保存的帖子（不在 settings 目录下，属于 `pages/post/`） |
| `ScheduledPostsPage` | `client/lib/pages/post/scheduled_posts_page.dart` | — | 定时发帖（同上） |
| `CommunityListPage` | `client/lib/pages/community/community_list_page.dart` | — | 我加入的社区 |
| `HiddenWordsPage` | `client/lib/common/settings/hidden_words_page.dart` | 378 | 隐藏词管理 |
| `LinksPage` | `client/lib/common/settings/links_page.dart` | 374 | 链接管理 |

### 1.3 独立的「消息设置」页（非主设置入口）

- **路径**：`client/lib/pages/message/message_settings_page.dart`
- **行数**：216
- **核心组件**：`class MessageSettingsPage extends StatefulWidget`（`message_settings_page.dart:8`）
- **入口**：`MessagePage` 右上角点击 → `Navigator.push(... MessageSettingsPage())`（`message_page.dart:126`）
- **职责**：消息模块独立偏好（与主设置平行，不互通）

### 1.4 应用图标水平选择条（设置页内嵌）

- **位置**：`client/lib/common/settings.dart:79-163`（ListView 第一项 `SizedBox(height: 20)` 之后）
- **入口组件**：`Consumer<AppIconState>`，仅包裹此区块，不影响设置页其它部分重建
- **结构**（从上到下）：
  1. **区块标题**（`settings.dart:98-108`）：左对齐 `Padding(horizontal: 20)` + `Text(l10n.appIcon, fontSize: 13, w600, textPrimary)`，与下方水平条间隔 `SizedBox(height: 10)`。
  2. **水平选择条**（`settings.dart:110-132`）：`SizedBox(height: 88) + ListView.separated(scrollDirection: Axis.horizontal, physics: BouncingScrollPhysics(), padding: horizontal 20, itemCount: AppIconState.totalAlternates = 25, separatorBuilder: SizedBox(width: 10))`。每个 `itemBuilder` 返回 `AppIconTile(id: i+1, selected: state.selectedId == id, onTap: ...)`。
  3. **`onTap` 行为**（`settings.dart:124-128`）：
     - `if (state.selectedId == id) return;`（防御性短路，避免重复触发）
     - `HapticFeedback.selectionClick();`（触觉反馈）
     - `state.setIcon(id);`（直接调用 `AppIconState.setIcon` 切换图标，无导航）
  4. **appIconChangeHint**（`settings.dart:133-144`）：`Padding(horizontal: 20) + Text(l10n.appIconChangeHint, fontSize: 12, height: 1.3, textSecondary)`。
  5. **appIconPrimaryHint**（`settings.dart:145-158`，**条件渲染**）：仅当 `state.selectedId == 0`（使用 primary 默认图标）时显示。同上样式 + `SizedBox(height: 4)` 分隔。
  6. **区块底部**：`SizedBox(height: 20)` 与下方第一菜单行衔接。
- **未支持分支**（`settings.dart:82-94`，防御性）：当 `!state.platformSupported`（Android）时，简化为只显示 `l10n.appIconNotSupportedAndroid` 文本。遵循 `CLAUDE.md` 的 iOS-only 策略，理论不可达。

### 1.5 应用图标缩略图组件 `AppIconTile`

- **路径**：`client/lib/widget/app_icon_tile.dart`
- **行数**：~90
- **核心组件**：`class AppIconTile extends StatelessWidget`（`app_icon_tile.dart:12`）
- **字段**：
  | 字段 | 类型 | 说明 | 行号 |
  | --- | --- | --- | --- |
  | `id` | `int` | 1..25，对应 `assets/logos/logo_NN.JPG` | `app_icon_tile.dart:15` |
  | `selected` | `bool` | 是否选中 | `app_icon_tile.dart:16` |
  | `onTap` | `VoidCallback?` | 点击回调 | `app_icon_tile.dart:17` |
- **视觉规格**：
  - 缩略图：56×56，`BorderRadius.circular(12)`，`Image.asset(fit: cover)` 带 `errorBuilder` 兜底
  - 选中边框：`Border.all(color: appColors.accent, width: 2)`
  - 选中勾：18×18 圆形 + `CupertinoIcons.check_mark` size 12，位于 `bottom: 4, right: 4`
  - 标签（id 数字）：缩略图下方 4px 间距 / 12px / 未选 `textSecondary w400` / 选中 `textPrimary w600`
  - 包裹 `Semantics(button: true, label: 'App icon $id', selected: selected)` 支持 VoiceOver
- **复用点**：任何需要展示「可选应用图标」列表的场景（设置页当前唯一消费者；未来 onboarding / profile 主题页可复用）

---

## 2. 状态层（Provider）

### 2.1 `SettingsState`（全局单例）

- **路径**：`client/lib/state/settings.state.dart`
- **行数**：95
- **核心组件**：`class SettingsState extends ChangeNotifier`（`settings.state.dart:5`）
- **字段**：
  | 字段 | 类型 | 说明 | 行号 |
  | --- | --- | --- | --- |
  | `_settings` | `UserSettings` | 当前远端设置 | `settings.state.dart:6` |
  | `_isBusy` | `bool` | 加载中标记 | `settings.state.dart:9` |
  | `_userService` | `UserService?` | 懒注入的服务（`getIt`） | `settings.state.dart:12` |
- **方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `loadSettings()` | 拉取远端 `UserSettings`，失败仅置 `isBusy=false` 不抛 | `settings.state.dart:18-29` |
  | `updateSetting(key, value)` | 乐观更新 → 调 `userService.updateSettings` → 失败回滚（`loadSettings`） | `settings.state.dart:31-43` |
  | `_copyWithKey(key, value)` | switch 分发到 22 个具体字段（reply / mention / notify / privacy / silent / content_rating 等） | `settings.state.dart:45-94` |
- **注册位置**：`client/lib/main.dart:92` — `ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()..loadSettings())`，全局单例，应用启动即拉一次配置。
- **消费方**：`PrivacySettingsPage`（`privacy_settings.dart:33`）、`NotificationSettingsPage`（`notification_settings.dart:33`）用 `Consumer<SettingsState>` 绑定。

### 2.2 `AppIconState`（全局单例）

- **路径**：`client/lib/state/app_icon_state.dart`
- **行数**：75
- **核心组件**：`class AppIconState extends ChangeNotifier`（`app_icon_state.dart:12`）
- **字段**：
  | 字段 | 类型 | 说明 | 行号 |
  | --- | --- | --- | --- |
  | `_selectedId` | `int` | 当前选中 id（0=primary，1..25=alternate） | `app_icon_state.dart:18` |
  | `_platformSupported` | `bool` | 是否支持运行时切换图标（iOS=true，Android=false） | `app_icon_state.dart:19` |
  | `_loaded` | `bool` | 状态是否已加载 | `app_icon_state.dart:20` |
  | `_prefs` | `SharedPreferences` | 持久化偏好 | `app_icon_state.dart:16` |
- **方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `load()` | 同步读 SharedPreferences → 异步校正 iOS 端实际状态 → `notifyListeners()` | `app_icon_state.dart:33-58` |
  | `setIcon(int id)` | 调 `AppIconService.setAlternateIconName` → 持久化 → `notifyListeners()`（短路 `id == _selectedId`） | `app_icon_state.dart:61-73` |
- **注册位置**：`client/lib/main.dart:104-107` — `ChangeNotifierProvider<AppIconState>(create: (_) => AppIconState(widget.sharedPreferences)..load(), lazy: false)`
- **消费方**：设置页水平条 `Consumer<AppIconState>`（`settings.dart:80`）

### 2.3 数据模型 `UserSettings`

- **路径**：`client/lib/services/user_service.dart`
- **核心**：`class UserSettings`（`user_service.dart:250`）— 字段定义、`fromJson`（`user_service.dart:308`）、`copyWith`（`user_service.dart:360`）均在同一文件。

---

## 3. 服务层（API）

### 3.1 `UserService`（设置读写）

- **路径**：`client/lib/services/user_service.dart`
- **关键方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `getSettings()` | GET `user/settings`，返回 `UserSettings` | `user_service.dart:53-56` |
  | `updateSettings(UserSettings)` | PUT/POST `user/settings` | `user_service.dart:62` |

> `UserSettings` 与 `UserService` 合并在同一文件，按功能内聚。

### 3.2 `AppIconService`（应用图标切换）

- **路径**：`client/lib/services/app_icon_service.dart`
- **行数**：60
- **核心组件**：`class AppIconService`（全部 `static` 方法）
- **关键方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `supportsAlternateIcons()` | 当前平台是否支持运行时切换 | `app_icon_service.dart:16-24` |
  | `getAlternateIconName()` | 获取当前 alternate 名称（primary 时返回 null） | `app_icon_service.dart:27-35` |
  | `setAlternateIconName(String?)` | 切换图标，失败抛 `AppIconException` | `app_icon_service.dart:44-52` |
- **MethodChannel**：`com.yt.threads/app_icon`（`app_icon_service.dart:9`）

> 详细平台支持矩阵、状态恢复机制、包体积影响等约束见 `docs/code-locations/app-icon.md`。

---

## 4. 入口集成点

| 入口 | 文件 | 行号 | 说明 |
| --- | --- | --- | --- |
| 主入口 | `client/lib/pages/profile/profile.dart` | `profile.dart:184` | 在 `ProfilePage` 的 AppBar 右上角（仅 `isOwnProfileTab == true` 时显示）`Navigator.push(... SettingsPage())` |
| 全局 Provider 注册（Settings） | `client/lib/main.dart` | `main.dart:92` | `ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()..loadSettings())` |
| 全局 Provider 注册（AppIcon） | `client/lib/main.dart` | `main.dart:104-107` | `ChangeNotifierProvider<AppIconState>(create: (_) => AppIconState(widget.sharedPreferences)..load(), lazy: false)` |

---

## 5. 关键设计要点

- **菜单项集中声明**：所有菜单项都在 `settings.dart` 单文件 `ListView` 里集中维护，没有用路由表 / 配置中心，新增菜单项需要修改 `_buildMenuRow` 调用列表 + 提供 l10n key。
- **跳转风格**：所有子页跳转统一用 `CupertinoPageRoute`（iOS 风格右滑返回），与项目规范一致。
- **国际化**：菜单标题全部走 `AppLocalizations`（`l10n.settingsTitle`、`l10n.followAndInviteFriends` 等），禁止硬编码。
- **颜色**：`appColors = Theme.of(context).extension<AppColorsExtension>()!.colors`，未直接读 `Theme.of` 的颜色。
- **登录态依赖**：退出登录按钮直接调用 `authState.logoutCallback()`，不弹确认框；用户操作需谨慎（应在调用前确认）。
- **媒体偏好特殊**：Media 设置页用本地 `MediaPreferencesState` / `MediaLayoutPreferencesState`，**不**经 `SettingsState`，所以媒体设置改动不同步到服务端。
- **应用图标选择条就地化**：自 2026-06-16 起，原本的独立 `AppIconPage`（已删除）被替换为设置页顶部内嵌的水平选择条（详见 1.4）。直接调用 `AppIconState.setIcon` 完成切换，无导航。
- **局部 `Consumer`**：`AppIconState` 的 Consumer 仅包裹水平条区块（`settings.dart:80`），与 `ThemeProvider` / `LocaleProvider` 的局部包裹模式一致，避免每次切换图标都重建整页。

---

## 6. 复用 & 扩展点

- 新增菜单项：仿照 `settings.dart` 已有的 `_buildMenuRow` 调用模板，加一行 → 准备 l10n key → 新建目标页面 → push 进去。
- 新增「需同步到服务端」的设置项：扩展 `UserSettings`（`user_service.dart:250`）字段 → `SettingsState._copyWithKey` 加一个 `case` 分支 → 子页 `Consumer<SettingsState>` 调 `updateSetting('new_key', value)`。
- 退出登录扩展：直接调用 `authState.logoutCallback()` 入口，可在此加确认弹窗或埋点，**无需**改 `AuthState`。
- **新增应用图标缩略图消费场景**：`AppIconTile` 已抽取为公开 widget，可直接在任何页面复用（如 onboarding 选图、profile 主题设置）。

---

_文档最后更新：2026-06-16（应用图标水平选择条迁移）_