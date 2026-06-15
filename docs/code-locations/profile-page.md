# 个人中心（Profile Page）— 代码定位

> 本文档汇总 iOS 客户端「个人中心」页面（底部导航栏第 5 个 Tab）涉及的所有源代码位置，包括主页面、编辑页、分享面板、状态层、服务层、入口集成点、相关跳转子页。
> 后续若收到「定位个人中心 / Profile / 我的资料」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 入口包装 `MyProfilePage`

- **路径**：`client/lib/pages/profile/myprofile.dart`
- **行数**：46
- **核心组件**：`class MyProfilePage extends StatelessWidget`（`myprofile.dart:8`）
- **职责**：作为底部 Tab 4 的入口，**不承载业务 UI**，仅负责：
  1. 用 `Selector<AuthState, String>` 跟踪 `auth.userId`（`myprofile.dart:20-21`）— userId 真正变化（登录恢复 / 登出换号）时触发重建。
  2. 未拿到 userId 时显示 `CupertinoActivityIndicator` 占位（`myprofile.dart:26-29`）。
  3. 用 `ValueKey(profileId)` + `ChangeNotifierProvider` **本地创建** `ProfileState`（`myprofile.dart:32-37`）— 不是全局单例，每次切到 Tab 4 不会保留旧实例。
  4. 把当前登录用户的 ID 显式传给 `ProfileState(profileId, currentUserId: profileId)`（`myprofile.dart:37`），让 `isMyProfile` 用 `AuthState.userId` 作为权威来源（修复首次打开显示"关注"按钮的 bug）。
  5. 渲染真正的 `ProfilePage`（`myprofile.dart:38-41`），并标记 `isOwnProfileTab: true`。

### 1.2 主个人页 `ProfilePage`

- **路径**：`client/lib/pages/profile/profile.dart`
- **行数**：912
- **核心组件**：
  - `class ProfilePage extends StatefulWidget`（`profile.dart:25`）— 同时被「自己 Tab」和「他人 Profile 入口」复用
  - `class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin`（`profile.dart:69`）
  - 静态工厂 `ProfilePage.getRoute({profileId, username})`（`profile.dart:37-63`）— 供 `Navigator.push` 进入他人 profile 时使用，自带 `ChangeNotifierProvider` + `FadeTransition`
- **字段**：
  | 字段 | 说明 | 行号 |
  | --- | --- | --- |
  | `profileId` | 要展示的 userId（String，组件内部 `int.tryParse` 转 int） | `profile.dart:33` |
  | `username` | 外部传入的 username 兜底（profile 接口不返回 username 时） | `profile.dart:34` |
  | `isOwnProfileTab` | 是否为底部 Tab 4 入口（true 时不显示返回按钮、显示设置入口） | `profile.dart:35` |
  | `_tabController` | 顶部 Threads / Media Tab 切换 | `profile.dart:71, 78` |
  | `_userPosts` / `_isLoadingPosts` | 用户帖子本地缓存 | `profile.dart:72-73` |
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 生命周期 | `initState`（创建 `TabController` + `_loadUserPosts`）/ `dispose` | `profile.dart:76-80, 158-161` |
  | 帖子加载 | `_loadUserPosts()` — `PostState.getUserPosts(userId)` | `profile.dart:82-94` |
  | 下拉刷新 | `_refreshAll()`（`ProfileState.refresh` + 重载帖子 + 自己的 Tab 时刷 AuthState） | `profile.dart:96-109` |
  | 分享 Profile | `_shareProfile(state)` — 弹 `ShareProfileSheet` | `profile.dart:111-123` |
  | 显示名解析 | `_resolveDisplayName(state, fallbackUsername)` — displayName → userName → widget.username → '' | `profile.dart:132-140` |
  | 跳关注列表 | `_navigateToFollowList(initialTab)` — 0=粉丝 / 1=关注 | `profile.dart:142-155` |
  | Build | `build`（AppBar 透明 + 头部信息 + Bio + 信息行 + 关注数 + 操作按钮 + TabBar） | `profile.dart:164-435` |
  | Threads Tab | `_buildThreadsTab`（用户帖子列表 / `FeedPostWidget`） | `profile.dart:437-460` |
  | Media Tab | `_buildMediaTab`（3 列 Grid / `CachedNetworkImage` / 视频角标 / 点开进 `MediaViewerPage`） | `profile.dart:462-546` |
  | 头像 | `_buildAvatar`（60x60，圆形 + `CachedNetworkImage`，无图时 Icon 兜底） | `profile.dart:548-578` |
  | 关注数点击 | `_buildStatItem`（RichText 拼接数字 + 标签） | `profile.dart:580-603` |
  | 扩展信息行 | `_buildInfoRow` + `_buildInfoItem` — 位置 / 代词 / 性别 | `profile.dart:607-692` |
  | 打开外链 | `_openLink(raw)` — 自动补 `https://` + `launchUrl` + 失败 SnackBar | `profile.dart:695-728` |
  | Profile 菜单 | `_showProfileMenu` — 静音 / 限制 / 拉黑 / 举报（仅他人 profile） | `profile.dart:732-820` |
  | 关系控制 | `_handleProfileRelationControl` — `UserService.addRelationControl`（controlType: 1=静音, 2=限制, 3=拉黑） | `profile.dart:822-848` |
  | Sheet 子件 | `_buildSheetOption` / `_buildSheetDivider` | `profile.dart:850-872` |
  | 操作按钮 | `_buildActionButton`（自己：编辑 / 分享；他人：关注 / 分享；带 loading 态） | `profile.dart:874-911` |

