# WebSocket 通知场景实现规范

> **用途**：指导在新对话中继续实现 `post_mention` 之外的其余通知场景（点赞 / 回复 / 关注 / 转发 / 引用 等）。
>
> **参考实现**：`post_mention`（截至 2026-06-24 已跑通完整链路：14dev 发帖 @12dev → 12dev 心形 Tab 实时红点）。
>
> **最后更新**：2026-06-24

---

## 0. 先读这段：核心结论

**接收侧（红点 / 通知列表）是一条通用链路，12 个通知事件全部共享，且已全部接好。** 新增一个场景**几乎不需要改接收链路的代码**。

每个新场景真正的工作量集中在三处：

1. **确认服务端真的会推这个 `event_type`**（最高风险，`post_mention` 当初就卡在这里——服务端建了通知却不推 WS）。
2. **发送侧触发**：哪个用户动作产生这个事件（点哪个按钮、调哪个 service 方法、请求体带什么字段）。
3. **展示与跳转**：通知文案（i18n）、点击通知跳到哪里。

**所以实现任何新场景，第一步永远是：用排障探针验证服务端推不推（见 §6）。** 不要一上来改客户端代码。

---

## 1. 适用的事件清单（12 个）

| event_type | typeCode | contextField | 发送侧触发动作 | 状态 |
| --- | --- | --- | --- | --- |
| `post_mention` | mention | post_id | 发帖时 @ 用户（`mentioned_user_ids`） | ✅ 已跑通（参考实现） |
| `reply_mention` | mention | reply_id | 回复时 @ 用户 | 接收链路已接，发送/跳转待补 |
| `post_like` | like | post_id | 点赞帖子（`likePost`） | 接收链路已接 |
| `reply_like` | like | reply_id | 点赞回复（`likeReply`） | 接收链路已接 |
| `post_reply` | reply | post_id | 发表回复（`createReply`） | 接收链路已接 |
| `post_repost` | repost | post_id | 转发（`repost`） | 接收链路已接 |
| `post_quote` | quote | post_id | 引用发帖 | 接收链路已接 |
| `follow_request` | follow | user_id | 发起关注请求 | 接收链路已接 |
| `follow_accept` | follow | user_id | 接受关注请求 | 接收链路已接 |
| `new_follower` | follow | user_id | 新粉丝（自动接受） | 接收链路已接 |
| `follow_request_declined` | follow | user_id | 拒绝关注请求 | 接收链路已接 |
| `notification_new` | (空) | (空) | 通用 ping（无 actor） | 接收链路已接 |

> 协议契约源：`docs/event-types-doc.md`（第一张表）。字段统一为 `{actor_id, actor_name, <context_id>}`，`notification_new` 例外（只有 `notification_id`）。

---

## 2. 通用接收链路（12 事件共享，已全部接好）

```
① WS 收到事件帧
   WebSocketService._onData                                 websocket_service.dart:273-325
   ├─ JSON 解析 + event_type 强制 toLowerCase() 归一化（服务端 snake_case / SCREAMING 都能吃）
   ├─ WsLogger.logEvent(event) 落日志（带分割线 + 完整 raw JSON）
   ├─ 广播到 events stream
   └─ 查路由表 _handlers[normalized] → 同步调 handler

② handler 注册 + 调用
   _wireupHandlers                                           main.dart:148-176
   ├─ 12 个事件全部已注册（GenericNotificationHandler 共用 10 个 + 具名 2 个）
   └─ handler.call(event) → notifState.handleWsEvent(event.type, event.payload)
       实现见 notification_handlers.dart:52-59（GenericNotificationHandler）

③ State 统一入口
   NotificationState.handleWsEvent                           notification.state.dart:209-225
   ├─ WsNotificationMapping.specFor(eventType) 查 spec
   ├─ needsLocalInsert=true → NotificationItem.fromWsEvent 本地构造 + 去重插入列表头
   ├─ incrementUnread()       → _unreadCount++ + notifyListeners()      notification.state.dart:186-189
   └─ _scheduleDebouncedRefresh()  500ms 后 HTTP loadNotifications(refresh:true) 对账

④ 红点 UI
   home.dart 心形 Tab                                        home.dart:133-156
   └─ Consumer<NotificationState>  →  unreadCount > 0 渲染 8×8 红点
```

