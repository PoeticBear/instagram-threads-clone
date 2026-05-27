# Phase 1 — 核心体验完善

> 目标：将 FeedPostWidget、用户资料编辑、设置页、关注模块从占位/半成品状态升级为可用功能
> 涉及文件：~20 个
> 前置条件：P0 已完成（ProfileState 修复 + 通知页对接）

---

## 子任务总览

| # | 子任务 | 类型 | 依赖 | 状态 |
|---|-------|------|------|------|
| 1.1 | 关注模块路径修正 + FollowStats 模型补全 | Bug 修复 | 无 | ✅ 已完成 |
| 1.2 | ProfilePage 添加关注/取关按钮 + 粉丝关注数展示 | UI 对接 | 1.1 | ✅ 已完成 |
| 1.3 | UserModel / UserInfo 补充缺失字段（pronouns/gender/location 等） | 模型补全 | 无 | ✅ 已完成 |
| 1.4 | EditProfilePage 补充新字段编辑（pronouns/gender/location/is_private/account_type） | UI 对接 | 1.3 | ✅ 已完成 |
| 1.5 | UserSettings 模型重写（对齐 API 22 个字段） | 模型补全 | 无 | ✅ 已完成 |
| 1.6 | 创建 SettingsState + SettingsPage 完整实现 | UI 对接 | 1.5 | ✅ 已完成 |
| 1.7 | PostState 补充 repost/save/share/report 方法 | 状态层补全 | 无 | ✅ 已完成 |
| 1.8 | FeedPostWidget 交互完善（转发/收藏/更多菜单） | UI 对接 | 1.7 | ✅ 已完成 |
| 1.9 | FeedPostWidget 评论功能完善（回复列表 + 创建回复） | UI 对接 | 1.7 | ✅ 已完成 |
| 1.10 | P1 本地化字符串补充 | i18n | 1.4, 1.6, 1.8, 1.9 | ✅ 已完成 |

---

## 子任务 1.1 — 关注模块路径修正 + FollowStats 模型补全

**状态：✅ 已完成**

### 问题描述

`FollowService` 中 `getFollowing()` 和 `getMutualFollowers()` 的 API 路径与后端不匹配：

| 方法 | 当前路径 | 正确路径 |
|------|---------|---------|
| `getFollowing()` | `follow/following/$userId` | `follow/following` |
| `getMutualFollowers()` | `follow/mutual/$userId` | `follow/mutual` |

后端从 Token 中获取当前用户 ID，不需要在路径中传 userId。`getFollowing` 和 `getMutualFollowers` 应改为查询参数方式。

此外，后端 `FollowStatsResponse` 返回 5 个字段，客户端 `FollowStats` 仅解析 3 个：

| 后端字段 | 客户端状态 |
|---------|-----------|
| `followers_count` | 已有 |
| `following_count` | 已有 |
| `is_following` | 已有（但字段名不匹配） |
| `is_followed_by_me` | **缺失** |
| `is_mutual` | **缺失** |

### 实现方案

**文件 1：`client/lib/services/follow_service.dart`**

1. `getFollowing()` — 移除路径中的 `/$userId`，改为查询参数：
   ```dart
   Future<List<UserInfo>> getFollowing({int page = 1, int pageSize = 20}) async {
     final response = await _apiClient.get(
       'follow/following',
       queryParameters: {
         'page': page.toString(),
         'page_size': pageSize.toString(),
       },
     );
     ...
   }
   ```

2. `getMutualFollowers()` — 同样移除 `/$userId`：
   ```dart
   Future<List<UserInfo>> getMutualFollowers({int page = 1, int pageSize = 20}) async {
     final response = await _apiClient.get(
       'follow/mutual',
       queryParameters: { ... },
     );
     ...
   }
   ```

**文件 2：`client/lib/services/user_service.dart`**

更新 `FollowStats` 模型，补全缺失字段：

```dart
class FollowStats {
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool isFollowedByMe;
  final bool isMutual;

  FollowStats({
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing = false,
    this.isFollowedByMe = false,
    this.isMutual = false,
  });

  factory FollowStats.fromJson(Map<String, dynamic> json) {
    return FollowStats(
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      postsCount: json['posts_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      isFollowedByMe: json['is_followed_by_me'] ?? false,
      isMutual: json['is_mutual'] ?? false,
    );
  }
}
```

