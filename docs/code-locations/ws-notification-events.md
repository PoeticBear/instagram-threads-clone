# WebSocket 通知事件(12 个)— 代码定位

> 本文档汇总 12 个 WS 通知类事件(`post_like` / `reply_like` / `post_mention` / `reply_mention` / `post_reply` / `post_repost` / `post_quote` / `follow_request` / `follow_accept` / `new_follower` / `follow_request_declined` / `notification_new`)在 iOS 客户端的完整处理路径,含协议常量、映射表、handler、State 入口、UI 渲染点。
>
> 后续若收到「某通知事件不触发 / 文案不对 / 红点不准 / 点击跳转错」类需求,先查阅本文档定位代码;未覆盖到的细节再执行 `Glob` / `Grep` 检索。
>
> 最后更新:2026-06-23

---

## 1. 协议契约源

- **路径**:`docs/event-types-doc.md`
- **第一张表**:12 个通知类事件,字段统一为 `{actor_id, actor_name, <context_id>}`(`notification_new` 例外,只有 `notification_id`)
- **字段语义**:`actor_id` + `actor_name` 是触发方;context 字段(`post_id` / `reply_id` / `user_id`)指向被作用对象

---

## 2. 协议常量(event_type 字符串)

- **路径**:`client/lib/network/ws_config.dart:107-119`
- **职责**:全部 12 个 event_type 的字符串常量(`evtPostLike` / `evtReplyLike` / ... / `evtFollowRequestDeclined`)
- **注册 key 来源**:`main.dart` 的 `_wireupHandlers` 用这些常量注册,避免散落字符串
- **大小写归一化**:`WebSocketService._onData` 收到帧后强制 `toLowerCase()`,服务端 snake_case 与 SCREAMING_SNAKE 都能路由

---

## 3. event_type → NotificationItem.type 映射表

- **路径**:`client/lib/network/ws_notification_mapping.dart`
- **核心类**:
  - `class WsNotificationSpec` —— 不可变 spec(`typeCode` / `contextField` / `needsLocalInsert`)
  - `class WsNotificationMapping` —— 静态查表入口(`specFor(eventType)`)
- **完整映射**(权威):

| event_type | typeCode | contextField | needsLocalInsert |
| --- | --- | --- | --- |
| `post_like` | `like` | `post_id` | ✓ |
| `reply_like` | `like` | `reply_id` | ✓ |
| `post_reply` | `reply` | `post_id` | ✓ |
| `follow_request` | `follow` | `user_id` | ✓ |
| `follow_accept` | `follow` | `user_id` | ✓ |
| `new_follower` | `follow` | `user_id` | ✓ |
| `follow_request_declined` | `follow` | `user_id` | ✓ |
| `post_mention` | `mention` | `post_id` | ✓ |
| `reply_mention` | `mention` | `reply_id` | ✓ |
| `post_repost` | `repost` | `post_id` | ✓ |
| `post_quote` | `quote` | `post_id` | ✓ |
| `notification_new` | (空) | (空) | ✗(仅 ping) |

---

## 4. Handler 注册与实现

### 4.1 注册入口

- **路径**:`client/lib/main.dart:144-172`(`_MyAppState._wireupHandlers`)
- **结构**:
  - 消息类 4 个 handler(具名 class)
  - 通知类 12 个 handler:
    - `NotificationNewHandler` + `PostLikeHandler`(具名,先期注册保留)
    - 10 个共用 `GenericNotificationHandler`(同一实例的 `.call` 引用注册到 10 个 event_type)
- **触发**:`_wireupWebSocket` 在 `WidgetsBinding.instance.addPostFrameCallback` 里调,保证 `navigatorKey.currentContext` 可用

### 4.2 Handler 实现

- **路径**:`client/lib/services/ws_handlers/notification_handlers.dart`
- **3 个 class**:
  - `NotificationNewHandler` —— 文档明确字段只有 `notification_id`,具名以示区别
  - `PostLikeHandler` —— 先期接入,具名保留
  - `GenericNotificationHandler` —— 通用 handler,供其余 10 个事件共用
- **3 个 class 的 `call` 实现完全一致**:
  ```dart
  void call(WsEvent event) {
    _state.handleWsEvent(event.type, event.payload);
  }
  ```
- 后续如需细化(如 post_reply 触发 PostState 联动),从此文件分叉具名 handler

---

## 5. State 入口

### 5.1 统一入口

- **路径**:`client/lib/state/notification.state.dart:209-225`(`NotificationState.handleWsEvent`)
- **签名**:`void handleWsEvent(String eventType, Map<String, dynamic> json)`
- **流程**:
  1. `WsNotificationMapping.specFor(eventType)` 查表;`spec == null` 或 `needsLocalInsert == false` → 跳过本地插入
  2. `needsLocalInsert == true` → `NotificationItem.fromWsEvent(eventType, json, spec)` 本地构造,按 `id` 去重插入列表头
  3. `incrementUnread()`(本地未读 +1,触发红点)
  4. `_scheduleDebouncedRefresh()`(500ms 防抖触发 HTTP `loadNotifications(refresh: true)`)

### 5.2 防抖对账

- **路径**:`client/lib/state/notification.state.dart:191-198`(`_scheduleDebouncedRefresh`)
- **Timer**:`Timer? _refreshDebounce`(field at line 183)
- **策略**:500ms 内多次 WS 事件合并成一次 HTTP 拉取,服务端权威数据整体替换本地列表
- **dispose**:`client/lib/state/notification.state.dart:227-231` 取消 Timer

### 5.3 本地构造(NotificationItem.fromWsEvent)

