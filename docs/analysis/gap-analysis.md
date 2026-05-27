# 客户端 vs 服务端 API — 差异分析报告

> 生成日期：2026-05-27
> 对比基准：`client-implementation-analysis.md` vs `server-api-analysis.md`
> 目的：穷举客户端未实现、未对接、与 API 不一致的所有差异项

---

## 目录

1. [整体概览](#1-整体概览)
2. [完全缺失的模块](#2-完全缺失的模块)
3. [各模块缺失的端点](#3-各模块缺失的端点)
4. [Service 已实现但 UI 未对接](#4-service-已实现但-ui-未对接)
5. [API 端点路径/参数不匹配](#5-api-端点路径参数不匹配)
6. [数据模型字段缺失](#6-数据模型字段缺失)
7. [发帖功能参数缺失](#7-发帖功能参数缺失)
8. [用户设置 UI 缺失](#8-用户设置-ui-缺失)
9. [UI 交互占位/未完成](#9-ui-交互占位未完成)
10. [代码质量问题（影响功能）](#10-代码质量问题影响功能)
11. [遗留/废弃代码待清理](#11-遗留废弃代码待清理)
12. [差异统计汇总](#12-差异统计汇总)

---

## 1. 整体概览

| 维度 | 服务端 API | 客户端实现 | 差距 |
|------|-----------|-----------|------|
| API 模块 | 9 个 | 7 个（缺 Message、Topic） | 2 个模块完全缺失 |
| 总端点数 | ~130 | 52 | 78 个端点未覆盖 |
| Service 层 | — | 54 方法 | 基础模块已覆盖，扩展功能大量缺失 |
| UI 页面 | — | 9 个活跃页面 | 多个模块无 UI |

---

## 2. 完全缺失的模块

### 2.1 消息模块 (Message) — 完全缺失

> 服务端提供 25+ 端点，客户端 **0 个 Service / 0 个 State / 0 个 UI 页面**

缺失的全部功能：

| 功能子领域 | 缺失内容 |
|-----------|---------|
| **私信会话** | 会话列表、会话消息列表、隐藏/验证/置顶会话 |
| **消息收发** | 发送消息、标记已读 |
| **消息反应** | 添加/删除消息反应（emoji） |
| **群聊** | 创建群聊、群聊列表/详情/更新、成员管理、邀请链接、加入/退出/审批 |
| **消息搜索** | 按关键词搜索消息 |
| **消息设置** | 获取/更新消息设置 |
| **推荐用户** | 推荐聊天用户、搜索可聊天用户 |
| **隐藏消息** | 查看已隐藏的会话列表 |

**需新建文件**：`message_service.dart`、`message_state.dart`、至少 3-5 个 UI 页面

### 2.2 话题模块 (Topic) — 基本缺失

> 服务端提供 10 个端点，客户端仅有搜索结果中的话题展示

缺失的全部功能：

| API 端点 | 缺失内容 |
|---------|---------|
| `GET /topic/trending` | 独立的热门话题列表（当前通过 SearchService.getHotTopics 间接获取） |
| `GET /topic/list` | 话题列表（分页，按来源筛选） |
| `GET /topic/detail/{topic_id}` | 话题详情页 |
| `POST /topic/follow/{topic_id}` | 关注话题（TopicTile 关注按钮无功能） |
| `DELETE /topic/follow/{topic_id}` | 取消关注话题 |
| `POST /topic/mute/{topic_id}` | 静音话题 |
| `DELETE /topic/mute/{topic_id}` | 取消静音话题 |
| `GET /topic/muted` | 已静音话题列表 |
| `GET /topic/posts/{topic_id}` | 话题下的帖子列表 |
| `GET /topic/related/{topic_id}` | 相关话题推荐 |

**需新建文件**：`topic_service.dart`、`topic_state.dart`、话题详情页、话题帖子列表页

### 2.3 社区模块 (Community) — 完全缺失

> 服务端提供 8 个端点，客户端 **0 个 Service / 0 个 State / 0 个 UI 页面**

缺失的全部功能：

| API 端点 | 缺失内容 |
|---------|---------|
| `GET /community/list` | 社区列表 |
| `GET /community/detail/{community_id}` | 社区详情 |
| `POST /community/join` | 加入社区 |
| `DELETE /community/leave/{community_id}` | 退出社区 |
| `GET /community/members/{community_id}` | 社区成员列表 |
| `GET /community/posts/{community_id}` | 社区帖子列表（含 Flair 标签） |
| `POST /community/{community_id}/champion/{user_id}` | 设置 Champion |
| `DELETE /community/{community_id}/champion/{user_id}` | 取消 Champion |

**需新建文件**：`community_service.dart`、`community_state.dart`、社区列表/详情/成员页面

---

## 3. 各模块缺失的端点

### 3.1 用户模块 (User) — 已实现 7/25 端点，缺失 18 个

| # | 缺失端点 | 方法 | 功能说明 |
|---|---------|------|---------|
| 1 | `/user/device-token/register` | POST | 注册设备推送令牌 |
| 2 | `/user/device-token/deregister` | POST | 注销设备推送令牌 |
| 3 | `/user/relation-control` | POST | 添加关系管控（静音/限制/拉黑） |
| 4 | `/user/relation-control/{target_user_id}` | DELETE | 移除关系管控 |
| 5 | `/user/relation-control/list` | GET | 关系管控列表（查看已静音/限制/拉黑的用户） |
| 6 | `/user/save-collections` | POST | 创建收藏夹 |
| 7 | `/user/save-collections` | GET | 收藏夹列表 |
| 8 | `/user/save-collections/{collection_id}` | DELETE | 删除收藏夹 |
| 9 | `/user/hidden-words` | GET | 隐藏词列表 |
| 10 | `/user/hidden-words` | POST | 添加隐藏词 |
| 11 | `/user/hidden-words/{word_id}` | DELETE | 删除隐藏词 |
| 12 | `/user/links` | GET | 链接列表 |
| 13 | `/user/links` | POST | 添加链接 |
| 14 | `/user/links/{link_id}` | PUT | 更新链接 |
| 15 | `/user/links/{link_id}` | DELETE | 删除链接 |
| 16 | `/user/account-status` | GET | 账号状态 |
| 17 | `/user/profile` (部分字段) | PUT | 编辑资料缺少 `pronouns`、`gender`、`location`、`is_private`、`account_type` 字段 |

### 3.2 帖子模块 (Post) — 已实现 22/42 端点，缺失 20 个

| # | 缺失端点 | 方法 | 功能说明 |
|---|---------|------|---------|
| 1 | `/post/{post_id}/edit-history` | GET | 帖子编辑历史 |
| 2 | `/post/share/{post_id}` | POST | 分享帖子（UI 无入口） |
| 3 | `/post/reply/pin/{reply_id}` | POST | 置顶回复 |
| 4 | `/post/reply/pin/{reply_id}` | DELETE | 取消置顶回复 |
| 5 | `/post/reply/pending/{post_id}` | GET | 待审核回复列表 |
| 6 | `/post/reply/pending/{post_id}/approve` | POST | 批准待审核回复 |
| 7 | `/post/reply/pending/{post_id}/reject` | POST | 拒绝待审核回复 |
| 8 | `/post/poll/{post_id}` | GET | 获取投票结果（当前仅在投票后获取） |
| 9 | `/post/nearby` | POST | 附近位置帖子计数 |
| 10 | `/post/scheduled` | GET | 定时帖子列表 |
| 11 | `/post/{post_id}/schedule` | DELETE | 取消定时帖子 |
| 12 | `/post/guest-reply-request` | POST | 申请回复幽灵帖 |
| 13 | `/post/guest-reply-request/{post_id}/approve` | POST | 批准幽灵帖回复 |
| 14 | `/post/guest-reply-request/{post_id}/reject` | POST | 拒绝幽灵帖回复 |
| 15 | `/post/guest-reply-request/{post_id}/pending` | GET | 待处理幽灵帖回复请求 |
| 16 | `/post/draft` | POST | 保存草稿 |
| 17 | `/post/draft/list` | GET | 草稿列表 |
| 18 | `/post/draft/{draft_id}` | GET | 草稿详情 |
| 19 | `/post/draft/{draft_id}` | DELETE | 删除草稿 |
| 20 | `/post/oembed` | GET | 帖子 oEmbed 嵌入 |

### 3.3 关注模块 (Follow) — 已实现 7/7 端点，但存在路径不匹配

> 端点数量完整，但 API 路径有差异（见第 5 节）

### 3.4 搜索模块 (Search) — 已实现 6/6 端点

> 搜索模块端点覆盖完整。

### 3.5 通知模块 (Notification) — 已实现 3/3 端点

> Service 层完整，但 UI 未对接（见第 4 节）。

### 3.6 杂项模块 (Misc) — 已实现 1/4 端点

| # | 缺失端点 | 方法 | 功能说明 |
|---|---------|------|---------|
| 1 | `/public-key` | GET | 获取 RSA 公钥 |
| 2 | `/moderation/callback` | POST | 内容审核回调（服务端回调，客户端不需要） |
| 3 | `/group/{invite_code}` | GET | 群邀请链接落地页（Web 端，客户端可能不需要） |

> 注：`/moderation/callback` 和 `/group/{invite_code}` 为服务端/Web 端接口，客户端通常不需要实现。

---

## 4. Service 已实现但 UI 未对接

| Service 方法 | 所属模块 | UI 状态 | 说明 |
|-------------|---------|--------|------|
| `getNotifications()` | Notification | 占位页面 | NotificationPage 使用假数据，未调用 NotificationService |
| `markAsRead()` | Notification | 无 UI | 没有标记已读的交互入口 |
| `getUnreadCount()` | Notification | 无 UI | 未读角标未显示 |
| `followUser()` / `unfollowUser()` | Follow | 按钮存在但无功能 | ProfileState 有运行时 bug 导致崩溃 |
| `repost()` | Post | 无 UI 入口 | FeedPostWidget 转发按钮无手势处理 |
| `reportPost()` | Post | 无 UI 入口 | 更多菜单(...)按钮无功能 |
| `savePost()` / `unsavePost()` | Post | 无 UI 入口 | 收藏按钮无交互 |
| `pinPost()` / `unpinPost()` | Post | 无 UI 入口 | 置顶功能无交互入口 |
| `createReply()` | Post | 打开空白 BottomSheet | 评论按钮存在但内容为空 |
| `getReplies()` | Post | 无 UI 展示 | 回复列表未渲染 |
| `likeReply()` / `unlikeReply()` | Post | 无 UI | 回复点赞无交互 |
| `hideReply()` / `unhideReply()` | Post | 无 UI | 回复隐藏无交互 |
| `getSavedPosts()` | Post | 无 UI 页面 | 已收藏帖子列表页缺失 |
| `getUserPosts()` | Post | 部分对接 | 仅 MyProfilePage 的 Threads Tab 使用 |
| `getSettings()` / `updateSettings()` | User | 无 UI | 设置页仅语言切换和登出可用，通知/隐私设置无 UI |

---

## 5. API 端点路径/参数不匹配

### 5.1 关注模块路径差异

| 客户端 Service 方法 | 客户端调用的路径 | 服务端 API 实际路径 | 问题 |
|-------------------|---------------|-----------------|------|
| `FollowService.getFollowing()` | `follow/following/{userId}` | `follow/following` | 客户端多了 `/{userId}` 路径参数，服务端不需要（服务端从 Token 获取当前用户） |
| `FollowService.getMutualFollowers()` | `follow/mutual/{userId}` | `follow/mutual` | 同上，客户端多了 `/{userId}` |
| `FollowService.getFollowers()` | `follow/followers/{userId}` | `follow/followers/{user_id}` | 路径匹配（这个正确） |

### 5.2 关注统计字段差异

服务端 `FollowStatsResponse` 返回 5 个字段：
- `followers_count`, `following_count`, `is_following`, `is_followed_by_me`, `is_mutual`

客户端 `FollowStats` 类仅解析 3 个字段：
- `followersCount`, `followingCount`, `isFollowing`

**缺失字段**：`is_followed_by_me`（我是否关注了对方）、`is_mutual`（是否互关）

---

## 6. 数据模型字段缺失

### 6.1 UserModel 缺失字段

服务端 `UserProfileResponse` 提供 16 个字段，客户端 `UserModel` 缺失：

| 服务端字段 | 说明 | 客户端状态 |
|-----------|------|----------|
| `pronouns` | 人称代词 | 缺失 |
| `gender` | 性别 | 缺失 |
| `location` | 所在地 | 缺失 |
| `is_verified` | 是否认证 | 缺失 |
| `account_type` | 账号类型 | 缺失 |
| `last_active_time` | 最后活跃时间 | 缺失 |
| `create_time` | 注册时间 | 部分映射（`createAt`） |
| `website_url` | 个人网站 | 映射为 `link`（字段名不一致） |

### 6.2 PostModel 缺失字段

| 服务端字段 | 说明 | 客户端状态 |
|-----------|------|----------|
| `shares_count` | 分享数 | fromJson 未解析，始终为 null |
| `pollData` | 投票数据 | fromJson 未解析，始终为 null |
| `location` | 位置信息 | 缺失 |
| `topic_ids` / `topics` | 关联话题 | 缺失 |
| `is_ghost` | 是否幽灵帖 | 缺失 |
| `community_id` | 所属社区 | 缺失 |
| `reply_settings` | 回复权限设置 | 缺失 |
| `quote_repost_id` | 引用转发原帖 | 缺失 |
| `scheduled_time` | 定时发布时间 | 缺失 |
| `is_pinned` | 是否置顶 | 缺失 |
| `edit_history` | 编辑历史 | 缺失 |

### 6.3 PostModel 遗留字段

| 客户端字段 | 说明 | 问题 |
|-----------|------|------|
| `key` | Firebase Key | 服务端不使用，应为遗留字段 |
| `comment` | 评论列表 | 从未填充数据，死代码 |

---

## 7. 发帖功能参数缺失

客户端 `ComposePost` 当前支持的参数：
- `content`（文本）
- `media_urls`（图片列表，最多 10 张）
- `poll`（投票选项）
- `reply_settings`（回复权限）

**缺失的 CreatePostRequest 参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `location` | string, nullable | 位置信息 |
| `topic_ids` | array<integer> | 关联话题 ID 列表 |
| `is_ghost` | boolean | 是否幽灵帖 |
| `community_id` | integer, nullable | 发到指定社区 |
| `quote_repost_id` | integer, nullable | 引用转发的原帖 ID |
| `scheduled_time` | string, nullable | 定时发布时间 |
| `is_ai` | boolean | AI 生成标记 |

---

## 8. 用户设置 UI 缺失

服务端 `SettingsResponse` 提供 22 个设置项，客户端 `SettingsPage` 仅有语言切换和登出。

### 缺失的设置页面/功能

| 设置类别 | 设置项 | 当前状态 |
|---------|-------|---------|
| **回复权限** | `reply_allow_type`（4 种级别） | 无 UI |
| **提及权限** | `mention_allow_type`（3 种级别） | 无 UI |
| **消息设置** | `message_request_enabled`, `message_request_allow_type` | 无 UI（消息模块整体缺失） |
| **通知开关（11 项）** | 点赞/回复/提及/关注/热门/系统/群消息/引用/转发/投票/社群 | 无 UI |
| **隐私设置** | `show_read_receipts`, `show_online_status`, `allow_recommend` | 无 UI |
| **显示设置** | `hide_likes_count` | 无 UI |
| **互动限制** | `interaction_restriction_type`（3 种级别） | 无 UI |
| **静默模式** | `silent_mode` | 无 UI |
| **内容分级** | `content_rating`（3 种级别） | 无 UI |

---

## 9. UI 交互占位/未完成

### 9.1 FeedPostWidget

| 交互项 | 状态 | 涉及的缺失 Service/逻辑 |
|-------|------|----------------------|
| 点赞 | 已完成（乐观更新） | — |
| 评论 | 占位 — 打开空白 BottomSheet | 回复列表 + 创建回复 UI |
| 转发 | 未实现 — 无手势处理 | `repost()` 已有 Service |
| 分享 | 未实现 — 无手势处理 | `share()` Service 缺失 |
| 更多菜单(...) | 未实现 — 无手势处理 | 举报/收藏/置顶等操作入口 |
| 头像/用户名点击 | 未实现 — 无跳转 | ProfilePage 路由跳转 |
| 收藏按钮 | 无 UI | `savePost()` 已有 Service |
| 话题标签点击 | 无 UI | 话题详情页缺失 |

### 9.2 页面级未完成

| 页面 | 未完成内容 |
|------|----------|
| **NotificationPage** | 整页为占位 — 使用 SearchState 假数据，筛选按钮无功能，列表固定 200px 高度 |
| **MyProfilePage** | Replies Tab 始终显示空状态；无置顶帖子展示 |
| **ProfilePage（他人）** | TabBarView 内容为硬编码空文本；关注按钮有运行时崩溃 bug |
| **SettingsPage** | 仅语言切换和登出可用，其余菜单项为纯展示 |
| **FeedPage** | 顶部快捷发帖区域无功能 |

---

## 10. 代码质量问题（影响功能）

| # | 问题 | 影响 | 优先级 |
|---|------|------|--------|
| 1 | ProfileState 中 `userId` 和 `_userModel` 为 `late` 未初始化 | 访问 `isMyProfile` 或 `followUser()` 触发 `LateInitializationError` 崩溃 | 高 |
| 2 | 无 Token 自动刷新拦截器 | 401 时不自动刷新，仅手动刷新一次 | 高 |
| 3 | Feed 失败回退到 mock 数据 `_loadMockData()` | 用户无法区分真假数据 | 中 |
| 4 | PostModel.fromJson 不解析 `sharesCount` 和 `pollData` | 始终为 null | 中 |
| 5 | 大部分 catch 块静默吞掉异常 | UI 无法展示错误信息 | 中 |
| 6 | UserModel toJson/fromJson 字段名不兼容 | 往返序列化丢失数据 | 低 |
| 7 | UserService 和 FollowService 重复定义 `getFollowStats()` | 同一端点两份实现 | 低 |
| 8 | Base URL 硬编码为局域网 IP `192.168.1.27:8005` | 无法用于生产环境 | 低 |

---

## 11. 遗留/废弃代码待清理

| 文件 | 类名 | 说明 |
|------|------|------|
| `auth/signup/signup.dart` | Signup | 旧版资料设置页 |
| `auth/signup/email.dart` | EmailPage | 旧版邮箱注册页（法文文本） |
| `auth/signup/account.dart` | SwitchAccount | 账号切换页 |
| `auth/onboard/privacy.dart` | PrivacyPage | 旧版隐私引导页 |
| `auth/onboard/follow.dart` | FollowerPage | 旧版关注推荐引导页（mock 数据） |
| `auth/onboard/thread.dart` | ThreadPage | 旧版 Threads 介绍页 |
| `pages/composePost/widget/composeBottomIconWidget.dart` | ComposeBottomIconWidget | 未使用的图片选择组件 |
| `widget/language_switcher.dart` | LanguageSwitcher | 未使用的语言切换组件 |
| `network/api_client.dart` | `patch()` 方法 | 已定义但从未被调用 |

---

## 12. 差异统计汇总

### 按类型统计

| 差异类型 | 数量 | 说明 |
|---------|------|------|
| **完全缺失的模块** | 3 | Message（25+ 端点）、Topic（10 端点）、Community（8 端点） |
| **缺失的 Service 端点** | ~58 | User: 16, Post: 20, Misc: 1-2, Message: 25+, Topic: 10, Community: 8 |
| **Service 已实现但 UI 未对接** | ~15 | 通知、关注操作、回复、收藏、置顶、转发、举报等 |
| **API 路径/参数不匹配** | 2 | FollowService 中 following 和 mutual 路径多传了 userId |
| **数据模型字段缺失** | ~20 | UserModel 缺 7 字段, PostModel 缺 11 字段 |
| **发帖参数缺失** | 7 | location, topic_ids, is_ghost, community_id, quote_repost_id, scheduled_time, is_ai |
| **设置项 UI 缺失** | 22 | 全部设置项无 UI |
| **UI 交互未完成** | 8+ | FeedPostWidget 多项交互、页面级占位 |

### 按优先级建议的开发顺序

| 优先级 | 模块/功能 | 理由 |
|--------|---------|------|
| P0 | 修复 ProfileState `late` 初始化崩溃 | 阻塞性 bug |
| P0 | 通知页 UI 对接 | Service 已完成，只需 UI |
| P1 | FeedPostWidget 交互完善（转发/评论/收藏/分享） | 核心用户体验 |
| P1 | 用户资料编辑补充（pronouns/gender/location/is_private） | API 已支持 |
| P1 | 用户设置页完整实现 | API 已支持 |
| P1 | 关注模块路径修正 + UI 对接 | 修正 API 不匹配 |
| P2 | 消息模块（Service + State + UI） | 大型新模块 |
| P2 | 话题模块（Service + State + UI） | 中型新模块 |
| P2 | 草稿功能（Service + UI） | 4 个端点 |
| P3 | 社区模块（Service + State + UI） | 中型新模块 |
| P3 | 回复审核/幽灵帖回复请求 | 管理员功能 |
| P3 | 关系管控（静音/限制/拉黑） | 3 个端点 |
| P3 | 收藏夹管理 | 3 个端点 |
| P3 | 隐藏词/链接管理 | 6 个端点 |
| P4 | 定时帖子、附近帖子、oEmbed | 辅助功能 |
