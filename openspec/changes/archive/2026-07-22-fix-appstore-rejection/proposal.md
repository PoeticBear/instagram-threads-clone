## Why

iOS 1.0.0 提审被苹果驳回，共 3 个问题。其中「删除账号」是阻断项——App Store Review Guideline 5.1.1(v) 强制要求：App 提供账号注册就必须提供 App 内**彻底删除**账号的入口（退出登录 / 停用都不算）；「Apple 登录按钮」不符合 HIG 样式规范。这两项不解决无法重新提审。本次 change 聚焦**所有可由客户端独立完成**的修复；后端缺失的删除账号接口标注为 TBD，客户端先按假定契约实现。

## What Changes

- **① Apple 登录按钮改用官方组件**
  - 将「通过 Apple 登录」按钮从手搓 `Container` + `GestureDetector` 替换为官方 `SignInWithAppleButton` 组件（项目已依赖 `sign_in_with_apple: ^6.1.4`，此前未使用其官方按钮）。
  - 强制满足 HIG：三种官方样式（black / white / whiteOutlined）、官方 Apple Logo 字形、本地化标题、原生点击反馈、无障碍语义标签。

- **② 新增「删除账号」完整客户端流程**
  - 在设置页（`SettingsPage`）「退出登录」附近新增红色「删除账号」入口。
  - 点击后弹出二次确认对话框（防误触）。
  - 新增 `AuthService.deleteAccount()` 调用假定契约 `DELETE /user/me`（**后端接口 TBD**）。
  - 删除成功后复用现有清理逻辑（`logoutCallback` / `forceSessionExpired`）清空登录态、token、本地缓存并回到登录页。
  - 补齐中英文案。

- **③ 年龄分级后台配置（非代码 follow-up）**
  - 在 App Store Connect 后台「App 信息 → 年龄分级」将「消息和聊天 (Messaging and Chat)」改为「是」。
  - 本仓库不涉及代码改动，转交 ASC 运营；在 `tasks.md` 记为 follow-up，不纳入客户端实现。

## Capabilities

### New Capabilities

- `apple-login-button`: 「通过 Apple 登录」按钮的样式与交互，满足 Apple HIG——使用官方 `SignInWithAppleButton` 组件、官方 Logo 字形、本地化标题、点击反馈与无障碍语义。
- `account-deletion`: 当前登录用户在 App 内彻底删除自己账号的入口、二次确认流程、服务调用与登录态清理。

### Modified Capabilities

（无——以上两项本仓库尚未定义，均为新能力。）

## Impact

- **代码改动**：
  - `client/lib/auth/signup/name.dart`（Apple 按钮，约 419–445 行）
  - `client/lib/common/settings.dart`（新增「删除账号」入口，近「退出登录」482–504 行）
  - `client/lib/services/auth_service.dart`（新增 `deleteAccount()` HTTP 调用）
  - `client/lib/state/auth.state.dart`（新增 `deleteAccount()` 状态方法，复用清理逻辑）
  - 国际化文案源（新增 `deleteAccount` 等 key，中英双语）
- **依赖**：复用已有 `sign_in_with_apple: ^6.1.4`，**无需新增依赖**。
- **API**：**假定新增** `DELETE /user/me`（后端 TBD）。客户端先按此契约实现，后端落地后联调。
- **平台**：仅 iOS（项目策略，不写 Android 适配）。
- **风险**：
  - 删除账号入口在后端接口落地前调用会失败（404 / 网络错误）——客户端需给出明确错误提示，且**重新提审前必须确保后端已上线**并完成真机录屏。
  - 必须实现「彻底删除」，不能退化为停用 / 退出登录，否则复审仍会被拒。
- **非代码 follow-up**：年龄分级配置转交 ASC 运营。