**关键不变量**：`incrementUnread()` 在 `handleWsEvent` 里**无条件执行**（在 try/catch 之外）。所以——**只要 ① 有事件帧到达，红点一定会亮**，哪怕本地构造 `NotificationItem` 因字段不匹配抛错。这条不变量是排障时的核心判据：红点亮不亮 = 服务端推没推。

---

## 3. 映射表（新增 event_type 时改这里）

`client/lib/network/ws_notification_mapping.dart`：

```dart
static const Map<String, WsNotificationSpec> _table = {
  'post_like':     WsNotificationSpec(typeCode: 'like',    contextField: 'post_id'),
  'post_mention':  WsNotificationSpec(typeCode: 'mention', contextField: 'post_id'),
  // ...
  'notification_new': WsNotificationSpec(typeCode: '', contextField: '', needsLocalInsert: false),
};
```

- `typeCode`：对应 `NotificationItem.type`，UI `_typeText` switch 据此渲染 i18n 文案（`like`/`reply`/`follow`/`mention`/`repost`/`quote`）。
- `contextField`：WS payload 里上下文 id 的字段名（`post_id`/`reply_id`/`user_id`），`NotificationItem.fromWsEvent` 据此取值。
- `needsLocalInsert`：是否本地乐观插入列表头。`notification_new` 设 false（无 actor，仅触发 HTTP 对账）。

**12 个事件当前已全部在表里。** 真正"新增事件"（服务端新增了一种 event_type）才需要改这里 + §4。

---

## 4. handler 注册（新增 event_type 时改这里）

`client/lib/main.dart` 的 `_wireupHandlers`（148-176 行）：

```dart
final genericNotifHandler = GenericNotificationHandler(notifState).call;
ws.registerHandler(WsConfig.evtPostMention, genericNotifHandler);
// ... 其余 11 个同理
```

- event_type 字符串常量集中在 `ws_config.dart:102-119`（`evtPostLike` / `evtPostMention` / ...）。
- **绝大多数通知事件直接复用 `GenericNotificationHandler`**（因为载荷结构一致，差异全在映射表里）。只有当某事件需要**特殊联动**（如 `post_reply` 要联动 PostState 刷新、`follow_*` 要联动 FollowRequestState）时，才分叉一个具名 handler。

---

## 5. 实现新场景的标准流程（Checklist）

对每个新场景，按顺序做：

### Step 1 — 验证服务端推不推（必做，最高风险）
用 §6 的探针脚本，复刻"发送方触发动作 → 接收方观察"。判定矩阵见 §6.3。
- 如果服务端**不推**：停下，把证据转给后端，等修。**不要改客户端**（客户端接收链路没问题）。
- 如果服务端**推了**：进 Step 2。

### Step 2 — 确认发送侧触发已正确发出
找到产生该事件的用户动作 → service 方法 → 请求体字段。对照 `post_service.dart` / `follow_service.dart` 等。
- 参照 `post_mention`：发帖时 `mentioned_user_ids` 字段（`post_service.dart:80-82`）。
- 用 `[MENTION-DEBUG]` 同款方式（`post_service.dart:84-111`）临时打印请求体 + 响应，确认字段发出且服务端回带确认。

### Step 3 — 确认映射表 + handler 注册（一般已就绪）
对照 §1 表格，确认目标 event_type 在 `WsNotificationMapping`（§3）和 `_wireupHandlers`（§4）里。**12 个已知事件均已就绪，跳过。**

### Step 4 — 展示文案（i18n）
通知列表 item 渲染：`client/lib/pages/notification/notification.dart` 的 `_NotificationTile._typeText`（按 `notification.type` switch 到 i18n key）。
- i18n key：`client/lib/l10n/app_en.arb` 与 `app_zh.arb`（`notifiedLikedPost` / `notifiedMentionedYou` / ...）。
- 若是新 typeCode，两个 `.arb` 都要加 key。**禁止硬编码中文/英文**（项目规范）。

### Step 5 — 点击跳转
通知 item 点击后跳哪：`notification.dart` 的 item onTap。
- `post_id` 类事件 → 帖子详情页。
- `reply_id` 类事件 → 需"reply → post"反查（当前缺口，见 §8）。
- `user_id` 类事件 → 用户 profile（注意 `user_id` 是 actor 还是 target，待服务端确认）。

