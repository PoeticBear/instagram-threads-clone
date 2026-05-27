# P4 阶段实施提示词

> 复制以下全部内容，在新对话中直接粘贴即可。

---

## 你的角色

你是一位资深 Flutter 开发者，负责继续推进 Instagram Threads Clone 客户端的 **Phase 4 (P4)** 阶段开发。项目已通过 P0-P3 完成了核心功能，现在需要完成高级辅助功能、UI 打磨和技术债务清理。

---

## 项目基本信息

- **项目路径**: `/Users/sihangpeng/Developer/instagram-threads-clone/client/`
- **Flutter 包名**: `threads`
- **架构**: Service → State(ChangeNotifier) → UI(Provider)，三层分离
- **依赖注入**: `get_it` (`getIt<ApiClient>()`)
- **状态管理**: Provider + ChangeNotifier（`AppStates` 基类）
- **路由**: Navigator.push + MaterialPageRoute
- **主题**: 纯黑背景 (Colors.black)，Cupertino + Material 混合
- **国际化**: 手写 ARB + 手写 generated Dart 文件（不使用 flutter gen-l10n）
- **API 基地址**: `http://192.168.1.27:8005/`（局域网开发环境）
- **API 文档**: `docs/analysis/server-api-analysis.md`（~130 端点，9 个模块）

---

## 已完成阶段概览

| 阶段 | 完成内容 |
|------|---------|
| P0 | 修复 ProfileState `late` 初始化崩溃 |
| P1 | FeedPostWidget 交互（点赞/评论/转发/收藏/分享/举报）、关注模块修正、用户资料编辑 |
| P2 | 消息模块（25+ 端点，DM + 群聊）、话题模块（10 端点）、草稿功能（4 端点） |
| P3 | 社区模块（8 端点）、关系管控/收藏夹/隐藏词/链接管理、数据模型补全、幽灵帖审核、composePost 参数扩展（location/topicIds/communityId/quoteRepostId/scheduledTime） |

---

## P4 实施范围

P4 分为 **A/B/C 三大块**，按优先级排列：

### A. 高级帖文功能（Service + UI）

| # | 功能 | 服务端端点 | 说明 |
|---|------|-----------|------|
| A1 | **定时帖子管理** | `GET /post/scheduled`（列表，分页）<br>`DELETE /post/{post_id}/schedule`（取消） | composePost 中 `scheduledTime` 字段已扩展到位，需补充定时帖列表页和取消功能 |
| A2 | **帖子编辑历史** | `GET /post/{post_id}/edit-history` | 返回 `List<EditHistoryResponse>`，15 分钟窗口内最多 5 次编辑 |
| A3 | **帖子编辑** | `PUT /post/{post_id}` | PostService.updatePost() 已存在，需 UI 入口（更多菜单 → 编辑） |
| A4 | **帖子删除** | `DELETE /post/{post_id}` | PostService.deletePost() 已存在，需 UI 入口（更多菜单 → 删除） |
| A5 | **附近帖子** | `POST /post/nearby` | 接收 POI 坐标列表，返回附近帖子计数 |
| A6 | **oEmbed** | `GET /post/oembed` | 接收 `url=https://domain/t/{short_code}`，返回 oEmbed 标准嵌入数据 |

### B. UI 打磨（Service 已有，补 UI）

| # | 功能 | 当前状态 | 需要做的 |
|---|------|---------|---------|
| B1 | **ProfilePage 他人帖子列表** | TabBarView 内容为静态占位文本 "No threads yet." | 对接 PostState.getUserPosts()，渲染真实帖子列表，支持分页 |
| B2 | **MyProfilePage 帖子/回复 Tab** | Threads Tab 已有数据，Replies Tab 为空 | 对接用户回复列表 |
| B3 | **帖子详情 + 回复列表** | 无独立帖子详情页 | 新建 PostDetailPage，展示帖子全文 + 回复列表（分页）+ 点赞回复 + 置顶/隐藏回复 |
| B4 | **NotificationPage i18n 修复** | `_typeText()` 和 `_formatTime()` 硬编码中文 | 替换为 AppLocalizations 调用 |
| B5 | **NotificationPage 导航** | 点击通知仅标记已读 | 根据通知类型导航到帖子详情或用户主页 |
| B6 | **已收藏帖子列表页** | PostService.getSavedPosts() 已实现，无 UI | 新建 SavedPostsPage |
| B7 | **FeedPostWidget 更多菜单补全** | 缺少编辑/删除/置顶选项 | 对自己帖子显示编辑/删除/置顶；编辑跳转 ComposePost（编辑模式） |
| B8 | **引用转发** | RepostBottomSheet 中 quote 按钮为 no-op | 实现引用转发 UI（输入引用评语 + 调用 createPost 传 quoteRepostId） |

