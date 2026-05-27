# Instagram Threads Clone — 客户端功能实现分析报告

> 生成日期：2026-05-27
> 分析范围：`client/lib/` 目录下全部 Dart 源代码

---

## 目录

1. [项目概览](#1-项目概览)
2. [网络层 (Network Layer)](#2-网络层-network-layer)
3. [功能模块详析](#3-功能模块详析)
   - [3.1 用户认证模块 (Auth)](#31-用户认证模块-auth)
   - [3.2 用户资料模块 (Profile)](#32-用户资料模块-profile)
   - [3.3 帖子/动态流模块 (Post/Feed)](#33-帖子动态流模块-postfeed)
   - [3.4 关注模块 (Follow)](#34-关注模块-follow)
   - [3.5 搜索模块 (Search)](#35-搜索模块-search)
   - [3.6 通知模块 (Notification)](#36-通知模块-notification)
   - [3.7 媒体上传模块 (Upload)](#37-媒体上传模块-upload)
4. [数据模型层 (Models)](#4-数据模型层-models)
5. [状态管理层 (State)](#5-状态管理层-state)
6. [UI 页面完成度矩阵](#6-ui-页面完成度矩阵)
7. [已知代码质量问题](#7-已知代码质量问题)
8. [遗留/废弃代码](#8-遗留废弃代码)
9. [统计摘要](#9-统计摘要)

---

## 1. 项目概览

| 项目属性 | 值 |
|----------|-----|
| 框架 | Flutter 3.x (Dart SDK >=3.0.0 <4.0.0) |
| 状态管理 | Provider + ChangeNotifier |
| 依赖注入 | get_it (service locator) |
| HTTP 客户端 | `http` package（非 Dio） |
| 本地存储 | SharedPreferences |
| 图片处理 | image_picker, image_cropper, cached_network_image, camera |
| 国际化 | flutter_localizations（英文 + 中文） |
| 源文件总数 | 58 个 Dart 文件 |
| API 服务方法总数 | 54 个（全部已实现，无 stub） |
| API 接口覆盖 | 52 个独立 endpoint |

### 代码目录结构

```
client/lib/
├── main.dart                          # 入口：初始化 + MultiProvider
├── network/                           # 网络基础设施
│   ├── api_config.dart                #   Base URL、超时等配置常量
│   ├── api_client.dart                #   HTTP 封装（GET/POST/PUT/PATCH/DELETE）
│   └── api_exception.dart             #   异常层级体系
├── services/                          # API 服务层（7个文件）
│   ├── auth_service.dart              #   认证：登录、注册、登出、Token刷新、改密
│   ├── user_service.dart              #   用户：资料CRUD、设置、关注请求
│   ├── post_service.dart              #   帖子：发帖、Feed、回复、点赞、转发、收藏、投票
│   ├── follow_service.dart            #   关注：关注/取关、列表、推荐
│   ├── search_service.dart            #   搜索：搜索、历史、热门话题/帖子
│   ├── notification_service.dart      #   通知：通知列表、已读、未读数
│   └── upload_service.dart            #   上传：预签名URL + COS直传
├── state/                             # 状态管理（7个文件）
│   ├── app.state.dart                 #   基类：loading 状态
│   ├── auth.state.dart                #   认证状态
│   ├── post.state.dart                #   帖子/Feed 状态
│   ├── profile.state.dart             #   用户资料状态
│   ├── search.state.dart              #   搜索状态
│   ├── compose.state.dart             #   发帖交互状态
│   └── locale.state.dart              #   语言切换状态
├── model/                             # 数据模型（2个文件 + 内联类）
│   ├── user.module.dart               #   UserModel
│   └── post.module.dart               #   PostModel
├── pages/                             # 页面级 Widget
│   ├── home.dart                      #   主导航 Shell（5 Tab）
│   ├── feed/feed.dart                 #   首页动态流
│   ├── search/search.dart             #   搜索页
│   ├── composePost/post.dart          #   发帖页
│   ├── notification/notification.dart #   通知页
│   ├── profile/myprofile.dart         #   个人主页
│   ├── profile/profile.dart           #   他人主页
│   ├── profile/edit.dart              #   编辑资料
│   └── camera/camera.dart             #   相机页
├── widget/                            # 可复用组件
│   ├── feedpost.dart                  #   Feed 帖子卡片
│   ├── poll_widget.dart               #   投票组件
│   ├── list.dart                      #   用户列表项
│   ├── topic_tile.dart                #   话题卡片
│   ├── search_post_tile.dart          #   搜索帖子卡片
│   ├── language_switcher.dart         #   语言切换（未使用）
│   └── custom/                        #   基础组件
├── auth/                              # 认证/注册页面
│   ├── signup/name.dart               #   登录页（活跃）
│   ├── signup/register.dart           #   注册页（活跃）
│   └── (其余5个为遗留废弃页面)
├── common/                            # 通用
│   ├── locator.dart                   #   GetIt DI 配置
│   ├── settings.dart                  #   设置页
│   └── splash.dart                    #   启动页/路由
├── helper/                            # 工具类
│   ├── enum.dart                      #   枚举定义
│   ├── utility.dart                   #   通用工具函数
│   └── shared_prefrence_helper.dart   #   SP 封装
└── l10n/                              # 国际化资源
    └── generated/                     #   自动生成
```

---

## 2. 网络层 (Network Layer)

### API 配置 (`api_config.dart`)

| 配置项 | 值 |
|--------|-----|
| Base URL | `http://192.168.1.27:8005/` |
| 连接超时 | 30 秒 |
| 接收超时 | 30 秒（已定义但未引用） |
| Content-Type | `application/json` |
| User-Agent | `ThreadsApp/1.0` |

### API 客户端 (`api_client.dart`)

| 方法 | 功能 | 使用情况 |
|------|------|----------|
| `get()` | GET 请求 | 正常使用 |
| `post()` | POST 请求 | 正常使用 |
| `put()` | PUT 请求 | 正常使用 |
| `patch()` | PATCH 请求 | **已定义但从未被任何 Service 调用** |
| `delete()` | DELETE 请求 | 正常使用 |
| `setTokens()` | 设置认证 Token | 正常使用 |
| `clearTokens()` | 清除 Token | 正常使用 |

**认证机制**：Bearer Token 方式，通过 `Authorization` Header 发送。`_refreshToken` 被存储但 ApiClient 本身不自动使用（无自动刷新拦截器）。

### 异常层级 (`api_exception.dart`)

| 异常类 | 触发条件 |
|--------|----------|
| `ApiException` | 基础异常 |
| `NetworkException` | 网络连接失败 |
| `AuthException` | 401/403 响应 |
| `ValidationException` | 400/422 响应 |
| `ServerException` | 500/502/503 响应 |

---

## 3. 功能模块详析

### 3.1 用户认证模块 (Auth)

**涉及文件：**
- `services/auth_service.dart` — 6 个公开方法
- `state/auth.state.dart` — AuthState
- `auth/signup/name.dart` — 登录页 (NamePage)
- `auth/signup/register.dart` — 注册页 (RegisterPage)
- `common/splash.dart` — 启动路由页

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `signIn()` | POST | `user/signin` | 已完成 |
| `register()` | POST | `user/register` | 已完成 |
| `logout()` | DELETE | `user/logout` | 已完成 |
| `getCurrentUser()` | GET | `user/me` | 已完成 |
| `refreshToken()` | POST | `user/token/refresh` | 已完成 |
| `modifyPassword()` | PUT | `user/modify_password` | 已完成 |

#### 已完成的 State 方法

| 方法 | 功能 | 状态 |
|------|------|------|
| `initAuthService()` | 从 SharedPreferences 恢复登录状态 | 已完成 |
| `signIn()` | 登录 + 获取完整资料 | 已完成 |
| `register()` | 注册 + 获取完整资料 | 已完成 |
| `logoutCallback()` | 登出 + 清理本地数据 | 已完成 |
| `getProfileUser()` | 获取当前用户完整资料（/user/me → /user/profile/{id}） | 已完成 |
| `updateUserProfile()` | 更新资料 + 上传头像 | 已完成 |
| `getUserDetail()` | 获取任意用户资料 | 已完成 |
| `getCurrentUser()` | 获取当前用户（失败自动刷新Token） | 已完成 |

#### 已完成的 UI 功能

| 页面 | 功能 | 完成度 |
|------|------|--------|
| SplashPage | 自动检测登录状态 → 路由分发 | 完成 |
| NamePage (登录) | 用户名/密码登录表单 + API 调用 | 完成 |
| RegisterPage (注册) | 用户名/密码/确认密码 + API 调用 | 完成 |

---

### 3.2 用户资料模块 (Profile)

**涉及文件：**
- `services/user_service.dart` — 7 个方法
- `state/profile.state.dart` — ProfileState
- `pages/profile/myprofile.dart` — 个人主页
- `pages/profile/profile.dart` — 他人主页
- `pages/profile/edit.dart` — 编辑资料

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `getUserProfile()` | GET | `user/profile/{userId}` | 已完成 |
| `updateProfile()` | PUT | `user/profile` | 已完成 |
| `getSettings()` | GET | `user/settings` | 已完成 |
| `updateSettings()` | PUT | `user/settings` | 已完成 |
| `getFollowRequests()` | GET | `user/follow-requests/pending` | 已完成 |
| `approveFollowRequest()` | POST | `user/follow-requests/{id}/approve` | 已完成 |
| `getFollowStats()` | GET | `follow/{userId}/stats` | 已完成 |

#### 已完成的 UI 功能

| 页面 | 功能 | 完成度 |
|------|------|--------|
| MyProfilePage | 头像、名称、简介、链接展示 + Tab(Threads/Replies) | 部分完成 — Threads Tab 加载真实帖子，Replies Tab 始终显示空状态 |
| ProfilePage (他人) | 他人资料展示 | 部分完成 — TabBarView 内容为硬编码空文本 |
| EditProfilePage | 编辑名称/简介/链接 + 头像上传 | 已完成 |

---

### 3.3 帖子/动态流模块 (Post/Feed)

**涉及文件：**
- `services/post_service.dart` — 22 个方法
- `state/post.state.dart` — PostState
- `pages/feed/feed.dart` — 动态流页面
- `pages/composePost/post.dart` — 发帖页面
- `widget/feedpost.dart` — 帖子卡片组件
- `widget/poll_widget.dart` — 投票组件

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `createPost()` | POST | `post/create` | 已完成 |
| `getPostDetail()` | GET | `post/detail/{postId}` | 已完成 |
| `deletePost()` | DELETE | `post/{postId}` | 已完成 |
| `updatePost()` | PUT | `post/{postId}` | 已完成 |
| `getFeed()` | GET | `post/feed` | 已完成 |
| `getUserPosts()` | GET | `post/user/{userId}/posts` | 已完成 |
| `likePost()` | POST | `post/like/{postId}` | 已完成 |
| `unlikePost()` | DELETE | `post/like/{postId}` | 已完成 |
| `repost()` | POST | `post/repost/{postId}` | 已完成 |
| `reportPost()` | POST | `post/report` | 已完成 |
| `savePost()` | POST | `post/save/{postId}` | 已完成 |
| `unsavePost()` | DELETE | `post/save/{postId}` | 已完成 |
| `pinPost()` | POST | `post/pin/{postId}` | 已完成 |
| `unpinPost()` | DELETE | `post/pin/{postId}` | 已完成 |
| `createReply()` | POST | `post/reply` | 已完成 |
| `getReplies()` | GET | `post/reply/list/{postId}` | 已完成 |
| `likeReply()` | POST | `post/reply/like/{replyId}` | 已完成 |
| `unlikeReply()` | DELETE | `post/reply/like/{replyId}` | 已完成 |
| `getSavedPosts()` | GET | `post/saved` | 已完成 |
| `votePoll()` | POST | `post/poll/{postId}/vote` | 已完成 |
| `hideReply()` | POST | `post/reply/hide/{replyId}` | 已完成 |
| `unhideReply()` | DELETE | `post/reply/hide/{replyId}` | 已完成 |

#### 已完成的 State 方法

| 方法 | 功能 | 状态 |
|------|------|------|
| `createPost()` | 发帖（含图片上传 + 投票选项 + 回复权限） | 已完成 |
| `getDataFromDatabase()` | 获取 Feed 列表 + 分页重置 | 已完成 |
| `loadMore()` | Feed 无限滚动分页加载 | 已完成 |
| `likePost()` / `unlikePost()` | 点赞/取消点赞（乐观更新 + 回滚） | 已完成 |
| `voteOnPoll()` | 投票（乐观更新 + 回滚） | 已完成 |
| `loadUserPosts()` | 加载指定用户帖子 | 已完成 |
| `uploadFile()` | 文件上传封装 | 已完成 |

#### 已完成的 UI 功能

| 页面/组件 | 功能 | 完成度 |
|-----------|------|--------|
| FeedPage | 动态流列表 + 无限滚动 + Lottie 加载动画 | 部分完成 — 顶部快捷发帖区域无功能 |
| ComposePost | 文字输入 + 图片上传(最多10张) + 投票(2-4选项) + 回复权限设置 + 发帖 | 已完成 |
| FeedPostWidget | 帖子渲染（文字/图片/投票） | 部分完成 — 仅点赞功能完整 |
| PollWidget | 投票选项展示 + 投票交互 + 结果展示 | 已完成 |

---

### 3.4 关注模块 (Follow)

**涉及文件：**
- `services/follow_service.dart` — 7 个方法
- `state/profile.state.dart` — 关注相关方法

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `followUser()` | POST | `follow/{userId}` | 已完成 |
| `unfollowUser()` | DELETE | `follow/{userId}` | 已完成 |
| `getFollowStats()` | GET | `follow/{userId}/stats` | 已完成 |
| `getFollowing()` | GET | `follow/following/{userId}` | 已完成 |
| `getFollowers()` | GET | `follow/followers/{userId}` | 已完成 |
| `getMutualFollowers()` | GET | `follow/mutual/{userId}` | 已完成 |
| `getRecommendedUsers()` | GET | `follow/recommend` | 已完成 |

#### 已完成的 State 方法

| 方法 | 功能 | 状态 |
|------|------|------|
| `getFollowStats()` | 获取关注统计 | 已完成 |
| `getFollowers()` | 获取粉丝列表 | 已完成 |
| `getFollowing()` | 获取关注列表 | 已完成 |
| `followUser()` | 关注/取关操作 | Service 已完成，State 层存在运行时问题（见质量问题） |

---

### 3.5 搜索模块 (Search)

**涉及文件：**
- `services/search_service.dart` — 6 个方法
- `state/search.state.dart` — SearchState
- `pages/search/search.dart` — 搜索页
- `widget/topic_tile.dart` — 话题卡片
- `widget/search_post_tile.dart` — 搜索帖子卡片

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `search()` | GET | `search` | 已完成 |
| `getSearchHistory()` | GET | `search/history` | 已完成 |
| `clearSearchHistory()` | DELETE | `search/history` | 已完成 |
| `deleteSearchHistoryItem()` | DELETE | `search/history/{id}` | 已完成 |
| `getHotTopics()` | GET | `search/hot-topics` | 已完成 |
| `getTrendingPosts()` | GET | `search/trending` | 已完成 |

#### 已完成的 State 方法

| 方法 | 功能 | 状态 |
|------|------|------|
| `loadEmptyStateData()` | 加载搜索历史 + 热门话题 + 热门帖子 | 已完成 |
| `onSearchChanged()` | 防抖搜索（400ms） | 已完成 |
| `changeTab()` | 切换搜索类型 Tab | 已完成 |
| `_performSearch()` | 执行搜索 API 调用 | 已完成 |
| `deleteHistoryItem()` | 删除单条搜索历史 | 已完成 |
| `clearSearchHistory()` | 清空搜索历史 | 已完成 |
| `filterByUsername()` | @ 提及用户过滤 | 已完成 |

#### 已完成的 UI 功能

| 页面/组件 | 功能 | 完成度 |
|-----------|------|--------|
| SearchPage | 搜索框 + 4 Tab(综合/用户/话题/帖子) + 搜索历史 + 热门话题/帖子 | 已完成 — 整个搜索页功能完整 |
| TopicTile | 话题卡片展示 | 部分完成 — 关注按钮无功能 |
| SearchPostTile | 搜索帖子卡片展示 | 部分完成 — 点击无跳转 |

---

### 3.6 通知模块 (Notification)

**涉及文件：**
- `services/notification_service.dart` — 3 个方法
- `pages/notification/notification.dart` — 通知页

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `getNotifications()` | GET | `notification/notifications` | 已完成 |
| `markAsRead()` | POST | `notification/notifications/read` | 已完成 |
| `getUnreadCount()` | GET | `notification/notifications/unread-count` | 已完成 |

#### 已完成的 UI 功能

| 页面 | 功能 | 完成度 |
|------|------|--------|
| NotificationPage | 通知展示 | **仅占位** — 未使用 NotificationService，复用 SearchState.userlist 作为假数据，筛选按钮无功能，列表固定 200px 高度 |

> 注意：Service 层已完整实现 3 个通知 API 方法，但 UI 层完全没有对接。

---

### 3.7 媒体上传模块 (Upload)

**涉及文件：**
- `services/upload_service.dart` — 3 个公开方法

#### 已完成的 Service 方法

| 方法 | HTTP | Endpoint | 状态 |
|------|------|----------|------|
| `uploadImage()` | POST + PUT | `upload/upload/presigned_url` + 外部PUT | 已完成 |
| `getPresignedUrl()` | POST | `upload/upload/presigned_url` | 已完成 |
| `uploadToPresignedUrl()` | PUT | 外部 URL | 已完成 |

**上传流程**：两步式 — (1) POST 获取预签名 URL + COS URL，(2) PUT 原始字节到预签名 URL。支持 jpg/png/gif/webp/heic/mp4/mov 格式。

---

## 4. 数据模型层 (Models)

### UserModel (`model/user.module.dart`)

| 字段 | 类型 | 可空 | 说明 |
|------|------|------|------|
| `key` | String? | 是 | Firebase 风格 Key |
| `userId` | int? | 是 | API 用户 ID |
| `userName` | String? | 是 | 用户名 |
| `displayName` | String? | 是 | 显示名称 |
| `bio` | String? | 是 | 简介 |
| `link` | String? | 是 | 链接 |
| `email` | String? | 是 | 邮箱 |
| `profilePic` | String? | 是 | 头像 URL |
| `createAt` | String? | 是 | 创建时间 |
| `isPrivate` | bool? | 是 | 是否私密账号 |
| `fcmToken` | String? | 是 | 推送 Token |
| `followersList` | List\<String\>? | 是 | 粉丝 ID 列表 |
| `followingList` | List\<String\>? | 是 | 关注 ID 列表 |
| `followersCount` | int? | 是 | 粉丝数 |
| `followingCount` | int? | 是 | 关注数 |

实现：`fromJson`（支持 camelCase + snake_case 双格式）、`toJson`、`copyWith`、`fromApiUser`、`Equatable`

### PostModel (`model/post.module.dart`)

| 字段 | 类型 | 可空 | 说明 |
|------|------|------|------|
| `key` | String? | 是 | Firebase Key |
| `postId` | String? | 是 | 帖子 ID |
| `bio` | String? | 是 | 帖子内容 |
| `createdAt` | String | 否 | 创建时间 |
| `imagePath` | String? | 是 | 图片 URL |
| `user` | UserModel? | 是 | 作者 |
| `likesCount` | int? | 是 | 点赞数 |
| `repliesCount` | int? | 是 | 回复数 |
| `repostsCount` | int? | 是 | 转发数 |
| `sharesCount` | int? | 是 | 分享数 |
| `isLiked` | bool? | 是 | 是否已点赞 |
| `isSaved` | bool? | 是 | 是否已收藏 |
| `replyToPostId` | String? | 是 | 回复目标帖子 |
| `replyToUserId` | String? | 是 | 回复目标用户 |
| `pollData` | PollData? | 是 | 投票数据 |
| `comment` | List\<String?\>? | 是 | 评论（从未填充） |

实现：`fromJson`、`toJson`、`copyWith`

### 内联数据类（定义在各 Service 文件中）

| 类名 | 所在文件 | 字段数 | 有 fromJson | 有 toJson |
|------|----------|--------|-------------|-----------|
| `PollData` | post_service.dart | 5 | 否（手动构建） | 否 |
| `PollOption` | post_service.dart | 3 | 是 | 否 |
| `MediaItem` | post_service.dart | 3 | 是 | 是 |
| `PostUser` | post_service.dart | 3 | 是 | 否 |
| `Reply` | post_service.dart | 7 | 是 | 否 |
| `FollowStats` | user_service.dart | 3 | 是 | 否 |
| `SearchResult` | search_service.dart | 7 | 是 | 否 |
| `SearchPostItem` | search_service.dart | 10 | 是 | 否 |
| `SearchHistoryItem` | search_service.dart | 5 | 是 | 否 |
| `TrendingTopic` | search_service.dart | 4 | 是 | 否 |
| `NotificationItem` | notification_service.dart | 多个 | 是 | 否 |
| `PresignedUrlResponse` | upload_service.dart | 2 | 是 | 否 |
| `LoginResponse` | auth_service.dart | 3 | 是 | 否 |
| `RegisterResponse` | auth_service.dart | 3 | 是 | 否 |
| `UserInfo` | auth_service.dart | 多个 | 是 | 否 |
| `UserSettings` | user_service.dart | 多个 | 是 | 是 |

---

## 5. 状态管理层 (State)

| 状态类 | 父类 | 主要职责 | 核心方法数 |
|--------|------|----------|-----------|
| `AppStates` | ChangeNotifier | 基类（loading 状态） | 1 |
| `AuthState` | AppStates | 认证、用户资料 | 9 |
| `PostState` | AppStates | Feed、帖子 CRUD、点赞、投票 | 14 |
| `ProfileState` | ChangeNotifier | 他人资料、关注操作 | 7 |
| `SearchState` | AppStates | 搜索、历史、热门 | 12 |
| `ComposePostState` | ChangeNotifier | 发帖交互逻辑 | 4 |
| `LocaleProvider` | ChangeNotifier | 语言切换 | 3 |

**状态消费模式**：
- UI 通过 `context.watch<T>()` 监听状态变化
- UI 通过 `context.read<T>()` 触发状态变更
- State 通过 Service 层调用 API
- Service 通过 ApiClient 发起 HTTP 请求

---

## 6. UI 页面完成度矩阵

| 页面 | 路由 | 数据源 | 交互完成度 | 说明 |
|------|------|--------|-----------|------|
| **SplashPage** | 启动页 | API | 完成 | 自动检测登录状态并路由 |
| **HomePage** | 主导航 | API | 完成 | 5 Tab 底部导航（无高亮选中态） |
| **FeedPage** | Tab 0 | API | 大部分完成 | 无限滚动 + 分页正常；顶部快捷发帖区无功能 |
| **SearchPage** | Tab 1 | API | 完成 | 搜索/历史/热门/Tab 切换全部可用 |
| **ComposePost** | Tab 2 | API | 完成 | 文字/图片/投票/回复权限/发帖全部可用 |
| **NotificationPage** | Tab 3 | 假数据 | 占位 | 未对接 NotificationService，使用 SearchState 数据 |
| **MyProfilePage** | Tab 4 | API | 大部分完成 | Threads Tab 有真实数据，Replies Tab 空 |
| **ProfilePage** | Push | API | 部分完成 | 资料展示正常，TabBarView 内容为空 |
| **EditProfilePage** | Push | API | 完成 | 编辑/上传/保存全部可用 |
| **CameraPage** | Drawer | API | 部分 | 拍照+上传可用，但帖子不会保存到数据库 |
| **SettingsPage** | Push | 本地 | 部分完成 | 仅语言切换和登出可用，其余菜单项为展示 |

### FeedPostWidget 交互完成度

| 交互 | 状态 |
|------|------|
| 点赞（红心） | 已完成 — 乐观更新 |
| 评论 | 占位 — 打开空白 BottomSheet |
| 转发 | 未实现 — 无手势处理 |
| 分享 | 未实现 — 无手势处理 |
| 更多菜单(...) | 未实现 — 无手势处理 |
| 头像/用户名点击 | 未实现 — 无跳转 |
| 投票 | 已完成 — 乐观更新 |

---

## 7. 已知代码质量问题

### 严重问题

| # | 问题 | 位置 | 影响 |
|---|------|------|------|
| 1 | ProfileState 中 `userId` 和 `_userModel` 为 `late` 但从未初始化 | `state/profile.state.dart` | 访问 `isMyProfile` 或调用 `followUser()` 会触发 `LateInitializationError` 崩溃 |
| 2 | PostState 的 `isBusy` 字段遮蔽了父类 AppStates 的 `_isBusy` | `state/post.state.dart` | 使用 `AppStates.isbusy` 访问时得到错误值 |
| 3 | 无 Token 自动刷新拦截器 | `network/api_client.dart` | 401 时不会自动刷新 Token 并重试，仅 AuthState 手动刷新一次 |

### 中等问题

| # | 问题 | 位置 | 说明 |
|---|------|------|------|
| 4 | UserModel toJson/fromJson 不兼容 | `model/user.module.dart` | toJson 输出 `follower_list`，fromJson 读取 `followerList`/`followersList`，往返序列化丢失数据 |
| 5 | PostModel.fromJson 不解析 `sharesCount` 和 `pollData` | `model/post.module.dart` | 这两个字段从 JSON 解析时始终为 null |
| 6 | 分页参数命名不一致 | 多个 Service | `size` / `page_size` / `limit` 三种命名混用 |
| 7 | 错误处理模式：大部分 catch 块静默吞掉异常 | 多个 State 文件 | 无统一错误状态字段，UI 无法展示错误信息 |
| 8 | Feed 失败时回退到 mock 数据 | `state/post.state.dart` | `_loadMockData()` 生成假帖子，用户无法区分真实数据和假数据 |
| 9 | votePoll() 无 try/catch | `services/post_service.dart` | 唯一一个没有错误处理的方法 |

### 轻微问题

| # | 问题 | 位置 | 说明 |
|---|------|------|------|
| 10 | Base URL 硬编码为局域网 IP | `network/api_config.dart` | `http://192.168.1.27:8005/`，无法用于生产环境 |
| 11 | 文件名拼写错误 | `helper/shared_prefrence_helper.dart` | "prefrence" → "preference" |
| 12 | TitleText 组件忽略 color 参数 | `widget/custom/title_text.dart` | 构造函数接受 color 但 build 中始终使用 Colors.white |
| 13 | 大量 UI 文本硬编码为中文/法文 | 多处 | EditProfilePage、RegisterPage、PollWidget 等未使用国际化系统 |
| 14 | ApiClient.patch() 已定义但从未使用 | `network/api_client.dart` | 死代码 |
| 15 | UserService 和 FollowService 重复定义 `getFollowStats()` | 两个 Service | 同一 endpoint 被两个 Service 各实现一次 |

---

## 8. 遗留/废弃代码

以下页面为旧版 Firebase 架构的遗留代码，在当前活跃流程中不被使用：

| 页面文件 | 类名 | 状态 | 说明 |
|----------|------|------|------|
| `auth/signup/signup.dart` | Signup | 废弃 | 旧版资料设置页，无人引用 |
| `auth/signup/email.dart` | EmailPage | 废弃 | 旧版邮箱注册页，法文文本 |
| `auth/signup/account.dart` | SwitchAccount | 废弃 | 账号切换页，无人引用 |
| `auth/onboard/privacy.dart` | PrivacyPage | 废弃 | 旧版隐私设置引导页 |
| `auth/onboard/follow.dart` | FollowerPage | 废弃 | 旧版关注推荐引导页，mock 数据 |
| `auth/onboard/thread.dart` | ThreadPage | 废弃 | 旧版 Threads 介绍页 |
| `pages/composePost/widget/composeBottomIconWidget.dart` | ComposeBottomIconWidget | 废弃 | 图片选择组件，ComposePost 未使用 |
| `widget/language_switcher.dart` | LanguageSwitcher | 废弃 | 语言切换组件，SettingsPage 使用内联实现 |

**活跃的认证流程**：`SplashPage → NamePage（登录）→ HomePage` 或 `SplashPage → NamePage → RegisterPage（注册）→ HomePage`

---

## 9. 统计摘要

### 代码量

| 类别 | 数量 |
|------|------|
| Dart 源文件 | 58 |
| API 服务文件 | 7 |
| 状态管理类 | 7 |
| 数据模型类 | 2 (主) + 14 (内联) |
| 页面 Widget | 9 (活跃) + 6 (废弃) |
| 可复用组件 | 7 |
| 测试文件 | 0 |

### Service 方法统计

| Service | 公开方法数 | 覆盖 Endpoint 数 |
|---------|-----------|-----------------|
| AuthService | 6 | 6 |
| UserService | 7 | 7 |
| PostService | 22 | 22 |
| FollowService | 7 | 7 |
| SearchService | 6 | 6 |
| NotificationService | 3 | 3 |
| UploadService | 3 | 1 (+ 外部 PUT) |
| **合计** | **54** | **52** |

### 功能完成度总览

| 模块 | Service 层 | State 层 | UI 层 | 整体评价 |
|------|-----------|----------|-------|---------|
| 认证 (Auth) | 完成 | 完成 | 完成 | 完整可用 |
| 用户资料 (Profile) | 完成 | 完成（有 bug） | 大部分完成 | 基本可用 |
| 帖子/Feed (Post) | 完成 | 完成 | 大部分完成 | Service 完整，UI 部分交互缺失 |
| 关注 (Follow) | 完成 | 部分（有 bug） | 部分 | Service 完整，UI 按钮未对接 |
| 搜索 (Search) | 完成 | 完成 | 完成 | 完整可用 |
| 通知 (Notification) | 完成 | 无 | 占位 | Service 完整但 UI 未对接 |
| 媒体上传 (Upload) | 完成 | 集成在 PostState | 集成在发帖/编辑 | 完整可用 |
| 消息 (Message) | 无 | 无 | 无 | **完全缺失** |
| 社区 (Community) | 无 | 无 | 无 | **完全缺失** |
| 话题 (Topic) | 无独立 Service | 无 | 仅搜索结果中的展示 | **基本缺失** |
