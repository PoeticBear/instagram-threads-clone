# 私信（聊天）模块代码定位清单

> 最后更新：2026-07-22
> 覆盖范围：单聊会话、群聊、消息收发、消息反应、入群审批、消息搜索、消息设置、隐藏会话、WebSocket 实时事件、**聊天使用协议（EULA）拦截**。

## 1. 模块总览

私信是一个独立的功能模块，代码集中在 `client/lib/` 下五个位置，遵循项目「页面 / 状态 / 服务 / 模型 / WS」的分层约定：

| 分层 | 文件 | 职责 |
| --- | --- | --- |
| 数据模型 | `model/message.module.dart` | `Conversation` / `ChatMessage` / `MessageReaction` / `GroupChat` / `GroupMember` / `MessageSettings` / `SendMessageResponse` |
| API 服务 | `services/message_service.dart` | 全部 HTTP 请求（会话、消息、群聊、搜索、设置等 28 个接口） |
| 状态管理 | `state/message.state.dart` | 全局单例 `MessageState`，承载所有列表数据 + 乐观更新 + WS 事件入口 |
| WebSocket 处理 | `services/ws_handlers/message_handlers.dart`、`services/ws_handlers/typing_handler.dart` | 解析 WS 事件并转发给 `MessageState` |
| 页面 / 组件 | `pages/message/`（13 个文件） | 会话列表、聊天详情、群聊详情、群成员、建群/加群/审批等 UI |

## 2. 入口点

**私信不是底部 5 个 Tab 之一**，而是从 Feed 顶部的消息图标进入：

- `pages/feed/feed.dart:135-137` — `GestureDetector` 点击 `Iconsax.message` → `Navigator.push(CupertinoPageRoute(builder: (_) => MessagePage()))`。
- `pages/home.dart:8` — 仅 import，未直接挂载。

底部 5 个 Tab（Feed / Search / ComposePost / Notification / Profile）见 `pages/home.dart`；私信属二级路由页面。

### 进入私信前的闸门：最终用户许可协议（EULA）拦截

用户首次（或协议改版后首次）进入私信模块时，强制以**底部 sheet** 弹出完整「最终用户许可协议」，必须点「同意并继续」才能真正使用私信；点「不同意」则退回 Feed，且**状态不落库**（下次仍弹）。同意后本地持久化，下次不再弹。涉及 3 处代码：

| 角色 | 文件 | 关键符号 / 行号 |
| --- | --- | --- |
| 拦截接入点 | `pages/message/message_page.dart:38-58` | `_maybeShowEulaThenLoad()`，由 `initState` 的 `addPostFrameCallback` 触发 |
| 弹窗 UI + 持久化逻辑 | `pages/message/chat_eula_dialog.dart` | `ChatEulaConsent`（`needsAgreement` / `markAgreed`）、`ChatEulaDialog`（底部 sheet）、`kCurrentChatEulaVersion` |
| 国际化文案 | `l10n/app_en.arb` / `app_zh.arb`（`chatEula*` 段，文末） | `chatEulaTitle` / `chatEulaLastUpdated` / `chatEulaIntro` / `chatEulaSection{1..6}Title`/`Body` / `chatEulaAgree` / `chatEulaDisagree`（17 key，中英双语） |

**拦截流程**（`_maybeShowEulaThenLoad`）：

```
MessagePage.initState (postFrameCallback)
  → ChatEulaConsent.needsAgreement?   // 从未同意，或已同意版本 != kCurrentChatEulaVersion
     ├─ 是 → showModalBottomSheet<ChatEulaDialog>(isScrollControlled, isDismissible:false, enableDrag:false)
     │        ├─ 返回 true（同意）  → ChatEulaConsent.markAgreed() 落库 → loadConversations()
     │        └─ 返回 false/关闭    → Navigator.pop() 退回 Feed（不落库，下次仍弹）
     └─ 否 → 直接 loadConversations()
```

- **形态**：底部 sheet（`showModalBottomSheet`，顶部圆角 16），禁用下拉与点遮罩关闭（`enableDrag: false` + `isDismissible: false`），用户**只能**点「同意并继续」或「不同意」二选一。
- **协议正文**：完整 EULA 全文内置（以 `ref-eula.md` 6 大条款为准，适配 App 显示名「Tweet」），结构化拆 key、按条款排版（小标题加粗 + 正文可滚动），**不依赖外链**、离线可读。
- **版本控制**：`kCurrentChatEulaVersion = '2026-07-21'`。协议改版时 bump 该常量，`needsAgreement` 会因版本号不一致而对所有老用户重新弹窗（强制重新同意）。
- **持久化**：复用 GetIt 注入的 `SharedPreferences`（见 `common/locator.dart`），键 `chat_eula_agreed`(bool) + `chat_eula_version`(string)。**仅本地存储，不上报服务端**。