### 1.3 编辑资料 `EditProfilePage`

- **路径**：`client/lib/pages/profile/edit.dart`
- **行数**：503
- **核心组件**：
  - `class EditProfilePage extends StatefulWidget`（`edit.dart:13`）
  - `class _EditProfilePageState extends State<EditProfilePage>`（`edit.dart:20`）
- **字段**：
  | 字段 | 说明 | 行号 |
  | --- | --- | --- |
  | `_displayName` / `_bio` / `_link` / `_pronouns` / `_location` | 5 个 `TextEditingController`，初值从 `AuthState.userModel` 取 | `edit.dart:21-25, 36-44` |
  | `_image` / `_avatarRemoved` | 新头像 / 是否清除头像 | `edit.dart:26-27` |
  | `_isSubmitting` | 提交 loading | `edit.dart:28` |
  | `_selectedGender` | 1=未设置, 2=男, 3=女, 4=其他 | `edit.dart:29` |
  | `_isPrivate` / `_accountType` | 私密账号开关 / 账号类型（1=个人, 2=创作者, 3=商家） | `edit.dart:30-31` |
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 生命周期 | `initState`（注入 AuthState 初值）/ `dispose` | `edit.dart:33-55` |
  | 选图（相册 / 相机） | `getImage(context, source, onImageSelected)` | `edit.dart:57-66` |
  | 文案辅助 | `_genderLabel` / `_accountTypeLabel` | `edit.dart:68-83` |
  | Build | `build`（AppBar + 卡片 + 5 个输入 + 头像编辑） | `edit.dart:86-244` |
  | 字段行 | `_fieldSection`（Bio / Link / Pronouns / Location） | `edit.dart:251-275` |
  | 选择器行 | `_selectorSection`（Gender / AccountType，点击弹 `CupertinoActionSheet`） | `edit.dart:277-308` |
  | 开关行 | `_toggleSection`（Private Account） | `edit.dart:310-334` |
  | 头像编辑 | `_buildAvatarEdit`（CupertinoActionSheet：相册 / 相机 / 移除） | `edit.dart:336-398` |
  | Gender 弹层 | `_showGenderPicker` | `edit.dart:400-432` |
  | AccountType 弹层 | `_showAccountTypePicker` | `edit.dart:434-462` |
  | 提交 | `_submitButton` — 校验长度（name ≤100, bio ≤500）+ `state.updateUserProfile(model, image: _image, removeAvatar: _avatarRemoved)` | `edit.dart:464-502` |

### 1.4 分享资料 `ShareProfileSheet`

- **路径**：`client/lib/pages/profile/share_profile_sheet.dart`
- **行数**：307
- **核心组件**：
  - `class ShareProfileSheet extends StatefulWidget`（`share_profile_sheet.dart:16`）
  - `class _ShareProfileSheetState extends State<ShareProfileSheet>`（`share_profile_sheet.dart:28`）
