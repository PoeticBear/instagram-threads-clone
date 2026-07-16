## Purpose

`compose-post` capability 覆盖 `ComposePost` widget 的对外契约 — 即普通图文 / 视频 / GIF / 投票 / 草稿 / 位置 / 定时 / 回复权限等所有发帖模式通用的接口约束。本文件聚焦**widget 签名层面的契约**,业务表现(Camera / 草稿选择 / 媒体上传 / 排版等)由各个调用方与子文件实现,不重复声明。

> 本文件由两条已归档 change 的 delta 合并生成:
> - `change-text-note-handoff` · `compose-post` delta — 提供媒体入参 (`initialMediaDrafts`)
> - `fix-compose-post-no-callback` · `compose-post` delta — 强制调用方补 nav 回调

---

## ADDED Requirements

### Requirement: `ComposePost` 支持通过 `initialMediaDrafts` 入参预填媒体列表

The system SHALL `ComposePost` widget 签名增加可选入参 `final List<MediaDraftItem>? initialMediaDrafts`,在 `initState` 中,**当且仅当 `widget.editingPostId == null` 且 `widget.initialMediaDrafts` 非空**时,直接赋值 `_mediaDrafts = [...widget.initialMediaDrafts!]`;在编辑模式下,`initialMediaDrafts` SHALL 被忽略,以原帖自有 media 恢复链路为准。

#### Scenario: 从外部交接进来,媒体预填
- **WHEN** 通过 `Navigator.push` / `pushReplacement` 进入 `ComposePost(initialContent: text, initialMediaDrafts: [draft])`
- **THEN** ComposePost 第一帧渲染时,底部媒体区域 SHALL 显示用户的卡片 PNG 缩略图作为首个 MediaDraftItem

#### Scenario: 编辑模式下不响应 initialMediaDrafts
- **WHEN** 通过 `Navigator.push(ComposePost(editingPostId: 'xxx', initialMediaDrafts: [draft]))` 调用
- **THEN** `_mediaDrafts` SHALL 不被 `initialMediaDrafts` 覆盖,继续走原有 `_onDraftSelected` 恢复逻辑

#### Scenario: 普通调用不受影响
- **WHEN** `ComposePost()` 不传 `initialMediaDrafts`
- **THEN** 行为与本需求之前完全一致,`_mediaDrafts` 初始为空

### Requirement: 任何 `push` / `pushReplacement` 实例化 `ComposePost` 的调用方 MUST 显式提供 `onPostSuccess` 与 `onCancel` 回调

The system SHALL `ComposePost` widget 对外接口为 `onPostSuccess` / `onCancel` 两个 `VoidCallback?`,缺省(no-op)行为是有意为之 —— 调用方负责把"发布成功/取消之后用户该去哪里"翻译成 Navigator 动作。任何通过 `Navigator.push` 或 `Navigator.pushReplacement` 把 `ComposePost` 推到路由栈上的入口 MUST 在构造 `ComposePost` 时同时提供 `onPostSuccess` 与 `onCancel`,并至少在 `onPostSuccess` 内执行 `Navigator.of(<this_route_context>).pop()` 或等价的导航动作(`setState(() => tab = 0)` 也算)。

#### Scenario: 调用方传了回调 — 发布后跳转
- **WHEN** `ComposePost._submit` 成功完成且 `widget.onPostSuccess != null`
- **THEN** 用户的下一帧 SHALL 看到上层路由(HomePage / Feed / Edit 后所在 Post 详情),**不**停留在一个内容已清空的 `ComposePost`

#### Scenario: 调用方传了回调 — 取消 / 返回后跳转
- **WHEN** `ComposePost._handleBack` 触发,且 `widget.onCancel != null`
- **THEN** 用户的下一帧 SHALL 看到上层路由,**不**停留在 `ComposePost`

#### Scenario: 调用方忘记传回调
- **WHEN** `push(ComposePost(...))` 漏传 `onPostSuccess` 或 `onCancel`
- **THEN** `ComposePost._submit` / `_handleBack` 内的回调 no-op,用户发布后**卡在内容已清空的 `ComposePost` 上**,只能手动系统返回手势退出 — 这是禁止行为

#### Scenario: 入口盘点契约
- **WHEN** 审查 `client/lib/` 下 `ComposePost(` 所有调用点
- **THEN** SHALL 满足:
  - `client/lib/pages/home.dart:39` 提供 `onPostSuccess: () => setState(() => tab = 0)`
  - `client/lib/pages/feed/feed.dart:292` 提供 `onPostSuccess: () { ...; Navigator.of(context).pop(); }`
  - `client/lib/widget/feedpost.dart:1249` 提供 `onPostSuccess: () => Navigator.of(routeContext).pop()` 与 `onCancel: () => Navigator.of(routeContext).pop()`(`routeContext` 来自 `MaterialPageRoute.builder` 入参)
  - `client/lib/pages/textNote/text_note_page.dart:173` 同上,`pushReplacement` 路径
