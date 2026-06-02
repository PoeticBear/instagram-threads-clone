# 服务端问题记录

## 2026-06-01

### 通知列表接口返回数据为空

- **接口**：`GET /notification/notifications`
- **问题**：所有通知类型（点赞、回复、关注、提及）的接口均返回 `total: 0`、`items: []`，用户在客户端动态页面无法看到任何通知数据
- **实际返回**：
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "total": 0,
      "page": 1,
      "size": 20,
      "items": []
    }
  }
  ```
- **期望返回**：当用户收到点赞、回复、关注、提及时，应生成对应的通知记录并返回
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "total": 5,
      "page": 1,
      "size": 20,
      "items": [
        {
          "id": 1,
          "type": 1,
          "sender": {
            "id": 1000242,
            "username": "pengsihang",
            "display_name": "xxx",
            "avatar": "xxx"
          },
          "content": "赞了你的帖子",
          "is_read": false,
          "create_time": "2026-06-01T15:00:00Z"
        }
      ]
    }
  }
  ```
- **涉及类型**：
  - `notif_type=1`（点赞）→ 空列表
  - `notif_type=2`（回复）→ 空列表
  - `notif_type=3`（关注）→ 空列表
  - `notif_type=4`（提及）→ 空列表
- **备注**：客户端请求链路正常，接口响应 `200`，问题是服务端未生成通知记录（可能服务端在用户点赞、回复、关注等操作时未触发通知创建逻辑）
