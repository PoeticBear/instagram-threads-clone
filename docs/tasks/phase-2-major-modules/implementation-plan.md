# Phase 2 — 大型模块开发

> 目标：实现 Message 模块（私信+群聊）、Topic 模块（话题系统）、Draft 功能（草稿箱）
> 涉及文件：~40 个（新建 ~25 个，修改 ~15 个）
> 前置条件：P0 + P1 已完成（核心体验已可用）

---

## 子任务总览

| # | 子任务 | 类型 | 依赖 | 状态 |
|---|-------|------|------|------|
| 2.1 | Message 模型定义（Conversation / Message / GroupChat / GroupMember） | Model | 无 | ⬜ 未开始 |
| 2.2 | MessageService 实现（会话管理 6 端点 + 消息收发 2 端点） | Service | 2.1 | ⬜ 未开始 |
| 2.3 | MessageService 补充（群聊 10 端点 + 消息反应 2 端点 + 搜索/设置/推荐 6 端点） | Service | 2.2 | ⬜ 未开始 |
| 2.4 | MessageState 实现（会话列表、消息收发、已读标记、消息反应） | State | 2.2 | ⬜ 未开始 |
| 2.5 | MessageState 补充（群聊管理、消息搜索、消息设置） | State | 2.3, 2.4 | ⬜ 未开始 |
| 2.6 | 会话列表页（MessagePage） | UI | 2.4 | ⬜ 未开始 |
| 2.7 | 聊天详情页（ChatDetailPage） | UI | 2.4 | ⬜ 未开始 |
| 2.8 | 群聊管理页面（GroupChatPage + GroupMembersPage） | UI | 2.5 | ⬜ 未开始 |
| 2.9 | Topic 模型定义（TopicInfo） | Model | 无 | ⬜ 未开始 |
| 2.10 | TopicService 实现（10 端点） | Service | 2.9 | ⬜ 未开始 |
| 2.11 | TopicState 实现（话题详情、关注/取关、静音、帖子列表） | State | 2.10 | ⬜ 未开始 |
| 2.12 | 话题详情页（TopicDetailPage）+ 话题帖子列表 | UI | 2.11 | ⬜ 未开始 |
| 2.13 | Draft 模型定义（DraftInfo）+ PostService 补充 Draft 端点 | Model/Service | 无 | ⬜ 未开始 |
| 2.14 | DraftState 实现 + 发帖页（ComposePost）集成草稿功能 | State/UI | 2.13 | ⬜ 未开始 |
| 2.15 | P2 本地化字符串补充（Message / Topic / Draft 相关文本） | i18n | 2.7, 2.12, 2.14 | ⬜ 未开始 |

---

## 子任务 2.1 — Message 模型定义

**状态：⬜ 未开始**

### 目标

定义消息模块所需的全部数据模型，覆盖服务端 API 文档中的 ConversationResponse、MessageResponse、GroupChatResponse、GroupMemberResponse、SendMessageRequest、MessageSettingsResponse 等。

### 模型清单

**Conversation**（会话模型）
- 字段：id, peerUserId, peerUsername, peerDisplayName, peerAvatarUrl, conversationType(1=收件箱/2=陌生人), lastMessageContent, lastMessageTime, unreadCount, isReplied, isVerified, isHidden, isPinned
- 方法：fromJson, toJson

**ChatMessage**（消息模型）
- 字段：id, senderId, receiverId, content, mediaType(0-4), mediaUrl, isRead, deliveryStatus(1-3), readTime, quoteMessageId, reactions(List<MessageReaction>), createTime
- 方法：fromJson, toJson

**MessageReaction**（消息反应）
- 字段：emoji, userId, createTime
- 方法：fromJson

**GroupChat**（群聊模型）
- 字段：id, name, avatarUrl, inviteLink, inviteLinkEnabled, needApprove, membersCount, lastMessageTime, createTime
- 方法：fromJson, toJson