### C. 技术债务

| # | 问题 | 修复方案 |
|---|------|---------|
| C1 | FollowService 路径不匹配 | `getFollowing()` 和 `getMutualFollowers()` 多传了 `/{userId}` 路径参数，服务端从 Token 获取，需删除多余路径参数 |
| C2 | NotificationPage filter 类型不匹配 | UI 用 2=reply,3=verify,4=mention；API 用 1=like,2=reply,3=follow,4=mention,5=repost,6=quote。需对齐 |
| C3 | FeedPostWidget "Copy Link" 硬编码 URL | 替换为基于 ApiConfig 的真实链接 |
| C4 | NotificationState 已实现但标记为 untracked | 确认完整性，补齐缺失方法 |

---

## 关键文件索引

### Service 层 (`lib/services/`)
- `post_service.dart` — Post CRUD + 互动 + 草稿 + 幽灵帖（Post / Reply / PollData / PollOption / MediaItem / PostUser / GuestReplyRequest 模型类）
- `user_service.dart` — 用户资料 + 设置 + 关系管控 + 收藏夹 + 隐藏词 + 链接（RelationControlledUser / SaveCollection / HiddenWord / UserLink 模型类）
- `message_service.dart` — 私信 + 群聊（25+ 端点）
- `topic_service.dart` — 话题（10 端点）
- `community_service.dart` — 社区（8 端点）
- `notification_service.dart` — 通知（3 端点）
- `follow_service.dart` — 关注（7 端点）
- `search_service.dart` — 搜索（5 端点）
- `auth_service.dart` — 认证
- `upload_service.dart` — 文件上传

### State 层 (`lib/state/`)
- `post.state.dart` — 帖子列表/Feed/CRUD/互动，createPost 支持 location/topicIds/communityId/quoteRepostId
- `profile.state.dart` — 用户资料（自己 + 他人），有 followUser/unfollowUser
- `settings.state.dart` — 22 个设置字段，loadSettings/updateSetting
- `message.state.dart` — 消息/群聊
- `topic.state.dart` — 话题
- `community.state.dart` — 社区
- `notification.state.dart` — 通知列表/筛选/分页/标记已读
- `draft.state.dart` — 草稿
- `auth.state.dart` — 认证状态

### Model 层 (`lib/model/`)
- `post.module.dart` — PostModel（含 P3 新字段：location, topicIds, isGhost, communityId, replySettings, quoteRepostId, isPinned, scheduledTime, isAi）
- `user.module.dart` — UserModel, UserSettings
- `message.module.dart` — 消息/会话/群聊模型
- `topic.module.dart` — 话题模型
- `community.module.dart` — 社区模型
- `draft.module.dart` — 草稿模型

### UI 页面 (`lib/pages/`)
- `feed/feed.dart` — 首页 Feed
- `composePost/post.dart` — 发帖页（支持 location 输入）
- `profile/profile.dart` — 他人主页（**TabBarView 为静态占位**）
- `profile/myprofile.dart` — 自己的主页
- `profile/edit.dart` — 编辑资料
- `notification/notification.dart` — 通知页（**i18n 硬编码中文**）
- `search/search.dart` — 搜索页
- `message/message_page.dart` — 消息列表
- `message/chat_detail_page.dart` — 聊天详情
- `community/community_list_page.dart` — 社区列表
- `community/community_detail_page.dart` — 社区详情
- `topic/topic_detail_page.dart` — 话题详情
- `post/guest_reply_review_page.dart` — 幽灵帖审核

