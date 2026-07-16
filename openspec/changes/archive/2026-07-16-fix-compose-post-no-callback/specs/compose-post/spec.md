## ADDED Requirements

### Requirement: 任何 `push` / `pushReplacement` 实例化 `ComposePost` 的调用方 MUST 显式提供 `onPostSuccess` 与 `onCancel` 回调

The system SHALL `ComposePost` widget 对外接口为 `onPostSuccess` / `onCancel` 两个 `VoidCallback?`,缺省(no-op)行为是有意为之 —— 调用方负责把"发布成功/取消之后用户该去哪里"翻译成 Navigator 动作。任何通过 `Navigator.push` 或 `Navigator.pushReplacement` 把 `ComposePost` 推到路由栈上的入口 MUST 在构造 `ComposePost` 时同时提供 `onPostSuccess` 与 `onCancel`,并至少在 `onPostSuccess` 内执行 `Navigator.of(<this_route_context>).pop()` 或等价的导航动作(`setState(() => tab = 0)` 也算) 。

#### Scenario: 调用方传了回调 — 发布后跳转

- **WHEN** `ComposePost._submit` 成功完成且 `widget.onPostSuccess != null`
- **THEN** 用户的下一帧 SHALL 看到上层路由(HomePage / Feed / Edit 后所在 Post 详情),**不**停留在一个内容已清空的 `ComposePost`

#### Scenario: 调用方传了回调 — 取消 / 返回后跳转

- **WHEN** `ComposePost._handleBack` 触发,且 `widget.onCancel != null`
- **THEN** 用户的下一帧 SHALL 看到上层路由,**不**停留在 `ComposePost`

#### Scenario: 调用方忘记传回调

- **WHEN** `push(ComposePost(...))` 漏传 `onPostSuccess` 或 `onCancel`
- **THEN** `ComposePost._submit` / `_handleBack` 内的回调 no-op,用户发布后**卡在内容已清空的 `ComposePost` 上**,只能手动系统返回手势退出 — 这是禁止行为

#### Scenario: 入口盘点(锁定本 change 涉及的 2 处)

- **WHEN** 审查 `client/lib/` 下 `ComposePost(` 所有调用点
- **THEN** SHALL 满足:
  - `client/lib/pages/home.dart:39` 提供 `onPostSuccess: () => setState(() => tab = 0)`
  - `client/lib/pages/feed/feed.dart:292` 提供 `onPostSuccess: () { ...; Navigator.of(context).pop(); }`
  - `client/lib/widget/feedpost.dart:1249` 提供 `onPostSuccess: () => Navigator.of(routeContext).pop()` 与 `onCancel: () => Navigator.of(routeContext).pop()`(`routeContext` 来自 `MaterialPageRoute.builder` 入参)
  - `client/lib/pages/textNote/text_note_page.dart:173` 同上,改自 `change-text-note-handoff` 的 `pushReplacement` 路径