**GroupMember**（群成员模型）
- 字段：userId, username, displayName, avatarUrl, role(1=成员/2=管理员), joinTime
- 方法：fromJson

**MessageSettings**（消息设置）
- 字段：messageRequestEnabled, messageRequestAllowType
- 方法：fromJson, toJson

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/model/message.module.dart` | **新建** | 全部消息模型 |

### 验证方式

- Conversation.fromJson 能正确解析 conversation_type、unread_count、is_pinned 等字段
- ChatMessage.fromJson 能正确解析 delivery_status、reactions 数组
- GroupChat.fromJson 能正确解析 invite_link、need_approve 等字段

---

## 子任务 2.2 — MessageService 实现（会话管理 + 消息收发）

**状态：⬜ 未开始**

### 目标

实现 MessageService 的基础部分：会话管理（6 端点）和消息收发（2 端点），覆盖核心私信功能。

### API 端点

| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| GET | `/message/conversations` | `getConversations(page, size)` |
| GET | `/message/conversations/{id}/messages` | `getMessages(conversationId, {page, size, beforeTime})` |
| POST | `/message/conversations/{id}/hide` | `hideConversation(conversationId)` |
| POST | `/message/conversations/{id}/verify` | `verifyConversation(conversationId)` |
| POST | `/message/conversations/{id}/pin` | `pinConversation(conversationId)` |
| DELETE | `/message/conversations/{id}/pin` | `unpinConversation(conversationId)` |
| POST | `/message/send` | `sendMessage(receiverId, content, {mediaType, mediaUrl, quoteMessageId})` |
| POST | `/message/mark-read` | `markAsRead(conversationId)` |

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/services/message_service.dart` | **新建** | MessageService + 基础 8 个方法 |

### 代码模式

遵循 PostService 的模式：
- 构造函数注入 `ApiClient`
- 每个方法 `try/catch ApiException`
- GET 列表支持 `PageMeta` 解析（先尝试 `data['items']`，再尝试 `data is List`）
- POST 返回解析后的模型对象

### 验证方式

- `getConversations()` 能正确调用并解析分页数据
- `sendMessage()` 能发送文本消息并返回 ChatMessage
- `markAsRead()` 能标记会话已读

---

## 子任务 2.3 — MessageService 补充（群聊 + 反应 + 搜索/设置/推荐）

**状态：⬜ 未开始**

### 目标

补充 MessageService 的完整功能：群聊管理（10 端点）、消息反应（2 端点）、消息搜索/设置/推荐用户（6 端点）。

### API 端点

**消息反应**
| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| POST | `/message/reactions` | `addReaction(messageId, emoji)` |
| DELETE | `/message/reactions` | `removeReaction(messageId, emoji)` |

**群聊管理**
| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| POST | `/message/group/create` | `createGroupChat(name, {avatarUrl, needApprove})` |
| GET | `/message/group/list` | `getGroupChats(page, size)` |
| GET | `/message/group/{id}` | `getGroupChatDetail(groupId)` |
| PUT | `/message/group/{id}` | `updateGroupChat(groupId, {name, avatarUrl, ...})` |
| GET | `/message/group/{id}/members` | `getGroupMembers(groupId, {page, size})` |
| DELETE | `/message/group/{id}/members/{uid}` | `removeGroupMember(groupId, userId)` |
| POST | `/message/group/join` | `joinGroupChat(inviteLink)` |
| POST | `/message/group/{id}/leave` | `leaveGroupChat(groupId)` |
| GET | `/message/group/{id}/join-requests` | `getJoinRequests(groupId)` |
| POST | `/message/group/{id}/join-requests/approve` | `approveJoinRequest(groupId, requestId)` |