**文件 3：`client/lib/services/auth_service.dart`**

`auth_service.dart` 中 `FollowStats` 引用来自 `user_service.dart`，需同步确认导入正确（当前通过 `import 'auth_service.dart'` 交叉引用）。

**文件 4：`client/lib/state/profile.state.dart`**

`getFollowing()` 方法签名需适配新的无参签名，移除传入的 `profileUserId`。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/services/follow_service.dart` | 修改 2 个方法的 API 路径 |
| `client/lib/services/user_service.dart` | FollowStats 补 3 个字段 |
| `client/lib/state/profile.state.dart` | getFollowing() 适配新签名 |

### 验证方式

- 调用 `getFollowing()` 不报 404
- 调用 `getMutualFollowers()` 不报 404
- `FollowStats` 正确解析 `is_followed_by_me` 和 `is_mutual` 字段

---

## 子任务 1.2 — ProfilePage 添加关注/取关按钮 + 粉丝关注数展示

**状态：✅ 已完成**

### 问题描述

当前 `ProfilePage` 缺少以下核心元素：
1. 他人主页没有关注/取关按钮（只有 "Edit profile" 和 "Share profile"）
2. 不显示粉丝数（followers）、关注数（following）、帖子数（posts）
3. `_profileUserModel` 构建的 `UserModel` 缺少 `followersCount`/`followingCount`

### 实现方案

**文件 1：`client/lib/pages/profile/profile.dart`**

1. 在 `_profileUserModel` 信息区域下方添加统计数据行：
   ```dart
   // 粉丝数 | 关注数
   Row(children: [
     Text('${stats.followingCount} following', ...),
     Text('${stats.followersCount} followers', ...),
   ])
   ```
   统计数据通过 `profileState.getFollowStats()` 获取。

2. 替换 "Edit profile" / "Share profile" 按钮逻辑：
   - **我的主页**：保留 "Edit profile" + "Share profile"
   - **他人主页**：显示 "Follow" / "Following" 按钮 + "Share profile"
   - 关注按钮点击调用 `profileState.followUser()` / `profileState.followUser(removeFollower: true)`

3. 在 `_initState` 或 `initState` 中加载 `FollowStats`，用于展示数字和按钮状态。

**文件 2：`client/lib/state/profile.state.dart`**

1. 缓存 `FollowStats` 到 state 中，避免每次 build 重复请求：
   ```dart
   FollowStats _followStats = FollowStats();
   FollowStats get followStats => _followStats;
   ```
2. 在 `_getProfileUser` 完成后自动调用 `getFollowStats()` 并缓存。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/pages/profile/profile.dart` | 添加统计行 + 关注按钮 |
| `client/lib/state/profile.state.dart` | 缓存 FollowStats |

### 验证方式

- 打开他人主页 → 显示 "Follow" 按钮 + 粉丝/关注数字
- 打开自己的主页 → 显示 "Edit profile" + 数字
- 点击 Follow → 按钮变为 "Following"，数字 +1
- 点击 Following → 取关确认 → 按钮变回 "Follow"，数字 -1

---

## 子任务 1.3 — UserModel / UserInfo 补充缺失字段

**状态：✅ 已完成**

### 问题描述

后端 `UserProfileResponse` 返回 16 个字段，客户端 `UserModel` 和 `UserInfo` 都缺少：`pronouns`、`gender`、`location`、`isVerified`、`accountType`、`postsCount`。

### 实现方案

**文件 1：`client/lib/model/user.module.dart`（UserModel）**

在 UserModel 中添加字段：

```dart
String? pronouns;
int? gender;        // 1=Not set, 2=Male, 3=Female, 4=Other
String? location;
bool? isVerified;
int? accountType;   // 1=Personal, 2=Creator, 3=Business
int? postsCount;
```

同步更新 `fromJson`、`toJson`、`copyWith` 方法。

**文件 2：`client/lib/services/auth_service.dart`（UserInfo）**

在 UserInfo 中添加同样的字段，同步更新 `fromJson` 工厂方法。

**文件 3：`client/lib/state/profile.state.dart`**