- **字段 / 派生 getter**：
  | 字段 / getter | 说明 | 行号 |
  | --- | --- | --- |
  | `_screenshotController` | `ScreenshotController`（`screenshot` 包）— 截 QR 卡片 | `share_profile_sheet.dart:29` |
  | `_isSaving` / `_toastMessage` | 保存到相册 loading / 顶部 toast | `share_profile_sheet.dart:30-31` |
  | `_qrData` | `threads://user/{userId}` | `share_profile_sheet.dart:33` |
  | `_username` / `_displayName` / `_avatarUrl` | 来自 `widget.user` | `share_profile_sheet.dart:34-36` |
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | Build | `build`（Drag handle + 头像/昵称 + QR 卡片 + 提示 + 两个按钮 + 顶部 toast） | `share_profile_sheet.dart:39-152` |
  | 用户信息行 | `_buildUserInfo`（头像 + displayName + userName） | `share_profile_sheet.dart:154-206` |
  | 操作按钮 | `_buildActionButton`（图标 + 文案 + loading 态） | `share_profile_sheet.dart:208-247` |
  | 保存到相册 | `_saveToGallery` — `ScreenshotController.capture()` + `path_provider` 写临时文件 + `Gal.putImage(..., album: 'Threads')` | `share_profile_sheet.dart:249-274` |
  | 复制链接 | `_copyLink` — `https://threads.net/@{username}` + `Clipboard.setData` | `share_profile_sheet.dart:276-280` |
  | Toast | `_showToast` / `_buildToast`（2s 自动消失） | `share_profile_sheet.dart:282-306` |

---

## 2. 入口集成点（页面路由）

### 2.1 底部导航栏 Tab 4（个人中心）

- **路径**：`client/lib/pages/home.dart`
- **关键行**：
  - 挂载页面：`_pages[4] = MyProfilePage()`（`home.dart:41`）
  - 初始化：`initProfile()` → `AuthState.getProfileUser()`（`home.dart:55-58`）— 触发 `_userModel` 加载，从而 `MyProfilePage` 内的 `Selector<AuthState, String>` 拿到 userId 完成首次渲染。
  - Tab 切换：走通用 `_switchTab`（不拦截，`home.dart:71-81`）。
  - 底部图标：`_tabBarItem(tabIndex: 4, icon: CupertinoIcons.person, ..., isActive: tab == 4)`（`home.dart:152`）。

### 2.2 跳转到他人 Profile

- **静态路由**：`ProfilePage.getRoute({profileId, username})`（`profile.dart:37-63`）— 内部 `ChangeNotifierProvider` + `FadeTransition`。
- **典型调用方**（全局搜索 `ProfilePage.getRoute(` 或 `ProfilePage(`）：
  - `client/lib/pages/post/post_detail_page.dart`（帖子详情内点击作者头像 / 昵称）。
  - `client/lib/pages/follow/follow_list_page.dart`（关注 / 粉丝列表点击用户）。
  - `client/lib/pages/search/search.dart`（搜索结果点击用户）。

### 2.3 编辑资料入口

- **位置**：`ProfilePage.build` 内「编辑资料」按钮（`profile.dart:343-358`）— `await Navigator.push(... EditProfilePage())`，返回后 `await _refreshAll()` 同步 UI。

### 2.4 设置入口（仅自己的 Tab）

- **位置**：`ProfilePage.build` 内 AppBar `actions` 第一个 `GestureDetector`（`profile.dart:177-189`）— `Navigator.push(... SettingsPage())`（SettingsPage 在 `client/lib/pages/settings/` 目录下，不属于个人中心范畴）。

### 2.5 关注 / 粉丝列表入口

- **位置**：`ProfilePage._buildStatItem`（`profile.dart:580-603`）— 点击 following 数 → `_navigateToFollowList(1)`；点击 followers 数 → `_navigateToFollowList(0)`。
- **目标页**：`client/lib/pages/follow/follow_list_page.dart`（由 `FollowListState` 提供数据）。

### 2.6 媒体查看器入口

- **位置**：`ProfilePage._buildMediaTab` 内每个 GridItem 的 `GestureDetector`（`profile.dart:501-512`）— `Navigator.push(... MediaViewerPage(mediaItems, initialIndex))`。
- **目标页**：`client/lib/pages/media/media_viewer_page.dart`。

### 2.7 帖子编辑入口（来自 FeedPostWidget）

- **位置**：`client/lib/widget/feedpost.dart` 内自己的帖子卡片右上角菜单。
- 详见 [`docs/code-locations/publish-post.md`](publish-post.md)。

---

## 3. 状态层（Provider）

### 3.1 `ProfileState`（**本地创建**，非全局单例）