**搜索/设置/推荐**
| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| GET | `/message/search` | `searchMessages(keyword, {page, size})` |
| GET | `/message/settings` | `getMessageSettings()` |
| PUT | `/message/settings` | `updateMessageSettings(settings)` |
| GET | `/message/recommend-users` | `getRecommendUsers({page, size})` |
| GET | `/message/search-users` | `searchChatUsers(keyword, {page, size})` |
| GET | `/message/hidden` | `getHiddenConversations({page, size})` |

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/services/message_service.dart` | 修改 | 新增 18 个方法 |

### 验证方式

- `addReaction()` 能添加 emoji 反应
- `createGroupChat()` 能创建群聊并返回 GroupChat
- `searchMessages()` 能按关键词搜索消息

---

## 子任务 2.4 — MessageState 实现（会话列表、消息收发、已读标记、消息反应）

**状态：⬜ 未开始**

### 目标

创建 MessageState，管理会话列表、当前聊天消息列表、发送消息、已读标记和消息反应的状态。

### 状态管理

```dart
class MessageState extends ChangeNotifier {
  // 会话列表
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  int _conversationPage = 1;
  bool _hasMoreConversations = true;

  // 当前聊天消息
  List<ChatMessage> _currentMessages = [];
  int _currentConversationId = 0;
  bool _isLoadingMessages = false;

  // 方法
  Future<void> loadConversations();
  Future<void> loadMoreConversations();
  Future<void> loadMessages(int conversationId);
  Future<void> sendMessage(int receiverId, String content, {int? mediaType, String? mediaUrl});
  Future<void> markAsRead(int conversationId);
  Future<void> addReaction(int messageId, String emoji);
  Future<void> removeReaction(int messageId, String emoji);
  Future<void> pinConversation(int conversationId);
  Future<void> unpinConversation(int conversationId);
  Future<void> hideConversation(int conversationId);
}
```

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/state/message.state.dart` | **新建** | MessageState |
| `client/lib/main.dart` | 修改 | MultiProvider 注册 MessageState |

### 代码模式

遵循 PostState 的模式：
- Service 通过 `getIt<ApiClient>()` 懒加载
- 发送消息使用乐观更新（先插入本地，失败回滚）
- 会话列表支持分页加载

### 验证方式

- `loadConversations()` 能加载会话列表
- `sendMessage()` 能乐观更新消息列表并发送到 API
- `markAsRead()` 能清除未读计数

---

## 子任务 2.5 — MessageState 补充（群聊管理、消息搜索、消息设置）

**状态：⬜ 未开始**

### 目标

补充 MessageState 的群聊管理、消息搜索和消息设置功能。

### 新增状态管理

```dart
// 群聊
List<GroupChat> _groupChats = [];
GroupChat? _currentGroupChat;
List<GroupMember> _groupMembers = [];

// 搜索
List<ChatMessage> _searchResults = [];
bool _isSearching = false;

// 设置
MessageSettings _messageSettings = MessageSettings();

// 方法
Future<void> loadGroupChats();
Future<void> createGroupChat(String name, {String? avatarUrl});
Future<void> loadGroupMembers(int groupId);
Future<void> leaveGroupChat(int groupId);
Future<List<ChatMessage>> searchMessages(String keyword);
Future<void> loadMessageSettings();
Future<void> updateMessageSettings(MessageSettings settings);
Future<void> getRecommendUsers();
Future<void> searchChatUsers(String keyword);
Future<void> getHiddenConversations();
Future<void> approveJoinRequest(int groupId, int requestId);
```

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/state/message.state.dart` | 修改 | 新增群聊/搜索/设置方法 |

### 验证方式

- `createGroupChat()` 能创建群聊并刷新列表
- `searchMessages()` 能返回搜索结果
- `loadMessageSettings()` 能获取消息设置

---

## 子任务 2.6 — 会话列表页（MessagePage）

**状态：⬜ 未开始**

### 目标

新建消息列表页面，显示所有会话（包括私聊和群聊），支持搜索、查看推荐用户、隐藏会话管理。

### 页面结构

```
┌──────────────────────────────────┐
│  ← Messages              ✏️(新建) │  顶栏
├──────────────────────────────────┤
│  [🔍 搜索]                       │  搜索栏
├──────────────────────────────────┤
│  👤 Alice        "Hey!"    3m    │  会话项
│  👤 Bob          "See you" 1h    │
│  👥 Group Chat   "Hello"   2h    │  群聊项
│  ...                             │
└──────────────────────────────────┘
```

### 功能

1. 会话列表展示：头像、用户名/群名、最后消息、时间、未读角标
2. 置顶会话排在最前
3. 下拉加载更多（分页）
4. 点击会话 → 导航到 ChatDetailPage
5. 右上角新建按钮 → 搜索用户发起新会话
6. 左滑/长按会话 → 置顶/隐藏/删除

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/pages/message/message_page.dart` | **新建** | 会话列表页 |
| `client/lib/pages/message/message_list_tile.dart` | **新建** | 会话列表项组件 |