更新 `_getloggedInUserProfile()` 和 `_getProfileUser()` 中构建 `UserModel` 的代码，补充新字段的映射。

**文件 4：`client/lib/services/user_service.dart`（updateProfile）**

扩展 `updateProfile()` 方法，支持新字段：

```dart
Future<UserInfo> updateProfile({
  String? displayName,
  String? bio,
  String? websiteUrl,
  String? avatarUrl,
  String? pronouns,
  int? gender,
  String? location,
  int? isPrivate,
  int? accountType,
}) async {
  final body = <String, dynamic>{};
  // ... 新增字段
  if (pronouns != null) body['pronouns'] = pronouns;
  if (gender != null) body['gender'] = gender;
  if (location != null) body['location'] = location;
  if (isPrivate != null) body['is_private'] = isPrivate;
  if (accountType != null) body['account_type'] = accountType;
  ...
}
```

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/model/user.module.dart` | UserModel 添加 6 个字段 + fromJson/toJson/copyWith |
| `client/lib/services/auth_service.dart` | UserInfo 添加 6 个字段 + fromJson |
| `client/lib/state/profile.state.dart` | 构建 UserModel 时映射新字段 |
| `client/lib/services/user_service.dart` | updateProfile 添加 5 个参数 |

### 验证方式

- `UserInfo.fromJson` 能解析 `pronouns`、`gender`、`location` 等字段
- `UserModel.fromJson` 能解析同上字段
- `updateProfile` 能提交新字段到 API

---

## 子任务 1.4 — EditProfilePage 补充新字段编辑

**状态：✅ 已完成**

### 问题描述

当前 `EditProfilePage` 仅支持编辑：名称（displayName）、简介（bio）、链接（link）。
后端 API 还支持：pronouns、gender、location、is_private、account_type，但 UI 无入口。

### 实现方案

**文件 1：`client/lib/pages/profile/edit.dart`**

在现有的 "链接" 编辑区域下方，依次添加：

1. **人称代词（Pronouns）**：`CupertinoTextField`
   - 当前值：`state.userModel?.pronouns`
   - 提示文本："添加人称代词"

2. **性别（Gender）**：点击弹出选择器（`CupertinoActionSheet`）
   - 选项：未设置(1) / 男(2) / 女(3) / 其他(4)
   - 展示当前选择的文本

3. **所在地（Location）**：`CupertinoTextField`
   - 当前值：`state.userModel?.location`
   - 提示文本："添加所在地"

4. **私密账号（Private Account）**：`CupertinoSwitch`
   - 当前值：`state.userModel?.isPrivate`
   - 开关切换

5. **账号类型（Account Type）**：点击弹出选择器
   - 选项：个人(1) / 创作者(2) / 商业(3)
   - 展示当前选择的文本

6. 更新 `_submitButton()` 中的 `copyWith`，传入新字段。
7. 更新 `initState` 中的控制器初始化。

**文件 2：`client/lib/state/auth.state.dart`**

`updateUserProfile()` 需要将新字段传递给 `userService.updateProfile()`。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/pages/profile/edit.dart` | 添加 5 个新字段编辑区域 + 提交逻辑 |
| `client/lib/state/auth.state.dart` | updateUserProfile 传递新字段 |

### 验证方式

- 编辑页显示所有新字段，带当前值
- 修改 pronouns → 保存 → API 请求包含 pronouns 字段
- 切换私密账号开关 → 保存 → API 请求包含 is_private
- 修改性别 → 弹出选择器 → 选择后显示对应文本

---

## 子任务 1.5 — UserSettings 模型重写（对齐 API 22 个字段）

**状态：✅ 已完成**

### 问题描述

当前 `UserSettings` 仅有 4 个布尔字段（`allowMentions`, `allowReplies`, `showOnlineStatus`, `readReceipts`），与后端 22 个 int 字段完全不匹配。JSON key 也不匹配后端 schema。

### 实现方案

**文件：`client/lib/services/user_service.dart`**

完全重写 `UserSettings` 类：

