## Why

当前登录入口（`NamePage`）只有「用户名密码 / Apple / Google」三种方式，且 Google 登录客户端需与后端实际验签口径对齐：后端按 `google-oauth-login-guide.md` **直接验签 idToken**（非授权码换取），客户端须发 idToken（曾一度误发 `serverAuthCode`，联调报 `101115 id_token decode error`，已纠正，详见 design 决策 1 修正记录）。同时，服务端已新增「手机号 + 短信验证码」登录两条接口（`/auth/sms/send`、`/auth/sms/signin`），客户端尚未实现，用户缺少最通用的手机号登录入口。

本变更一次性补齐：让 Google 登录按真实契约跑通，并新增手机号 + 验证码登录（手机号须明确区分国家区号前缀）。

## What Changes

- **Google 登录契约对齐**：客户端发往 `/auth/google/login` 的请求体为 `{code}`，`code` 取 `google_sign_in` 7.x 的 `account.authentication.idToken`（Google 签发的 idToken JWT，后端直接验签，非授权码换取）。`idToken` 为空时给出清晰错误而非静默失败。
- **新增短信登录服务层**：`AuthService` 新增 `sendSmsCode(phoneCountryCode, phone)` → `POST /auth/sms/send`、`signInWithSms(phoneCountryCode, phone, code)` → `POST /auth/sms/signin`；登录成功复用既有 `LoginResponse` 解析与 token 落地。
- **新增短信登录状态层**：`AuthState.signInWithSms`，复用既有登录态机（`needsUsernameSetup` 闸门 → `LOGGED_IN`）。
- **新增手机号登录 UI**：新建 `PhoneLoginPage`（国家区号选择器 + 手机号输入 + 「获取验证码」按钮含 60s 倒计时 + 验证码输入 + 登录），并在 `NamePage` 增加「使用手机号登录」入口；登录成功导航路径与其它登录方式一致。
- **国家区号选择器**：手机号须明确区分国家/地区前缀编码——用轻量 `showModalBottomSheet` 可搜索列表（国旗 emoji + 国家名 + 拨号码），常用区号为主并允许手动输入自定义区号（受服务端 `phone_country_code` 长度 2–10 约束）。
- **网络层小修**：把 `auth/google/login` 与 `auth/sms/signin` 纳入 `api_client` 的 401 重试豁免名单（`skipPaths`），避免登录类接口触发无意义的 token 刷新重试。
- **文案本地化**：新增手机号登录相关中英文案到 `app_en.arb` / `app_zh.arb`，运行 `flutter gen-l10n` 重新生成。

## Capabilities

### New Capabilities

- `google-login`: Google 账号登录能力契约 —— 客户端从 `google_sign_in` 取 `account.authentication.idToken`（idToken JWT），以 `{code}` 提交 `/auth/google/login`，后端直接验签后返回 `SigninResponse`，客户端落地 token 并进入主页。
- `sms-login`: 手机号 + 短信验证码登录能力契约 —— 先 `POST /auth/sms/send` 发码（手机号须带国家区号前缀），再 `POST /auth/sms/signin` 用「区号 + 手机号 + 验证码」换登录态；含国家区号选择、验证码倒计时/重发、登录态落地。

### Modified Capabilities

无 —— `openspec/specs/` 目前只有 `api-path-docs`，登录相关能力为首次建立。

## Impact

- `client/lib/services/auth_service.dart`：`signInWithGoogle` 入参为 `idToken`、请求体 `{code: idToken}`（字段名 `code` 为历史命名，内容为 idToken）；新增 `sendSmsCode` / `signInWithSms`。
- `client/lib/state/auth.state.dart`：`signInWithGoogle` 透传参数调整（`idToken`）；新增 `signInWithSms`。
- `client/lib/auth/signup/name.dart`：`_handleGoogleSignIn` 取 `account.authentication.idToken`；新增「使用手机号登录」入口。
- `client/lib/auth/signup/phone.dart`（新建）：`PhoneLoginPage` 及区号选择器。
- `client/lib/network/api_client.dart`：`skipPaths` 追加 `auth/google/login`、`auth/sms/signin`。
- `client/lib/l10n/app_en.arb` / `app_zh.arb`：新增手机号登录文案；重新生成 `generated/` 三件套。
- 依赖：无新增第三方包（`google_sign_in: ^7.1.1` 已存在；区号选择器用纯 Flutter 实现；`http` 复用）。

非目标（明确不做）：

- 不改服务端接口（契约以 `openapi_docs/versions/openapi_20260708.json` 为准）。
- 不做设备指纹识别（`user-agent` / `device-os` / `device-name` 三个可选请求头本期不实现，服务端为非必填）。
- 不动 Apple 登录、用户名密码登录、注册流程。
- 不做 Android 适配（项目仅维护 iOS）。
- 不引入 `country_pickers` / `device_info_plus` 等新依赖。
