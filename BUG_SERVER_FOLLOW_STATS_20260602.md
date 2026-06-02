# 服务端问题记录

## 2026-06-02

### 关注统计接口 followers_count / following_count 始终返回 0

- **接口**：`GET /follow/{user_id}/stats`
- **问题**：关注统计接口的 `followers_count` 和 `following_count` 始终返回 0，即使关注关系已存在。导致客户端个人中心页面的粉丝数和关注数始终显示为 0
- **复现步骤**：
  1. 用户 A（pengsihang, id=1000242）关注用户 B（axiongmei, id=1000378）
  2. 调用 `GET /follow/1000378/stats` 查看用户 B 的统计
- **实际返回**：
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "followers_count": 0,
      "following_count": 0,
      "is_following": 0,
      "is_followed_by_me": 0,
      "is_mutual": 0
    }
  }
  ```
- **期望返回**：
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "followers_count": 1,
      "following_count": 0,
      "is_following": 1,
      "is_followed_by_me": 0,
      "is_mutual": 0
    }
  }
  ```

- **交叉验证（证明关注关系已存在）**：
  - `GET /follow/followers/1000378`（用户 B 的粉丝列表）→ 返回 `total: 1`，pengsihang 在列表中，`follow_time: "2026-06-02T03:48:22"`，`is_mutual: 1`
  - `GET /follow/following/1000242`（用户 A 的关注列表）→ 返回 `total: 5`，axiongmei 在列表中
  - 说明**关注关系已正确写入数据库**，但 stats 接口的计数查询未正确聚合

- **关联问题**：`GET /user/profile/{user_id}` 返回的 `followers_count` 和 `following_count` 同样为 0（可能依赖了相同的计数逻辑或缓存未更新）

- **备注**：客户端侧已确认请求链路正常（接口响应 200），问题是服务端 stats 接口的 `followers_count`/`following_count` 统计逻辑未正确计算已存在的关注关系