```dart
class UserSettings {
  // 回复权限
  int replyAllowType;           // 1=Everyone, 2=Followers, 3=Pages you follow, 4=Mentioned
  // 提及权限
  int mentionAllowType;         // 1=Everyone, 2=Users you follow, 3=Mutuals only
  // 消息设置
  int messageRequestEnabled;    // 0=Off, 1=On
  int messageRequestAllowType;  // 1=Only followed users, 2=Anyone
  // 通知开关 (11 项)
  int notifyLikes;
  int notifyReplies;
  int notifyMentions;
  int notifyFollows;
  int notifyTrending;
  int notifySystem;
  int notifyGroupMessages;
  int notifyQuotes;
  int notifyReposts;
  int notifyPolls;
  int notifyCommunities;
  // 隐私设置
  int showReadReceipts;
  int showOnlineStatus;
  int allowRecommend;
  // 显示设置
  int hideLikesCount;
  // 互动限制
  int interactionRestrictionType; // 1=None, 2=Followed >1 week, 3=Mutuals only
  // 静默模式
  int silentMode;               // 0=Off, 1=On
  // 内容分级
  int contentRating;            // 1=All, 2=Teen, 3=Adult

  UserSettings({
    this.replyAllowType = 1,
    this.mentionAllowType = 1,
    this.messageRequestEnabled = 1,
    this.messageRequestAllowType = 1,
    this.notifyLikes = 1,
    this.notifyReplies = 1,
    this.notifyMentions = 1,
    this.notifyFollows = 1,
    this.notifyTrending = 1,
    this.notifySystem = 1,
    this.notifyGroupMessages = 1,
    this.notifyQuotes = 1,
    this.notifyReposts = 1,
    this.notifyPolls = 1,
    this.notifyCommunities = 1,
    this.showReadReceipts = 1,
    this.showOnlineStatus = 1,
    this.allowRecommend = 1,
    this.hideLikesCount = 0,
    this.interactionRestrictionType = 1,
    this.silentMode = 0,
    this.contentRating = 1,
  });

  // fromJson / toJson ...
}
```

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/services/user_service.dart` | 重写 UserSettings 类 |

### 验证方式

- `UserSettings.fromJson` 正确解析所有 22 个字段
- `toJson` 输出所有 22 个字段
- 默认值与 API spec 一致

---

## 子任务 1.6 — 创建 SettingsState + SettingsPage 完整实现

**状态：⬜ 未开始**

### 问题描述

当前 `SettingsPage` 仅语言切换和登出可用，其余菜单项（通知/隐私/帮助/关于）为纯展示文字，无点击事件。设置页无法读取或修改后端 22 项设置。

### 实现方案

**文件 1：`client/lib/state/settings.state.dart`（新建）**

```dart
class SettingsState extends ChangeNotifier {
  UserSettings _settings = UserSettings();
  UserSettings get settings => _settings;
  bool _isBusy = false;
  bool get isBusy => _isBusy;

  Future<void> loadSettings() async { ... }
  Future<void> updateSetting(String key, int value) async { ... }
}
```

**文件 2：`client/lib/main.dart`**

注册 `SettingsState` 到 `MultiProvider`。

**文件 3：`client/lib/common/settings.dart`**

重写 `SettingsPage`，将菜单项改为可交互：

| 菜单项 | 子页面/操作 |
|-------|-----------|
| 关注与邀请好友 | 导航到关注推荐页（已有 FollowService.getRecommendedUsers） |
| 通知 | 导航到通知设置子页面（11 个通知开关） |
| 隐私 | 导航到隐私设置子页面（回复权限/提及权限/互动限制/显示设置） |
| 帮助 | 显示帮助信息（简单文本页） |
| 关于 | 显示 App 版本信息 |
| 语言 | 保留现有切换 |
| 登出 | 保留现有逻辑 |

**新建子页面文件（按需）：**

- `client/lib/common/settings/notification_settings.dart` — 11 个通知开关
- `client/lib/common/settings/privacy_settings.dart` — 隐私相关设置

每个开关使用 `CupertinoSwitch`，切换时调用 `SettingsState.updateSetting()`。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/state/settings.state.dart` | **新建** |
| `client/lib/main.dart` | 注册 SettingsState |
| `client/lib/common/settings.dart` | 重写设置页 |
| `client/lib/common/settings/notification_settings.dart` | **新建** |
| `client/lib/common/settings/privacy_settings.dart` | **新建** |

### 验证方式

