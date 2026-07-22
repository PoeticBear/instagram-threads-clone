# 账号注销功能代码定位清单

> 最后更新：2026-07-22
> 范围：【设置】页 →「注销账号」入口 → 独立注销页 → DELETE `/user/me` → 清本地登录态。

## 1. 模块总览

注销功能由**独立注销页**承载，完整流程：注销须知（5 条）→ 勾选「我已阅读并同意」门禁 → 点「确认注销」→ 二次确认 alert → 全屏 loading → `AuthState.deleteAccount()`（`DELETE /user/me`）→ 成功后根路由自动切回登录页 / 失败提示并保留登录态可重试。

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
| 服务 | `lib/services/auth_service.dart` | 306-318 | `deleteAccount()`：`DELETE user/me`，失败抛 `ApiException` |
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
    await _apiClient.delete('user/me');   // DELETE /user/me
  } on ApiException {
    rethrow;                              // 不吞错 → 上层可提示 + 重试
  } catch (e) {
    throw ApiException(message: '删除账号失败: $e');
  }
}
```

**与 `logout()` 的关键区别**：`logout` 走 `/auth/logout` 且**吞错**（失败仍清 token 保证登出）；`deleteAccount` 走 `/user/me` 且**抛错**（账号没删成绝不能把用户踢到登录页）。

## 6. 状态管理（`AuthState.deleteAccount`）

`lib/state/auth.state.dart:102-105`

> **当前状态：客户端模拟注销**。服务端 `DELETE /user/me` 尚未实现，`deleteAccount()` 已注释掉服务端调用，仅做本地登录态清理（等价登出）。效果：清 token + 回登录页，但**后端数据仍在**。

```dart
Future<void> deleteAccount() async {
  // await authService.deleteAccount();  // ⚠️ 临时注释：后端无此端点，模拟注销先跳过
  await _clearLocalSessionAndExit();     // 仅清本地登录态（等价登出）
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
   │     └─ DELETE /user/me  (失败抛 ApiException → 上层提示 + 保留登录态)
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

## 9. 待办 / 已知缺口

- **🔴 当前为客户端模拟注销**：`DELETE /user/me` 后端尚未实现（openapi 全量无此端点，`/user/me` 仅支持 GET），调用会 405/404。`AuthState.deleteAccount()` 已注释掉服务端调用、仅做本地清理（等价登出）。**后端接口 ready 后**：取消 `auth.state.dart` 内注释、对接 `auth_service.dart:310` 的 `deleteAccount()`，并恢复「失败抛错、不清登录态」语义。
- **App Store 合规风险**：5.1.1(v) 要求真实账号删除。当前模拟仅清本地，后端数据仍在——若用户用同账号重新登录会发现账号还在。**上架前必须落地真实删除接口**。
- 注销页与「退出登录」入口在设置页**区分展示**：登出走 `logoutCallback()`（`/auth/logout`），注销走独立页。
