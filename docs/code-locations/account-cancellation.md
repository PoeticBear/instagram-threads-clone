# 账号注销功能代码定位清单

> 最后更新：2026-07-22
> 范围：【设置】页 →「注销账号」入口 → 独立注销页 → POST `/user/deactivate` → 清本地登录态。

## 1. 模块总览

注销功能由**独立注销页**承载，完整流程：注销须知（5 条）→ 勾选「我已阅读并同意」门禁 → 点「确认注销」→ 二次确认 alert → 全屏 loading → `AuthState.deleteAccount()`（`POST /user/deactivate`）→ 成功后根路由自动切回登录页 / 失败提示并保留登录态可重试。

**背景**：为满足 App Store 审核指南 **5.1.1(v)**（提供账号创建即须提供真实账号删除）。这是**彻底删除账号**，与「退出登录」（会话级，`/auth/logout`，吞错）严格区分。

> ⚠️ 易混淆项：仓库根目录的 `feature-account-cancellation.md` 是**另一个 iOS 项目（拜老爷）**的参考文档（Swift + SwiftUI），**不是本项目代码**，仅供交互设计参考。本项目实际实现为下文 Flutter 代码。

## 2. 入口点

`client/lib/common/settings.dart:366-377` — 设置页「注销账号」菜单项，`_buildMenuRow` + `CupertinoPageRoute` push 到 `AccountCancellationPage`。

## 3. 涉及文件清单

| 层级 | 文件 | 行号 | 作用 |
|------|------|------|------|
| 页面 | `lib/common/settings/account_cancellation_page.dart` | 全文 | 注销页 UI + 交互（须知 / 勾选 / 二次确认 / loading） |
| 入口 | `lib/common/settings.dart` | 366-377 | 设置页菜单项，push 注销页 |
| 状态 | `lib/state/auth.state.dart` | 99-105 | `deleteAccount()`：调 service + 本地清理 |
| 状态（共用） | `lib/state/auth.state.dart` | 111-124 | `_clearLocalSessionAndExit()`：登出 / 注销共用的本地清理 |
| 服务 | `lib/services/auth_service.dart` | 306-318 | `deleteAccount()`：`POST user/deactivate`，失败抛 `ApiException` |
| 文案 | `lib/l10n/app_en.arb` / `app_zh.arb` | 103-116 | 注销相关 14 个 i18n key |

## 4. 注销页详解（`AccountCancellationPage`）

`StatefulWidget`，3 个核心 `@State` 字段：

| 字段 | 行号 | 作用 |
|------|------|------|
| `_isAgreed` | 21 | 勾选门禁：`false` 时「确认注销」按钮禁用（`onPressed: _isAgreed ? _showConfirmAlert : null`，197 行） |
| `_isCancelling` | 22 | 注销中：`true` 时整页切 loading 视图，阻止重复操作（91 行 `body` 三元） |

关键方法：

- **`_performCancellation()`（27-40 行）** — 最终执行：`setState` 切 loading → `authState.deleteAccount()` → 成功无需导航（根路由自动切登录页）→ 失败关 loading、Snack 提示 `deleteAccountFailed`、保留登录态可重试。
- **`_showConfirmAlert()`（43-66 行）** — 二次确认 `AlertDialog`（`cancellationConfirm` / `cancellationConfirmMessage`），红色 destructive 按钮。
- **`_buildContent()`（95-230 行）** — 须知列表（橙色警示三角 + 5 条圆点）、勾选框、「确认注销」红按钮、「取消」返回。
- **`_buildLoading()`（232-248 行）** — `CupertinoActivityIndicator` + `cancellationLoading` 文案。

## 5. API 服务层（`AuthService.deleteAccount`）

`lib/services/auth_service.dart:306-318`

```dart
Future<void> deleteAccount() async {
  try {
    await _apiClient.post('user/deactivate', body: {});  // POST /user/deactivate
  } on ApiException {
    rethrow;                              // 不吞错 → 上层可提示 + 重试
  } catch (e) {
    throw ApiException(message: '删除账号失败: $e');
  }
}
```

**与 `logout()` 的关键区别**：`logout` 走 `/auth/logout` 且**吞错**（失败仍清 token 保证登出）；`deleteAccount` 走 `/user/deactivate` 且**抛错**（账号没注销成绝不能把用户踢到登录页）。