- 设置页展示当前设置值
- 切换通知开关 → API 更新成功 → 重进保持
- 修改隐私设置 → API 更新成功
- 语言切换、登出功能不受影响

---

## 子任务 1.7 — PostState 补充 repost/save/share/report 方法

**状态：⬜ 未开始**

### 问题描述

`PostService` 已实现 `repost()`、`savePost()`、`unsavePost()`、`reportPost()` 方法，但 `PostState` 没有对应的状态管理方法。`PostModel` 也缺少 `isReposted` 和 `isSaved` 字段。此外 `PostService` 缺少 `sharePost()` 方法。

### 实现方案

**文件 1：`client/lib/model/post.module.dart`（PostModel）**

添加字段：
```dart
bool? isReposted;
bool? isSaved;
```
更新 `fromJson` 解析这两个字段。

**文件 2：`client/lib/services/post_service.dart`**

添加缺失方法：
```dart
Future<void> sharePost(int postId) async {
  await _apiClient.post('post/share/$postId');
}
```

**文件 3：`client/lib/state/post.state.dart`**

添加状态方法（带乐观更新）：

```dart
// 转发
Future<void> repost(int postId) async {
  // 乐观更新: isReposted = true, repostsCount++
  // 调用 _postService.repost(postId)
  // 失败时回滚
}

Future<void> unrepost(int postId) async {
  // 乐观更新: isReposted = false, repostsCount--
  // 需确认 API 是否有 DELETE /post/repost/{post_id}
}

// 收藏
Future<void> savePost(int postId) async {
  // 乐观更新: isSaved = true
  // 调用 _postService.savePost(postId)
}

Future<void> unsavePost(int postId) async {
  // 乐观更新: isSaved = false
  // 调用 _postService.unsavePost(postId)
}

// 分享（仅记录，无乐观更新）
Future<void> sharePost(int postId) async {
  await _postService.sharePost(postId);
}

// 举报
Future<void> reportPost(int postId, {int reportType = 1, String? description}) async {
  await _postService.reportPost(postId, reason: description);
}
```

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/model/post.module.dart` | PostModel 添加 isReposted + isSaved |
| `client/lib/services/post_service.dart` | 添加 sharePost() |
| `client/lib/state/post.state.dart` | 添加 repost/unrepost/save/unsave/share/report |

### 验证方式

- PostModel.fromJson 能解析 isReposted 和 isSaved
- PostState.repost() 能乐观更新 UI 并调用 API
- PostState.savePost() 能切换收藏状态

---

## 子任务 1.8 — FeedPostWidget 交互完善（转发/收藏/更多菜单）

**状态：⬜ 未开始**

### 问题描述

当前 `FeedPostWidget` 的交互行：
- 点赞：已完成
- 评论：打开空白 BottomSheet
- 转发：`Iconsax.repeat` 图标无 `GestureDetector`
- 分享：`Iconsax.send_2` 图标无 `GestureDetector`
- 更多菜单：`Icons.more_horiz` 无 `GestureDetector`
- 收藏：无 UI

### 实现方案

**文件：`client/lib/widget/feedpost.dart`**

1. **转发按钮**：添加 `GestureDetector`，点击弹出 BottomSheet：
   ```
   ┌────────────────────┐
   │  🔄 转发            │  → 调用 PostState.repost()
   │  ❝ 引用转发         │  → 打开 ComposePost（带引用模式）
   │  ↩️ 撤销转发         │  → 调用 PostState.unrepost()（仅已转发时显示）
   └────────────────────┘
   ```
   转发图标在 `isReposted == true` 时高亮为绿色。

2. **分享按钮**：添加 `GestureDetector`，点击弹出 BottomSheet：
   ```
   ┌────────────────────┐
   │  📋 复制链接         │
   │  📤 分享到...        │  → 调用系统分享
   └────────────────────┘
   ```
   同时调用 `PostState.sharePost()` 记录分享行为。

3. **更多菜单(...)按钮**：添加 `GestureDetector`，点击弹出 BottomSheet：
   ```
   ┌────────────────────┐
   │  🔖 收藏 / 取消收藏   │  → PostState.savePost/unsavePost
   │  📌 置顶帖子         │  → PostState.pinPost（仅自己的帖子）
   │  ⚠️ 举报            │  → 弹出举报原因选择
   │  👎 不感兴趣         │  → 隐藏该帖
   └────────────────────┘
   ```

4. **头像/用户名点击**：添加 `GestureDetector`，导航到 `ProfilePage(profileId: userId)`。

5. 修正分享按钮旁的计数文本：当前错误显示 `repliesCount`，应改为 `sharesCount`。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/widget/feedpost.dart` | 添加 4 个交互手势 + 3 个 BottomSheet |

