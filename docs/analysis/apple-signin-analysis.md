# Apple 登录功能分析

> 范围：客户端 `sign_in_with_apple: ^6.1.4` 集成现状 + 待补全项
> 适用版本：当前 `main` 分支
> 分析日期：2026-06-11

## 一、功能定位

Apple 登录是账号密码登录的备选入口，仅在 `NamePage`（`client/lib/auth/signup/name.dart:69`）的 `_handleAppleSignIn` 中实现。用户点击黑色"Continue with Apple"按钮触发。

## 二、当前实现状态：客户端 Stub（半成品）

### 2.1 已完成 ✅

| 项目 | 位置 | 说明 |
|---|---|---|
| iOS Capability | `client/ios/Runner/Runner.entitlements:5-8` | `com.apple.developer.applesignin = Default` |
| 插件依赖 | `client/pubspec.yaml:40` | `sign_in_with_apple: ^6.1.4` |
| 插件原生注册 | `client/macos/Flutter/GeneratedPluginRegistrant.swift:12` | macOS 端也已注册 |
| UI 渲染 | `client/lib/auth/signup/name.dart:211-235` | 黑色按钮 + Apple 图标 + 国际化文案 `loginWithApple` |
| i18n 文案 | `client/lib/l10n/app_zh.arb:43-46` / `client/lib/l10n/app_en.arb:43-46` | 三条：按钮标题 / 成功 / 失败 |
| 错误处理 | `client/lib/auth/signup/name.dart:92-110` | 分别捕获 `SignInWithAppleAuthorizationException` 与通用异常 |

### 2.2 未完成 ❌

#### 1. 没有后端调用（`client/lib/auth/signup/name.dart:81-91`）

```dart
// 当前阶段：仅做客户端获取，不与后端校验，提示用户后续接入。
// TODO: 后端就绪后，把 credential 交给 AuthState 调 /user/social-signin。
debugPrint('[Apple SignIn] userIdentifier=${credential.userIdentifier} '
    'email=${credential.email} '
    'authorizationCode=${credential.authorizationCode} '
    'hasToken=${credential.identityToken != null}');
```

拿到凭据后**只打印日志**，不调任何 API。

#### 2. 后端无对应接口

- `openapi_docs/user.json:286` 只有 `POST /user/signin`，没有 `/user/social-signin` 或类似路由
- `client/lib/services/auth_service.dart` 的方法列表（`signIn` / `register` / `registerDeviceToken` / `deregisterDeviceToken`）也**没有 Apple / 第三方登录方法**

#### 3. 没有写入 AuthState

- 没有 `AuthState.signInWithApple(credential)` 方法
- 不会修改 `authStatus` / `userId` / `_userModel`
- 不会跳转到 `HomePage`

#### 4. 成功提示具有误导性

- `appleSignInSuccess` 文案：
  - 中文：`已获取 Apple 凭据，等待后端对接`
  - 英文：`Apple credential obtained. Backend integration pending.`
- 实际只是"拿到了凭据"，并未真正登录成功

## 三、潜在问题与改进点

### 3.1 安全相关

- **无 nonce 生成**：未传入 `rawNonce` / `nonce`，无法防止重放攻击（Apple 官方推荐做法）
- **无 state 参数**：没有 CSRF 防护
- **敏感数据落入 `debugPrint`**：`authorizationCode` / `identityToken` 出现在日志里属于安全隐患；Release 构建中 `debugPrint` 不输出，但开发构建存在泄露风险

### 3.2 架构相关

- **凭据获取写在 Page 里**：`_handleAppleSignIn` 直接耦合在 `NamePage`，缺少 `AppleAuthService` / `SocialAuthService` 这类抽象层。一旦未来要接 Google、Facebook，无法复用
- **新用户引导缺失**：Apple 首次登录通常是"匿名 userIdentifier"（真实 email 只在**首次授权**时返回），后端若按 `userIdentifier` 自动建账号，本地没有"补充 username / displayName"的引导页
- **未复用 AuthState 的 `scaffoldKey` snackbar 机制**：账号密码走 `authState.signIn` → `Utility.customSnackBar(scaffoldKey, ...)`，Apple 走 `ScaffoldMessenger`，错误展示不一致

### 3.3 UX 相关

- 失败 snackbar 拼接 `'${appleSignInFailed}: $e'` 会把异常对象 toString 出来，对用户不友好
- Apple 登录中**没有 loading 态**（账号密码有 `_isLoading` 圈）
- 按钮上 `GestureDetector` 没有 `HitTestBehavior.opaque`，Apple 按钮圆形边角边缘可能漏点击

## 四、对接后端时需要做的事（清单）

1. **后端**：新增 `POST /user/social-signin`，body 含 `identityToken` / `authorizationCode` / `userIdentifier` / `email` / `fullName` / `provider="apple"`
2. **客户端安全**：生成 `rawNonce`（32 字节随机）并 SHA-256 后传入 `SignInWithApple.getAppleIDCredential(nonce: ...)`
3. **AuthState**：新增 `AuthState.signInWithApple(AppleIDCredential)`，调用 `AuthService.socialSignIn`（待补），写入 `userId` / `_userModel` / `authStatus = LOGGED_IN`
4. **UI 状态机**：首次 Apple 登录需要走 `RegisterPage` 补充 username / displayName
5. **重构**：把 `_handleAppleSignIn` 从 Page 抽到 `services/social_auth_service.dart`

## 五、相关文件索引

| 类别 | 文件 | 关键行 |
|---|---|---|
| 触发点 | `client/lib/auth/signup/name.dart` | 69-111 |
| 插件依赖 | `client/pubspec.yaml` | 40 |
| 能力声明 | `client/ios/Runner/Runner.entitlements` | 5-8 |
| 国际化（中文） | `client/lib/l10n/app_zh.arb` | 43-46 |
| 国际化（英文） | `client/lib/l10n/app_en.arb` | 43-46 |
| AuthState（缺方法） | `client/lib/state/auth.state.dart` | 71-103 |
| AuthService（缺方法） | `client/lib/services/auth_service.dart` | 33-95 |
| 后端 OpenAPI | `openapi_docs/user.json` | 286 |

## 六、结论

Apple 登录当前是**仅完成客户端凭据获取的骨架**，距离真正可用还差：

1. 后端 social-signin 路由
2. 客户端 `AuthState` / `AuthService` 对应方法
3. nonce / state 安全加固
4. 首次登录的账号补全流程
5. 凭据获取逻辑从 Page 抽到 Service 层

短期可先打通"已有账号走 Apple 登录"，长期建议把"第三方登录"抽成统一的 `SocialAuthService`，便于 Google、Facebook 等扩展。
