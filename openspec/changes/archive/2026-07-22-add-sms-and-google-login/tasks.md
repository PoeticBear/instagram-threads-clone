# Tasks — add-sms-and-google-login

> 实现顺序：先打底（网络层 skipPaths）→ Google 契约对齐（service → state → UI）→ SMS 服务+状态层 → SMS UI + 区号选择器 + 文案 → 静态校验。端到端真机联调留作最后的人工 QA。每步可独立编译。

## 1. 网络层：登录接口豁免 401 刷新重试

- [x] 1.1 `client/lib/network/api_client.dart`
  - 在 `skipPaths`（约 116–121 行）追加 `'auth/google/login'` 与 `'auth/sms/signin'`，行为对齐 `auth/username/signin` / `auth/apple/login`。
  - 其余刷新逻辑保持不变。

## 2. Google 登录契约对齐（idToken 验签）

> ⚠️ 方向修正（2026-07-08）：本节最初实现为「发 serverAuthCode」，联调报 `101115 id_token decode error` 后回退为「发 idToken」。下面为最终落地内容。

- [x] 2.1 `client/lib/services/auth_service.dart`
  - `signInWithGoogle`：入参为 `idToken`，请求体 `{'code': idToken}`（字段名 `code` 为历史命名，内容为 idToken JWT），路径仍 `auth/google/login`。
  - 注释说明「后端直接验签 idToken，非授权码换取」。
  - 响应解析、token 落地（`LoginResponse`、`_saveTokens`）保持不变。
- [x] 2.2 `client/lib/state/auth.state.dart`
  - `signInWithGoogle`：透传参数为 `idToken`，调用 `authService.signInWithGoogle(idToken: ...)`；登录态机（存 token、设 `LOGGED_IN`）不变。
- [x] 2.3 `client/lib/auth/signup/name.dart`
  - `_handleGoogleSignIn`：`authenticate()` 后取 `account.authentication.idToken`（同步 getter，`String?`）；为空时本地提示「Google 授权失败，请重试」并 return，不发请求。
  - 调 `authState.signInWithGoogle(idToken, ...)`。
  - dev 日志只打印 idToken 长度/前缀，不打印完整 JWT。

## 3. SMS 服务层 + 状态层

- [x] 3.1 `client/lib/services/auth_service.dart`
  - 新增 `Future<bool> sendSmsCode({required String phoneCountryCode, required String phone})`：`POST auth/sms/send`，body `{'phone_country_code': ..., 'phone': ...}`；以顶层 `code == 0` 判定成功返回 bool（异常交由 `ApiClient` 抛出，调用方 catch）。
  - 新增 `Future<LoginResponse> signInWithSms({required String phoneCountryCode, required String phone, required String code})`：`POST auth/sms/signin`，body 含三字段；成功解析 `response['data']` → `LoginResponse` 并 `_saveTokens`，结构同 `signInWithApple` / `signInWithGoogle`。
- [x] 3.2 `client/lib/state/auth.state.dart`
  - 新增 `signInWithSms({phoneCountryCode, phone, code})`：与 `signInWithGoogle` 同构——调 `authService.signInWithSms` → 存 token → 设 `authStatus = LOGGED_IN` → 返回 `userId`；异常向上抛由 UI catch。

## 4. 手机号登录 UI + 国家区号选择 + 文案

- [x] 4.1 `client/lib/auth/signup/phone.dart`（新建）
  - `PhoneLoginPage`：标题 / 区号位（可点开选择器）+ 手机号输入 / 「获取验证码」按钮（60s 倒计时 + 重发）/ 验证码输入框 / 「登录」按钮 / 错误提示位。
  - 区号选择器：`showModalBottomSheet`，内置常用国家（国旗 emoji + 国家名 + 拨号码，按 locale 显示中/英文名），顶部搜索框按国家名/区号过滤，底部「自定义区号」入口（校验 `^\+\d{1,9}$`、长度 ≤10）。默认 `+86`。
  - 发码：本地校验手机号非空 → 调 `authState.authService.sendSmsCode` → 成功进倒计时、失败按异常 msg 提示不进倒计时。
  - 登录：调 `authState.signInWithSms` → 成功走 `needsUsernameSetup` 闸门 → `Navigator.pushReplacement(HomePage)`（与 `NamePage` 一致）；失败按 msg 提示。
  - 倒计时用 `Timer.periodic`，`dispose` 取消；`setState` 前 `mounted` 守卫。
  - 颜色走 `Theme.of(context).extension<AppColorsExtension>()!.colors`；文案全部走 `AppLocalizations`（禁止硬编码中英文）。
- [x] 4.2 `client/lib/auth/signup/name.dart`
  - 在 Google 按钮下方、「创建新账号」上方加一条「使用手机号登录」文字按钮 → `Navigator.push(PhoneLoginPage())`。
- [x] 4.3 `client/lib/l10n/app_en.arb` / `app_zh.arb`
  - 新增手机号登录相关 key（phoneLoginTitle / phoneLoginSubtitle / selectCountryCode / searchCountryCode / customCountryCode / customCodeDialogTitle / customCodeHint / countryCodeInvalid / phoneNumberHint / verificationCodeHint / sendCode / resendCountdown({seconds}) / smsCodeSent / pleaseEnterPhoneNumber / pleaseEnterVerificationCode / smsLoginFailed / loginWithPhone / googleAuthFailedRetry）。
- [x] 4.4 在 `client/` 下运行 `flutter gen-l10n`，确认 `lib/l10n/generated/app_localizations{,_en,_zh}.dart` 均已生成对应 getter（含 `resendCountdown(int seconds)` 占位符签名）。

## 5. 验证

> 5.1–5.4 为运行期人工 QA 场景，依赖真机/模拟器 + 可用的服务端（含真实 Google 凭据、可用短信通道）。代码层已按 spec 实现并已通过静态分析（见 5.5）。**5.1（Google）已于 2026-07-08 验证通过；在 5.2–5.4（SMS）通过前不归档本变更。**

- [x] 5.1 Google 登录：点 Google 按钮 → 完成授权 → 成功进主页。**2026-07-08 已端到端验证通过**（idToken 流，新用户 2000435，`code:0 success`；详见 `docs/daily-requirement/20260708-login-integration-results.md` 第 7 节）。
- [ ] 5.2 SMS 发码：输入区号 + 手机号 → 点获取验证码 → 收到短信 + 按钮进 60s 倒计时；错误手机号按 `msg` 提示且不进倒计时。
- [ ] 5.3 SMS 登录：输入正确验证码 → 成功进主页；错误验证码按 `msg` 提示、不改变登录态。
- [ ] 5.4 区号选择器：搜索过滤、自定义区号（合法/非法）、默认 +86、回填正确。
- [x] 5.5 `cd client && flutter analyze` 无新增告警。（仅余 `_refreshToken` unused_field 一条历史告警，位于 api_client.dart:14，上一轮变更已记录，非本次引入。）
