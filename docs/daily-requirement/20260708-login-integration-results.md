# 2026-07-08 登录联调结果（Google / SMS）

> **结论先行（TL;DR）**：新增的三个登录接口（`/auth/google/login`、`/auth/sms/send`、`/auth/sms/signin`）**本次无法完成业务级联调**——**开发环境后端 `192.168.1.27:8005` 当前不可用**：TCP 端口能连通，但任何 HTTP 请求都会被服务端「Connection reset by peer」直接重置，拿不到任何响应。生产环境正常。客户端代码与请求结构经核对与 OpenAPI 契约一致，问题在服务端。**需要服务端先修复 dev 环境**，再重跑本报告中的用例。

---

## 1. 环境

| 项 | 值 |
| --- | --- |
| 客户端构建 | `flutter run --dart-define=APP_ENV=dev`（dev 环境） |
| 设备 | iPhone 17 Pro 模拟器 `FEED462A-2E1B-4981-A1E0-8F87ECCC2D5F`（iOS 26.1） |
| dev baseUrl | `http://192.168.1.27:8005/` |
| 本机网络 | en1 = `192.168.1.35`，网关 `192.168.1.1`（与服务端 `192.168.1.27` 同一 `/24` 局域网） |
| OpenAPI 契约 | `openapi_docs/versions/openapi_20260708.json` |
| 探测方式 | ① 本机 `curl` 直连 dev 后端 ② 客户端实机启动抓 `debugPrint` 日志 |

---

## 2. 核心问题：dev 后端「TCP 通、HTTP 全被 reset」

### 2.1 TCP 层正常

```
$ nc -zv 192.168.1.27 8005
Connection to 192.168.1.27 port 8005 [tcp/*] succeeded!
```

- 8005 端口**监听正常**，TCP 三次握手成功。
- 同机 8000 / 8080 / 80 端口均为 `Connection refused`（说明服务确实只挂在 8005）。

### 2.2 HTTP 层全部被「Connection reset by peer」

对所有路径、所有 Host 头、HTTP 与 HTTPS、GET 与 POST，表现完全一致——**发出请求后服务端立即 RST，无任何 HTTP 响应**：

| # | 探测 | 结果 |
| --- | --- | --- |
| A | `GET http://192.168.1.27:8005/health` | `Recv failure: Connection reset by peer`（HTTP 000） |
| B | `GET /docs`（FastAPI 默认文档） | reset（HTTP 000） |
| C | `GET /openapi.json` | reset（HTTP 000） |
| D | `GET https://192.168.1.27:8005/health`（TLS） | reset（HTTP 000） |
| E | `POST /auth/sms/send`（真实请求体） | reset（HTTP 000） |
| F | `GET /health` + `Host: api.tweetcaht.com` | reset（HTTP 000） |
| G | `GET /health` + `Host: localhost` | reset（HTTP 000） |
| H | 裸 `GET /health HTTP/1.0`（nc，无 Host） | reset（无输出） |

`curl -v` 关键片段：
```
* Connected to 192.168.1.27 port 8005
> GET /health HTTP/1.1
> Host: 192.168.1.27:8005
* Request completely sent off
* Recv failure: Connection reset by peer
```

### 2.3 对照：生产环境正常

```
$ curl https://api.tweetcaht.com/health
prod https://api.tweetcaht.com/health -> HTTP 200
```

→ 说明**仅 dev 异常**，prod 健康。**不是客户端网络问题，也不是客户端代码问题。**

### 2.4 客户端实机复现（同一现象）

App 在模拟器上成功启动，启动期会调用 `GET /user/me`（本地有缓存 token 时的会话校验），报的是**完全相同**的错误：

```
flutter: [GoogleOAuth] initialize 成功
flutter: initAuthService - isLoggedIn: false
flutter: [AppleLogin] getProfileUser: 捕获异常 → ApiException: 网络请求异常:
        ClientException: Connection reset by peer,
        uri=http://192.168.1.27:8005/user/me (status: null)
```

- `status: null` —— 连 HTTP 状态码都没拿到，纯传输层失败。
- 该错误来自 `ApiClient` 的统一 `ClientException` 包装，与上面 curl 结果互相印证。

> **判断**：dev 后端进程在 `accept()` 后、处理任何请求前就 RST 了连接。常见原因：FastAPI/uvicorn worker 启动失败或反复崩溃、前置代理（nginx/caddy）upstream 配置异常、或服务被防火墙/安全组在应用层丢弃。请服务端排查 dev 机器 `192.168.1.27:8005` 上的服务进程与反代日志。

