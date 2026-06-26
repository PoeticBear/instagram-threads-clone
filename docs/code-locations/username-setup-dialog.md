# 设置用户名弹窗（UsernameSetupDialog）— 代码定位

> 本文档汇总 iOS 客户端「设置你的用户名」强制弹窗的全部源代码位置，含弹窗 UI、三个触发入口、状态层判定/写入逻辑与国际化文案。
> 后续若收到「定位 用户名弹窗 / 设置用户名 / username setup / 补填 username」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

> 触发条件：登录/注册成功后拉取用户资料，若服务端 `userName` 为空（典型场景：Apple 登录首次进入、未填 username），即标记 `needsUsernameSetup = true`，在「进入应用」的出口强制弹出此对话框补填。username 是唯一身份标识、设定后不可修改，故弹窗**不可关闭**，校验通过并成功写入服务端才放行。

---

## 1. 弹窗组件（UI 层）

### 1.1 `UsernameSetupDialog`

- **路径**：`client/lib/auth/username_setup_dialog.dart`
- **行数**：178
- **核心组件**：
  - `class UsernameSetupDialog extends StatefulWidget`（`username_setup_dialog.dart:14`）— 接收 `AuthState authState`
  - `class _UsernameSetupDialogState extends State<UsernameSetupDialog>`（`username_setup_dialog.dart:33`）— 持有 `_controller` / `_submitting` / `_error`
- **职责**：不可关闭的强制补填对话框，校验输入并调 `authState.setUsername(...)` 写入服务端。
- **UI 结构**（`AlertDialog`，从上到下）：

  | 区块 | 说明 | 行号 |
  | --- | --- | --- |
  | 标题 | `l10n.usernameSetupTitle`（"设置你的用户名" / "Choose your username"） | `username_setup_dialog.dart:90-97` |
  | 「不可修改」提示 | 锁图标 + `l10n.usernameSetupWarning`，灰底圆角容器 | `username_setup_dialog.dart:103-123` |
  | 用户名输入框 | `autofocus`，`hintText: l10n.username`，`errorText: _error` | `username_setup_dialog.dart:125-143` |
  | 确认按钮 | `l10n.confirmButton`，提交中显示 `CircularProgressIndicator` | `username_setup_dialog.dart:147-172` |

- **关键方法 / 行为**：

  | 方法 / 配置 | 说明 | 行号 |
  | --- | --- | --- |
  | `UsernameSetupDialog.show(context, authState)` | 便捷入口；`barrierDismissible: false`，返回 `Future<bool>`（true=已补填） | `username_setup_dialog.dart:21-27` |
  | `PopScope(canPop: false)` | 拦截系统返回手势 / 返回键，禁止关闭 | `username_setup_dialog.dart:86-87` |
  | `_submit()` | 非空校验 → ≥2 字符 → `authState.setUsername(value)` → 成功 `Navigator.pop(true)` | `username_setup_dialog.dart:44-79` |
  | 错误兜底 | `ApiException` 显示后端原因（如「用户名已被占用」）；其他异常回退 `l10n.usernameSetupFailed` | `username_setup_dialog.dart:66-78` |

---

## 2. 触发入口（调用点）

三个「进入应用」出口在跳 `HomePage` 前统一拦截：

| 入口 | 文件 | 行号 | 说明 |
| --- | --- | --- | --- |
| 启动鉴权路由 | `client/lib/common/splash.dart` | `splash.dart:41-42` | 已登录用户冷启动，资料缺 username 时弹窗 |
| 登录页 `NamePage` | `client/lib/auth/signup/name.dart` | `name.dart:63-64`（账号密码登录） / `name.dart:143-144`（Apple 登录） | 登录成功后判定 |
| 注册页 `RegisterPage` | `client/lib/auth/signup/register.dart` | `register.dart:81-82` | 防御性：注册已填 username，正常不触发 |

统一模式：`if (authState.needsUsernameSetup) { await UsernameSetupDialog.show(context, authState); }` 后再 `Navigator.pushReplacement(HomePage)`。

---

## 3. 状态层（判定 + 写入）

`client/lib/state/auth.state.dart` — `AuthState`：

| 字段 / 方法 | 说明 | 行号 |
| --- | --- | --- |
| `bool needsUsernameSetup` | 是否需补填的标志位 | 定义 `auth.state.dart:47`；登录态重置 `:101` / `:121` |
| 资料拉取后判空 | `needsUsernameSetup = (_userModel?.userName ?? '').isEmpty` | `auth.state.dart:503` |
| `setUsername(String)` | 调 `userService.updateProfile(username:)` → `copyWith` 刷新本地 `_userModel` → 存 SharedPreferences → 置 `needsUsernameSetup = false` | `auth.state.dart:530-544` |

> `setUsername` 失败时抛异常（`ApiException` 携带后端原因），由弹窗 `_submit()` catch 后直接展示给用户。

---

## 4. 服务层（命中的接口）

调用链：弹窗 `_submit()` → `AuthState.setUsername()`（`auth.state.dart:530`）→ `userService.setUsername()`（`auth.state.dart:534`）。

- `UserService.setUsername` — `client/lib/services/user_service.dart`，调用 `_apiClient.put('user/username', body: {'username': ...})`。
- **最终接口**：`PUT /user/username`（operationId `set_username_user_username_put`），请求体 `{ "username": "..." }`，需登录态鉴权。
- **接口语义**：「设置用户名」——仅未设置过 username 的用户可调用，服务端写入时同步显示名称；失败抛 `ApiException`（携带「用户名已被占用」等后端原因）。
- **服务端契约**：本地 `openapi_docs/`（最新快照 2026-06-16）尚未收录此接口；定义见服务端最新 OpenAPI 导出。

> 历史背景：此链路原先误用通用「更新资料」接口 `PUT /user/profile`（`UserService.updateProfile`，现仍被个人资料编辑页用于改 display_name / bio 等），后改为语义更贴合的专用「设置用户名」接口 `PUT /user/username`。

---

## 5. 国际化文案

`client/lib/l10n/app_zh.arb` / `app_en.arb`（key 相同，行号对齐在 `:682-686`）：

| Key | 中文 | 英文 |
| --- | --- | --- |
| `usernameSetupTitle` | 设置你的用户名 | Choose your username |
| `usernameSetupWarning` | 用户名一旦设定将无法修改，请谨慎填写。 | Your username cannot be changed once it is set. Please choose carefully. |
| `usernameSetupEmptyError` | 请输入用户名 | Please enter a username |
| `usernameSetupTooShortError` | 用户名至少需要 2 个字符 | Username must be at least 2 characters |
| `usernameSetupFailed` | 设置用户名失败，请重试 | Failed to set username, please try again |

生成代码：`client/lib/l10n/generated/app_localizations.dart:3101-3129`（抽象 getter）/ `app_localizations_zh.dart:1580-1592` / `app_localizations_en.dart:1607-1621`。

---

*最后更新：2026-06-26*
