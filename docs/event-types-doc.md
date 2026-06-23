这是一份从图片中提取出来的 Markdown 格式表格：

| event_type | 语义 | 前端展示 | 包含字段 |
| --- | --- | --- | --- |
| `post_like` | 帖子被赞 | @xxx 赞了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `reply_like` | 回复被赞 | @xxx 赞了你的回复 | `actor_id`, `actor_name`, `reply_id` |
| `post_mention` | 帖子中被@ | @xxx 在帖子中提到了你 | `actor_id`, `actor_name`, `post_id` |
| `reply_mention` | 回复中被@ | @xxx 在回复中提到了你 | `actor_id`, `actor_name`, `reply_id` |
| `post_reply` | 帖子被回复 | @xxx 回复了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `post_repost` | 帖子被转发 | @xxx 转发了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `post_quote` | 帖子被引用 | @xxx 引用了你的帖子 | `actor_id`, `actor_name`, `post_id` |
| `follow_request` | 关注请求 | @xxx 想要关注你 | `actor_id`, `actor_name`, `user_id` |
| `follow_accept` | 关注请求被接受 | @xxx 接受了你的关注请求 | `actor_id`, `actor_name`, `user_id` |
| `new_follower` | 新粉丝 | @xxx 开始关注你 | `actor_id`, `actor_name`, `user_id` |
| `follow_request_declined` | 关注请求被拒绝 | @xxx 拒绝了你的关注请求 | `actor_id`, `actor_name`, `user_id` |
| `notification_new` | 通用新通知 | 未读通知数 +1 | `notification_id` |


这是第二张图片中的表格内容的 Markdown 格式：

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `post_create` | 关注者发新帖 | Feed 流顶部插入新帖 | `post_id`, `user_id` |
| `reply_create` | 帖子收到新回复 | 帖子详情页实时追加回复 | `post_id`, `reply_id`, `user_id` |
| `post_edit` | 帖子被编辑 | Feed 流更新该帖内容 | `actor_id`, `actor_name`, `post_id` |
| `reply_approved` | 回复审核通过 | 自动显示该回复 | `actor_id(无)`, `reply_id` |
| `reply_rejected` | 回复被拒绝 | 显示拒绝提示 | `actor_id(无)`, `reply_id` |

这是第三张图片中表格内容的 Markdown 格式：

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `community_new_post` | 社群有新帖 | 社群页面推送 + 红点 | `actor_id`, `actor_name`, `post_id`, `community_id` |
| `community_join` | 新成员加入社群 | 社群动态更新 | `actor_id`, `actor_name`, `community_id` |
| `community_champion` | Champion 变更 | 社群荣誉榜更新 | `actor_id`, `actor_name`, `community_id` |

这是图片 "b3b802cfad1755ab99229e5940cbbb46.png" 中表格内容的 Markdown 格式：

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `group_message` | 群聊新消息 | 消息列表中新增 | `target_id`, `content` |
| `message_typing` | 对方正在输入 | 显示"正在输入..." | `conversation_id` |
| `message_read` | 消息已读 | 更新已读回执 | `message_ids` |
| `message_reaction` | 消息表情反应 | 显示 emoji 反应 | `message_id` |

这是最后一张图片中表格内容的 Markdown 格式：

| event_type | 语义 | 前端处理 | 包含字段 |
| --- | --- | --- | --- |
| `poll_close` | 投票结束 | 帖子中投票结果锁定 | `actor_id`, `actor_name`, `post_id` |
| `ghost_post_expired` | 幽灵帖过期 | 私密存档提示 | `actor_id(无)`, `post_id` |
| `report_status_updated` | 举报处理完成 | 用户收到处理结果 | `actor_id(无)`, `report_id` |
| `system_announcement` | 系统公告 | App 内公告弹窗/Banner | `actor_id(无)`, `content` |


{
    "event_type": "post_like",    // 事件类型 (必含)
    "actor_id": 123,              // 触发者 (通知类事件)
    "actor_name": "张三",         // 触发者名称 (通知类事件)
    "post_id": 456,               // 上下文ID (视事件)
    ...
}