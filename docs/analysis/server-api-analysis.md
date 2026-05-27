# Instagram Threads Clone — 服务端 API 功能分析报告

> 生成日期：2026-05-27
> 分析范围：`openapi_docs/` 目录下全部 OpenAPI 3.1.0 JSON 文档
> API 文档版本：0.1.0

---

## 目录

1. [API 总览](#1-api-总览)
2. [通用约定](#2-通用约定)
3. [功能模块详析](#3-功能模块详析)
   - [3.1 用户模块 (User)](#31-用户模块-user)
   - [3.2 帖子模块 (Post)](#32-帖子模块-post)
   - [3.3 关注模块 (Follow)](#33-关注模块-follow)
   - [3.4 搜索模块 (Search)](#34-搜索模块-search)
   - [3.5 消息模块 (Message)](#35-消息模块-message)
   - [3.6 社区模块 (Community)](#36-社区模块-community)
   - [3.7 话题模块 (Topic)](#37-话题模块-topic)
   - [3.8 通知模块 (Notification)](#38-通知模块-notification)
   - [3.9 杂项模块 (Misc)](#39-杂项模块-misc)
4. [数据模型汇总](#4-数据模型汇总)
5. [统计摘要](#5-统计摘要)

---

## 1. API 总览

服务端 API 共分为 **9 个模块**，提供 **约 150 个端点**：

| 模块 | 文档文件 | 端点数量 | 功能概述 |
|------|---------|---------|---------|
| 用户 (User) | `user.json` | 25 | 注册/登录、资料管理、设置、关系管控、收藏夹、隐藏词、链接管理 |
| 帖子 (Post) | `post.json` | 42 | 帖子 CRUD、互动（赞/转发/收藏/置顶）、回复、投票、草稿、幽灵帖、Feed、oEmbed |
| 关注 (Follow) | `follow.json` | 7 | 关注/取关、关注统计、关注列表、粉丝列表、互关、推荐关注 |
| 搜索 (Search) | `search.json` | 5 | 综合搜索、搜索历史、热门话题、热门帖子 |
| 消息 (Message) | `message.json` | 25+ | 私信会话、消息收发、群聊、消息反应、消息搜索、消息设置 |
| 社区 (Community) | `community.json` | 8 | 社区列表/详情、加入/退出、成员管理、社区帖子、Champion |
| 话题 (Topic) | `topic.json` | 10 | 话题列表/详情、关注/取关、静音、话题帖子、相关话题推荐 |
| 通知 (Notification) | `notification.json` | 3 | 通知列表、标记已读、未读数 |
| 杂项 (Misc) | `_misc.json` | 4 | RSA 公钥、内容审核回调、群邀请链接、文件上传 |
| **合计** | **9 个文件** | **~130** | |

---

## 2. 通用约定

### 2.1 统一响应包装

所有 API 均使用 `ResponseModel<T>` 作为外层包装：

```json
{
  "code": 200,        // integer, 必填 — 状态码
  "msg": "success",   // string, 必填 — 消息
  "data": T | null    // 泛型数据，可为 null
}
```

### 2.2 统一分页结构

列表类接口使用 `PageMeta<T>` 结构：

```json
{
  "total": 100,     // integer — 总数
  "page": 1,        // integer — 当前页码
  "size": 20,       // integer — 每页条数
  "items": [T]      // array<T> — 数据列表
}
```

### 2.3 通用请求头

| Header | 类型 | 说明 | 使用场景 |
|--------|------|------|---------|
| `Authorization` | string | 登录 Token（Bearer） | 需要身份验证的端点 |
| `device-os` | string | 设备操作系统 | 几乎所有端点 |
| `user-agent` | string | 用户代理信息 | 注册/登录/部分帖子端点 |
| `device-name` | string | 设备名称（如 ipad） | 注册/登录/部分帖子端点 |

### 2.4 错误响应

验证错误返回 `HTTPValidationError`：

```json
{
  "detail": [
    {
      "loc": ["body", "username"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

---

## 3. 功能模块详析

---

### 3.1 用户模块 (User)

> 文件：`user.json` | 端点数：**25**

#### 3.1.1 认证与登录

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | POST | `/user/register` | 用户名注册 | Body: `username`(2-50), `password`(5-50), `confirm_password`(5-50) | `OKResponse` |
| 2 | POST | `/user/signin` | 用户名登录 | Body: `username`(2-50), `password`(5-50) | `SigninResponse` |
| 3 | POST | `/user/token/refresh` | 刷新令牌 | Body: `refresh_token` | `RefreshTokenResponse` |
| 4 | DELETE | `/user/logout` | 退出登录 | Header: Authorization | `OKResponse` |
| 5 | PUT | `/user/modify_password` | 修改密码 | Body: `old_password`, `password`, `confirm_password` | `OKResponse` |

**SigninResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 用户 ID |
| `username` | string | 用户名（max 32） |
| `avatar` | string | 头像 |
| `access_token` | string | 访问令牌 |
| `refresh_token` | string | 刷新令牌 |

#### 3.1.2 用户资料

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 6 | GET | `/user/me` | 获取当前用户信息 | Header: Authorization | `MeUserResponse` |
| 7 | GET | `/user/profile/{user_id}` | 获取用户资料 | Path: `user_id` | `UserProfileResponse` |
| 8 | PUT | `/user/profile` | 更新用户资料 | Body: 见下方 | `OKResponse` |

**MeUserResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 用户 ID |
| `username` | string | 用户名（max 32） |
| `avatar` | string | 头像 |

**UserProfileResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | integer | 用户 ID |
| `display_name` | string | 显示名称 |
| `avatar_url` | string | 头像 URL |
| `bio` | string | 个人简介 |
| `pronouns` | string | 人称代词 |
| `gender` | integer | 性别：1=未设置, 2=男, 3=女, 4=其他 |
| `location` | string | 所在地 |
| `website_url` | string | 个人网站 |
| `is_verified` | integer | 是否认证：0=否, 1=是 |
| `is_private` | integer | 是否私密：0=否, 1=是 |
| `account_type` | integer | 账号类型：1=个人, 2=创作者, 3=商业 |
| `posts_count` | integer | 帖子数 |
| `followers_count` | integer | 粉丝数 |
| `following_count` | integer | 关注数 |
| `last_active_time` | string/null | 最后活跃时间 |
| `create_time` | string | 注册时间 |

**UpdateProfileRequest 字段**（全部可选）：
`display_name`(max 100), `avatar_url`, `bio`(max 500), `pronouns`(max 50), `gender`(1-4), `location`(max 100), `website_url`(max 500), `is_private`(0/1), `account_type`(1-3)

#### 3.1.3 用户设置

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 9 | GET | `/user/settings` | 获取用户设置 | Header: Authorization | `SettingsResponse` |
| 10 | PUT | `/user/settings` | 更新用户设置 | Body: 见下方 | `OKResponse` |

**SettingsResponse 数据结构**（22 个字段）：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `reply_allow_type` | integer | 1 | 回复权限：1=所有人, 2=你的粉丝, 3=你关注的主页, 4=你提及的主页 |
| `mention_allow_type` | integer | 1 | 提及权限：1=所有人, 2=你关注的用户, 3=仅互关 |
| `message_request_enabled` | integer | 1 | 陌生消息开关：0=关闭, 1=开启 |
| `message_request_allow_type` | integer | 1 | 谁能发消息：1=仅你关注的用户, 2=任何人 |
| `notify_likes` | integer | 1 | 点赞通知 |
| `notify_replies` | integer | 1 | 回复通知 |
| `notify_mentions` | integer | 1 | 提及通知 |
| `notify_follows` | integer | 1 | 关注通知 |
| `notify_trending` | integer | 1 | 热门通知 |
| `notify_system` | integer | 1 | 系统通知 |
| `notify_group_messages` | integer | 1 | 群消息通知 |
| `notify_quotes` | integer | 1 | 引用转发通知 |
| `notify_reposts` | integer | 1 | 纯转发通知 |
| `notify_polls` | integer | 1 | 投票结果通知 |
| `notify_communities` | integer | 1 | 社群动态通知 |
| `show_read_receipts` | integer | 1 | 显示已读回执 |
| `show_online_status` | integer | 1 | 显示在线状态 |
| `allow_recommend` | integer | 1 | 允许推荐 |
| `hide_likes_count` | integer | 0 | 隐藏点赞数 |
| `interaction_restriction_type` | integer | 1 | 互动限制：1=无限制, 2=关注超过1周, 3=仅互关 |
| `silent_mode` | integer | 0 | 静默模式 |
| `content_rating` | integer | 1 | 内容分级：1=全部, 2=青少年, 3=成人 |

#### 3.1.4 设备令牌

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 11 | POST | `/user/device-token/register` | 注册设备令牌 | Body: `device_token`(5-100) | `OKResponse` |
| 12 | POST | `/user/device-token/deregister` | 注销设备令牌 | Body: `device_token`(5-100) | `OKResponse` |

#### 3.1.5 关注请求审批（私密账号）

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 13 | GET | `/user/follow-requests/pending` | 获取待审批关注请求 | Header: Authorization | `List<FollowRequestResponse>` |
| 14 | POST | `/user/follow-requests/{request_id}/approve` | 审批关注请求 | Path: `request_id`; Body: `action`(1=批准, 2=拒绝) | `OKResponse` |

**FollowRequestResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 请求 ID |
| `user_id` | integer | 被关注者 ID |
| `requester_id` | integer | 请求者 ID |
| `requester_username` | string | 请求者用户名 |
| `requester_avatar` | string | 请求者头像 |
| `requester_display_name` | string | 请求者显示名称 |
| `status` | integer | 状态：1=待审批, 2=已批准, 3=已拒绝 |
| `create_time` | string | 请求时间 |

#### 3.1.6 关系管控

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 15 | POST | `/user/relation-control` | 添加关系管控 | Body: `target_user_id`, `control_type`(1=静音, 2=限制, 3=拉黑), `reason`(max 255) | `OKResponse` |
| 16 | DELETE | `/user/relation-control/{target_user_id}` | 移除关系管控 | Path: `target_user_id` | `OKResponse` |
| 17 | GET | `/user/relation-control/list` | 关系管控列表 | Query: `control_type`(1/2/3, 可选) | `List` |

#### 3.1.7 收藏夹

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 18 | POST | `/user/save-collections` | 创建收藏夹 | Body: `name`(max 100) | `SaveCollectionResponse` |
| 19 | GET | `/user/save-collections` | 收藏夹列表 | Header: Authorization | `List<SaveCollectionResponse>` |
| 20 | DELETE | `/user/save-collections/{collection_id}` | 删除收藏夹（软删除） | Path: `collection_id` | `OKResponse` |

**SaveCollectionResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 收藏夹 ID |
| `name` | string | 收藏夹名称 |
| `is_default` | boolean | 是否默认收藏夹 |
| `save_count` | integer | 收藏帖子数量 |
| `create_time` | string | 创建时间 |

#### 3.1.8 隐藏词管理

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 21 | GET | `/user/hidden-words` | 隐藏词列表 | Header: Authorization | `List` |
| 22 | POST | `/user/hidden-words` | 添加隐藏词 | Query: `word_type`(1=关键词, 2=短语, 3=emoji), `content` | `OKResponse` |
| 23 | DELETE | `/user/hidden-words/{word_id}` | 删除隐藏词 | Path: `word_id` | `OKResponse` |

#### 3.1.9 链接管理

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 24 | GET | `/user/links` | 链接列表 | Header: Authorization | `List` |
| 25 | POST | `/user/links` | 添加链接 | Query: `title`, `url` | `OKResponse` |
| 26 | PUT | `/user/links/{link_id}` | 更新链接 | Path: `link_id`; Query: `title`, `url` | `OKResponse` |
| 27 | DELETE | `/user/links/{link_id}` | 删除链接 | Path: `link_id` | `OKResponse` |

#### 3.1.10 账号状态

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 28 | GET | `/user/account-status` | 账号状态 | Header: Authorization | `dict` |

---

### 3.2 帖子模块 (Post)

> 文件：`post.json` | 端点数：**42**

#### 3.2.1 帖子 CRUD

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | POST | `/post/create` | 创建帖子 | Body: `CreatePostRequest`（见下方） | `PostResponse` |
| 2 | GET | `/post/detail/{post_id}` | 帖子详情 | Path: `post_id` | `PostResponse` |
| 3 | DELETE | `/post/{post_id}` | 删除帖子 | Path: `post_id` | `OKResponse` |
| 4 | PUT | `/post/{post_id}` | 编辑帖子（15分钟内，最多5次） | Path: `post_id`; Body: `EditPostRequest` | `PostResponse` |
| 5 | GET | `/post/{post_id}/edit-history` | 帖子编辑历史 | Path: `post_id` | `List<EditHistoryResponse>` |

**CreatePostRequest 关键字段**：
- `content`(string, max 500) — 帖子文本内容
- `media_urls`(array) — 媒体 URL 列表，最多 10 个
- `location`(string, nullable) — 位置信息
- `topic_ids`(array<integer>) — 关联话题 ID
- `poll` — 投票配置（可选）
- `is_ghost`(boolean) — 是否幽灵帖
- `community_id`(integer, nullable) — 所属社区 ID
- `reply_settings`(integer) — 回复设置
- `quote_repost_id`(integer, nullable) — 引用转发的原帖 ID
- `scheduled_time`(string, nullable) — 定时发布时间
- `is_ai`(boolean) — AI 生成标记

#### 3.2.2 帖子互动

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 6 | POST | `/post/like/{post_id}` | 点赞帖子 | Path: `post_id` | `OKResponse` |
| 7 | DELETE | `/post/like/{post_id}` | 取消点赞 | Path: `post_id` | `OKResponse` |
| 8 | POST | `/post/repost/{post_id}` | 转发帖子 | Path: `post_id`; Body: `RepostRequest` | `OKResponse` |
| 9 | POST | `/post/share/{post_id}` | 分享帖子 | Path: `post_id` | `OKResponse` |
| 10 | POST | `/post/report` | 举报内容 | Body: `CreateReportRequest` | `ReportResponse` |
| 11 | POST | `/post/save/{post_id}` | 收藏帖子 | Path: `post_id` | `OKResponse` |
| 12 | DELETE | `/post/save/{post_id}` | 取消收藏 | Path: `post_id` | `OKResponse` |
| 13 | POST | `/post/pin/{post_id}` | 置顶帖子 | Path: `post_id` | `OKResponse` |
| 14 | DELETE | `/post/pin/{post_id}` | 取消置顶 | Path: `post_id` | `OKResponse` |

#### 3.2.3 回复系统

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 15 | POST | `/post/reply` | 创建回复 | Body: `CreateReplyRequest` | `ReplyResponse` |
| 16 | GET | `/post/reply/list/{post_id}` | 回复列表（分页） | Path: `post_id`; Query: `page`, `size`, `parent_id`(子回复), `sort_by`(relevant/recent) | `PageMeta<ReplyResponse>` |
| 17 | POST | `/post/reply/like/{reply_id}` | 点赞回复 | Path: `reply_id` | `OKResponse` |
| 18 | DELETE | `/post/reply/like/{reply_id}` | 取消点赞回复 | Path: `reply_id` | `OKResponse` |
| 19 | POST | `/post/reply/pin/{reply_id}` | 置顶回复 | Path: `reply_id` | `OKResponse` |
| 20 | DELETE | `/post/reply/pin/{reply_id}` | 取消置顶回复 | Path: `reply_id` | `OKResponse` |
| 21 | POST | `/post/reply/hide/{reply_id}` | 隐藏回复 | Path: `reply_id` | `OKResponse` |
| 22 | DELETE | `/post/reply/hide/{reply_id}` | 取消隐藏回复 | Path: `reply_id` | `OKResponse` |

#### 3.2.4 回复审核

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 23 | GET | `/post/reply/pending/{post_id}` | 待审核回复列表 | Path: `post_id` | `List<ReplyResponse>` |
| 24 | POST | `/post/reply/pending/{post_id}/approve` | 批准待审核回复 | Path: `post_id`; Body: `ApprovePendingReplyRequest` | `OKResponse` |
| 25 | POST | `/post/reply/pending/{post_id}/reject` | 拒绝待审核回复 | Path: `post_id`; Body: `RejectPendingReplyRequest` | `OKResponse` |

#### 3.2.5 投票

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 26 | POST | `/post/poll/{post_id}/vote` | 投票 | Path: `post_id`; Body: `VotePollRequest` | `PollResultResponse` |
| 27 | GET | `/post/poll/{post_id}` | 获取投票结果 | Path: `post_id` | `PollResultResponse` |

#### 3.2.6 Feed 与列表

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 28 | POST | `/post/nearby` | 附近位置帖子计数 | Body: `NearbyPostsRequest`（POI 列表） | `NearbyPostsResponse` |
| 29 | GET | `/post/feed` | 首页 Feed | Query: `page`, `size`, `feed_type`(1=推荐, 2=关注) | `PageMeta<PostResponse>` |
| 30 | GET | `/post/user/{user_id}/posts` | 用户帖子列表 | Path: `user_id`; Query: `page`, `size` | `PageMeta<PostResponse>` |
| 31 | GET | `/post/saved` | 已收藏帖子列表 | Query: `page`, `size` | `PageMeta<PostResponse>` |
| 32 | GET | `/post/scheduled` | 定时帖子列表 | Query: `page`, `size` | `PageMeta<PostResponse>` |
| 33 | DELETE | `/post/{post_id}/schedule` | 取消定时帖子 | Path: `post_id` | `OKResponse` |

#### 3.2.7 幽灵帖回复请求

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 34 | POST | `/post/guest-reply-request` | 申请回复幽灵帖 | Body: `post_id`, `content` | `GuestPostReplyRequestResponse` |
| 35 | POST | `/post/guest-reply-request/{post_id}/approve` | 批准幽灵帖回复请求 | Body: `request_id` | `OKResponse` |
| 36 | POST | `/post/guest-reply-request/{post_id}/reject` | 拒绝幽灵帖回复请求 | Body: `request_id` | `OKResponse` |
| 37 | GET | `/post/guest-reply-request/{post_id}/pending` | 待处理幽灵帖回复请求 | Path: `post_id` | `List<GuestPostReplyRequestResponse>` |

#### 3.2.8 草稿

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 38 | POST | `/post/draft` | 保存草稿 | Body: `SaveDraftRequest` | `DraftResponse` |
| 39 | GET | `/post/draft/list` | 草稿列表 | Query: `page`, `size` | `PageMeta<DraftResponse>` |
| 40 | GET | `/post/draft/{draft_id}` | 草稿详情 | Path: `draft_id` | `DraftResponse` |
| 41 | DELETE | `/post/draft/{draft_id}` | 删除草稿 | Path: `draft_id` | `OKResponse` |

#### 3.2.9 oEmbed

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 42 | GET | `/post/oembed` | 帖子嵌入（oEmbed 标准） | Query: `url`(格式 `https://domain/t/{short_code}`), `format` | oEmbed JSON |

---

### 3.3 关注模块 (Follow)

> 文件：`follow.json` | 端点数：**7**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | POST | `/follow/{user_id}` | 关注用户 | Path: `user_id` | `OKResponse` |
| 2 | DELETE | `/follow/{user_id}` | 取消关注 | Path: `user_id` | `OKResponse` |
| 3 | GET | `/follow/stats/{user_id}` | 关注统计 | Path: `user_id` | `FollowStatsResponse` |
| 4 | GET | `/follow/following` | 关注列表 | Query: `page`, `size`, `keyword` | `PageMeta<FollowUserItem>` |
| 5 | GET | `/follow/followers/{user_id}` | 粉丝列表 | Path: `user_id`; Query: `page`, `size`, `keyword` | `PageMeta<FollowUserItem>` |
| 6 | GET | `/follow/mutual` | 互关列表 | Query: `page`, `size` | `PageMeta<FollowUserItem>` |
| 7 | GET | `/follow/recommend` | 推荐关注 | Query: `page`, `size` | `PageMeta<RecommendUserItem>` |

**FollowStatsResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `followers_count` | integer | 粉丝数 |
| `following_count` | integer | 关注数 |
| `is_following` | integer | 是否被该用户关注：0/1 |
| `is_followed_by_me` | integer | 我是否关注了该用户：0/1 |
| `is_mutual` | integer | 是否互关：0/1 |

**FollowUserItem 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | integer | 用户 ID |
| `username` | string | 用户名 |
| `display_name` | string | 显示名称 |
| `avatar_url` | string | 头像 URL |
| `bio` | string | 个人简介 |
| `is_verified` | boolean | 是否认证 |
| `is_following` | integer | 是否正在关注 |
| `is_mutual` | integer | 是否互关 |
| `follow_time` | string | 关注时间 |
| `posts_count` | integer | 帖子数 |
| `followers_count` | integer | 粉丝数 |
| `following_count` | integer | 关注数 |

**RecommendUserItem 额外字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `reason` | string | 推荐理由 |
| `common_followers_count` | integer | 共同关注数 |

---

### 3.4 搜索模块 (Search)

> 文件：`search.json` | 端点数：**5**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/search` | 综合搜索 | Query: `keyword`(必填), `search_type`(1=综合, 2=用户, 3=话题, 4=帖子), `sort`(top/recent), `page`, `limit` | `SearchResult` |
| 2 | GET | `/search/history` | 获取搜索历史 | Query: `limit`(默认 10) | `SearchHistoryResponse` |
| 3 | DELETE | `/search/history` | 清空搜索历史 | — | `ResponseModel` |
| 4 | DELETE | `/search/history/{history_id}` | 删除单条搜索历史 | Path: `history_id` | `ResponseModel` |
| 5 | GET | `/search/hot-topics` | 获取热门话题 | Query: `limit`(默认 10) | `ResponseModel` |
| 6 | GET | `/search/trending` | 获取热门帖子 | Query: `limit`(默认 10) | `ResponseModel` |

**SearchResult 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `keyword` | string | 搜索关键词 |
| `users` | `List<SearchUserItem>` | 用户列表 |
| `topics` | `List<SearchTopicItem>` | 话题列表 |
| `posts` | `List<SearchPostItem>` | 帖子列表 |
| `total_users` | integer | 用户总数 |
| `total_topics` | integer | 话题总数 |
| `total_posts` | integer | 帖子总数 |

**SearchUserItem**：`id`, `username`, `display_name`, `avatar_url`, `is_verified`, `followers_count`
**SearchTopicItem**：`id`, `name`, `posts_count`
**SearchPostItem**：`id`, `user_id`, `username`, `display_name`, `avatar_url`, `content`, `media_count`, `likes_count`, `replies_count`, `create_time`

**SearchHistoryItem**：`id`, `keyword`, `search_type`(1-4), `result_count`, `create_time`

---

### 3.5 消息模块 (Message)

> 文件：`message.json` | 端点数：**25+**

#### 3.5.1 会话管理

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/message/conversations` | 会话列表 | Query: `page`, `size` | `PageMeta<ConversationResponse>` |
| 2 | GET | `/message/conversations/{conversation_id}/messages` | 会话消息列表 | Path: `conversation_id`; Query: `page`, `size`, `before_time` | `PageMeta<MessageResponse>` |
| 3 | POST | `/message/conversations/{conversation_id}/hide` | 隐藏会话 | Path: `conversation_id` | `OKResponse` |
| 4 | POST | `/message/conversations/{conversation_id}/verify` | 验证会话 | Path: `conversation_id` | `OKResponse` |
| 5 | POST | `/message/conversations/{conversation_id}/pin` | 置顶会话 | Path: `conversation_id` | `OKResponse` |
| 6 | DELETE | `/message/conversations/{conversation_id}/pin` | 取消置顶会话 | Path: `conversation_id` | `OKResponse` |

**ConversationResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 会话 ID |
| `peer_user_id` | integer | 对方用户 ID |
| `conversation_type` | integer | 类型：1=收件箱, 2=陌生人 |
| `last_message_content` | string | 最后一条消息内容 |
| `last_message_time` | string | 最后一条消息时间 |
| `unread_count` | integer | 未读数 |
| `is_replied` | boolean | 是否已回复 |
| `is_verified` | boolean | 是否已验证 |
| `is_hidden` | boolean | 是否已隐藏 |
| `is_pinned` | boolean | 是否已置顶 |

#### 3.5.2 消息收发

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 7 | POST | `/message/send` | 发送消息 | Body: `SendMessageRequest` | `MessageResponse` |
| 8 | POST | `/message/mark-read` | 标记已读 | Body: `conversation_id` | `OKResponse` |

**SendMessageRequest 字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `receiver_id` | integer | 接收者 ID |
| `content` | string | 消息内容（max 2000） |
| `media_type` | integer | 媒体类型：0=纯文本, 1=图片, 2=视频, 3=语音, 4=文件 |
| `media_url` | string | 媒体 URL |
| `quote_message_id` | integer | 引用消息 ID（可选） |

**MessageResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 消息 ID |
| `sender_id` | integer | 发送者 ID |
| `receiver_id` | integer | 接收者 ID |
| `content` | string | 消息内容 |
| `media_type` | integer | 媒体类型 |
| `media_url` | string | 媒体 URL |
| `is_read` | boolean | 是否已读 |
| `delivery_status` | integer | 投递状态：1=发送中, 2=已送达, 3=发送失败 |
| `read_time` | string | 已读时间 |
| `quote_message_id` | integer | 引用消息 ID |
| `reactions` | array | 消息反应列表 |
| `create_time` | string | 创建时间 |

#### 3.5.3 消息反应（Reactions）

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 9 | POST | `/message/reactions` | 添加消息反应 | Body: `message_id`, `emoji` | `OKResponse` |
| 10 | DELETE | `/message/reactions` | 删除消息反应 | Body: `message_id`, `emoji` | `OKResponse` |

#### 3.5.4 群聊

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 11 | POST | `/message/group/create` | 创建群聊（含邀请链接） | Body: `CreateGroupChatRequest` | `GroupChatResponse` |
| 12 | GET | `/message/group/list` | 群聊列表 | Query: `page`, `size` | `PageMeta<GroupChatResponse>` |
| 13 | GET | `/message/group/{group_id}` | 群聊详情 | Path: `group_id` | `GroupChatResponse` |
| 14 | PUT | `/message/group/{group_id}` | 更新群聊信息 | Path: `group_id`; Body: 更新字段 | `OKResponse` |
| 15 | GET | `/message/group/{group_id}/members` | 群成员列表 | Path: `group_id`; Query: `page`, `size` | `PageMeta<GroupMemberResponse>` |
| 16 | DELETE | `/message/group/{group_id}/members/{user_id}` | 移除群成员 | Path: `group_id`, `user_id` | `OKResponse` |
| 17 | POST | `/message/group/join` | 通过邀请链接加入 | Body: `invite_link` | `OKResponse` |
| 18 | POST | `/message/group/{group_id}/leave` | 退出群聊 | Path: `group_id` | `OKResponse` |
| 19 | GET | `/message/group/{group_id}/join-requests` | 入群请求列表 | Path: `group_id` | `List` |
| 20 | POST | `/message/group/{group_id}/join-requests/approve` | 批准入群 | Body: `request_id` | `OKResponse` |

**GroupChatResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 群聊 ID |
| `name` | string | 群名 |
| `avatar_url` | string | 群头像 |
| `invite_link` | string | 邀请链接 |
| `invite_link_enabled` | boolean | 邀请链接是否启用 |
| `need_approve` | boolean | 是否需要审批 |
| `members_count` | integer | 成员数 |
| `last_message_time` | string | 最后消息时间 |
| `create_time` | string | 创建时间 |

**GroupMemberResponse 数据结构**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | integer | 用户 ID |
| `username` | string | 用户名 |
| `display_name` | string | 显示名称 |
| `avatar_url` | string | 头像 |
| `role` | integer | 角色：1=成员, 2=管理员 |
| `join_time` | string | 加入时间 |

#### 3.5.5 消息搜索与设置

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 21 | GET | `/message/search` | 消息搜索 | Query: `keyword`, `page`, `size` | `PageMeta<MessageResponse>` |
| 22 | GET | `/message/settings` | 获取消息设置 | — | `MessageSettingsResponse` |
| 23 | PUT | `/message/settings` | 更新消息设置 | Body: 设置字段 | `OKResponse` |
| 24 | GET | `/message/recommend-users` | 推荐聊天用户 | Query: `page`, `size` | `List` |
| 25 | GET | `/message/search-users` | 搜索可聊天用户 | Query: `keyword`, `page`, `size` | `List` |
| 26 | GET | `/message/hidden` | 隐藏消息列表 | Query: `page`, `size` | `PageMeta<ConversationResponse>` |

---

### 3.6 社区模块 (Community)

> 文件：`community.json` | 端点数：**8**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/community/list` | 社区列表 | Query: `page`(默认 1), `size`(默认 20, max 100) | `PageMeta<CommunityResponse>` |
| 2 | GET | `/community/detail/{community_id}` | 社区详情 | Path: `community_id` | `CommunityResponse` |
| 3 | POST | `/community/join` | 加入社区 | Body: `community_id` | `OKResponse` |
| 4 | DELETE | `/community/leave/{community_id}` | 退出社区 | Path: `community_id` | `OKResponse` |
| 5 | GET | `/community/members/{community_id}` | 社区成员列表 | Path: `community_id`; Query: `page`, `size`, `keyword` | `PageMeta<CommunityMemberResponse>` |
| 6 | GET | `/community/posts/{community_id}` | 社区帖子列表（含 Flair 标签） | Path: `community_id`; Query: `page`, `size`, `sort`(recent/top) | `PageMeta<PostResponse>` |
| 7 | POST | `/community/{community_id}/champion/{user_id}` | 设置 Champion 活跃成员 | Path: `community_id`, `user_id` | `OKResponse` |
| 8 | DELETE | `/community/{community_id}/champion/{user_id}` | 取消 Champion | Path: `community_id`, `user_id` | `OKResponse` |

---

### 3.7 话题模块 (Topic)

> 文件：`topic.json` | 端点数：**10**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/topic/trending` | 热门话题 | Query: `limit`(1-50, 默认 10) | `List<TopicResponse>` |
| 2 | GET | `/topic/list` | 话题列表 | Query: `page`, `size`, `source_type`(1=用户创建, 2=平台) | `PageMeta<TopicResponse>` |
| 3 | GET | `/topic/detail/{topic_id}` | 话题详情 | Path: `topic_id` | `TopicResponse` |
| 4 | POST | `/topic/follow/{topic_id}` | 关注话题 | Path: `topic_id` | `OKResponse` |
| 5 | DELETE | `/topic/follow/{topic_id}` | 取消关注话题 | Path: `topic_id` | `OKResponse` |
| 6 | POST | `/topic/mute/{topic_id}` | 静音话题 | Path: `topic_id` | `OKResponse` |
| 7 | DELETE | `/topic/mute/{topic_id}` | 取消静音话题 | Path: `topic_id` | `OKResponse` |
| 8 | GET | `/topic/muted` | 已静音话题 ID 列表 | — | `List<int>` |
| 9 | GET | `/topic/posts/{topic_id}` | 话题帖子列表 | Path: `topic_id`; Query: `page`, `size`, `sort`(latest/popular/people) | `PageMeta<TopicPostItem>` |
| 10 | GET | `/topic/related/{topic_id}` | 相关话题推荐 | Path: `topic_id`; Query: `limit` | `List<TopicResponse>` |

---

### 3.8 通知模块 (Notification)

> 文件：`notification.json` | 端点数：**3**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/notification/notifications` | 通知列表 | Query: `page`, `size`(max 100), `notif_type`(1=点赞, 2=回复, 3=关注, 4=提及, 5=转发, 6=引用) | `PageMeta<NotificationResponse>` |
| 2 | POST | `/notification/notifications/read` | 标记已读 | Body: `notification_ids`(int 数组, 空则全部标记已读) | `OKResponse` |
| 3 | GET | `/notification/notifications/unread-count` | 未读通知数 | — | `integer` |

---

### 3.9 杂项模块 (Misc)

> 文件：`_misc.json` | 端点数：**4**

| # | 方法 | 路径 | 摘要 | 关键参数 | 响应 |
|---|------|------|------|---------|------|
| 1 | GET | `/public-key` | 获取 RSA 公钥 | — | `PublicKeyResponse` |
| 2 | POST | `/moderation/callback` | 内容审核回调（腾讯云 CI） | — | `ResponseModel` |
| 3 | GET | `/group/{invite_code}` | 群邀请链接落地页 | Path: `invite_code` | HTML 页面 |
| 4 | POST | `/upload/upload/presigned_url` | 获取 COS 预签名上传 URL | Body: `filename`, `content_type`, `file_size` | `PresignedUrlResponse` |

**文件上传流程**：
1. 客户端调用 `/upload/upload/presigned_url` 获取预签名 URL
2. 客户端使用 PUT 方法将文件上传至预签名 URL
3. 上传完成后，使用返回的 `cos_url` 作为媒体 URL 创建帖子/消息

---

## 4. 数据模型汇总

### 4.1 用户相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `MeUserResponse` | User | id, username, avatar |
| `UserProfileResponse` | User | user_id, display_name, avatar_url, bio, pronouns, gender, location, website_url, is_verified, is_private, account_type, posts_count, followers_count, following_count, last_active_time, create_time |
| `SettingsResponse` | User | 22 个设置字段（回复权限、提及权限、通知开关、隐私设置等） |
| `SigninResponse` | User | id, username, avatar, access_token, refresh_token |
| `FollowRequestResponse` | User | id, user_id, requester_id, requester_username/avatar/display_name, status, create_time |
| `SaveCollectionResponse` | User | id, name, is_default, save_count, create_time |

### 4.2 帖子相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `PostResponse` | Post | 帖子完整数据（含作者信息、互动统计、媒体、投票、标签等） |
| `ReplyResponse` | Post | 回复数据 |
| `EditHistoryResponse` | Post | 编辑历史 |
| `PollResultResponse` | Post | 投票结果（选项、分布、用户投票状态） |
| `DraftResponse` | Post | 草稿数据 |
| `ReportResponse` | Post | 举报记录 |
| `NearbyPostsResponse` | Post | 附近帖子计数 |

### 4.3 社交相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `FollowStatsResponse` | Follow | followers_count, following_count, is_following, is_followed_by_me, is_mutual |
| `FollowUserItem` | Follow | user_id, username, display_name, avatar_url, bio, is_verified, is_following, is_mutual, follow_time, posts_count, followers_count, following_count |
| `RecommendUserItem` | Follow | 继承 FollowUserItem + reason, common_followers_count |
| `SearchResult` | Search | keyword, users[], topics[], posts[], total_users, total_topics, total_posts |
| `SearchUserItem` | Search | id, username, display_name, avatar_url, is_verified, followers_count |
| `SearchTopicItem` | Search | id, name, posts_count |
| `SearchPostItem` | Search | id, user_id, username, display_name, avatar_url, content, media_count, likes_count, replies_count, create_time |
| `SearchHistoryItem` | Search | id, keyword, search_type, result_count, create_time |

### 4.4 消息相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `ConversationResponse` | Message | id, peer_user_id, conversation_type(1=收件箱/2=陌生人), last_message_content/time, unread_count, is_replied, is_verified, is_hidden, is_pinned |
| `MessageResponse` | Message | id, sender_id, receiver_id, content, media_type(0-4), media_url, is_read, delivery_status(1-3), read_time, quote_message_id, reactions[], create_time |
| `GroupChatResponse` | Message | id, name, avatar_url, invite_link, invite_link_enabled, need_approve, members_count, last_message_time, create_time |
| `GroupMemberResponse` | Message | user_id, username, display_name, avatar_url, role(1=成员/2=管理员), join_time |

### 4.5 社区/话题相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `CommunityResponse` | Community | 社区详情 |
| `CommunityMemberResponse` | Community | 成员信息 |
| `TopicResponse` | Topic | 话题详情 |
| `TopicPostItem` | Topic | 话题下的帖子 |

### 4.6 通知相关模型

| 模型 | 所属模块 | 核心字段 |
|------|---------|---------|
| `NotificationResponse` | Notification | 通知详情（含类型、关联内容、时间等） |

---

## 5. 统计摘要

### 5.1 端点分布

| 模块 | GET | POST | PUT | DELETE | 合计 |
|------|-----|------|-----|--------|------|
| User | 8 | 8 | 4 | 5 | 25 |
| Post | 12 | 15 | 1 | 14 | 42 |
| Follow | 5 | 1 | 0 | 1 | 7 |
| Search | 4 | 0 | 0 | 2 | 6 |
| Message | 10 | 10 | 1 | 4 | 25+ |
| Community | 4 | 2 | 0 | 2 | 8 |
| Topic | 8 | 2 | 0 | 0 | 10 |
| Notification | 2 | 1 | 0 | 0 | 3 |
| Misc | 1 | 3 | 0 | 0 | 4 |
| **合计** | **54** | **42** | **6** | **28** | **~130** |

### 5.2 功能完整度评估

| 功能领域 | 端点覆盖 | 说明 |
|---------|---------|------|
| 用户认证 | ★★★★★ | 注册/登录/Token 刷新/退出，完整 |
| 用户资料 | ★★★★★ | 查看/编辑资料，支持丰富的字段 |
| 用户设置 | ★★★★★ | 22 项设置，涵盖通知/隐私/内容分级 |
| 帖子核心 | ★★★★★ | CRUD + 编辑历史 + 定时发布 |
| 帖子互动 | ★★★★★ | 赞/转发/收藏/置顶/分享/举报 |
| 回复系统 | ★★★★★ | 创建/列表/点赞/置顶/隐藏 + 审核流程 |
| 投票 | ★★★★☆ | 创建/投票/查看结果（创建在 CreatePostRequest 中） |
| 草稿 | ★★★★★ | 完整的 CRUD |
| Feed | ★★★★☆ | 推荐 + 关注两种 Feed，缺少按时间线排列选项 |
| 幽灵帖 | ★★★★★ | 申请/审批/拒绝/查看待处理 |
| 关注系统 | ★★★★★ | 关注/取关/统计/列表/互关/推荐 |
| 私信 | ★★★★★ | 会话管理/消息收发/反应/已读/搜索 |
| 群聊 | ★★★★★ | 创建/管理/成员/邀请链接/审批 |
| 搜索 | ★★★★☆ | 综合搜索 + 历史管理 + 热门内容 |
| 社区 | ★★★★☆ | 基础功能完整，缺少社区创建/管理后台 |
| 话题 | ★★★★★ | 关注/静音/帖子/推荐 |
| 通知 | ★★★☆☆ | 基础列表和已读，缺少通知设置（在 User 设置中） |
| 文件上传 | ★★★★★ | 预签名 URL + COS 直传 |

### 5.3 关键特性总结

1. **认证体系**：基于 username/password 注册登录，JWT Token（access_token + refresh_token）认证，支持设备令牌管理
2. **私密账号**：支持私密账号模式，关注需审批
3. **关系管控**：支持静音/限制/拉黑三种管控方式
4. **帖子能力**：文本 + 媒体（最多 10 个）+ 位置 + 话题 + 投票 + 幽灵帖 + 社区发布 + 引用转发 + 定时发布
5. **回复管理**：支持嵌套回复、回复审核、回复置顶/隐藏
6. **消息系统**：完整的私聊 + 群聊系统，支持消息反应、引用消息、已读回执
7. **社区功能**：社区浏览/加入/退出 + Champion 机制
8. **话题系统**：关注/静音/热门/推荐/帖子浏览
9. **内容安全**：内容审核回调（腾讯云 CI）+ 举报机制
10. **多端支持**：device-os / device-name / user-agent 请求头支持多设备场景