### 验证方式

- 打开消息页 → 显示会话列表
- 点击会话 → 进入聊天详情
- 下拉滚动 → 加载更多会话
- 置顶的会话显示在最上面

---

## 子任务 2.7 — 聊天详情页（ChatDetailPage）

**状态：⬜ 未开始**

### 目标

新建 1 对 1 聊天详情页，显示消息列表，支持发送消息、消息反应、已读标记。

### 页面结构

```
┌──────────────────────────────────┐
│  ← Alice                  ⋮     │  顶栏（用户名 + 更多菜单）
├──────────────────────────────────┤
│                                  │
│     Hey! 👋                  3m │  对方消息（右对齐气泡）
│                                  │
│  👋 Hi there!                3m │  我的消息（左对齐气泡）
│                                  │
│  ～～～                         │
├──────────────────────────────────┤
│  😊 [Type a message...]  [➤]    │  底部输入栏
└──────────────────────────────────┘
```

### 功能

1. 消息列表：左右气泡布局，显示头像、内容、时间
2. 底部输入框：输入文本 + 发送按钮
3. 双击/长按消息 → 弹出 emoji 反应选择器
4. 更多菜单(⋮)：置顶/取消置顶会话、隐藏会话、标记已读
5. 进入聊天时自动调用 `markAsRead()`
6. 消息气泡支持图片消息（mediaType=1）
7. 引用消息展示（quoteMessageId 对应的消息摘要）

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/pages/message/chat_detail_page.dart` | **新建** | 聊天详情页 |
| `client/lib/pages/message/chat_bubble.dart` | **新建** | 消息气泡组件 |
| `client/lib/pages/message/reaction_picker.dart` | **新建** | Emoji 反应选择器 |

### 验证方式

- 进入聊天 → 显示消息历史
- 输入文字 → 发送 → 消息出现在列表底部
- 双击消息 → 弹出 emoji 选择器 → 选择后反应显示在气泡下方
- 进入聊天 → 未读计数清零

---

## 子任务 2.8 — 群聊管理页面

**状态：⬜ 未开始**

### 目标

新建群聊管理相关页面：创建群聊、群聊详情、群成员列表、入群审批。

### 页面清单

**CreateGroupChatPage** — 创建群聊
- 输入群名、上传群头像
- 选择群成员（从关注列表/推荐用户中选择）
- 设置是否需要审批入群
- 生成邀请链接

**GroupChatDetailPage** — 群聊详情
- 群名、群头像、邀请链接
- 成员列表入口
- 修改群信息
- 退出群聊

**GroupMembersPage** — 群成员列表
- 分页加载成员
- 管理员可移除成员
- 入群请求审批入口（仅管理员）

**JoinRequestsPage** — 入群审批
- 显示待审批请求列表
- 批准/拒绝操作

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/pages/message/create_group_page.dart` | **新建** | 创建群聊页 |
| `client/lib/pages/message/group_chat_detail_page.dart` | **新建** | 群聊详情页 |
| `client/lib/pages/message/group_members_page.dart` | **新建** | 群成员列表页 |
| `client/lib/pages/message/join_requests_page.dart` | **新建** | 入群审批页 |