> ⚠️ **拦截范围**：当前仅覆盖「Feed 顶部消息图标 → `MessagePage`」这一个主入口。其它潜在私信入口（如 Profile 主页「发私信」、推送 / 深链直达某个会话）**尚未接入拦截**——后续若新增入口，需同步在这些路径上检查 `ChatEulaConsent.needsAgreement`，否则会绕过协议闸门。

## 3. 目录结构

```
client/lib/
├─ model/
│  └─ message.module.dart            # 数据模型（7 个类）
├─ services/
│  ├─ message_service.dart           # HTTP 服务层（28 个接口）
│  └─ ws_handlers/
│     ├─ message_handlers.dart       # message_read / message_reaction / group_message
│     └─ typing_handler.dart         # message_typing
├─ state/
│  └─ message.state.dart             # 全局状态 MessageState
└─ pages/message/
   ├─ message_page.dart              # 会话列表主页（Tab：全部 / 陌生人消息）+ EULA 拦截入口
   ├─ chat_eula_dialog.dart          # EULA 底部 sheet 弹窗 + 同意状态持久化（ChatEulaConsent / ChatEulaDialog / kCurrentChatEulaVersion）
   ├─ message_list_tile.dart         # 会话列表项组件
   ├─ chat_detail_page.dart          # 单聊 + 群聊消息页（复用，isGroupChat 区分）
   ├─ chat_bubble.dart               # 消息气泡组件（文本/图片/视频/语音/文件 + 反应 + 状态）
   ├─ reaction_picker.dart           # 表情反应选择器（长按消息触发）
   ├─ group_chat_detail_page.dart    # 群信息页（改群名 / 设置 / 成员预览 / 退群）
   ├─ group_members_page.dart        # 群成员列表页（搜索 / 移除成员）
   ├─ create_group_page.dart         # 建群页（选人 + 入群审批/邀请链接开关）
   ├─ join_group_page.dart           # 邀请链接加群页
   ├─ join_requests_page.dart        # 入群审批页（批准 / 拒绝）
   ├─ message_search_page.dart       # 消息内容搜索页
   ├─ message_settings_page.dart     # 消息请求设置页
   └─ hidden_conversations_page.dart # 隐藏会话列表页
```

## 4. 数据模型（`model/message.module.dart`）

| 类 | 关键字段 | 说明 |
| --- | --- | --- |
| `Conversation` | `id` / `peerUserId` / `peerUsername` / `peerDisplayName` / `peerAvatarUrl` / `conversationType`(1=收件箱, 2=陌生人) / `lastMessageContent` / `lastMessageTime` / `unreadCount` / `isReplied` / `isVerified` / `isHidden` / `isPinned` | 会话（列表项），immutable |
| `ChatMessage` | `id` / `senderId` / `receiverId` / `content` / `mediaType`(0 文本, 1 图片, 2 视频, 3 语音, 4 文件) / `mediaUrl` / `isRead` / `deliveryStatus`(1 发送中, 2 已送达, 3 发送失败) / `readTime` / `quoteMessageId` / `reactions` / `createTime` | 单条消息，immutable |
| `MessageReaction` | `emoji` / `userId` / `createTime` | 消息上的表情反应 |
| `GroupChat` | `id` / `name` / `avatarUrl` / `inviteLink` / `inviteLinkEnabled` / `needApprove` / `membersCount` / `lastMessageTime` / `createTime` | 群聊 |
| `GroupMember` | `userId` / `username` / `displayName` / `avatarUrl` / `role`(1 成员, 2 管理员) / `joinTime` | 群成员 |
| `MessageSettings` | `messageRequestEnabled` / `messageRequestAllowType` | 消息请求设置 |
| `SendMessageResponse` | `conversationId` / `messageId` | 发送消息后服务端回包 |

> 注意：`Conversation` / `ChatMessage` 是 immutable（`final` 字段），所有状态变更需整体重建对象（见 `MessageState` 中大量 `ChatMessage(...)` / `Conversation(...)` 重建逻辑）。