- **路径**：`client/lib/state/profile.state.dart`
- **行数**：240
- **注册方式**：**每个 `ProfilePage` 独立实例** — 由 `MyProfilePage`（`myprofile.dart:32-37`）或 `ProfilePage.getRoute`（`profile.dart:40-49`）的 `ChangeNotifierProvider.create` 创建。
- **字段**：
  | 字段 | 说明 | 行号 |
  | --- | --- | --- |
  | `profileId` | 构造时传入（必填） | `profile.state.dart:10` |
  | `currentUserId` | 构造时传入（可选）— 优先于缓存 userId，用于 `isMyProfile` 判定 | `profile.state.dart:17, 19` |
  | `userId` | 从 `SharedPreferences` 缓存的当前用户 ID | `profile.state.dart:23` |
  | `userModel` | 缓存的当前用户完整资料（`_userModel`） | `profile.state.dart:25-26` |
  | `profileUserModel` | 当前正在展示的用户资料（来自 `/user/profile/{id}`） | `profile.state.dart:28-29` |
  | `isbusy` | 加载中（`isbusy` 拼写就是这样的，保持历史兼容） | `profile.state.dart:31-32` |
  | `isFollowing` / `isFollowLoading` | 关注态 + 操作 loading | `profile.state.dart:51-55` |
  | `followStats` | 关注数 / 粉丝数 / 是否互关 | `profile.state.dart:57-58` |
- **服务依赖**（懒加载）：`UserService`（`profile.state.dart:41-44`）、`FollowService`（`profile.state.dart:46-49`），都通过 `getIt()` 拿 `ApiClient`。
- **关键方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `_init()` | 加载缓存用户 → 加载 profile 用户 → 加载关注统计 | `profile.state.dart:60-64` |
  | `_loadCurrentUser()` | 从 `SharedPreferenceHelper.getUserProfile()` 读取缓存的 `_userModel` | `profile.state.dart:66-76` |
  | `isMyProfile` (getter) | `effectiveUserId == profileId`，`effectiveUserId = currentUserId ?? userId` | `profile.state.dart:78-85` |
  | `_getProfileUser(profileId)` | `userService.getUserProfile(userIdInt)` — 自己 profile 时用缓存的 userName/displayName/profilePic 兜底 | `profile.state.dart:87-138` |
  | `followUser({removeFollower})` | 乐观更新 + `followService.followUser / unfollowUser` + 错误回滚 + 刷新统计 | `profile.state.dart:140-169` |
  | `_loadFollowStats()` | `followService.getFollowStats` + 同步 `isFollowing` | `profile.state.dart:171-182` |
  | `refresh()` | 重载 profile + 关注统计 | `profile.state.dart:184-187` |
  | `getFollowers({page})` / `getFollowing({page})` | 关注列表分页 — 由 `FollowListPage` 调用 | `profile.state.dart:201-239` |

### 3.2 `AuthState`（全局单例，自己 profile 辅助数据源）

- **路径**：`client/lib/state/auth.state.dart`
- **关键方法**：
  - `getProfileUser({userProfileId})`（`auth.state.dart:415`）— Splash / 登录 / 下拉刷新时调用，**写入 `_userModel` 缓存**，让 `MyProfilePage` 内的 Selector 拿到 userId。
  - `updateUserProfile(userModel, {image, removeAvatar})`（`auth.state.dart:335`）— `EditProfilePage._submitButton` 调用的实际提交方法。
  - `getUserDetail(userIdStr)`（`auth.state.dart:387`）— 拉单个用户详情。
  - `userModel` / `profileUserModel` getter（`auth.state.dart:28-29`）— 字段返回同一个 `_userModel`。

### 3.3 `FollowListState`（本地创建，关注列表用）

- **路径**：`client/lib/state/follow_list.state.dart`
- **行数**：约 235
- **注册方式**：每个 `FollowListPage` 独立创建（`profile.dart:146-147`）。
- **职责**：分页加载 followers / following / 推荐用户 / 互关列表，搜索 keyword。

### 3.4 其他关联 Provider

- `PostState`（`client/lib/state/post.state.dart`）— `getUserPosts(userId)`（profile 帖子列表）、`reportContent(targetType: 3 = User, targetId, reportType: 9 = Other)`（profile 菜单举报）。
- `NotificationState` — 通知 Tab 独立数据源，与个人中心无直接耦合。

---

## 4. 服务层（API）

### 4.1 `UserService`