### 验证方式

- 创建群聊 → 选择成员 → 成功创建
- 群聊详情页显示群信息和成员数
- 群成员列表可分页加载
- 管理员可批准/拒绝入群请求

---

## 子任务 2.9 — Topic 模型定义

**状态：⬜ 未开始**

### 目标

定义话题模块的数据模型 TopicInfo，对齐服务端 TopicResponse / TopicPostItem 数据结构。

### 模型

**TopicInfo**（话题模型）
- 字段：id, name, description, postsCount, followersCount, isFollowing, isMuted, coverUrl, createTime
- 方法：fromJson, toJson, copyWith

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/model/topic.module.dart` | **新建** | TopicInfo 模型 |

### 验证方式

- TopicInfo.fromJson 能解析服务端返回的话题数据
- copyWith 能正确复制并修改字段

---

## 子任务 2.10 — TopicService 实现

**状态：⬜ 未开始**

### 目标

实现 TopicService，覆盖全部 10 个端点。

### API 端点

| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| GET | `/topic/trending` | `getTrendingTopics({limit})` |
| GET | `/topic/list` | `getTopics({page, size, sourceType})` |
| GET | `/topic/detail/{topic_id}` | `getTopicDetail(topicId)` |
| POST | `/topic/follow/{topic_id}` | `followTopic(topicId)` |
| DELETE | `/topic/follow/{topic_id}` | `unfollowTopic(topicId)` |
| POST | `/topic/mute/{topic_id}` | `muteTopic(topicId)` |
| DELETE | `/topic/mute/{topic_id}` | `unmuteTopic(topicId)` |
| GET | `/topic/muted` | `getMutedTopics()` |
| GET | `/topic/posts/{topic_id}` | `getTopicPosts(topicId, {page, size, sort})` |
| GET | `/topic/related/{topic_id}` | `getRelatedTopics(topicId, {limit})` |

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/services/topic_service.dart` | **新建** | TopicService + 10 个方法 |

### 验证方式

- `getTopicDetail()` 能获取话题详情
- `followTopic()` 能关注话题
- `getTopicPosts()` 能分页获取话题帖子

---

## 子任务 2.11 — TopicState 实现

**状态：⬜ 未开始**

### 目标

创建 TopicState，管理话题详情、关注/取关、静音、话题帖子列表的状态。

### 状态管理

