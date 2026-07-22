# google-login Specification

## Purpose
TBD - created by archiving change add-sms-and-google-login. Update Purpose after archive.
## Requirements
### Requirement: 使用 Google idToken 登录

客户端 SHALL 通过 `google_sign_in` 的 `authenticate()` 完成用户授权后，从 `account.authentication.idToken` 取得 Google 签发的 idToken（JWT），以请求体 `{ "code": <idToken> }`（字段名 `code` 为历史命名，内容为 idToken）调用 `POST /auth/google/login`。后端直接验签 idToken（非授权码换取，依据 `google-oauth-login-guide.md`）。客户端 MUST NOT 发送 OAuth 授权码（`serverAuthCode`）作为登录凭据——授权码非 JWT，后端当 JWT 解码会报 `101115 id_token decode error`。

成功响应 `data` 为 `SigninResponse`（`id` / `username` / `avatar` / `access_token` / `refresh_token` / `display_name`）时，客户端 SHALL 复用既有登录态落地逻辑：持久化 `access_token` / `refresh_token` / `user_id`（响应用 `id`，客户端 `data['user_id'] ?? data['id']` 兜底），置登录态为已登录，并在通过 `needsUsernameSetup` 闸门后导航至主页。

客户端 SHALL 以业务码（顶层 `code`）判定结果，不得仅依赖 HTTP 状态码：`code` 非 0 时为业务失败，按 `msg` 提示。

#### Scenario: 取到 idToken 并登录成功

- **WHEN** 用户在登录页点 Google 按钮完成系统授权
- **AND** `account.authentication.idToken` 非空
- **THEN** 客户端以 `{ "code": <idToken> }` 发起 `POST /auth/google/login`
- **AND** 服务端返回 `code == 0` 且 `data` 含有效 `access_token` / `refresh_token`
- **AND** 客户端持久化 token、置登录态为已登录、导航至主页（若需补用户名则先弹用户名设置闸门）

#### Scenario: 业务失败按 msg 提示

- **WHEN** `/auth/google/login` 返回 `code != 0`（如 Google 校验失败、账号被禁）
- **THEN** 客户端不落地任何 token、不改变登录态
- **AND** 在登录页按 `msg` 展示失败提示，Google 按钮恢复可点

### Requirement: Google idToken 缺失的兜底处理

当 `account.authentication.idToken` 为 `null` 时（如 `initialize` 未传 `serverClientId`、平台异常），客户端 MUST NOT 向 `/auth/google/login` 发送空 `code`（服务端约束 `minLength: 1`，空串会被 422 拒绝）。客户端 SHALL 在本地给出明确错误并允许用户重试。

#### Scenario: idToken 为空

- **WHEN** 用户完成 Google 授权但取得的 `idToken` 为 `null`
- **THEN** 客户端不发起 `/auth/google/login` 请求
- **AND** 在登录页展示「Google 授权失败，请重试」类提示
- **AND** Google 按钮恢复可点，允许用户再次触发授权拿新的 idToken

### Requirement: Google 登录接口豁免 401 刷新重试

`/auth/google/login` 属于登录类接口（请求本身不带 access token），客户端 SHALL 将其纳入 `api_client` 的 401 重试豁免名单（`skipPaths`），命中 401 时不触发 token 刷新与重试，直接把错误抛回调用方。

#### Scenario: Google 登录返回 401 不触发刷新

- **WHEN** `/auth/google/login` 收到 HTTP 401
- **THEN** 客户端不调用 `auth/token/refresh`
- **AND** 不对该请求进行自动重试
- **AND** 错误按既定异常类型抛回登录页处理