- **路径**：`client/lib/services/user_service.dart`
- **行数**：582
- **关键方法**（被 Profile 直接 / 间接调用）：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `getUserProfile(int userId)` | 拉单个用户公开资料 | `user_service.dart:11` |
  | `updateProfile({...})` | 更新个人资料 | `user_service.dart:23` |
  | `getSettings()` / `updateSettings(...)` | 用户偏好设置（首页 Feed 偏好等） | `user_service.dart:53, 62` |
  | `getFollowStats(int userId)` | 关注 / 粉丝数（FollowService 也有同名方法） | `user_service.dart:90` |
  | `addRelationControl({targetUserId, controlType, reason})` | 静音 / 限制 / 拉黑（controlType: 1=静音, 2=限制, 3=拉黑） | `user_service.dart:102` |
  | `removeRelationControl(int targetUserId)` | 解除关系控制 | `user_service.dart:116` |
  | `addHiddenWord({wordType, content})` | 隐藏词 | `user_service.dart:183` |

### 4.2 `FollowService`

- **路径**：`client/lib/services/follow_service.dart`
- **行数**：134
- **关键方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `followUser(int userId)` | 关注 | `follow_service.dart:18` |
  | `unfollowUser(int userId)` | 取消关注 | `follow_service.dart:26` |
  | `getFollowStats(int userId)` | 关注 / 粉丝统计 | `follow_service.dart:34` |
  | `getFollowing(int userId, {page, size, keyword})` | 关注列表分页 | `follow_service.dart:43` |
  | `getFollowers(int userId, {page, size, keyword})` | 粉丝列表分页 | `follow_service.dart:68` |
  | `getMutualFollowers({page, size})` | 互关列表 | `follow_service.dart:93` |
  | `getRecommendedUsers({page, size})` | 推荐关注 | `follow_service.dart:114` |

### 4.3 `PostService`

- **路径**：`client/lib/services/post_service.dart`
- 关键调用：`getUserPosts(userId)`（由 `PostState.getUserPosts` 包装）— 用于 Profile 的 Threads Tab；`reportContent(...)`（由 `PostState.reportContent` 包装）— 用于 Profile 菜单的举报。

---

## 5. 数据模型

| 模型 | 路径 | 关键字段 |
| --- | --- | --- |
| `UserModel` | `client/lib/model/user.module.dart` | `userId` / `userName` / `displayName` / `profilePic` / `bio` / `link` / `pronouns` / `gender` / `location` / `isVerified` / `isPrivate` / `accountType` / `followersCount` / `followingCount` / `postsCount` |
| `UserInfo` | `client/lib/services/user_service.dart` 内（fromJson） | API 端 user 对象 — 字段基本同 `UserModel` |
| `FollowStats` | `client/lib/services/follow_service.dart` 内 | `followersCount` / `followingCount` / `isFollowing` / `mutualCount` |
| `FollowListResult` | `client/lib/services/follow_service.dart` 内 | `users: List<UserInfo>` / `total` / `hasMore` |
| `UserSettings` | `client/lib/services/user_service.dart` 内 | 首页 Feed 偏好等 |
| `MediaItemModel` / `MediaType` | `client/lib/model/post.module.dart` | Media Tab 用 |
| `PostModel` | `client/lib/model/post.module.dart` | Threads Tab 用 |

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arab`、`client/lib/l10n/app_zh.arab`
- **个人中心常用 key**（以 profile / edit / share sheet 为例）：
  - `tabThreads` / `tabMedia` — Tab 标签（`profile.dart:406, 414`）
  - `editProfile` / `shareProfile` / `follow` / `following` — 按钮（`profile.dart:346, 362, 372-373`）
  - `statFollowing` / `statFollowers` — 关注数标签（`profile.dart:328, 334`）
  - `noThreadsYetOthers` / `noMediaYet` — 空态（`profile.dart:447, 482`）
  - `muteUsername(u)` / `restrictUsername(u)` / `blockUsername(u)` / `reportUser` / `blockConfirmTitle` / `blockConfirmDesc` / `userMuted` / `userRestricted` / `userBlocked` / `reportSuccess` — Profile 菜单（`profile.dart:750-812`）
  - `name` / `bio` / `linkLabel` / `pronouns` / `locationLabel` / `gender` / `accountType` / `privateAccount` / `addBio` / `addLinkField` / `addPronouns` / `addLocationField` / `changeAvatar` / `avatarVisibility` / `gallery` / `cameraLabel` / `remove` / `cancel` / `done` / `maxNameChars` / `maxBioChars` / `updateFailed` / `notSet` / `male` / `female` / `otherGender` / `personal` / `creator` / `business` — EditProfilePage
  - `scanToFollow` / `saveToGallery` / `copyLink` / `savedToGallery` / `saveFailed` / `copied` — ShareProfileSheet

---

## 7. 主题 / 颜色

- 颜色统一通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取。
- 入口：`client/lib/theme/app_colors.dart`（`AppColorsExtension` + `AppColors`）。
- 个人中心常用颜色：`textPrimary` / `textSecondary` / `textHint` / `background` / `surface` / `surfaceSecondary` / `surfaceTertiary` / `accent` / `destructive` / `divider`。
- 头像边框：`appColors.textSecondary` 0.5px（`profile.dart:556`）；外链 chip：`appColors.surface` + `appColors.accent`（`profile.dart:273, 282`）；关注按钮高亮：`appColors.textPrimary` 底 + `appColors.background` 字（`profile.dart:886-907`）。

---

## 8. 相关 / 间接依赖

- **FeedPostWidget**（`client/lib/widget/feedpost.dart`）— Profile 的 Threads Tab 直接复用。
- **MediaViewerPage**（`client/lib/pages/media/media_viewer_page.dart`）— Media Tab 点开图片 / 视频。
- **FollowListPage**（`client/lib/pages/follow/follow_list_page.dart`）— 关注 / 粉丝列表。
- **SettingsPage**（`client/lib/pages/settings/...`）— 仅自己的 Tab 时 AppBar 入口。
- **image_picker** 包（`edit.dart:7, 59-65`）— 编辑头像时选图（相册 / 相机）。
- **qr_flutter** 包（`share_profile_sheet.dart:10, 83-95`）— 分享面板 QR 码。
- **screenshot + path_provider + gal** 包（`share_profile_sheet.dart:8-11, 249-274`）— 截屏 → 写临时文件 → 保存到相册。
- **url_launcher** 包（`profile.dart:23, 713`）— 打开外链。
- **Deep Link**：`threads://user/{userId}`（`share_profile_sheet.dart:33`）— 配合 `client/lib/services/deep_link_service.dart` 实现扫码拉起他人 profile。

