# i18n 本地化排查指南

> 本文档用于系统性排查和修复项目中未正确实现语言本地化的页面与组件。

---

## 一、业务模块清单

按业务功能划分为 **15 个模块**，排查时按模块逐个执行。

### 模块总览

| 编号 | 模块名称 | 文件路径 | 文件数 |
|:---:|---|---|:---:|
| M1 | 启动与首页框架 | `lib/pages/home.dart`, `lib/common/splash.dart` | 2 |
| M2 | Feed 信息流 | `lib/pages/feed/` | 1 |
| M3 | 搜索 | `lib/pages/search/` | 1 |
| M4 | 发帖（编辑器） | `lib/pages/composePost/` | 2 |
| M5 | 帖子详情与管理 | `lib/pages/post/` | 5 |
| M6 | 个人资料（自己） | `lib/pages/profile/myprofile.dart` | 1 |
| M7 | 个人资料（他人） | `lib/pages/profile/profile.dart` | 1 |
| M8 | 编辑资料 | `lib/pages/profile/edit.dart` | 1 |
| M9 | 消息与聊天 | `lib/pages/message/` | 9 |
| M10 | 通知/动态 | `lib/pages/notification/` | 1 |
| M11 | 社区 | `lib/pages/community/` | 3 |
| M12 | 话题 | `lib/pages/topic/` | 1 |
| M13 | 相机 | `lib/pages/camera/` | 1 |
| M14 | 注册与引导 | `lib/auth/` | 8 |
| M15 | 设置（含子页面） | `lib/common/settings.dart` + `lib/common/settings/` | 7 |

### 各模块文件清单

#### M1 — 启动与首页框架
- `lib/common/splash.dart` — 启动页
- `lib/pages/home.dart` — 底部导航框架（6 个 Tab）

#### M2 — Feed 信息流
- `lib/pages/feed/feed.dart` — 首页信息流

#### M3 — 搜索
- `lib/pages/search/search.dart` — 搜索页（Top / Users / Topics / Posts 四个 Tab）

#### M4 — 发帖（编辑器）
- `lib/pages/composePost/post.dart` — 帖子编辑器
- `lib/pages/composePost/widget/composeBottomIconWidget.dart` — 编辑器底部工具栏

#### M5 — 帖子详情与管理
- `lib/pages/post/post_detail_page.dart` — 帖子详情
- `lib/pages/post/reply_review_page.dart` — 回复审核
- `lib/pages/post/guest_reply_page.dart` — 访客回复审核
- `lib/pages/post/saved_posts_page.dart` — 已收藏帖子
- `lib/pages/post/scheduled_posts_page.dart` — 定时帖子

#### M6 — 个人资料（自己）
- `lib/pages/profile/myprofile.dart` — 自己的主页

#### M7 — 个人资料（他人）
- `lib/pages/profile/profile.dart` — 他人主页

#### M8 — 编辑资料
- `lib/pages/profile/edit.dart` — 编辑资料页

#### M9 — 消息与聊天
- `lib/pages/message/message_page.dart` — 消息列表页
- `lib/pages/message/message_list_tile.dart` — 消息列表项
- `lib/pages/message/chat_detail_page.dart` — 单聊详情
- `lib/pages/message/chat_bubble.dart` — 聊天气泡
- `lib/pages/message/reaction_picker.dart` — 表情回应选择器
- `lib/pages/message/create_group_page.dart` — 创建群组
- `lib/pages/message/group_chat_detail_page.dart` — 群聊详情
- `lib/pages/message/group_members_page.dart` — 群成员管理
- `lib/pages/message/join_requests_page.dart` — 入群请求

#### M10 — 通知/动态
- `lib/pages/notification/notification.dart` — 通知页

#### M11 — 社区
- `lib/pages/community/community_list_page.dart` — 社区列表
- `lib/pages/community/community_detail_page.dart` — 社区详情
- `lib/pages/community/community_members_page.dart` — 社区成员

#### M12 — 话题
- `lib/pages/topic/topic_detail_page.dart` — 话题详情

#### M13 — 相机
- `lib/pages/camera/camera.dart` — 相机拍摄页

#### M14 — 注册与引导
- `lib/auth/signup/name.dart` — 输入姓名
- `lib/auth/signup/email.dart` — 输入邮箱
- `lib/auth/signup/account.dart` — 创建账号
- `lib/auth/signup/register.dart` — 注册
- `lib/auth/signup/signup.dart` — 设置个人资料（头像/简介/链接）
- `lib/auth/onboard/follow.dart` — 引导：推荐关注
- `lib/auth/onboard/privacy.dart` — 引导：隐私设置
- `lib/auth/onboard/thread.dart` — 引导：偏好设置

#### M15 — 设置（含子页面）
- `lib/common/settings.dart` — 设置主页
- `lib/common/settings/notification_settings.dart` — 通知设置
- `lib/common/settings/privacy_settings.dart` — 隐私设置
- `lib/common/settings/relation_control_page.dart` — 关系管理（屏蔽/静音/限制）
- `lib/common/settings/collections_page.dart` — 收藏夹管理
- `lib/common/settings/hidden_words_page.dart` — 隐藏词管理
- `lib/common/settings/links_page.dart` — 链接管理