- **路径**:`client/lib/services/notification_service.dart:144-164`
- **签名**:`NotificationItem.fromWsEvent(String eventType, Map json, WsNotificationSpec spec)`
- **字段策略**:
  - `id` = `ws_${eventType}_${actorId}_${contextId}`(合成 id,`ws_` 前缀便于排查)
  - `type` = `spec.typeCode`(供 UI switch 渲染 i18n 文案)
  - `body` = `''`(空,服务端未下发,UI 主文案靠 type 渲染)
  - `postId` = 仅 `contextField == 'post_id'` 时填充;`reply_id` / `user_id` 场景目前不存(留 TODO)
  - `fromUserId` / `fromDisplayName` = 取自 `actor_id` / `actor_name`
  - `wsEventType` = 原样保留 event_type,供 UI 未来按细粒度渲染

---

## 6. UI 渲染

### 6.1 通知列表 item

- **路径**:`client/lib/pages/notification/notification.dart`
- **widget**:`_NotificationTile`(lines 277-450)
- **核心方法**:`_typeText(BuildContext)` at lines 305-323
- **渲染策略**:switch on `notification.type`(`'like'` / `'reply'` / `'follow'` / `'mention'` / `'repost'` / `'quote'`)→ 对应 i18n key
- **`body` 字段**:仅作为辅助副文本显示(lines 394-407);`type == 'follow'` 时完全不渲染 body

### 6.2 i18n key(已存在,无新增)

- **路径**:
  - `client/lib/l10n/app_en.arb:345-350`
  - `client/lib/l10n/app_zh.arb:345-350`
- **6 个 key**:
  - `notifiedLikedPost` / `notifiedRepliedToYou` / `notifiedFollowedYou` / `notifiedMentionedYou` / `notifiedRepostedPost` / `notifiedQuotedPost`
- **限制**:无 reply 变体(`reply_like` / `reply_mention` 共用 post 版本文案);未来按 `wsEventType` 渲染可分叉

### 6.3 红点

- **路径**:`client/lib/pages/home.dart:133-156`
- **渲染**:`unreadCount > 0` 时显示 8×8 红点(布尔指示,不显示数字)
- **触发**:`Consumer<NotificationState>` 监听,`incrementUnread()` / `loadNotifications()` 都会 `notifyListeners()`

---

## 7. 已知限制与待办

| # | 限制 | 影响 | 解决方向 |
| --- | --- | --- | --- |
| 1 | follow 类事件 `user_id` 字段语义未确认 | 点击通知跳转可能到错的 profile | 等服务端确认后决定 `fromUserId` 取 actor 还是 target |
| 2 | reply 类事件跳转缺 post_id | `reply_like` / `reply_mention` 点击跳转链路不完整 | (a) 加 `replyId` 字段 + UI 查 reply→post;或 (b) 服务端补 post_id |
| 3 | `reply_like` / `reply_mention` 共用 post 文案 | 文案轻微不准(显示"赞了你的帖子"实际是回复) | 加 i18n reply 变体 + UI 按 `wsEventType` 渲染 |
| 4 | follow 4 种场景共用一个文案 | 无法区分"请求 / 接受 / 新粉丝 / 拒绝" | 加 4 个 i18n key + UI 按 `wsEventType` 渲染 |
| 5 | HTTP 对账时本地条目"消失" | 用户正在看列表时有刷新闪烁 | 改为"保留本地 ws_ 前缀条目 + 合并 HTTP 条目" |
| 6 | `notification_new` 与细粒度事件并发推送时红点重复 +1 | 数据不准(红点布尔化不可见) | 红点不可见容忍;`getUnreadCount` HTTP 接口每次对账纠正 |
| 7 | follow 事件未联动 `FollowRequestState` | 关注请求页面与通知中心可能不一致 | 后续在 `handleWsEvent` 内按 event_type 分叉联动 |

---

## 8. 验收清单(手动测试)

| # | 场景 | 期望 |
| --- | --- | --- |
| 1 | 别人点赞我的帖子 | 红点 + 列表头部插入条目,文案"赞了你的帖子" |
| 2 | 别人点赞我的回复 | 同上(type=like,文案暂同帖子版) |
| 3 | 别人在帖子里 @ 我 | type=mention,文案"提及了你" |
| 4 | 别人在回复里 @ 我 | 同上 |
| 5 | 别人回复我的帖子 | type=reply,文案"回复了你" |
| 6 | 别人转发我的帖子 | type=repost,文案"转发了你的帖子" |
| 7 | 别人引用我的帖子 | type=quote,文案"引用了你的帖子" |
| 8 | 别人发起关注请求 | type=follow,文案"关注了你" |
| 9 | 别人接受我的关注请求 | 同上 |
| 10 | 新粉丝(请求被自动接受) | 同上 |
| 11 | 关注请求被拒绝 | 同上 |
| 12 | 后端推 notification_new | 红点 +1,500ms 后列表整体刷新 |

---

## 9. 服务端待确认问题

| # | 问题 | 影响步骤 |
| --- | --- | --- |
| 1 | `post_like` 与 `notification_new` 是否并发推送? | 红点重复计数(虽然不可见) |
| 2 | follow 类 `user_id` 是 actor 还是 target? | 跳转目标 profile |
| 3 | 是否有"按 reply_id 查所属 post"的接口? | reply 类事件点击跳转 |
| 4 | `follow_request` 与 `new_follower` 是否串行触发? | 是否需要去重 |
| 5 | 是否需要联动 `FollowRequestState`(关注请求页)? | UI 一致性 |