---

## 3. 待联调的三个接口（客户端实际发送的请求结构）

虽然没拿到业务响应，以下为**客户端真实发出的请求**（源自 `client/lib/services/auth_service.dart`，已与 OpenAPI 契约核对一致），供服务端确认契约：

### 3.1 `POST /auth/google/login` — Google 登录

- **Body**：`{ "code": "<serverAuthCode>" }`
  - `code` = Google 一次性授权码，由 `google_sign_in` 7.x（方式 B）的 `authorizationClient.authorizeServer(...)` 取得，`minLength: 1`。
- **Headers**：客户端当前**不发送** `device-os` / `device-name`（仅 username 登录/注册会带）。
- **期望 200 `data` = `SigninResponse`**：`{ id, username, avatar, access_token, refresh_token, display_name }`。

### 3.2 `POST /auth/sms/send` — 发送验证码

- **Body**：`{ "phone_country_code": "+86", "phone": "<手机号>" }`
- **Headers**：无。
- **期望 200 `data` = `{}`（`OKResponse`）**；客户端以顶层 `code == 0` 判定成功。

### 3.3 `POST /auth/sms/signin` — 验证码登录 / 注册

- **Body**：`{ "phone_country_code": "+86", "phone": "<手机号>", "code": "<4–6 位验证码>" }`
- **Headers**：客户端当前**不发送** `device-os` / `device-name`。
- **期望 200 `data` = `SigninResponse`**（结构同 3.1）。

---

## 4. 需要服务端确认 / 协助的事项

1. **【阻塞】修复 dev 后端**：`192.168.1.27:8005` TCP 通但所有 HTTP 请求被 reset（见第 2 节）。修复后我们立即重跑 2.1~2.4 的用例并补全三个接口的业务级响应（`code` / `msg` / `data`）。
2. **`SigninResponse` 字段一致性**：三个登录接口（含既有 apple/username 登录）共用 `SigninResponse`。客户端用 `data['user_id'] ?? data['id']` 兼容取用户 ID，`data.access_token` / `data.refresh_token` 取令牌。请确认 dev 修复后**三个接口都返回** `access_token` + `refresh_token` + `id`（或 `user_id`）。
3. **新用户 `username` 是否为空**：Google / SMS 首次登录会自动注册，客户端预期 `data.username` 可能为空，并设有「补填用户名」引导（`needsUsernameSetup`）。请确认服务端对**新注册用户返回空字符串 `""`**（而非 `null` / 缺字段），以免客户端解析异常。
4. **`device-*` 请求头是否必需**：OpenAPI 把 `user-agent` / `device-os` / `device-name` 列为 google/sms 登录的可选头，客户端目前**未发送**。若服务端实际依赖（例如风控 / 设备绑定），请告知，客户端再补。

---

## 5. 客户端侧已验证 OK 的部分（无需服务端介入）

- ✅ dev 包成功在 iPhone 17 Pro 模拟器构建并启动（`--dart-define=APP_ENV=dev` 生效，请求确实打到 `192.168.1.27:8005`）。
- ✅ Google 登录 SDK 初始化成功：`[GoogleOAuth] initialize 成功`（`google_sign_in` 7.x 方式 B 已就绪，可取授权码）。
- ✅ SMS 登录页 UI（区号选择器 + 手机号 + 验证码 + 60s 倒计时）已就位，区号校验与服务端 `phone_country_code(2–10)` 约束一致。
- ✅ 请求结构经核对与 OpenAPI 契约一致。

---

## 6. 重跑计划（dev 修复后）

服务端确认 dev 恢复后，按以下顺序复测，结果回填本表：

| 用例 | 请求 | 期望 | 实测（待填） |
| --- | --- | --- | --- |
| 健康检查 | `GET /health` | HTTP 200 | _ |
| 发送验证码 | `POST /auth/sms/send` `+86/<真实号>` | `code==0` | _ |
| 验证码登录（错码） | `POST /auth/sms/signin` 错码 | 业务错误码 + msg | _ |
| 验证码登录（正确码） | `POST /auth/sms/signin` 正确码 | `SigninResponse` | _ |
| Google 登录 | `POST /auth/google/login` 真实授权码 | `SigninResponse` | _ |

---

---

## 7. 更新：dev 恢复 + Google 登录实测与修复（2026-07-08 续）

dev 后端已恢复（TCP/HTTP 正常）。实测 Google 登录拿到了**业务级响应**，但报错 `101115`。