### 附加排查范围：共享组件

> 以下共享 Widget 被多个模块引用，需单独排查。

- `lib/widget/feedpost.dart` — 帖子卡片（Feed/搜索/帖子详情共用）
- `lib/widget/poll_widget.dart` — 投票组件
- `lib/widget/reply_bottom_sheet.dart` — 回复底部弹窗
- `lib/widget/edit_history_sheet.dart` — 编辑历史弹窗
- `lib/widget/draft_list_sheet.dart` — 草稿列表弹窗
- `lib/widget/topic_tile.dart` — 话题条目
- `lib/widget/search_post_tile.dart` — 搜索帖子条目
- `lib/widget/list.dart` — 通用列表组件
- `lib/widget/language_switcher.dart` — 语言切换器

---

## 二、排查规则

对每个模块，按照以下 **6 步流程** 执行排查。

### 步骤 1：扫描硬编码字符串

**目标**：找出文件中所有未走本地化的硬编码文本。

**操作**：
1. 逐文件阅读，搜索以下模式：
   - `Text('...')` / `Text("...")` — 直接传入字符串字面量
   - `hintText: '...'` / `labelText: '...'` / `helperText: '...'` — 输入框装饰
   - `title: Text('...')` — AppBar 标题
   - `Tab(text: '...')` — Tab 标签
   - `'...'.i18n` / `tr('...')` — 若使用了非标准方式
   - `showDialog` / `showModalBottomSheet` / `showMenu` 中的硬编码文本
   - `AlertDialog` 中的 `title`、`content`、`actions` 文字
   - `SnackBar` 中的文本
   - `Tooltip` 中的 `message`
   - `Semantics` 中的 `label`
   - `Icon` 的 `semanticLabel`
2. 对每个发现的硬编码字符串，记录：
   - 所在文件和行号
   - 硬编码内容原文
   - 是否已有对应 ARB key 可用

**判定标准**：
- 以下情况**不需要本地化**（可跳过）：
  - 纯数字、符号（如 `'.'`, `'/'`）
  - API 路径或技术字符串（如 `'https://...'`）
  - 用于调试的 `print()` / `debugPrint()` 中的文本
  - `Key('...')` 中的标识符
  - `routeName` 等导航标识
  - 已通过 `AppLocalizations.of(context)!.xxx` 引用的字符串
- 以下情况**需要本地化**：
  - 所有面向用户的可见文本
  - SnackBar、Toast、Dialog 中的提示文字
  - 空状态提示（如 `'No conversations yet'`）
  - 按钮、标签、占位符文本
  - 错误提示信息

### 步骤 2：检查 ARB Key 是否已存在

**目标**：确定硬编码字符串是否已有可复用的本地化 Key。

**操作**：
1. 打开 `client/lib/l10n/app_en.arb` 搜索对应的英文值
2. 如果找到了对应 Key → 记录 Key 名称，后续直接引用
3. 如果没有找到 → 进入步骤 3 新增 Key

**参考**：当前项目已定义约 **135 个** ARB Key，覆盖的主要类别包括：
- 通用（search, cancel, post, back, save, share...）
- 发帖（newPost, saySomething, publishSuccess...）
- 搜索（searchTitle, searchTop, noResultsFound...）
- 登录（loginTitle, usernameHint...）
- 设置（settingsTitle, notifications, privacy...）
- 通知设置（notifyLikes, notifyReplies...）
- 隐私设置（privacySettings, whoCanReplyToYou...）
- 活动/通知（activityTitle, filterAll...）
- 个人资料（editProfile, shareProfile, followers, following...）
- 帖子操作（repost, quote, report, follow...）
- 消息（messages, noConversations, newMessage...）
- 群组（createGroup, groupName, members...）
- 话题（topic, followTopic, hot, latest...）
- 草稿（drafts, saveDraft, deleteDraft...）
- 社区（communities, joinCommunity...）
- 账号管控（mutedUsers, blockedUsers...）
- 收藏夹（collections, createCollection...）
- 隐藏词（hiddenWords, keywords...）
- 链接（links, addLink...）
- 帖子管理（scheduledPosts, savedPosts...）
- 时间（justNow, minutesAgo...）

### 步骤 3：新增 ARB Key（如需）

**目标**：为步骤 1 中发现的、且步骤 2 确认无对应 Key 的硬编码字符串创建新的本地化条目。

**操作**：
1. 在 `client/lib/l10n/app_en.arb` 中追加新 Key，遵循命名规范：
   - 格式：`"@{moduleId}{Description}"`（驼峰）
   - 示例：`"cameraTitle": "Camera"`, `"noUsersFound": "No users found"`