```dart
class TopicState extends ChangeNotifier {
  TopicInfo? _topicDetail;
  List<TopicInfo> _relatedTopics = [];
  bool _isFollowing = false;
  bool _isMuted = false;
  List<Post> _topicPosts = [];
  bool _isLoadingPosts = false;
  int _postsPage = 1;
  bool _hasMorePosts = true;

  // 方法
  Future<void> loadTopicDetail(int topicId);
  Future<void> followTopic(int topicId);
  Future<void> unfollowTopic(int topicId);
  Future<void> muteTopic(int topicId);
  Future<void> unmuteTopic(int topicId);
  Future<void> loadTopicPosts(int topicId, {String sort = 'latest'});
  Future<void> loadMoreTopicPosts(int topicId);
  Future<void> loadRelatedTopics(int topicId);
}
```

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/state/topic.state.dart` | **新建** | TopicState |
| `client/lib/main.dart` | 修改 | MultiProvider 注册 TopicState（如果需要全局访问） |

注意：TopicState 也可以作为局部 Provider，仅在 TopicDetailPage 中通过 `ChangeNotifierProvider` 创建，类似 ProfilePage 的模式。具体选择取决于是否需要在其他页面（如搜索页）共享关注状态。建议使用局部 Provider 模式，避免全局状态过度膨胀。

### 验证方式

- `loadTopicDetail()` 能加载话题详情
- `followTopic()` 乐观更新 isFollowing 状态
- `loadTopicPosts()` 能分页加载话题帖子

---

## 子任务 2.12 — 话题详情页 + 话题帖子列表

**状态：⬜ 未开始**

### 目标

新建话题详情页，展示话题信息、关注按钮、话题下的帖子列表和相关话题推荐。同时更新现有的 TopicTile 组件，使关注按钮对接 API。

### 页面结构

```
┌──────────────────────────────────┐
│  ← #Technology            ⋮     │  顶栏
├──────────────────────────────────┤
│  #Technology                     │  话题名称
│  12.5K posts · 3.2K followers    │  统计
│  [Follow]                        │  关注按钮
├──────────────────────────────────┤
│  [Latest] [Top] [People]         │  排序 Tab
├──────────────────────────────────┤
│  帖子1                           │
│  帖子2                           │  帖子列表（复用 FeedPostWidget）
│  ...                             │
├──────────────────────────────────┤
│  Related Topics                  │
│  #AI  #Programming  #Tech        │  相关话题
└──────────────────────────────────┘
```

### 功能

1. 话题信息展示：名称、帖子数、关注数、描述
2. 关注/取关按钮（乐观更新）
3. 更多菜单(⋮)：静音/取消静音话题
4. 帖子列表：复用 FeedPostWidget，支持分页加载
5. 排序切换：latest / popular / people
6. 相关话题推荐：横向滚动展示，点击可导航到另一个话题详情页
7. 更新 TopicTile 的关注按钮，对接 TopicService.followTopic/unfollowTopic

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/pages/topic/topic_detail_page.dart` | **新建** | 话题详情页 |
| `client/lib/widget/topic_tile.dart` | 修改 | 关注按钮对接 API |

### 验证方式

- 从搜索页点击话题 → 进入话题详情页
- 点击关注 → 按钮变为 "Following"，数量 +1
- 帖子列表正确展示，可滚动加载更多
- 相关话题可点击跳转

---

## 子任务 2.13 — Draft 模型定义 + PostService 补充 Draft 端点

**状态：⬜ 未开始**

### 目标

定义草稿数据模型 DraftInfo，并在 PostService 中补充 4 个草稿相关端点。

### 模型

**DraftInfo**（草稿模型）
- 字段：id, content, mediaUrls(List<String>), pollOptions(List<String>?), topicIds(List<int>?), replySettings(int?), createdAt, updatedAt
- 方法：fromJson, toJson

### API 端点

| 方法 | 路径 | Service 方法 |
|------|------|-------------|
| POST | `/post/draft` | `saveDraft(content, {mediaUrls, pollOptions, topicIds, replySettings})` |
| GET | `/post/draft/list` | `getDrafts({page, size})` |
| GET | `/post/draft/{draft_id}` | `getDraftDetail(draftId)` |
| DELETE | `/post/draft/{draft_id}` | `deleteDraft(draftId)` |

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/model/draft.module.dart` | **新建** | DraftInfo 模型 |
| `client/lib/services/post_service.dart` | 修改 | 新增 4 个 Draft 方法 |

### 验证方式

- `saveDraft()` 能保存草稿并返回 DraftInfo
- `getDrafts()` 能获取草稿列表
- `deleteDraft()` 能删除草稿

---

## 子任务 2.14 — DraftState 实现 + 发帖页集成草稿功能

**状态：⬜ 未开始**

### 目标

创建 DraftState 管理草稿列表状态，并在发帖页（ComposePost）集成草稿功能：保存草稿、加载草稿列表、恢复草稿内容。

### 状态管理

```dart
class DraftState extends ChangeNotifier {
  List<DraftInfo> _drafts = [];
  bool _isLoading = false;