### 验证方式

- 点击转发 → 弹出选项 → 纯转发成功，图标变绿
- 点击分享 → 弹出选项 → 复制链接到剪贴板
- 点击更多 → 弹出菜单 → 收藏成功，图标变化
- 点击头像/用户名 → 跳转到对应 ProfilePage
- 举报 → 选择原因 → 提交成功

---

## 子任务 1.9 — FeedPostWidget 评论功能完善（回复列表 + 创建回复）

**状态：⬜ 未开始**

### 问题描述

点击评论图标（`Iconsax.message`）当前打开空白 BottomSheet，只显示 "评论" 文字。需要实现完整的回复列表和创建回复功能。

### 实现方案

**文件 1：`client/lib/widget/feedpost.dart`**

将评论 BottomSheet 内容替换为完整的回复页面：

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => ReplyBottomSheet(postId: widget.postModel.id),
);
```

**文件 2：`client/lib/widget/reply_bottom_sheet.dart`（新建）**

```
┌──────────────────────────────────┐
│  ← 评论                          │  顶栏
├──────────────────────────────────┤
│  原帖内容摘要                     │
├──────────────────────────────────┤
│  回复 1                          │
│  回复 2                          │  回复列表（可滚动）
│  ...                             │
├──────────────────────────────────┤
│  [头像] 写一条评论...    [发送]    │  底部输入框
└──────────────────────────────────┘
```

功能：
1. 加载时调用 `PostService.getReplies(postId)` 获取回复列表
2. 支持分页加载
3. 每条回复显示：头像、用户名、内容、时间、点赞按钮 + 计数
4. 底部固定输入框，输入文本后点击发送调用 `PostService.createReply(postId, content)`
5. 发送成功后刷新列表

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/widget/feedpost.dart` | 替换空白 BottomSheet 为 ReplyBottomSheet |
| `client/lib/widget/reply_bottom_sheet.dart` | **新建** |

### 验证方式

- 点击评论图标 → 弹出回复列表
- 回复列表正确展示已有回复
- 输入文字 → 发送 → 回复出现在列表中
- 回复列表可滚动、可分页加载
- 点赞回复 → 计数 +1

---

## 子任务 1.10 — P1 本地化字符串补充

**状态：⬜ 未开始**

### 问题描述

P1 新增的所有 UI 文本需要添加 i18n 字符串。

### 实现方案

**文件 1：`client/lib/l10n/app_en.arb`**
**文件 2：`client/lib/l10n/app_zh.arb`**

新增的本地化 key 列表：

