## Why

登录页 `NamePage`（`client/lib/auth/signup/name.dart`）在请求登录时，账号密码按钮和 Apple 按钮会**同时**出现转圈加载动画——视觉上像是「两个动作同时在进行」，与实际只触发了一个登录请求的语义不符，给用户造成困惑。该问题根因是页面级的 `_isLoading` 标志被 4 个登录入口共享，且两个按钮的子控件直接按 `_isLoading ? CircularProgressIndicator : 原内容` 渲染。修复方式是把「加载中」的视觉从按钮内迁出到页面级统一遮罩，按钮在加载期间只保持禁用、不切换内容。

## What Changes

- **删除** `name.dart` 中两个按钮内的 spinner 三元：
  - 账号密码登录按钮（L342-348）：`_isLoading ? CircularProgressIndicator(...) : Text(...)` → 仅保留 `Text(...)`
  - Apple 登录按钮（L400-410）：`_isLoading ? CircularProgressIndicator(...) : Row(...)` → 仅保留 `Row(...)`
- **新增** 页面级私有 helper `_loadingOverlay({required bool loading, required Widget child})`：
  - `Stack` 包裹 `child`；当 `loading=true` 时叠加 `Positioned.fill` 覆盖层，含 `IgnorePointer`（屏蔽所有点击）+ 半透明背景（`appColors.background.withOpacity(0.6)`）+ 居中 `CircularProgressIndicator(color: appColors.textPrimary)`
- **修改** `Scaffold.body`：用 `_loadingOverlay(loading: _isLoading, child: SafeArea(...))` 包裹原内容
- **修改** 顶层 `return`：增加 `PopScope(canPop: !_isLoading, child: Scaffold(...))` 拦截转圈期间的系统返回手势，避免状态泄漏
- **保持不变**：局部 `_isLoading: bool` 字段（不动 `AuthState.isBusy`，避免被 `getProfileUser` 等非登录流程污染而误触发遮罩）

## Capabilities

### New Capabilities

无。本变更不引入新能力，只是修改登录页的视觉反馈行为，不属于产品级新功能。

### Modified Capabilities

无。`openspec/specs/` 下未发现 `login` 相关 spec（仅 `api-path-docs`），且本变更为 UI 行为修正，不涉及可被独立 spec 描述的需求契约变更。

## Impact

- **受影响文件**：`client/lib/auth/signup/name.dart`（仅此 1 个文件）
- **受影响接口**：无
- **受影响依赖**：无（用到的 `Stack` / `Positioned` / `IgnorePointer` / `PopScope` / `CircularProgressIndicator` / `ColoredBox` 均为 Flutter SDK 内置）
- **不在范围**：
  - `client/lib/auth/signup/phone.dart`：通过拆分 `_isLoading` 与 `_sendingCode` 两个 flag 已规避同样问题，无 bug
  - `client/lib/auth/signup/register.dart`：仅 1 个登录按钮，无 bug
  - `docs/code-locations/login.md`：与本任务无关
  - 国际化文案：遮罩不展示文字，无需新增 l10n key
- **回归测试范围**：3 条登录路径（账号密码 / Apple / Google）+ 1 条「加载中按系统返回」交互