  Future<void> loadDrafts();
  Future<DraftInfo> saveDraft(String content, {List<String>? mediaUrls, ...});
  Future<void> deleteDraft(int draftId);
  Future<DraftInfo?> loadDraftForEditing(int draftId);
}
```

### 发帖页集成

在 ComposePost 页面中：

1. **新增「草稿箱」按钮**：顶栏右侧，点击弹出草稿列表 BottomSheet
2. **草稿列表 BottomSheet**：显示已保存草稿，点击可恢复内容到编辑区
3. **自动保存草稿**：用户编辑中途退出时，弹出确认对话框：
   - 「保存草稿」→ 调用 `saveDraft()`
   - 「丢弃」→ 直接退出
   - 「继续编辑」→ 留在页面
4. **草稿恢复**：从草稿列表选择草稿后，恢复文本、图片等编辑内容

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/state/draft.state.dart` | **新建** | DraftState |
| `client/lib/main.dart` | 修改 | MultiProvider 注册 DraftState |
| `client/lib/pages/composePost/compose_post_page.dart` | 修改 | 集成草稿功能 |
| `client/lib/widget/draft_list_sheet.dart` | **新建** | 草稿列表 BottomSheet |

### 验证方式

- 编辑帖子 → 退出 → 选择「保存草稿」→ 草稿保存成功
- 打开草稿箱 → 看到已保存草稿 → 点击恢复 → 编辑区恢复内容
- 删除草稿 → 草稿从列表移除

---

## 子任务 2.15 — P2 本地化字符串补充

**状态：⬜ 未开始**

### 目标

为 P2 新增的所有 UI 文本添加 i18n 字符串，支持中英文。

### 新增的本地化 key

```json
// === Message 模块 ===
"messages": "Messages" / "消息"
"newMessage": "New Message" / "新消息"
"searchMessages": "Search messages" / "搜索消息"
"searchUsers": "Search users" / "搜索用户"
"typeMessage": "Type a message..." / "输入消息..."
"send": "Send" / "发送"
"conversations": "Conversations" / "会话"
"noMessages": "No messages yet" / "暂无消息"
"noConversations": "No conversations" / "暂无会话"
"pinConversation": "Pin" / "置顶"
"unpinConversation": "Unpin" / "取消置顶"
"hideConversation": "Hide" / "隐藏"
"messageSettings": "Message Settings" / "消息设置"
"messageRequestEnabled": "Message Requests" / "陌生人消息"
"messageRequestAllowType": "Who can message you" / "谁能发消息"
"onlyFollowedUsers": "Followed users" / "仅你关注的用户"
"anyone": "Anyone" / "任何人"

// 群聊
"createGroup": "Create Group" / "创建群聊"
"groupName": "Group Name" / "群名称"
"groupMembers": "Members" / "成员"
"inviteLink": "Invite Link" / "邀请链接"
"leaveGroup": "Leave Group" / "退出群聊"
"joinGroup": "Join Group" / "加入群聊"
"joinRequests": "Join Requests" / "入群请求"
"approve": "Approve" / "批准"
"reject": "Reject" / "拒绝"
"needApprove": "Require Approval" / "需要审批"
"selectMembers": "Select Members" / "选择成员"
"groupInfo": "Group Info" / "群信息"

// 消息反应
"reactions": "Reactions" / "回应"
"addReaction": "Add Reaction" / "添加回应"
"removeReaction": "Remove Reaction" / "移除回应"

// === Topic 模块 ===
"topicDetail": "Topic" / "话题"
"followTopic": "Follow" / "关注"
"unfollowTopic": "Following" / "已关注"
"muteTopic": "Mute" / "静音"
"unmuteTopic": "Unmute" / "取消静音"
"topicPosts": "Posts" / "帖子"
"relatedTopics": "Related Topics" / "相关话题"
"latest": "Latest" / "最新"
"popular": "Popular" / "热门"
"mutedTopics": "Muted Topics" / "已静音话题"
"topicFollowers": "followers" / "关注者"
"topicPostsCount": "posts" / "帖子"

// === Draft 模块 ===
"drafts": "Drafts" / "草稿箱"
"saveDraft": "Save Draft" / "保存草稿"
"discardDraft": "Discard" / "丢弃"
"continueEditing": "Continue Editing" / "继续编辑"
"noDrafts": "No drafts" / "暂无草稿"
"loadDraft": "Load" / "加载"
"deleteDraft": "Delete" / "删除"
"unsavedChanges": "Unsaved changes" / "未保存的更改"
"saveDraftHint": "Would you like to save this as a draft?" / "是否保存为草稿？"
```