---

## 9. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改个人中心整体布局 | `ProfilePage` / `build` | `client/lib/pages/profile/profile.dart` |
| 修改编辑资料表单 | `EditProfilePage` / `_fieldSection` / `_selectorSection` | `client/lib/pages/profile/edit.dart` |
| 修改分享面板（QR / 保存 / 复制） | `ShareProfileSheet` / `_saveToGallery` / `_copyLink` | `client/lib/pages/profile/share_profile_sheet.dart` |
| 修改「自己 vs 他人」判定 | `isMyProfile` / `currentUserId` | `client/lib/state/profile.state.dart:78-85` + `client/lib/pages/profile/myprofile.dart:32-37` |
| 修改关注 / 取消关注逻辑 | `followUser` / `FollowService` | `client/lib/state/profile.state.dart:140-169` + `client/lib/services/follow_service.dart` |
| 修改 Profile 菜单（静音 / 限制 / 拉黑 / 举报） | `_showProfileMenu` / `addRelationControl` | `client/lib/pages/profile/profile.dart:732-848` + `client/lib/services/user_service.dart:102` |
| 修改 Media Tab 网格 | `_buildMediaTab` / `MediaViewerPage` | `client/lib/pages/profile/profile.dart:462-546` + `client/lib/pages/media/media_viewer_page.dart` |
| 修改下拉刷新行为 | `_refreshAll` / `state.refresh()` | `client/lib/pages/profile/profile.dart:96-109` + `client/lib/state/profile.state.dart:184-187` |
| 修改用户名兜底逻辑 | `_resolveDisplayName` / `_getProfileUser` | `client/lib/pages/profile/profile.dart:132-140` + `client/lib/state/profile.state.dart:87-138` |
| 修改头像上传 / 清除 | `getImage` / `_submitButton` / `updateUserProfile` | `client/lib/pages/profile/edit.dart:57-66, 464-502` + `client/lib/state/auth.state.dart:335` |
| 修改对外链 / 邮箱等外链字段 | `_openLink` / `link` | `client/lib/pages/profile/profile.dart:695-728` + `client/lib/model/user.module.dart` |
| 添加 / 修改文案 | `l10n.xxx` | `client/lib/l10n/app_zh.arab` + `app_en.arab` |

---

_最后更新：2026-06-15 — 由 Claude 自动化梳理（基于代码静态分析）。_
