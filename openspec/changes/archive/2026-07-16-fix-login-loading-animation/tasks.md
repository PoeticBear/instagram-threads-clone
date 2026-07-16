# Tasks: 修复登录页加载动画 bug

> **范围**：仅 `client/lib/auth/signup/name.dart` 一个文件。
> **设计依据**：[proposal.md](./proposal.md) / [design.md](./design.md)

## 1. 删除按钮内 spinner

- [x] 1.1 删除账号密码登录按钮（`name.dart` L342-348）的 `_isLoading ? CircularProgressIndicator(color: appColors.background) : Text(...)` 三元，恢复为单一 `Text(loginButton)`
- [x] 1.2 删除 Apple 登录按钮（`name.dart` L400-410）的 `_isLoading ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))) : Row(...)` 三元，恢复为单一 `Row(...)`（apple icon + 文字）

## 2. 新增页面级 `_loadingOverlay` helper

- [x] 2.1 在 `_NamePageState` 类内（建议紧跟 `dispose()` 之后）新增私有方法 `_loadingOverlay({required bool loading, required Widget child})`
- [x] 2.2 helper 内部用 `Stack` 包裹 `child`；当 `loading=true` 时叠加 `Positioned.fill` → `IgnorePointer` → `ColoredBox(color: Color(0xCC000000))` → `Center` → `CircularProgressIndicator(color: Colors.white)`

## 3. 用 helper 包裹 `Scaffold.body`

- [x] 3.1 将 `Scaffold.body` 由当前的 `SafeArea(child: SingleChildScrollView(...))` 改为 `_loadingOverlay(loading: _isLoading, child: SafeArea(child: SingleChildScrollView(...)))`
- [x] 3.2 确认 `SafeArea` 仍包在 overlay **内部**（即遮罩覆盖到 SafeArea 之外也无所谓，但保持原结构最稳）

## 4. 加 `PopScope` 拦截返回

- [x] 4.1 将 `build()` 的顶层 `return Scaffold(...)` 改为 `return PopScope(canPop: !_isLoading, child: Scaffold(...))`
- [x] 4.2 确认 `PopScope` 在 widget 树最外层（不要塞在 `Scaffold` 内部）

## 5. 状态字段自检

- [x] 5.1 确认 `bool _isLoading` 字段未删除、未改名
- [x] 5.2 确认三个 handler（`_handleLogin` / `_handleAppleSignIn` / `_handleGoogleSignIn`）的 `setState(() => _isLoading = true/false)` 调用点未变
- [x] 5.3 确认按钮的 `onPressed` / `onTap` 仍保留 `_isLoading ? null : ...` 的禁用逻辑（叠加遮罩的 `IgnorePointer` 是双保险，不要单边依赖）

## 6. 验证

- [x] 6.1 跑 `cd client && flutter analyze` 确认无报错（`name.dart` 单文件 No issues found；全项目 54 个 issues 全部位于其它文件 `withOpacity` deprecation 与本次改动无关）
- [ ] 6.2 真机/模拟器回归 3 条登录路径：账号密码、Apple、Google，每条触发后确认：
  - 页面中央出现 1 个 spinner（不再 2 个）
  - 登录按钮 / Apple 按钮内容仍是原文本/图标，没有变 spinner
  - 加载期间点不动任何按钮、输入框
  - 加载期间右滑返回无响应
  - 登录成功后 spinner 消失、跳转 HomePage
- [ ] 6.3 手动触发一次失败（错误密码）确认 spinner 消失、SnackBar 正常弹出、按钮恢复可点
- [ ] 6.4 手动测试「点击 Apple 登录后立刻右滑返回」确认：要么请求被取消、要么界面保持锁住直到请求完成（不会出现「页面已 pop 但 spinner 仍转」的鬼影）