### 文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/lib/l10n/app_en.arb` | 修改 | 新增 ~50 个 key |
| `client/lib/l10n/app_zh.arb` | 修改 | 新增 ~50 个 key |
| `client/lib/l10n/generated/app_localizations.dart` | 修改 | 新增 getter |
| `client/lib/l10n/generated/app_localizations_en.dart` | 修改 | 新增实现 |
| `client/lib/l10n/generated/app_localizations_zh.dart` | 修改 | 新增实现 |

### 验证方式

- 所有新字符串通过 `AppLocalizations.of(context)!.xxx` 可访问
- 中英文切换后文本正确显示

---

## 执行顺序与依赖关系

```
2.1 Message 模型 ─────→ 2.2 MessageService (基础) ─────→ 2.3 MessageService (补充)
                            │                                    │
                            ├─→ 2.4 MessageState (基础) ─────→ 2.5 MessageState (补充)
                            │         │                            │
                            │         ├─→ 2.6 会话列表页            │
                            │         ├─→ 2.7 聊天详情页            │
                            │                                       ├─→ 2.8 群聊管理页面
                            │
2.9 Topic 模型 ────→ 2.10 TopicService ────→ 2.11 TopicState ────→ 2.12 话题详情页

2.13 Draft 模型 + Service ────→ 2.14 DraftState + ComposePost 集成

2.7 + 2.12 + 2.14 ──────→ 2.15 本地化字符串
```

可并行的工作组：
- **组 A**：2.1→2.2→2.3（Message Service 全量）
- **组 B**：2.9→2.10（Topic Service 全量）
- **组 C**：2.13（Draft 模型 + Service）

State 和 UI 层依赖对应的 Service 完成：
- **组 D**：2.4→2.6+2.7（Message State + 核心 UI）— 依赖组 A 的 2.2
- **组 E**：2.5→2.8（Message State 补充 + 群聊 UI）— 依赖组 A 的 2.3
- **组 F**：2.11→2.12（Topic State + 详情页）— 依赖组 B
- **组 G**：2.14（Draft State + 集成）— 依赖组 C
- **组 H**：2.15（i18n）— 依赖所有 UI 子任务

### 推荐执行顺序

```
第一批（模型层 + Service，可并行）：
  2.1 → 2.2 → 2.3    (Message 全量 Service)
  2.9 → 2.10          (Topic 全量 Service)
  2.13                (Draft 模型 + Service)

第二批（State + UI）：
  2.4 → 2.6           (Message State + 会话列表)
  2.4 → 2.7           (Message State + 聊天详情)
  2.11 → 2.12         (Topic State + 详情页)
  2.14                (Draft State + 集成)

第三批（补充 + 收尾）：
  2.5 → 2.8           (群聊管理)
  2.15                (i18n)
```

---

## 完成标准

- [ ] 会话列表页正确展示私聊和群聊会话
- [ ] 聊天详情页能发送/接收文本消息
- [ ] 消息反应（emoji）可添加/移除
- [ ] 群聊能创建、查看成员、管理入群请求
- [ ] 消息设置可读取和修改
- [ ] 话题详情页展示话题信息和帖子列表
- [ ] 话题关注/取关可用，TopicTile 按钮对接 API
- [ ] 话题可静音/取消静音
- [ ] 草稿可保存、加载、删除
- [ ] 发帖页集成草稿保存/恢复功能
- [ ] 所有新文本支持中英文切换
- [ ] 无新增 lint warning
