# WebSocket 事件类型总览（event_type）

本文档列出服务端通过 WebSocket 推送的全部 `event_type`，按业务域分类，共 **28** 个事件。供客户端参考事件语义、载荷字段与对应的前端处理方式。

## 通用消息结构

所有事件共用如下 JSON 载体，`event_type` 为必含字段，其余字段视事件类型而定：

```json
{
    "event_type": "post_like",   // 事件类型（必含）
    "actor_id": 123,             // 触发者 ID（通知类事件携带）
    "actor_name": "张三",        // 触发者名称（通知类事件携带）
    "post_id": 456,              // 上下文对象 ID（视事件：post_id / reply_id / user_id / ...）
    ...                          // 其余扩展字段
}
```

### 字段约定

| 字段 | 说明 | 是否必含 |
| --- | --- | --- |
| `event_type` | 事件类型，用于分发到对应处理逻辑 | 必含 |
| `actor_id` / `actor_name` | 触发者 ID 与名称。系统 / 生命周期类事件不携带（下表标注 `actor_id(无)`） | 通知类必含 |
| `post_id` / `reply_id` / `user_id` / `community_id` / `report_id` / `message_id` 等 | 上下文对象 ID，由具体事件决定 | 视事件 |

> 标注「`actor_id(无)`」的事件由系统或定时任务触发，无具体触发者，前端展示时不应拼接「@xxx」。

---

## 一、互动通知

进入通知中心、展示带「@xxx」文案的人际互动通知。上下文对象为 `post_id` 或 `reply_id`。

| event_type | 语义 | 前端展示文案 | 包含字段 |
| --- | --- | --- | --- |
| `post_like` | 帖子被赞 | @xxx 赞了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `reply_like` | 回复被赞 | @xxx 赞了你的回复 | `actor_id`, `actor_name`, `reply_id` |
| `post_mention` | 帖子中被 @ | @xxx 在帖子中提到了你 | `actor_id`, `actor_name`, `post_id` |
| `reply_mention` | 回复中被 @ | @xxx 在回复中提到了你 | `actor_id`, `actor_name`, `reply_id` |
| `post_reply` | 帖子被回复 | @xxx 回复了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `post_repost` | 帖子被转发 | @xxx 转发了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `post_quote` | 帖子被引用 | @xxx 引用了你的帖子 | `actor_id`, `actor_name`, `post_id` |

## 二、关注关系通知

关注 / 被关注相关通知。上下文对象为 `user_id`。

| event_type | 语义 | 前端展示文案 | 包含字段 |
| --- | --- | --- | --- |
| `follow_request` | 关注请求 | @xxx 想要关注你 | `actor_id`, `actor_name`, `user_id` |
| `follow_accept` | 关注请求被接受 | @xxx 接受了你的关注请求 | `actor_id`, `actor_name`, `user_id` |
| `new_follower` | 新粉丝 | @xxx 开始关注你 | `actor_id`, `actor_name`, `user_id` |
| `follow_request_declined` | 关注请求被拒绝 | @xxx 拒绝了你的关注请求 | `actor_id`, `actor_name`, `user_id` |

## 三、通用通知计数

不携带具体互动信息，仅用于驱动未读角标。

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `notification_new` | 通用新通知 | 未读通知数 +1 | `notification_id` |

## 四、内容实时更新

Feed 流与帖子详情的实时数据同步事件，用于增量更新列表内容。

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `post_create` | 关注者发新帖 | Feed 流顶部插入新帖 | `post_id`, `user_id` |
| `reply_create` | 帖子收到新回复 | 帖子详情页实时追加回复 | `post_id`, `reply_id`, `user_id` |
| `post_edit` | 帖子被编辑 | Feed 流更新该帖内容 | `actor_id`, `actor_name`, `post_id` |
| `reply_approved` | 回复审核通过 | 自动显示该回复 | `actor_id(无)`, `reply_id` |
| `reply_rejected` | 回复被拒绝 | 显示拒绝提示 | `actor_id(无)`, `reply_id` |

## 五、社群动态

社群（Community）相关事件。

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `community_new_post` | 社群有新帖 | 社群页面推送 + 红点 | `actor_id`, `actor_name`, `post_id`, `community_id` |
| `community_join` | 新成员加入社群 | 社群动态更新 | `actor_id`, `actor_name`, `community_id` |
| `community_champion` | Champion 变更 | 社群荣誉榜更新 | `actor_id`, `actor_name`, `community_id` |

## 六、私信 / 会话

即时消息相关事件。

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `group_message` | 群聊新消息 | 消息列表中新增 | `target_id`, `content` |
| `message_typing` | 对方正在输入 | 显示「正在输入...」 | `conversation_id` |
| `message_read` | 消息已读 | 更新已读回执 | `message_ids` |
| `message_reaction` | 消息表情反应 | 显示 emoji 反应 | `message_id` |

## 七、系统与生命周期

投票结束、内容过期、举报处理、系统公告等非互动类事件，多由系统触发（无 `actor_id`）。

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `poll_close` | 投票结束 | 帖子中投票结果锁定 | `actor_id`, `actor_name`, `post_id` |
| `ghost_post_expired` | 幽灵帖过期 | 私密存档提示 | `actor_id(无)`, `post_id` |
| `report_status_updated` | 举报处理完成 | 用户收到处理结果 | `actor_id(无)`, `report_id` |
| `system_announcement` | 系统公告 | App 内公告弹窗 / Banner | `actor_id(无)`, `content` |
