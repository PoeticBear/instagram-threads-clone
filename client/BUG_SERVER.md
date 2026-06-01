# 服务端问题记录

## 2026-06-01

### Feed 列表接口 user 对象字段未填充

- **接口**：`GET /post/feed`
- **问题**：返回数据中，每条帖子的 `user` 对象只有 `id` 有值，`username`、`display_name`、`avatar` 均为空字符串
- **实际返回**：
  ```json
  "user": {
    "id": 1000242,
    "username": "",
    "display_name": "",
    "avatar": "",
    "is_verified": 0
  }
  ```
- **期望返回**：
  ```json
  "user": {
    "id": 1000242,
    "username": "pengsihang",
    "display_name": "xxx",
    "avatar": "xxx",
    "is_verified": 0
  }
  ```

### Feed 列表接口 quote_post 嵌套对象未填充

- **接口**：`GET /post/feed`
- **问题**：引用帖子在列表接口中只返回 `quote_post_id`，`quote_post` 始终为 `null`，无法在信息流中展示被引用帖子的内容
- **实际返回**：
  ```json
  {
    "id": 1000364,
    "content": "我引用了这条帖子，发表一下我的看法。",
    "quote_post_id": 1000360,
    "quote_post": null
  }
  ```
- **期望返回**：
  ```json
  {
    "id": 1000364,
    "content": "我引用了这条帖子，发表一下我的看法。",
    "quote_post_id": 1000360,
    "quote_post": {
      "id": 1000360,
      "user": { "id": 1000242, "username": "pengsihang", "display_name": "xxx", "avatar": "xxx" },
      "content": "This is the original post for testing quote feature."
    }
  }
  ```
- **备注**：`GET /post/detail/{postId}` 接口返回的 `quote_post` 是正常的
