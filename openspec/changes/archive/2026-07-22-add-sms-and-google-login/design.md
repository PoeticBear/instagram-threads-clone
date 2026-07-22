## Context

登录入口 `NamePage`（`client/lib/auth/signup/name.dart`）现状：用户名密码、Apple、Google 三种方式，登录成功后统一走 `needsUsernameSetup` 闸门 → `HomePage`。三条登录链路在 `AuthState` 里是同构的状态机：调 `AuthService` → 存 token（`access_token` / `refresh_token` / `user_id`，SharedPreferences）→ 设 `authStatus = LOGGED_IN` → UI 层 `Navigator.pushReplacement(HomePage)`。

服务端契约（`openapi_docs/versions/openapi_20260708.json`，已逐字段核对）：

- `POST /auth/google/login`：请求体 `{code: string}`（字段名 `code` 为历史命名，**内容实为 Google idToken JWT**——后端按 `google-oauth-login-guide.md` 直接验签，非授权码换取），可选设备头，成功 → `SigninResponse`。
- `POST /auth/sms/send`：请求体 `{phone_country_code(2–10), phone(1–20)}`，成功 → `OKResponse`（空 `data`）。
- `POST /auth/sms/signin`：请求体 `{phone_country_code(2–10), phone(1–20), code(4–6)}`，可选设备头，成功 → `SigninResponse`。

两条 `signin` 类接口成功返回的 `SigninResponse` 完全一致（`id` / `username` / `avatar` / `access_token` / `refresh_token` / `display_name`），客户端登录态落地可复用同一套——这正是本次设计的最大复用点。

## Goals / Non-Goals

**Goals:**

- 让 Google 登录按后端实际验签口径跑通（客户端只负责取 idToken，后端直接验签）。
- 新增「手机号 + 验证码」登录，手机号须明确区分国家区号前缀。
- 最大化复用既有登录态机与 token 落地逻辑，新方式只新增「换登录态的那一次调用」。

**Non-Goals:**

- 不改服务端接口（契约以 OpenAPI 为准）。
- 不实现 `user-agent` / `device-os` / `device-name` 三个可选设备识别头（非必填，本期不做）。
- 不动 Apple / 用户名密码登录、注册流程。
- 不做 Android 适配。
- 不新增第三方包。

## Decisions

### 决策 1：Google 登录发 idToken，后端直接验签（采用；曾误用 serverAuthCode，已纠正）

后端按 `google-oauth-login-guide.md` 的设计：登录「只需校验 idToken」。客户端取 Google 签发的 idToken（JWT）发给后端，后端用 Google 公钥验签读身份。OpenAPI 把 `/auth/google/login.code` 描述成「Google 授权码、后端换取」属误导——后端实际只验签 idToken。

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 发 `{code: account.authentication.idToken}` | 与后端实际验签口径一致；idToken 短时、可由 Google 验真 |
| B | 发 `{code: serverAuthCode}`（OAuth 授权码） | ❌ 已实测否决：授权码非 JWT，后端当 JWT 解码 → `101115 id_token decode error` |
| C | 同时发 `code` + `id_token` | 契约单字段，多发无意义且易让后端逻辑分叉 |

❗ **修正记录（2026-07-08）**：本决策最初选了 B（发 serverAuthCode），依据是对 OpenAPI「换取」描述的字面理解，并按 `google_sign_in` 7.x 用 `authorizationClient.authorizeServer(...)` 取授权码。端到端联调时后端报 `101115 id_token decode error`，定位到后端是「直接把 `code` 字段当 JWT 解码」而授权码（`4/0AdkVL...`，非 JWT）解码必败，遂回退为 A（发 idToken），复测通过（新用户 2000435，`code:0 success`）。

前置条件已满足：`GoogleOAuth.initialize()`（`google_oauth_config.dart`）已传入 `serverClientId: webClientId`——只有传了 `serverClientId`，`account.authentication.idToken` 才会被填充，且其 `aud` 即 Web clientId（后端验签 audience 按它校验）。无需再改初始化。

边界处理：`idToken` 可能为 `null`（如 `initialize` 未传 `serverClientId`、平台异常）。此时**不**向后端发空串（服务端 `minLength: 1` 会 422），而是在客户端给出明确错误提示并引导重试。

### 决策 2：短信登录复用 `LoginResponse` 与既有登录态机（采用）

`/auth/sms/signin` 的 `SigninResponse` 与用户名密码登录的响应结构一致，`AuthService` 里现有的 `LoginResponse` 解析 + token 落地（`_saveTokens` / `ApiClient` 内存 token）可直接复用。因此：