2. 同时在 `client/lib/l10n/app_zh.arb` 中添加对应的中文翻译
3. 如果字符串包含变量，使用 `{variableName}` 占位符，并在 ARB 中添加 `@description` 和 `@placeholders` 元数据
   ```json
   "unreadCount": "{count} unread",
   "@unreadCount": {
     "placeholders": {
       "count": { "type": "int" }
     }
   }
   ```
4. 运行生成命令：
   ```bash
   cd client && flutter gen-l10n
   ```

### 步骤 4：替换硬编码为 l10n 调用

**目标**：将步骤 1 发现的硬编码字符串替换为 `AppLocalizations` 调用。

**操作**：
1. 确认文件顶部已导入：
   ```dart
   import 'package:threads/l10n/generated/app_localizations.dart';
   ```
2. 如果文件中有多处使用，在 `build()` 方法顶部缓存引用：
   ```dart
   final l10n = AppLocalizations.of(context)!;
   ```
3. 将硬编码替换为 l10n 调用：
   ```dart
   // 替换前
   Text('Cancel')
   // 替换后
   Text(l10n.cancel)
   ```
4. 注意：对于在 `build()` 之外无法访问 `context` 的场景（如 `State` 字段初始化），需在使用处获取 l10n

### 步骤 5：验证编译与功能

**目标**：确保替换后代码编译通过、功能正常。

**操作**：
1. 运行编译检查：
   ```bash
   cd client && flutter analyze
   ```
2. 确认无未定义 Key 报错
3. 启动应用，切换语言（英文 ↔ 中文），检查该模块页面：
   - 所有文本正确显示对应语言
   - 无遗漏的硬编码文本
   - 布局未因文本长度变化而溢出

### 步骤 6：记录排查结果

**目标**：留档，避免重复排查。

**操作**：在每个模块排查完成后，在本文档末尾的「排查记录」区域填写：

```
| M{编号} | 模块名 | ✅/⚠️/❌ | 发现问题数 | 修复数 | 备注 |
```

- ✅ = 全部通过，无硬编码问题
- ⚠️ = 有硬编码问题但已修复
- ❌ = 有硬编码问题，待修复

---

## 三、排查记录

> 按模块逐个填写，完成一个记一个。

| 模块 | 状态 | 发现问题 | 已修复 | 备注 |
|:---:|:---:|:---:|:---:|---|
| M1 | - | - | - | |
| M2 | - | - | - | |
| M3 | - | - | - | |
| M4 | - | - | - | |
| M5 | - | - | - | |
| M6 | - | - | - | |
| M7 | - | - | - | |
| M8 | - | - | - | |
| M9 | - | - | - | |
| M10 | - | - | - | |
| M11 | - | - | - | |
| M12 | - | - | - | |
| M13 | - | - | - | |
| M14 | - | - | - | |
| M15 | - | - | - | |
| 共享组件 | - | - | - | |

---

## 四、已知问题提示

以下是已知的典型硬编码问题（排查时重点关注）：

1. **M9 消息模块** — `message_page.dart` 大量硬编码（`'Messages'`, `'All'`, `'Requests'`, `'New Message'`, `'Search users...'` 等），对应 ARB Key 已存在但未使用
2. **M14 注册模块** — `signup.dart` 包含**法语硬编码**（`'Changer de photo de profil'`, `'Photothèque'`, `'Appareil photo'` 等）及英文硬编码
3. **M15 设置模块** — `settings.dart` 中 `'Communities'` 未走 l10n
4. **共享组件** — `widget/feedpost.dart` 被多个模块引用，是高优先级排查对象

---

## 五、执行提示词模板

> 以下是一段可复用的提示词。每次执行一个模块的排查与修复时，将 `{模块编号}` 替换为实际值（如 `M1`、`M9`、`共享组件`）后发送即可。

```
请按照 docs/i18n-audit-guide.md 中的排查规则（6 步流程），对 {模块编号} 模块执行完整的 i18n 本地化排查与修复。

具体要求：

1. 先阅读 docs/i18n-audit-guide.md 了解模块文件清单和排查规则
2. 逐文件扫描所有硬编码字符串（重点关注 Text('...')、hintText、Tab(text:)、Dialog、SnackBar、Tooltip 等），列出完整的问题清单（文件:行号 + 硬编码原文 + 是否已有 ARB Key）
3. 对于已有 ARB Key 的硬编码，直接替换为 AppLocalizations.of(context)!.keyName
4. 对于没有 ARB Key 的硬编码，在 client/lib/l10n/app_en.arb 和 app_zh.arb 中新增对应 Key 和翻译，然后运行 flutter gen-l10n 生成代码，最后替换硬编码
5. 全部替换完成后，运行 flutter analyze 验证无编译错误
6. 将排查结果更新到 docs/i18n-audit-guide.md 的排查记录表格中
```

**使用示例**：

- 排查 M1：将 `{模块编号}` 替换为 `M1`
- 排查 M9：将 `{模块编号}` 替换为 `M9`
- 排查共享组件：将 `{模块编号}` 替换为 `共享组件`
