# 登录与注册（Login / Signup）— 代码定位

> 本文档汇总 iOS 客户端「登录 / 注册 / Apple 登录 / 启动鉴权路由」相关全部源代码位置，包含入口路由判定、登录页、注册页、Apple 登录、状态层、服务层、国际化、Provider 注册以及当前**未被主流程使用**的遗留 signup 页面。
> 后续若收到「定位登录页 / 登录 / 注册 / Sign in / Login」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

> ⚠️ 注意：当前**真正在跑的登录页类名是 `NamePage`**（路径 `client/lib/auth/signup/name.dart`），尽管文件名/目录名叫 "signup"，但它就是登录入口。注册页是 `RegisterPage`。下文 1.1 / 1.2 详细说明。

---

## 1. 核心页面（UI 层）

### 1.1 登录页 `NamePage`

- **路径**：`client/lib/auth/signup/name.dart`
- **行数**：356
- **核心组件**：
  - `class NamePage extends StatefulWidget`（`name.dart:10`）— 接受可选 `VoidCallback? loginCallback`
  - `class _NamePageState extends State<NamePage>`（`name.dart:18`）— 持有 `_usernameController` / `_passwordController` / `_isLoading`
- **职责**：账号密码登录 + Apple 登录 + Google 登录入口（Google 仅占位未绑定回调），底部「创建新账号」按钮跳到 `RegisterPage`。
- **UI 结构**（从上到下）：

  | 区块 | 说明 | 行号 |
  | --- | --- | --- |
  | Logo | `Image.asset("assets/threads.png", height: 80)` | `name.dart:150-154` |
  | 标题 | `l10n.loginTitle`（"登录" / "Login"） | `name.dart:156-164` |
  | 用户名输入框 | `l10n.usernameHint` | `name.dart:166-181` |
  | 密码输入框 | `l10n.passwordHint`，`obscureText: true`（**无显示/隐藏切换**） | `name.dart:183-199` |
  | 登录按钮 | `l10n.loginButton`，loading 时替换为 `CircularProgressIndicator` | `name.dart:201-220` |
  | 「或」分隔线 | `l10n.or` + 两侧 `Divider` | `name.dart:222-234` |
  | Apple 登录 | `Icon(Icons.apple)` + `l10n.loginWithApple`，纯黑底白字 | `name.dart:236-272` |
  | Google 登录 | `l10n.loginWithGoogle`，**未绑定 onTap 回调（占位）** | `name.dart:274-311` |
  | 创建新账号 | `l10n.createNewAccount` → `Navigator.push(... RegisterPage())` | `name.dart:313-348` |

- **关键方法**：

  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `_handleLogin()` | 取用户名/密码 → 校验非空 → `authState.signIn(...)` → 成功 `Navigator.pushReplacement(HomePage)` / 失败 snackbar | `name.dart:30-67` |
  | `_handleAppleSignIn()` | 调 `SignInWithApple.getAppleIDCredential(scopes: [email, fullName])` → `authState.signInWithApple(authorizationCode)` → 成功跳 `HomePage` | `name.dart:69-136` |

- **登录成功跳转**：`Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()))`（`name.dart:58-61` / `131-134`）

### 1.2 注册页 `RegisterPage`

- **路径**：`client/lib/auth/signup/register.dart`
- **行数**：238
- **核心组件**：
  - `class RegisterPage extends StatefulWidget`（`register.dart:7`）
  - `class _RegisterPageState extends State<RegisterPage>`（`register.dart:14`）— 持有 `_usernameController` / `_passwordController` / `_confirmPasswordController` / `_isLoading` / `_obscurePassword` / `_obscureConfirmPassword`
- **职责**：用户名 + 密码 + 确认密码的注册表单，注册成功后**自动登录**并跳 `HomePage`。
- **字段校验**（`register.dart:30-61`）：
  - 三项非空 → `'请填写所有字段'`
  - 用户名 ≥ 2 字符
  - 密码 ≥ 5 字符
  - 两次密码一致
  - ⚠️ 上述 snackbar 文案当前为**硬编码中文**，未走 `AppLocalizations`，与 `CLAUDE.md` 规范有偏差。
- **关键方法**：

  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `_handleRegister()` async | 校验 → `authState.register(username, password, ...)` → 成功 `Navigator.pushReplacement(HomePage)` | `register.dart:30-85` |

- **入口**：仅由登录页 `NamePage` 底部「创建新账号」按钮进入（`name.dart:313-319`）。
- **回登录入口**：底部 `'已有账号？去登录'`（`register.dart:220-230`）— 硬编码中文，未走 l10n，仅 `Navigator.pop` 回登录页。

### 1.3 启动鉴权路由 `SplashPage`