## 5. API 服务层（`services/message_service.dart`）

全部走 `ApiClient`，路径统一前缀 `message/`，按职责分组：

| 分组 | 接口 | 路径 |
| --- | --- | --- |
| 会话管理 | 会话列表 | `GET message/conversations`（支持 `conversation_type` / `filter_type`） |
| | 会话消息列表 | `GET message/conversations/{id}/messages` |
| | 隐藏会话 | `POST message/conversations/{id}/hide` |
| | 认证会话 | `POST message/conversations/{id}/verify` |
| | 置顶 / 取消置顶 | `POST` / `DELETE message/conversations/{id}/pin` |
| 消息收发 | 发送消息 | `POST message/messages` |
| | 标记已读 | `POST message/messages/read` |
| 消息反应 | 添加 / 移除 | `POST` / `DELETE message/messages/{id}/reaction` |
| 群聊管理 | 建群（带链接） | `POST message/group-chats/with-link` |
| | 群列表 / 群详情 | `GET message/group-chats` / `message/group-chats/{id}` |
| | 更新群信息 / 设置 | `PATCH message/group-chats/{id}` |
| | 群成员列表 | `GET message/group-chats/{id}/members` |
| | 移除成员 | `DELETE message/group-chats/{id}/members/{userId}` |
| | 链接加群 / 退群 | `POST .../join-by-link` / `.../{id}/leave` |
| | 入群申请列表 | `GET message/group-chats/{id}/join-requests` |
| | 审批 / 拒绝申请 | `POST .../join-requests/{reqId}/approve`（`action: 1|2`） |
| | 群消息列表 / 发送 | `GET` / `POST message/group-chats/{id}/messages` |
| 搜索/设置/推荐 | 搜索消息 | `GET message/search?q=` |
| | 消息设置 | `GET` / `POST message/settings` |
| | 推荐用户 | `GET message/recommend-users` |
| | 搜索聊天用户 | `GET message/search-users?q=` |
| | 隐藏会话列表 | `GET message/hidden` |

> 列表接口统一兼容两种返回：`data` 为 `List` 或 `data.items`（见各方法中 `data is List ? ... : data['items']` 的分支）。

## 6. 状态管理（`state/message.state.dart`，`MessageState`）

全局单例，在 `main.dart:288` 注册（`ChangeNotifierProvider<MessageState>`）。持有以下数据域与对应方法：

- **会话列表**：`conversations` / `loadConversations()` / `loadMoreConversations()`（分页阈值 < 20 停止）
- **当前聊天消息**：`currentMessages` / `currentConversationId` / `loadMessages(id)` / `loadMoreMessages()`；加载后自动 `markAsRead`（见 80-87 行）
- **发送消息（乐观更新）**：`sendMessage()` / `sendGroupChatMessage()` — 先插临时负 ID 消息（`deliveryStatus=1`），成功后用服务端 `messageId` 替换（`=2`），失败标 `=3`；新会话用返回的 `conversationId` 替换临时负 ID
- **消息反应**：`addReaction` / `removeReaction`
- **陌生人消息**：`strangerConversations` / `loadStrangerConversations()`（`conversationType=2`）
- **会话操作**：`verifyConversation` / `pinConversation` / `unpinConversation` / `hideConversation`
- **群聊**：`groupChats` / `currentGroupChat` / `groupMembers` / `createGroupChat` / `loadGroupDetail`(`loadGroupChatDetail` 别名) / `updateGroupChat` / `updateGroupChatSettings` / `loadGroupMembers` / `removeGroupMember` / `leaveGroupChat` / `joinGroupChat`
- **群消息**：`loadGroupChatMessages` / `loadMoreGroupChatMessages`
- **入群申请**：`joinRequests` / `loadJoinRequests` / `approveJoinRequest` / `rejectJoinRequest`
- **消息搜索**：`searchResults` / `searchMessages(keyword)`
- **消息设置**：`messageSettings` / `loadMessageSettings` / `updateMessageSettings`（失败回滚）
- **推荐 / 搜索用户**：`recommendUsers` / `loadRecommendUsers` / `searchChatUsers(keyword)`
- **隐藏会话**：`hiddenConversations` / `loadHiddenConversations()`

### WebSocket 事件入口（`MessageState` 内，由 ws_handlers 调用）