```json
// 关注
"follow": "Follow" / "关注"
"following": "Following" / "正在关注"
"unfollow": "Unfollow" / "取消关注"
"followBack": "Follow Back" / "回关"
"followers": "followers" / "粉丝"
"followingCount": "following" / "关注"

// 转发
"repost": "Repost" / "转发"
"quoteRepost": "Quote Repost" / "引用转发"
"undoRepost": "Undo Repost" / "撤销转发"
"reposted": "Reposted" / "已转发"

// 收藏
"save": "Save" / "收藏"
"saved": "Saved" / "已收藏"
"removeFromSaved": "Remove from Saved" / "取消收藏"

// 分享
"shareTo": "Share to..." / "分享到..."
"copyLink": "Copy Link" / "复制链接"
"linkCopied": "Link copied" / "链接已复制"
"sharePost": "Share Post" / "分享帖子"

// 更多菜单
"more": "More" / "更多"
"report": "Report" / "举报"
"notInterested": "Not Interested" / "不感兴趣"
"pinPost": "Pin Post" / "置顶帖子"
"unpinPost": "Unpin Post" / "取消置顶"

// 举报原因
"reportSpam": "Spam" / "垃圾信息"
"reportHarassment": "Harassment" / "骚扰"
"reportHateSpeech": "Hate Speech" / "仇恨言论"
"reportViolence": "Violence" / "暴力"
"reportOther": "Other" / "其他"
"reportSubmitted": "Report submitted" / "举报已提交"

// 资料编辑
"pronouns": "Pronouns" / "人称代词"
"addPronouns": "Add pronouns" / "添加人称代词"
"gender": "Gender" / "性别"
"notSet": "Not set" / "未设置"
"male": "Male" / "男"
"female": "Female" / "女"
"other": "Other" / "其他"
"location": "Location" / "所在地"
"addLocation": "Add location" / "添加所在地"
"privateAccount": "Private Account" / "私密账号"
"accountType": "Account Type" / "账号类型"
"personal": "Personal" / "个人"
"creator": "Creator" / "创作者"
"business": "Business" / "商业"

// 设置
"notificationSettings": "Notification Settings" / "通知设置"
"privacySettings": "Privacy Settings" / "隐私设置"
"replyAllowType": "Who can reply" / "谁可以回复"
"mentionAllowType": "Who can mention you" / "谁可以提及你"
"interactionRestriction": "Interaction Restriction" / "互动限制"
"contentRating": "Content Rating" / "内容分级"
"silentMode": "Silent Mode" / "静默模式"
"hideLikesCount": "Hide Likes Count" / "隐藏点赞数"
"showOnlineStatus": "Show Online Status" / "显示在线状态"
"showReadReceipts": "Show Read Receipts" / "显示已读回执"
"allowRecommend": "Allow Recommendations" / "允许推荐"
"everyone": "Everyone" / "所有人"
"followersOnly": "Followers" / "粉丝"
"mutualsOnly": "Mutuals" / "互相关注"
"pagesYouFollow": "Pages you follow" / "你关注的页面"
"mentionedOnly": "Mentioned" / "仅被提及时"
"noRestriction": "No restriction" / "无限制"
"followedMoreThanWeek": "Followed > 1 week" / "关注超过一周"
"allContent": "All" / "全部"
"teenContent": "Teen" / "青少年"
"adultContent": "Adult" / "成人"

// 评论
"comments": "Comments" / "评论"
"writeAComment": "Write a comment..." / "写一条评论..."
"send": "Send" / "发送"
```

更新后运行 `flutter gen-l10n` 重新生成。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/l10n/app_en.arb` | 新增 ~70 个 key |
| `client/lib/l10n/app_zh.arb` | 新增 ~70 个 key |
| `client/lib/l10n/generated/*` | 自动生成 |

### 验证方式

- 所有新字符串通过 `AppLocalizations.of(context)!.xxx` 可访问
- 中英文切换后文本正确显示

---

## 执行顺序与依赖关系

```
1.1 关注路径修正 ──────────────→ 1.2 ProfilePage 关注按钮
                                         │
1.3 UserModel 字段补全 ──────→ 1.4 EditProfilePage 新字段
                                         │
1.5 UserSettings 模型重写 ───→ 1.6 SettingsPage 完整实现
                                         │
1.7 PostState 方法补全 ──────→ 1.8 FeedPostWidget 交互
                            │─→ 1.9 评论功能完善
                                         │
1.4 + 1.6 + 1.8 + 1.9 ──────→ 1.10 本地化字符串
```

可并行的工作组：
- **组 A**：1.1→1.2（关注模块）
- **组 B**：1.3→1.4（资料编辑）
- **组 C**：1.5→1.6（设置页）
- **组 D**：1.7→1.8+1.9（帖子交互）

1.10 依赖所有前置子任务完成。

---

## 完成标准

- [ ] 关注/取关按钮可用，API 路径正确
- [ ] 粉丝/关注/帖子数字正确显示
- [ ] 资料编辑页支持 pronouns/gender/location/is_private/account_type
- [ ] 设置页 22 项设置可读可写
- [ ] 帖子转发（纯转发+引用转发）可用
- [ ] 帖子收藏/取消收藏可用
- [ ] 帖子分享（复制链接）可用
- [ ] 更多菜单（收藏/举报/不感兴趣）可用
- [ ] 评论回复列表 + 创建回复可用
- [ ] 所有新文本支持中英文切换
- [ ] 无新增 lint warning
