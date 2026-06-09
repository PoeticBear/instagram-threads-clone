# 服务端问题记录

## 2026-06-03

### 举报接口 POST /post/report 返回服务器内部错误

- **接口**：`POST /post/report`
- **问题**：客户端按照 API 文档正确传参，但服务端返回 `code: 101001`，msg 为"服务器开小差中，请稍候重试"。举报功能无法正常使用
- **复现步骤**：
  1. 用户 A（axiongmei, id=1000378）在信息流中点击帖子（id=1000486）右上角更多图标
  2. 选择"举报" → 选择举报类型（如"垃圾信息"）
  3. 客户端发送 `POST /post/report`
- **客户端发送的请求**：
  ```
  POST /post/report
  Headers:
    Content-Type: application/json
    Authorization: Bearer eyJhbGci...***
  Body:
  {
    "target_type": 1,
    "target_id": 1000486,
    "report_type": 1
  }
  ```
- **实际返回**：
  ```json
  {
    "code": 101001,
    "msg": "服务器开小差中，请稍候重试。"
  }
  ```
- **期望返回**：
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "id": 1,
      "reporter_id": 1000378,
      "target_type": 1,
      "target_id": 1000486,
      "report_type": 1,
      "description": "",
      "status": 1,
      "create_time": "2026-06-03T11:16:51"
    }
  }
  ```

- **参数对照（与 API 文档一致）**：

  | 字段 | 文档要求 | 客户端发送 | 是否一致 |
  |------|----------|-----------|---------|
  | `target_type` | int, 必填 | `1` (帖子) | ✓ |
  | `target_id` | int, 必填 | `1000486` | ✓ |
  | `report_type` | int, 必填 | `1` (垃圾信息) | ✓ |
  | `description` | string, 可选 | 未发送 | ✓ |

- **备注**：客户端侧已确认请求参数完全符合 API 文档定义（`openapi_docs/post.json` 第 400-404 行）。HTTP 状态码为 200，但业务 code 为 101001。该错误码非参数校验错误（参数错误应为 101003），属于服务端内部错误，请排查 `/post/report` 接口的后端处理逻辑