| 方法 | 对应事件 | 行为 |
| --- | --- | --- |
| `handleTypingEvent()` | `message_typing` | 维护 `typingByConversation`（`conversationId → 时间戳`），3 秒无新事件由 `_typingCleanupTimer` 自动清空 |
| `handleReadEvent()` | `message_read` | 把对应消息 `isRead=true`，会话未读数 -1（下限 0） |
| `handleReactionEvent()` | `message_reaction` | `action=='add'` 去重加入，否则移除（重建 ChatMessage） |
| `handleGroupMessageEvent()` | `group_message` | 当前打开的群会话 → insert 到列表头 |

## 7. WebSocket 实时链路

WS 事件类型常量定义于 `network/ws_config.dart:102-105`：

```dart
static const String evtMessageTyping   = 'message_typing';
static const String evtMessageRead     = 'message_read';
static const String evtMessageReaction = 'message_reaction';
static const String evtGroupMessage    = 'group_message';
```

**注册位置**：`main.dart:171-179` —— 登录后把 4 个 handler 注册到 `ws`：

```dart
ws.registerHandler(WsConfig.evtMessageTyping,   TypingHandler(msgState).call);
ws.registerHandler(WsConfig.evtMessageRead,     MessageReadHandler(msgState).call);
ws.registerHandler(WsConfig.evtMessageReaction, MessageReactionHandler(msgState).call);
ws.registerHandler(WsConfig.evtGroupMessage,    GroupMessageHandler(msgState).call);
```

**Handler 文件**：

- `services/ws_handlers/typing_handler.dart` — `TypingHandler`：取 `conversation_id` / `user_id`（多别名 + 大小写无关），转发 `handleTypingEvent(expireAfter: 3s)`。
- `services/ws_handlers/message_handlers.dart` — 三个类：
  - `MessageReadHandler`：`message_id` / `conversation_id` → `handleReadEvent`
  - `MessageReactionHandler`：`message_id` / `emoji` / `action` / `user_id` → `handleReactionEvent`
  - `GroupMessageHandler`：`group_id` + `message`（嵌套）或整个 payload（平铺）→ `handleGroupMessageEvent`

> ⚠️ 协议假设：handler 文件注释标注「服务端契约待对齐」，字段取值用了多别名兜底。新增/对接事件前请先探针验证服务端推送格式。相关规范见 `docs/ws-notification-scenario-guide.md`（[[ws-notification-scenarios-playbook]]）。

> 注意：**单聊新消息（1-on-1）目前没有 WS 事件入口**，`MessageState` 没有 `handleMessageEvent`。仅群消息有实时推送；单聊新消息依赖重新拉取会话列表 / 进会话加载。群未读数也暂未本地维护（`GroupChat` 无 `unread_count`，见 `handleGroupMessageEvent` 注释 TODO）。

## 8. 页面与组件详解

### `message_page.dart` — 会话列表主页（`MessagePage`）
- 双 Tab：**全部**（`conversations`）/ **消息请求**（陌生人 `strangerConversations`，切到该 Tab 时懒加载）。
- 顶栏 3 个按钮：搜索（→ `MessageSearchPage`）、新消息（→ `_NewMessageBottomSheet`）、设置（→ `MessageSettingsPage`）。
- 列表项 `MessageListTile`，点击进 `ChatDetailPage`，长按弹「置顶 / 认证 / 隐藏」菜单。
- `_NewMessageBottomSheet`：搜索用户 + 推荐用户；选中用户后用**临时负 ID** `-userId` 打开 `ChatDetailPage`，首条消息发送时由服务端创建会话。

### `chat_detail_page.dart` — 单聊 + 群聊消息页（`ChatDetailPage`）
- **单页复用**：`isGroupChat` + `groupId` 区分单聊 / 群聊，分别走 `MessageState` 的单聊 / 群方法。
- `getRoute()` 静态方法返回 `PageRouteBuilder`（淡入动画），统一构造入口。
- `conversationId < 0` 表示新会话（尚未创建），跳过消息加载。
- 消息列表 `reverse: true`（最新在底部），下拉刷新 / 上拉加载更多。
- 输入栏 `onSubmitted` → `_sendMessage()`；按 `_getPeerUserId()` 取对端 ID（优先 widget 参数，其次从现有消息推断）。
- 长按消息 → `ReactionPicker` → `addReaction`。
- 顶栏右上：群聊 → `GroupChatDetailPage`（信息图标）；单聊 → 会话操作菜单（认证 / 置顶 / 隐藏）。