- `AuthService.signInWithSms(...)` 内部结构与 `signInWithApple` / `signInWithGoogle` 同构：`post('auth/sms/signin', body)` → 解析 `response['data']` → `LoginResponse` → 保存。
- `AuthState.signInWithSms(...)` 与 `signInWithGoogle` 同构：调 service → 存 token → 设 `LOGGED_IN` → UI 层走 `needsUsernameSetup` 闸门 → `HomePage`。

不在 UI 层各自重复 token 处理，避免三套登录方式三份落地逻辑漂移。

### 决策 3：国家区号选择器——轻量自实现，不引包（采用）

需求明确「手机号须明确区分国家/地区前缀编码」。候选方案：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 自实现：`showModalBottomSheet` + 可搜索列表（国旗 emoji + 国家名 + 拨号码），常用区号为主，并允许手动输入自定义区号 | 零新依赖；体积可控；满足「明确区分前缀」；与服务端 `phone_country_code` 长度 2–10 约束对齐（输入框限制长度） |
| B | 引 `country_pickers` / `country_code_picker` | 多一个依赖、包体增大，且其数据集/样式不一定贴合本项目主题色与文案风格 |
| C | 只放一个 `+86` 固定前缀 | 不满足「区分国家/地区」 |

默认选中 `+86`（主要用户群）。列表内置一批常用国家（中、美、英、日、韩、新、马、澳、港、台、德、法、加 等），顶部带搜索框按国家名/区号过滤；列表底部给一个「自定义区号」入口，弹小输入框（校验 `^\+\d{1,9}$`，长度 ≤10）。选中后回填到登录页的区号显示位。

国旗用 emoji（iOS 原生支持），不引图片资源。

### 决策 4：手机号登录独立成 `PhoneLoginPage`，入口挂在 `NamePage`（采用）

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 新建 `PhoneLoginPage`，`NamePage` 底部加一条「使用手机号登录」文字按钮 `push` 过去 | 与既有页面解耦；用户名密码登录页零改动、低风险；导航栈自然回退 |
| B | 在 `NamePage` 顶部做 Tab（账号 / 手机号）切换 | 改动 `NamePage` 较大，且两种表单字段差异多，Tab 内嵌拥挤 |
| C | 直接替换用户名密码为手机号 | 破坏既有登录方式，不可取 |

`PhoneLoginPage` 布局（自上而下）：返回按钮 / 标题 / 区号+手机号一行（区号可点开选择器）/ 「获取验证码」按钮（含 60s 倒计时与重发）/ 验证码输入框 / 「登录」按钮 / 错误提示位。登录成功导航与 `NamePage` 一致（`needsUsernameSetup` 闸门 → `HomePage`，`pushReplacement` 清栈）。

### 决策 5：验证码「60s 倒计时 + 重发」

点「获取验证码」成功后，按钮置灰并开始 60s 倒计时（`Timer.periodic`），倒计时结束恢复可点。倒计时期间再次点击不发请求。页面 `dispose` 时取消定时器防泄漏。发码失败（如手机号格式不对被服务端 422、或业务码非 0）不进入倒计时，直接提示 `msg`，便于用户立即修正重发。

### 决策 6：`skipPaths` 补登两条登录接口

`api_client._request` 的 401 → refresh → 重试逻辑里，`skipPaths` 已豁免 `auth/username/signin`、`auth/apple/login`、`auth/token/refresh`、`auth/logout`，但**漏了 `auth/google/login`**。登录类接口本身不带 token，401 不应触发刷新重试。本次顺手补 `auth/google/login` 与新增的 `auth/sms/signin`，行为对齐其它登录接口。

## Risks / Trade-offs

- **`idToken` 偶发为 null** → 客户端拦截：为空时不发请求，提示「Google 授权失败，请重试」，引导用户重新点 Google 按钮（`authenticate()` 会重新走授权拿新 idToken）。
- **OpenAPI 契约描述误导** → `/auth/google/login.code` 被描述成「授权码、换取」，实际内容是 idToken。已在本变更文档澄清；建议服务端把字段描述改对或重命名为 `id_token`（非阻塞）。
- **区号列表不全** → 自实现列表只内置常用国家，但有「自定义区号」兜底入口，任何 2–10 位 `+xxx` 区号都能输入，不会把用户卡死。
- **倒计时定时器泄漏** → `PhoneLoginPage.dispose` 取消 `Timer`，并用 `mounted` 守卫 `setState`。
- **网络层改动面** → `skipPaths` 仅追加两条路径，默认行为对其它接口零影响；最坏退化为「登录接口 401 触发一次刷新重试」（即现状），不会更糟。