---

## 6. 排障方法论（本次会话核心产出）

### 6.1 链路四跳，逐跳隔离

```
发送侧                  服务端                          接收侧
──────                 ──────                          ──────
触发动作 ──▶ [④a] 接受事件 ──▶ [④b] 建通知+未读+1 ──▶ [⑤] 推 WS 帧 ──▶ [⑥] 客户端收帧 → 红点
```

任何一个场景不工作，断点必在这 4 跳之一。**用独立探针逐跳验证，不要靠猜。**

### 6.2 探针脚本模板（脱离 Flutter 客户端）

> ⚠️ 探针脚本放 `wstest/`，**不要提交 git**（含硬编码密码/token）。当前 `wstest/` 已在 `.gitignore` 之外但未跟踪——保持本地。

复刻任意场景，三段式（Python，依赖 `websockets` 库）：

```python
# 1. 登录发送方 + 接收方，拿 token + userId
#    POST auth/username/signin {username, password}  → data.access_token / data.id

# 2. 发送方触发动作（例：createPost 带 mentioned_user_ids）
#    打印完整请求体 + 服务端响应（看是否回带确认字段）

# 3a. [验 ④b] 接收方 HTTP 查未读数 + 通知列表
#    GET notification/notifications/unread-count   → data（增量 = 服务端建了通知？）
#    GET notification/notifications?page=1&size=10 → data.items（有没有 type 对应的条目）

# 3b. [验 ⑤] 接收方连 WS，观察 N 秒收到的帧
#    ws://192.168.1.27:8005/websocket/ws?access_token=Bearer <jwt>
#    连上后发送方触发动作，打印所有收到的帧（不只看目标 event_type，全打）
```

完整参考实现：`wstest/mention_e2e.py`（端到端，覆盖 3a+3b）、`wstest/send_as_12dev.py`（仅发送侧，配合真实 app 观察接收）。

### 6.3 判定矩阵

| ④b 未读增量 | 通知列表有条目 | ⑤ WS 收到帧 | 结论 |
| --- | --- | --- | --- |
| 0 | 无 | 无 | 服务端没建通知 → 断在 ④a/④b（发送侧字段没发对，或服务端没识别） |
| >0 | 有 | 无 | **服务端建了通知但不推 WS → 断在 ⑤**（`post_mention` 当初就是这个） |
| >0 | 有 | 有 | 服务端全通 → 若 app 仍不亮红点，断在 ⑥ 客户端接收（查 app WS 连接/handler） |

### 6.4 真实 app 端到端验证（最硬证据）

接收方用**真实 Flutter app**（不是 Python WS 客户端）：

1. 接收方 app 登录、保持前台（**后台会断 WS**，见 §8）。
2. 发送方用 `send_as_<sender>.py` 脚本触发动作（脚本只登录发送方，不碰接收方会话）。
3. 看 `flutter run` 终端：
   - `[WS] state → connected` = 连接已建立（握手+鉴权通过）。
   - `[WS] app-layer ping sent` / `pong received — heartbeat ok` = 心跳健康。
   - `━━━ WS EVENT (post_mention) ━━━` + `event type=post_mention raw={...}` = **收到事件帧**（分割线让它在噪音里一眼可见）。
   - 心形 Tab 红点是否亮。

> 解码 JWT 确认连接身份：`echo '<payload段>' | base64 -d` → 看 `id`/`username`。

---

## 7. 发送侧触发动作速查

| 场景 | service 方法 | 文件:行 | 关键请求字段 |
| --- | --- | --- | --- |
| post_mention | `createPost` | post_service.dart:26 | `mentioned_user_ids: [userId]` |
| reply_mention | `createReply` | post_service.dart:405 | （mention 字段待确认服务端契约） |
| post_like | `likePost` | post_service.dart:316 | （path 参数 post_id） |
| reply_like | `likeReply` | post_service.dart:500 | （path 参数 reply_id） |
| post_reply | `createReply` | post_service.dart:405 | `post_id`, `content` |
| post_repost | `repost` | post_service.dart:332 | `repost_type` |
| post_quote | （引用发帖） | post_service.dart createPost | `quote_post_id` |
| follow_* | `follow_service` | services/follow_service.dart | （关注/接受/拒绝接口） |