- **路径**：`client/lib/common/splash.dart`
- **行数**：63
- **核心组件**：`class SplashPage extends StatefulWidget`（`splash.dart:9`）
- **职责**：应用冷启动时根据 `AuthState.authStatus` 三态分发路由：

  ```dart
  // splash.dart:56-61
  state.authStatus == AuthStatus.NOT_DETERMINED  → 空白容器（初始化中）
  state.authStatus == AuthStatus.NOT_LOGGED_IN   → const NamePage()   // 登录页
  state.authStatus == AuthStatus.LOGGED_IN       → const HomePage()
  ```

- **初始化逻辑**（`splash.dart:27-45`）：
  1. `state.initAuthService()`（恢复 token + 缓存的 `userModel`）
  2. `state.getProfileUser()`（拉远端 `/user/me` + `/user/profile/{id}`）
  3. 若已登录，触发 `DeepLinkService.instance.processPendingLink()`

- **入口**：`client/lib/main.dart:131` — `home: SplashPage()`，作为 `MaterialApp` 的首页。

---

## 2. 状态层（Provider）

### 2.1 `AuthState`（全局单例）

- **路径**：`client/lib/state/auth.state.dart`
- **行数**：472
- **核心组件**：`class AuthState extends AppStates`（`auth.state.dart:15`）
- **字段**：
  | 字段 | 类型 | 说明 | 行号 |
  | --- | --- | --- | --- |
  | `authStatus` | `AuthStatus` | 三态：`NOT_DETERMINED` / `NOT_LOGGED_IN` / `LOGGED_IN` | `auth.state.dart:16` |
  | `userId` | `String` | 默认空串（避免 `LateInitializationError`） | `auth.state.dart:20` |
  | `_userModel` | `UserModel?` | 当前登录用户完整资料 | `auth.state.dart:22` |
  | `isSignInWithGoogle` | `bool` | Google 登录标记（**当前未实际使用**） | `auth.state.dart:17` |
- **关键方法**：
  | 方法 | 说明 | 行号 |
  | --- | --- | --- |
  | `initAuthService()` | 启动初始化：恢复 token → 读缓存 `userModel` → 设置 `authStatus` | `auth.state.dart:49-62` |
  | `signIn(username, password, ctx, scaffoldKey)` | 账密登录：调 `authService.signIn` → `getProfileUser` → `userId` 空兜底回 `NOT_LOGGED_IN` | `auth.state.dart:73-113` |
  | `signInWithApple(code, ctx, scaffoldKey)` | Apple 登录：调 `authService.signInWithApple(code)` → 同上流程 | `auth.state.dart:129-162` |
  | `register(username, password, ctx, scaffoldKey)` | 注册：调 `authService.register` → **再调 `authService.signIn` 自动登录** → `getProfileUser` | `auth.state.dart:215-259` |
  | `signUp(userModel, ctx, scaffoldKey, password)` | **遗留**：旧 email 注册流程，被 `EmailPage` 调用（主流程不再用） | `auth.state.dart:164-203` |
  | `getCurrentUser()` | 拉 `/user/me` → 失败时尝试 `refreshToken()` 续命 → 仍失败置 `NOT_LOGGED_IN` | `auth.state.dart:261-333` |
  | `getProfileUser({userProfileId?})` | 拉 `/user/me` + `/user/profile/{id}`，合并字段写入 `_userModel`（关键：`username` 来源 `/user/me`） | `auth.state.dart:415-469` |
  | `logoutCallback()` | 退登：清状态 + `authService.logout()` + `clearPreferenceValues()` | `auth.state.dart:64-71` |
- **注册位置**：`client/lib/main.dart:88` — `ChangeNotifierProvider<AuthState>(create: (_) => AuthState())`，全局单例。
- **消费方**：
  - `SplashPage`（`splash.dart:30 / 53`）— 监听 `authStatus` 切换路由
  - `NamePage` / `RegisterPage` — `Provider.of<AuthState>(context, listen: false)` 调登录/注册方法
  - `SettingsPage` 退出登录按钮（`settings.dart`）— 调 `logoutCallback()`

### 2.2 `AuthStatus` 枚举

- **路径**：`client/lib/helper/enum.dart:1-5`
- **值**：`NOT_DETERMINED` / `NOT_LOGGED_IN` / `LOGGED_IN`

---

## 3. 服务层（API）

### 3.1 `AuthService`