### `chat_bubble.dart` — 消息气泡（`ChatBubble`）
- 按 `mediaType` 渲染：文本 / 图片（CachedNetworkImage）/ 视频 / 语音 / 文件图标。
- 自己的消息（`isMe`）显示送达状态图标（`deliveryStatus` 1=转圈, 2=单勾, 3=双勾）。
- 引用消息（`quoteMessageId != null`）显示「引用的消息」标签。
- 反应：按 emoji 聚合计数显示在气泡下方。

### `reaction_picker.dart` — 表情选择器（`ReactionPicker`）
- 固定 6 个表情（❤️ 👍 😂 😮 😢 🔥），底部弹窗，选中回调后关闭。

### `message_list_tile.dart` — 会话列表项（`MessageListTile`）
- 头像 + 昵称 + 最后消息 + 相对时间（刚刚 / N 分钟前 / N 小时前 / N 天前 / 月/日）+ 未读红点（`>99` 显示 `99+`）。

### `group_chat_detail_page.dart` — 群信息页（`GroupChatDetailPage`）
- 群头像 / 群名（点击改）/ 成员数 + 创建日期。
- 两个开关：入群审批（`needApprove`）/ 邀请链接（`inviteLinkEnabled`）→ `updateGroupChatSettings`。
- 成员预览（前 6 个头像）→ `GroupMembersPage`；开启邀请链接时显示「复制邀请链接」；开启审批时显示「入群申请」入口。
- 操作按钮：「发消息」→ `ChatDetailPage`（群模式）。
- 「退出群聊」确认弹窗 → `leaveGroupChat`。

### `group_members_page.dart` — 群成员列表（`GroupMembersPage`）
- 搜索过滤；当前用户若是管理员（`role==2`）可移除其他成员（确认弹窗 → `removeGroupMember`）。

### `create_group_page.dart` — 建群（`CreateGroupPage`）
- 群名 + 头像占位（TODO）+ 两个开关 + 选人（推荐用户 / 搜索用户，Checkbox 多选，选中以 Chip 展示）→ `createGroupChat`。

### `join_group_page.dart` — 链接加群（`JoinGroupPage`）
- 输入邀请链接 → `joinGroupChat`，成功后 Toast + 返回。

### `join_requests_page.dart` — 入群审批（`JoinRequestsPage`）
- 待审批列表，每项「批准 / 拒绝」→ `approveJoinRequest` / `rejectJoinRequest`。

### `message_search_page.dart` — 消息搜索（`MessageSearchPage`）
- 输入框 500ms 防抖 → `searchMessages`；点击结果用 `receiverId` 当 conversationId 进 `ChatDetailPage`。

### `message_settings_page.dart` — 消息请求设置（`MessageSettingsPage`）
- 开关「允许消息请求」+ 单选「谁可以发消息请求」（1=仅关注的人, 2=任何人）→ `updateMessageSettings`。

### `hidden_conversations_page.dart` — 隐藏会话（`HiddenConversationsPage`）
- 展示 `hiddenConversations`（只读列表，无操作按钮）。

## 9. 关键交互数据流

**发送一条消息**（乐观更新）：
```
ChatDetailPage._sendMessage
  → MessageState.sendMessage (插入临时负ID消息 deliveryStatus=1)
  → MessageService.sendMessage (POST message/messages)
  → 成功：用返回 messageId/conversationId 替换临时消息 (deliveryStatus=2)
  → 失败：标记 deliveryStatus=3
  → ChatBubble 据 deliveryStatus 渲染状态图标
```

**收到群新消息**（实时）：
```
WS group_message 事件
  → GroupMessageHandler.call (message_handlers.dart)
  → MessageState.handleGroupMessageEvent
  → 若 _currentConversationId == groupId：insert 到 currentMessages 头
  → ChatDetailPage (群模式) Consumer 自动刷新
```

## 10. 待办 / 已知缺口

- 单聊新消息无 WS 实时入口（仅群消息有 `group_message`）。
- 群聊未读数未本地维护（`GroupChat` 缺 `unread_count`，`handleGroupMessageEvent` 注释 TODO）。
- `addReaction` 的乐观更新注释标「简化处理」，实际未重建 ChatMessage。
- 建群头像选择为 TODO（`create_group_page.dart`）。
- WS 事件字段多为「服务端契约待对齐」，需探针验证。
