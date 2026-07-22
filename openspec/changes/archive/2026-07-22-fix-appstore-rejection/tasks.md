# Implementation Tasks — fix-appstore-rejection

> 实现顺序按依赖排列。① Apple 按钮与②删除账号相互独立，可并行。
> 后端 `DELETE /user/me` 为 **TBD**，客户端先按假定契约实现；提审前置条件见 §5。
>
> **进度：19/25 完成（§1–§6.6 客户端代码已完成）。**
> 未完成 6 项均为**非代码**：设备回归(1.4 / 5.2 / 6.7 设备部分)、后端联调(5.3)、真机录屏(5.4)、ASC 运营转交(5.5)。

## 1. Apple 登录按钮（capability: apple-login-button）

- [x] 1.1 阅读 `client/lib/auth/signup/name.dart` 419–445 行确认当前手搓按钮、`_handleAppleSignIn`（106–180）与 `_loadingOverlay`（38–55）现状
- [x] 1.2 将手搓 `Container` + `GestureDetector` 替换为官方 `SignInWithAppleButton`（`style: SignInWithAppleButtonStyle.black`，高度与登录主按钮一致），`onPressed` 接到现有 `_handleAppleSignIn`
- [x] 1.3 确认加载期间 `_loadingOverlay` 仍覆盖按钮、拦截重复点击（保留 `_isLoading` 逻辑）
- [ ] 1.4 iOS 真机/模拟器回归按钮渲染与点击（`flutter analyze` 已在 5.1 通过；设备 UI 验证待人工）

## 2. 删除账号 — service & state（capability: account-deletion）

- [x] 2.1 在 `client/lib/services/auth_service.dart` 新增 `deleteAccount()`：发 `DELETE /user/me`（携带当前 access token），返回成功/抛错；**不**调用 `logout()`
- [x] 2.2 在 `client/lib/state/auth.state.dart` 抽取内部 `_clearLocalSessionAndExit()`：禁 WS + 清内存态 + `authService.clearLocalSession()` + 清 prefs + `notifyListeners()`（供登出与删除共用，避免逻辑漂移）
- [x] 2.3 `logoutCallback()` 改为复用 `_clearLocalSessionAndExit()`（仍调 `authService.logout()` 发 `/auth/logout`，最终登录态一致）
- [x] 2.4 新增 `AuthState.deleteAccount()`：调 `authService.deleteAccount()`；成功 → `_clearLocalSessionAndExit()`；失败 → 抛出，**不**清登录态

## 3. 国际化文案

- [x] 3.1 在文案源（`.arb`）新增 key：`deleteAccount`、`deleteAccountWarning`、`deleteAccountConfirm`、`deleteAccountFailed`（`cancel` 复用既有 key）
- [x] 3.2 补齐中文 + 英文译文；`flutter gen-l10n` 重新生成；确认无硬编码字符串

## 4. 删除账号 — UI 入口 & 确认弹窗

- [x] 4.1 在 `client/lib/common/settings.dart`「退出登录」（482–504）附近新增红色「删除账号」入口
- [x] 4.2 点击入口弹出确认对话框（破坏性「删除」+「取消」，文案取自 §3）
- [x] 4.3 确认后调 `AuthState.deleteAccount()`：展示加载态；成功自动回登录页；失败展示 `deleteAccountFailed` 并保留登录态可重试

## 5. 验证 & 提审前置

- [x] 5.1 `flutter analyze` 全绿（改动文件零问题；全量 54 条均为既有问题，与本次改动无关）
- [ ] 5.2 iOS 真机回归：Apple 按钮样式/点击/VoiceOver；删除账号入口→确认→（后端 TBD 时）失败提示正确、登录态不丢（待人工）
- [ ] 5.3 **[提审前置·TBD]** 后端 `DELETE /user/me` 落地后联调成功路径（待后端）
- [ ] 5.4 **[提审前置]** 真机录屏：新注册 → 导航至删除账号入口 → 完成注销全流程，交付提审同事附入 App Store Connect 审核备注（待人工）
- [ ] 5.5 **[非代码 follow-up]** 转 ASC 运营：后台「App 信息 → 年龄分级 → 消息和聊天」改为「是」（待运营）

## 6. 注销页升级 — 独立页流程（取代 §4 的弹窗）

> 依据 `feature-account-cancellation.md`：把注销交互从「弹窗」升级为「独立注销页 + 须知 + 同意勾选 + 二次确认 + 全屏 loading」。
> 底层 `AuthState.deleteAccount()` / `_clearLocalSessionAndExit()` 状态机不变（§2），只升级 UI 层。

- [x] 6.1 新建 `client/lib/common/settings/account_cancellation_page.dart`：警示图标 + 「账号注销须知」标题 + 5 条须知 + 「我已阅读并同意」勾选框 + 「确认注销」/「取消」按钮
- [x] 6.2 注销须知文案（按本项目改写，无内购）：①个人资料永久删除无法恢复 ②帖子/回复/点赞/转发清空 ③关注/粉丝/收藏/社区关系解除 ④第三方登录(Apple/Google)解绑 ⑤操作不可撤销
- [x] 6.3 「确认注销」按钮在未勾选同意时禁用；勾选后点击弹出二次确认 alert（取消 / 确认注销）
- [x] 6.4 最终确认后调 `AuthState.deleteAccount()`：切换全屏「正在处理注销…」loading；成功自动回登录页；失败展示 `deleteAccountFailed`、保留登录态可重试
- [x] 6.5 把「设置」页注销入口 onTap 从 `_showDeleteAccountDialog` 改为 `push(AccountCancellationPage)`，移除旧的 `_showDeleteAccountDialog` 方法
- [x] 6.6 l10n：新增注销页标题 / 5 条须知 / 同意文案 / 「确认注销」/ loading 文案等 key（zh+en），`flutter gen-l10n`
- [ ] 6.7 `flutter analyze` 全绿（已过）；iOS 设备回归注销全流程（勾选门禁 / 二次确认 / 成功回登录页 / 失败保留登录态）待人工