> 实现前先用 §6 探针确认每个动作**服务端是否真的下推对应 event_type**。

---

## 8. 已知限制与待办（跨场景）

| # | 限制 | 影响 | 解决方向 |
| --- | --- | --- | --- |
| 1 | App 进后台时 WS 主动断开（`main.dart` didChangeAppLifecycleState） | 后台期间的事件帧丢失；且 resume 只重连 WS、**不补拉 `fetchUnreadCount`** | resume 时补 `fetchUnreadCount()` + `loadNotifications()` |
| 2 | `reply_id` / `user_id` 类事件点击跳转缺 post_id | `reply_like`/`reply_mention` 点击跳转链路不完整 | 加 replyId 字段 + UI 反查 reply→post；或服务端补 post_id |
| 3 | follow 类 `user_id` 是 actor 还是 target 待确认 | 点击可能跳错 profile | 等服务端确认 |
| 4 | `notification_new` 与细粒度事件并发 → 红点重复 +1 | 未读数偏大（布尔红点不可见） | 容忍；`fetchUnreadCount` HTTP 对账纠正 |
| 5 | `reply_like`/`reply_mention` 共用 post 版本文案 | 文案轻微不准 | 加 reply 变体 i18n + UI 按 `wsEventType` 渲染 |
| 6 | follow 4 种场景共用一个文案 | 无法区分请求/接受/新粉丝/拒绝 | 加 4 个 i18n key + 按 `wsEventType` 渲染 |
| 7 | follow 事件未联动 `FollowRequestState` | 关注请求页与通知中心可能不一致 | `handleWsEvent` 内按 event_type 分叉联动 |

---

## 9. 关键代码位置索引

| 职责 | 文件 | 关键行 |
| --- | --- | --- |
| WS 连接管理 + 帧路由 | `services/websocket_service.dart` | `_onData` 273-325 |
| WS 协议常量（event_type / URL / 鉴权） | `network/ws_config.dart` | 102-119（事件名）、42-64（URL+鉴权） |
| WS 日志（分割线 + 心跳） | `network/ws_logger.dart` | `logEvent`、`log` |
| event_type → typeCode 映射 | `network/ws_notification_mapping.dart` | `_table` 33-65 |
| handler 注册 | `main.dart` | `_wireupHandlers` 148-176 |
| 通知 handler 实现 | `services/ws_handlers/notification_handlers.dart` | GenericNotificationHandler 52-59 |
| 通知 State（统一入口 + 未读） | `state/notification.state.dart` | `handleWsEvent` 209-225、`incrementUnread` 186-189 |
| NotificationItem 构造（WS / HTTP 两路） | `services/notification_service.dart` | `fromWsEvent` 144-164、`fromJson` 105-123 |
| 红点 UI | `pages/home.dart` | 133-156（心形 Tab Consumer） |
| 通知列表 item + 文案 + 跳转 | `pages/notification/notification.dart` | `_NotificationTile` |
| i18n 文案 | `l10n/app_en.arb` / `app_zh.arb` | `notified*` 系列 |
| 已有代码定位清单（更详细） | `docs/code-locations/ws-notification-events.md` | — |

---

## 10. 新对话快速上手清单

在新对话里实现某个场景时，把这 4 件事告诉 Claude：

1. **目标场景**：例如"实现 `post_like`（别人点赞我的帖子 → 我实时收到红点）"。
2. **让 Claude 先读本规范**：`docs/ws-notification-scenario-guide.md`（即本文件）+ `docs/code-locations/ws-notification-events.md`。
3. **第一步永远是 §6 排障探针**：先验证服务端推不推该 event_type，再决定动不动客户端。
4. **测试账号**：14dev(id=1000382) / 12dev(id=1000383)，密码 `123456`，dev 服务器 `192.168.1.27:8005`。

> 配套排障脚本（本地 `wstest/`，未提交）：`mention_e2e.py`（端到端探针模板）、`send_as_12dev.py`（发送侧触发，配合真实 app 观察接收）。新场景照着改 event_type / 触发动作即可。