**客户端日志（已脱敏）：**
```
[Google SignIn] account=117847...557, serverAuthCode=4/0AdkVL... (73 chars)
[signInWithGoogle] 发往后端 POST auth/google/login, code 长度: 73 chars
[signInWithGoogle] ❌ 请求失败
  异常类型: ServerException   业务码: 101115
  message: Google login failed, id_token decode error
  服务端原始响应: {"code": 101115, "msg": "Google login failed, id_token decode error"}
```

### 根因：guide 与 OpenAPI 契约矛盾，客户端发错了凭据类型

| 文档 | 描述的流程 |
| --- | --- |
| `google-oauth-login-guide.md`（团队原始设计） | 客户端发 **idToken（JWT）**，后端**直接验签**；serverAuthCode 仅在需离线访问 Google API 时才用 |
| OpenAPI（`/auth/google/login`） | 客户端发 **授权码 code**，后端向 Google **换取** id_token 后解码 |
| 客户端改动后实际行为（`add-sms-and-google-login`） | 按对 OpenAPI 的理解，发 `{code: serverAuthCode}` |

后端报 `id_token **decode** error` = 它把收到的 `code` 字段**当 JWT 解码**，而客户端发的是 73 位**授权码**（`4/0AdkVL...`，**非 JWT**——JWT 应以 `eyJ` 开头）→ 解码必然失败。**结论：后端实际走 guide 那套（直接验签 idToken），并未做授权码换取。** 选定方向 **A：客户端回退为发 idToken**。

### 已应用的客户端修复

- `lib/auth/signup/name.dart`：`authenticate()` 后取 `account.authentication.idToken`，不再调 `authorizeServer`。
- `lib/services/auth_service.dart`：`signInWithGoogle(idToken)`，请求体 `{code: idToken}`（字段名沿用契约，内容换成 idToken JWT）。
- `lib/state/auth.state.dart`：透传参数改为 `idToken`。
- `flutter analyze` 三个文件 **0 issue**。

### ✅ 实测结果（修复后，2026-07-08）

重新点 Google 登录，后端**放行**，`101115` 消失：

```
[Google SignIn] account=117847...557, idToken=eyJhbGci... (1218 chars)   ← 现在发的是 JWT（原先 73 位授权码）
[signInWithGoogle] 发往后端 POST auth/google/login, idToken 长度: 1218 chars
[signInWithGoogle] 服务端返回:
{
  "code": 0,
  "msg": "success",
  "data": {
    "id": 2000435,
    "username": "",
    "avatar": "https://lh3.googleusercontent.com/...",
    "access_token": "<redacted>",
    "refresh_token": "<redacted>",
    "display_name": "user_2000435"
  }
}
```

- 返回结构 = OpenAPI 的 `SigninResponse`，`code: 0` 成功；用户 `2000435`（新用户、Google 头像、`create_time` 当天）自动注册并登录。
- `username: ""` → 客户端 `needsUsernameSetup=true`，正确触发补填用户名引导。
- 响应用 `id`（非 `user_id`），客户端 `data['user_id'] ?? data['id']` 兜底正确取到 `2000435`。
- 两次复测均成功，日志中无任何 1011xx。

### 需要服务端确认 / 跟进

1. **【确认】`/auth/google/login` 的 `code` 字段是否就是收 idToken JWT？** 若是，请把 OpenAPI 里该字段描述从「Google 登录授权码」改为「Google idToken(JWT)」，或字段名直接改为 `id_token`，消除 guide 与 OpenAPI 的矛盾，避免下次再踩。
2. **idToken 验签要点**（后端若已实现可忽略）：
   - `aud`（audience）校验为 **Web 客户端 id** `818599281759-g2selrt12levi6nme9v2gpkd4t76adoq.apps.googleusercontent.com`（客户端 `serverClientId` 已配此值，故 idToken 的 `aud` 即为它）。
   - `iss` 校验 `accounts.google.com` / `https://accounts.google.com`。
   - 签名用 Google JWKS 公钥（`https://www.googleapis.com/oauth2/v3/certs`）。
3. **OpenSpec 记录校正**：`openspec/changes/add-sms-and-google-login` 的 design/proposal/spec 写的是「serverAuthCode 换取」流程，现已与实际（idToken 验签）不符，建议归档/校正时改写。

---

*生成方式：客户端 `flutter run --dart-define=APP_ENV=dev`（iPhone 17 Pro 模拟器）+ 本机 `curl` 直连 dev/prod 后端对照探测。客户端源码：`client/lib/services/auth_service.dart`、`client/lib/auth/signup/phone.dart`、`client/lib/auth/signup/name.dart`。*
