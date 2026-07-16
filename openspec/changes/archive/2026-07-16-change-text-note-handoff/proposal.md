## Why

`add-text-note-feature` v1 已落地「写文字」功能,流程是「写卡片 → 立即发帖(关闭页面 + pop + Feed 出现新帖)」。实操中发现这段 UX 与 Threads/小红书的真实使用习惯不一致:

- 用户经常想在卡片基础上**再加一两张图**(图文混排),或者**补一段更长的正文**(目前的 hard cap 500 字 / 卡片预览最佳 80 字),或者**加投票 / 位置 / 定时**。当前流程下这些都得放弃文字卡片重新走普通图文,卡片就废了。
- 用户进入「写文字」页时,**心智上是「先排卡片,后写正文」**,不是「这就是我的全部内容」。当前一次性把卡片+文字打包发出去的形态,跳过了用户对**最终正文**的二次审视环节。
- **服务端 / Provider / 上传链路没有任何必要变化**,纯客户端 UX 调整,改动面小,验证成本低。

把流程改成「**写文字页 → 确认 → 交接给 `ComposePost` → 在 `ComposePost` 二次编辑后最终发布**」,是更符合用户实际工作流的形态。

## What Changes

- **改写 `pages/textNote/text_note_page.dart`** 右上角"发布"为"确认",AppBar 按钮文案从 `l10n.post` 改为新增的 `l10n.textCardConfirm`。
- **改写 `_publish()` 为 `_confirm()`**:取消卡内直接 `PostState.createPost` 的链路,**改为截图 + 写临时文件 + 构造 `MediaDraftItem` + 用 `Navigator.pushReplacement` 跳转到 `ComposePost(initialContent: text, initialMediaDrafts: [draft])`**。文字作为正文,卡片截图作为媒体项,接管 ComposePost 的完整编辑能力(图 / 文 / 投票 / 位置 / 定时)。
- **新增 `ComposePost.initialMediaDrafts` 可选入参**:签名增加 `final List<MediaDraftItem>? initialMediaDrafts;`,在 `initState` 中预填 `_mediaDrafts`。
- **放行空文字**:按钮可用条件从「必须有内容」放宽为「未在截图中」,允许用户只发一张纯渐变卡片(图无文字)。
- **新增 i18n key** `textCardConfirm`(zh: "确认" / en: "Confirm");`textCardPublishSuccess` 在 TextNotePage 不再使用,可下线;`textCardPublishFailed` 改名为 `textCardConfirmFailed`(语义更准)。
- **不修改**:`PostState` / `PostService` / `UploadService` / 服务端契约 — 接管的 `ComposePost` 完全沿用现有上传+发布链路。
- **不修改**:Popup 菜单 / Feed 页 FAB / 编辑帖子入口 行为不变(它们的"普通图文"路径与本次改动无关)。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `text-note`:写文字页面的发布语义从"页面内闭环发帖"改为"确认后交接给 `ComposePost`,由用户在普通图文页继续编辑和最终发布"。规格重写 — 见 `specs/text-note/spec.md`。

## Impact

**修改文件**

- 修改:`client/lib/pages/textNote/text_note_page.dart`(核心改动:`_publish` → `_confirm`;AppBar 文案;删 `Provider/AuthState/PostState/PostModel/UserModel/UploadService` 相关代码与 import;新增 `pages/composePost/post.dart` import)
- 修改:`client/lib/pages/composePost/post.dart`(新增 `initialMediaDrafts` 可选参数 + `initState` 预填)
- 修改:`client/lib/l10n/app_zh.arb`、`app_en.arb`、`generated/app_localizations*.dart`(新增 `textCardConfirm`;下线 `textCardPublishSuccess`;`textCardPublishFailed` → `textCardConfirmFailed`)
- 修改:`docs/code-locations/write-text.md`(第 1.1、2.1、6 节随之重写)
- 修改:`docs/code-locations/publish-post.md`(§2.4 节"写文字 Popup 入口"描述更新)

**新增文件**

- 无(typedef `TextNoteHandoff` 内联在 `text_note_page.dart` 顶部,无需单独文件)

**依赖包**(`pubspec.yaml`)

- 无变化(`screenshot` / `path_provider` 继续复用)

**服务端**

- 零变化。

**平台**

- 沿用项目规范,只维护 iOS,无 Android 适配代码。

**状态层 / Provider**

- 零变化。

**supersedes**

- 部分覆盖 `add-text-note-feature` `design.md` 决策 R4(关于"写文字页"返回栈的设计)— 本次用 `pushReplacement` 替代 `Navigator.popUntil`,原因见 `design.md` §决策 1。
- 完全覆盖 `add-text-note-feature` `tasks.md` §4.8(原"实现 `_publish` 直接 createPost"任务)— 由本 change 的 §任务 2 取代。