## 6. 状态管理（`AuthState.deleteAccount`）

`lib/state/auth.state.dart:102-105`

> **已对接真实接口**（`POST /user/deactivate`）。先调服务端注销，成功才清本地登录态；失败抛出，登录态保留可重试。

```dart
Future<void> deleteAccount() async {
  await authService.deleteAccount(); // POST /user/deactivate，失败抛 ApiException → 不清登录态
  await _clearLocalSessionAndExit(); // 成功才清本地登录态（根路由自动切回登录页）
}
```

**`_clearLocalSessionAndExit()`（111-124 行）** — 登出 / 注销共用的本地清理，**不发任何服务端请求**：

1. `WebSocketService.disableForAuth()` — 防 token 失效后被重连机制反复握手（防御性双保险，根监听已会 disconnect）
2. `authStatus = NOT_LOGGED_IN` + `userId=''` + `_userModel=null` + `needsUsernameSetup=false` — 清内存态
3. `authService.clearLocalSession()` — 清本地凭证
4. `notifyListeners()` — 触发根路由 `onAuthChanged` 切回登录页
5. `clearPreferenceValues()` — 清 prefs

> 状态驱动导航：根视图根据 `authStatus` 切换登录页 / 主界面，注销**无需手动** `Navigator.pop`，置 `NOT_LOGGED_IN` 即自动回退。

## 7. 关键交互数据流

```
设置页 settings.dart:367
   │  _buildMenuRow「注销账号」→ push CupertinoPageRoute
   ▼
AccountCancellationPage
   │  1. 须知 5 条 (cancellationNotice1~5)
   │  2. 勾选「我已阅读并同意」→ _isAgreed = true（门禁）
   │  3. 点「确认注销」（未勾选时禁用）
   │  4. 二次确认 AlertDialog
   ▼
_performCancellation()                  account_cancellation_page.dart:27
   │  setState(_isCancelling=true) → 整页 loading
   ▼
AuthState.deleteAccount()               auth.state.dart:102
   │
   ├─ AuthService.deleteAccount()       auth_service.dart:310
   │     └─ POST /user/deactivate  (失败抛 ApiException → 上层提示 + 保留登录态)
   │
   └─ _clearLocalSessionAndExit()       auth.state.dart:111
        ├─ WS disableForAuth
        ├─ authStatus = NOT_LOGGED_IN
        ├─ clearLocalSession + 清 prefs
        └─ notifyListeners → 根路由自动切回登录页
```

## 8. 国际化文案（`app_en.arb` / `app_zh.arb`，行 103-116）

| key | zh |
|-----|----|
| `deleteAccount` | 注销账号 |
| `deleteAccountWarning` | 将永久删除你的账号及所有相关数据，此操作无法撤销。 |
| `deleteAccountFailed` | 删除账号失败，请稍后重试。 |
| `accountCancellationNoticeTitle` | 账号注销须知 |
| `cancellationNotice1~5` | 个人资料 / 帖子回复点赞转发 / 关注粉丝收藏社区 / 第三方登录解绑 / 不可撤销 |
| `cancellationAgree` | 我已阅读并同意上述条款 |
| `cancellationConfirm` | 确认注销 |
| `cancellationConfirmMessage` | 确认注销后将返回登录页面。 |
| `cancellationLoading` | 正在处理注销… |

## 9. 对接状态

- **✅ 已对接 `POST /user/deactivate`**：服务端接口已就绪，客户端取消模拟注释、恢复「失败抛错、不清登录态」语义。
  - `auth_service.dart:310`：`_apiClient.post('user/deactivate', body: {})`
  - `auth.state.dart:102`：先 `authService.deleteAccount()` 再 `_clearLocalSessionAndExit()`
- **⚠️ 待冒烟验证**：接口契约（请求体 / 响应 / 鉴权）尚未写入 `openapi_docs/user.json`，当前按「空 body、`auth: true`、`OKResponse`」假设对接。首次真机走一遍注销流程确认无 4xx；若服务端实际需要参数（如密码 / 验证码），按报错补 `body` 字段。
- 注销页与「退出登录」入口在设置页**区分展示**：登出走 `logoutCallback()`（`/auth/logout`），注销走独立页。