- **路径**：`client/lib/services/auth_service.dart`
- **行数**：396
- **核心组件**：`class AuthService`（`auth_service.dart:7`）— 持有 `ApiClient` + `SharedPreferences`
- **关键方法**：
  | 方法 | 端点 | 说明 | 行号 |
  | --- | --- | --- | --- |
  | `init()` | — | 启动恢复：env 变化清 token → 重新读 token 注入 `ApiClient` | `auth_service.dart:25-39` |
  | `signIn({username, password})` | POST `auth/username/signin` | 保存 token + `userId`，返回 `LoginResponse` | `auth_service.dart:45-78` |
  | `signInWithApple({code})` | POST `auth/apple/login` | 把 Apple `authorizationCode` 交给后端兑换 token | `auth_service.dart:87-108` |
  | `register({username, password, confirmPassword, displayName?, bio?})` | POST `auth/username/register` | **不返回 token**，需后续调 `signIn` | `auth_service.dart:110-155` |
  | `getCurrentUser()` | GET `user/me` | 返回 `UserInfo` | `auth_service.dart:167-177` |
  | `refreshToken()` | POST `auth/token/refresh` | 失败时清 token | `auth_service.dart:179-200` |
  | `logout()` | DELETE `auth/logout` | 失败静默忽略，最终清本地 token | `auth_service.dart:157-165` |
  | `modifyPassword({oldPassword, newPassword})` | PUT `user/modify_password` | 修改密码 | `auth_service.dart:202-217` |
  | `registerDeviceToken(token)` / `deregisterDeviceToken(token)` | POST `user/device-token/{register,deregister}` | 推送设备 token 注册 / 注销 | `auth_service.dart:220-241` |
- **登录态判定**：`bool get isLoggedIn => _prefs.getString('access_token') != null`（`auth_service.dart:41`）
- **token 持久化**：`access_token` / `refresh_token` / `user_id` 三键（`auth_service.dart:11-13`），写 `ApiClient.setTokens` 同时双写 SharedPreferences
- **响应模型**：
  - `LoginResponse`（`auth_service.dart:270-289`）— `accessToken` / `refreshToken` / `userId?`，`fromJson` 兼容 `id` 与 `user_id` 两种字段名
  - `RegisterResponse`（`auth_service.dart:291-310`）— 同上结构
  - `UserInfo`（`auth_service.dart:312-396`）— 完整用户资料，含 `is_private` / `is_verified` / `is_following` / `is_mutual` 等 int/bool 兼容解析

### 3.2 第三方插件

| 插件 | 用途 | 使用位置 |
| --- | --- | --- |
| `sign_in_with_apple` | Apple ID 登录 | `name.dart:3` / `name.dart:78` `SignInWithApple.getAppleIDCredential(scopes: [email, fullName])` |

> ⚠️ Google 登录目前**仅有 UI 占位**（`name.dart:274-311`），未引入 google_sign_in 插件，无回调。

---

## 4. 入口集成点

| 入口 | 文件 | 行号 | 说明 |
| --- | --- | --- | --- |
| 应用首页 | `client/lib/main.dart` | `main.dart:131` | `MaterialApp(home: SplashPage())` |
| AuthState Provider 注册 | `client/lib/main.dart` | `main.dart:88` | `ChangeNotifierProvider<AuthState>(create: (_) => AuthState())` |
| 登录 ↔ 注册跳转 | `client/lib/auth/signup/name.dart` | `name.dart:313-319` | 「创建新账号」→ `RegisterPage` |
| 注册 → 登录回退 | `client/lib/auth/signup/register.dart` | `register.dart:220-230` | 「已有账号？去登录」→ `Navigator.pop` |
| 登录/注册成功 → 主页 | `name.dart` / `register.dart` | `name.dart:58-61`、`131-134`；`register.dart:79-82` | `Navigator.pushReplacement(HomePage)` |
| 退登入口 | `client/lib/common/settings.dart` | （见 `settings-page.md`） | 调 `authState.logoutCallback()` |

---

## 5. 国际化（l10n）

- **arb 文件**：`client/lib/l10n/app_en.arb` / `client/lib/l10n/app_zh.arb`
- **生成文件**：`client/lib/l10n/generated/app_localizations_{en,zh}.dart`
- **相关 key**：

  | key | en | zh |
  | --- | --- | --- |
  | `loginTitle` | Login | 登录 |
  | `usernameHint` | Username | 用户名 |
  | `passwordHint` | Password | 密码 |
  | `loginButton` | Login | 登录 |
  | `loginWithApple` | Continue with Apple | 通过 Apple 继续 |
  | `loginWithGoogle` | Continue with Google | 通过 Google 继续 |
  | `createNewAccount` | Create new account | 创建新账号 |
  | `pleaseEnterUsernameAndPassword` | Please enter username and password | 请输入用户名和密码 |
  | `loginFailedCheckCredentials` | Login failed, please check username and password | 登录失败，请检查用户名和密码 |
  | `or` | (or) | (或) |

> ⚠️ `RegisterPage` 内的多条提示文案（`'请填写所有字段'` / `'用户名至少需要 2 个字符'` / `'两次输入的密码不一致'` / `'已有账号？去登录'`）当前**硬编码中文**，未走 l10n，与 `CLAUDE.md` 规范有偏差。