### Widget (`lib/widget/`)
- `feedpost.dart` — Feed 帖子卡片（点赞/评论/转发/收藏/分享/更多菜单均已实现，引用转发为 no-op）
- `reply_bottom_sheet.dart` — 回复输入底部弹窗
- `poll_widget.dart` — 投票组件
- `draft_list_sheet.dart` — 草稿列表弹窗
- `topic_tile.dart` — 话题标签组件

### Settings (`lib/common/settings/`)
- `settings.dart` — 设置主页（语言切换、登出、链接到各子页面）
- `notification_settings.dart` — 通知设置页
- `privacy_settings.dart` — 隐私设置页
- `relation_control_page.dart` — 关系管控（静音/限制/拉黑）
- `collections_page.dart` — 收藏夹管理
- `hidden_words_page.dart` — 隐藏词管理
- `links_page.dart` — 链接管理

### 国际化 (`lib/l10n/`)
- `app_en.arb` / `app_zh.arb` — 英文/中文翻译源文件（~242 行）
- `generated/app_localizations.dart` — 抽象基类
- `generated/app_localizations_en.dart` — 英文实现
- `generated/app_localizations_zh.dart` — 中文实现

---

## 编码规范与约束

1. **三层架构**: Service（API 调用）→ State（ChangeNotifier + 乐观更新）→ UI（Consumer/Provider.of）。不要跳层。
2. **Service 初始化**: State 中使用懒加载 `PostService? _postService; PostService get postService { _postService ??= PostService(apiClient: getIt()); return _postService!; }`
3. **双格式 JSON 解析**: Model.fromJson 同时支持 snake_case 和 camelCase（如 `map['likes_count'] ?? map['likesCount']`）
4. **分页响应**: API 可能返回 `List` 或 `{items: [], total, page, size}` 格式，都要兼容（参照 PostService.getFeed() 中的处理模式）
5. **暗色主题**:
   - `Scaffold(backgroundColor: Colors.black)`
   - `AppBar(backgroundColor: Colors.transparent, elevation: 0)`
   - 分割线: `Color(0xff333333)`, thickness 0.5
   - 次要文字: `Color(0xff888888)`
   - 时间戳: `Color(0xff555555)`
   - 容器背景: `Color(0xff1a1a1a)`
   - `withOpacity` 已废弃，统一使用 `withValues(alpha: x)`
6. **i18n**: 所有 UI 文字通过 `AppLocalizations.of(context)!` 获取。新增 key 需同步更新：`app_en.arb` → `app_zh.arb` → `app_localizations.dart`（抽象 getter）→ `app_localizations_en.dart` → `app_localizations_zh.dart`
7. **不创建文档文件**: 不要写 README 或 .md 文件（除非是 docs/tasks/ 下的实施计划）
8. **不添加不必要的注释/文档/类型注解**: 只在逻辑不自明时添加注释
9. **乐观更新**: like/unlike、repost/unrepost、save/unsave 等交互先更新 UI 再调 API，失败时回滚
10. **mounted 检查**: 所有 async 操作后 setState 前必须 `if (mounted)` 检查

---

## 执行方式

1. **先读取关键文件**了解当前实现：`post_service.dart`、`post.state.dart`、`feedpost.dart`、`profile/profile.dart`、`notification/notification.dart`、`notification_service.dart`、`notification.state.dart`、`server-api-analysis.md`
2. **制定实施计划**，写入 `docs/tasks/phase-4-advanced-features/implementation-plan.md`，包含子任务编号、依赖关系、批量执行策略
3. **按批量执行**：Model/Service → State → UI → i18n，每批内尽可能并行
4. **每个子任务完成后立即标记 todo 为 completed**
5. **最后运行 `dart analyze`**，确保 0 新增 error

---

## 参考文档路径

- 服务端 API 分析: `docs/analysis/server-api-analysis.md`
- 客户端差距分析: `docs/analysis/gap-analysis.md`
- P3 实施计划: `docs/tasks/phase-3-social-enhancement/implementation-plan.md`
- OpenAPI 原始文档: `openapi_docs/` 目录下的 JSON 文件