---

## 6. 遗留代码（不在主流程中使用）

以下三个文件**当前没有任何入口引用**（仅彼此互引或自引用），属于早期 "Threads 风格 email 注册" 的旧流程，新需求**不应**在这些文件上修改：

| 文件 | 类 | 说明 | 状态 |
| --- | --- | --- | --- |
| `client/lib/auth/signup/signup.dart` | `Signup` | 旧的 "Profile" 资料填写页（Name + Bio + Link + 头像），跳到 `EmailPage` | 未被引用 |
| `client/lib/auth/signup/email.dart` | `EmailPage` | 旧的 email + password 注册，调 `state.signUp` | 仅被 `Signup` 引用 |
| `client/lib/auth/signup/account.dart` | `SwitchAccount` | 旧 "Switch accounts" 切账号占位页（含 Android 分支对话框） | 未被引用 |

- `AuthState.signUp(...)`（`auth.state.dart:164-203`）仍保留以兼容 `EmailPage`，主流程已改用 `register(...)`。
- 若后续确认彻底废弃，建议连同 `signup.dart` / `email.dart` / `account.dart` 一并清理，并把目录 `auth/signup/` 重命名为 `auth/` 以减少误导（`NamePage` 实为登录页，目录名却叫 signup）。

---

## 7. 关键设计要点

- **登录页命名误导**：登录页类名 `NamePage`、目录 `auth/signup/`、文件名 `name.dart`，但实际承担**登录入口**职责。重构时建议改名 `LoginPage` / `auth/login_page.dart`。
- **状态机三态分发**：`SplashPage` 不直接渲染登录 UI，而是 `Provider.of<AuthState>(context)` 监听 `authStatus`，路由切换由 `notifyListeners()` 驱动。
- **注册即登录**：`AuthState.register` 内部串行调用 `authService.register` → `authService.signIn`，保证注册后无需二次手动登录。注释明确说明：服务端 `/user/register` 不返回 token。
- **token 持久化双写**：`AuthService._saveTokens` 同时写 SharedPreferences（用于冷启动恢复）和 `ApiClient.setTokens`（用于当前会话的 HTTP Header）。
- **环境切换清 token**：`AuthService.init()` 检测 `APP_ENV` 变化（dev ↔ prod），自动清旧 token，避免跨环境 401。
- **登录后 deep link 处理**：`SplashPage.timer` 在确认 `LOGGED_IN` 后调 `DeepLinkService.instance.processPendingLink()`，处理"未登录时点击外部链接"的延迟分发。
- **Apple 登录安全模型**：客户端只持有 Apple 短期 `authorizationCode`，不外发 `identityToken`；`userIdentifier` 只截前 8 位打印（`name.dart:89-95`）。
- **Google 登录占位**：UI 完整但**未绑定 onTap**（`name.dart:274`），未来接入 Google 登录时需补 `onPressed` 回调并新增 `AuthState.signInWithGoogle` + `AuthService.signInWithGoogle` + google_sign_in 插件。
- **国际化遗漏**：`RegisterPage` 的部分提示文案硬编码中文，与全局 l10n 策略不一致。

---

## 8. 复用 & 扩展点

- **新增第三方登录**（如微信 / Facebook）：
  1. `AuthService` 加 `signInWithXxx` 方法（参照 `signInWithApple`）
  2. `AuthState` 加同名方法，状态机顺序严格对齐 `signIn`（`isBusy = true` → 调 service → `userId = ...` / `authStatus = LOGGED_IN` → `await getProfileUser()` → 防御性回退 → `notifyListeners()`）
  3. `NamePage` 加对应按钮，loading 状态共享 `_isLoading`
- **接入 Google 登录**：直接在 `name.dart:274` 的 `GestureDetector` 补 `onTap: _isLoading ? null : _handleGoogleSignIn`，并补 `AuthState` / `AuthService` 方法。
- **新增「忘记密码」入口**：在 `name.dart` 密码输入框下方加 `ForgotPasswordPage` 跳转；服务端能力对齐后，在 `AuthService` 加 `requestPasswordReset(email)` 方法。
- **清理遗留代码**：确认无外部 PR / 分支依赖后，删除 `signup.dart` / `email.dart` / `account.dart` 及 `AuthState.signUp`，可顺手把 `auth/signup/` 目录改名 `auth/`。
- **修复 l10n 遗漏**：把 `register.dart` 的硬编码中文文案补成 `app_en.arb` / `app_zh.arb` 新 key（如 `registerValidationErrorEmpty` / `registerValidationUsernameLength` 等），运行 `flutter gen-l10n` 重新生成。

---

_文档最后更新：2026-06-17_
