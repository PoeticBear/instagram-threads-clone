## Context

承接 `add-text-note-feature` 的 v1 实现。项目是一个 Flutter iOS 客户端(`CLAUDE.md` 项目约定:只维护 iOS、不做 Android 适配),发帖统一经过 `ComposePost`(`client/lib/pages/composePost/post.dart`),它承载图文 / 视频 / GIF / 投票 / 草稿 / 位置 / 定时 / 回复权限等所有发帖模式。`TextNotePage`(`client/lib/pages/textNote/text_note_page.dart`)目前是"页面内闭环"的发帖短路径,与 `ComposePost` 并列但不复用。

本次 UX 调整要求把 `TextNotePage` 从"闭环发布"改为"半成品 → 交接 `ComposePost`",让用户在普通图文页继续编辑和最终发布。

`ComposePost` 现有 widget 签名已经支持 `initialContent`(编辑模式预填正文),我们只需要再加一个 `initialMediaDrafts` 平行入参,就能让 `TextNotePage` 把 (text, cardImage) 同时交过去。

## Goals / Non-Goals

**Goals**

- 把用户从"被迫在卡片内部发表完整帖子"中释放出来,允许继续在 `ComposePost` 二次编辑
- 改写后的 `TextNotePage` 仍是短生命周期、单页交互的入口,体验流畅
- 复用 `ComposePost` 现有完整功能:加图、改文、加投票、加位置、定时、撤回、敏感内容标记…
- 全 i18n 化,中英文双语同步
- 改动面尽量收敛到两个 widget + 两份 l10n + 一份代码定位文档,不波及 Provider / Service / 服务端
- 沿用 `add-text-note-feature` 已验证的技术栈(`screenshot` + `path_provider` + `MediaDraftItem.fromLocalImage`)

**Non-Goals**

- 不支持「确认后回到 TextNotePage 再改样式」— 这意味状态需要序列化、双向同步,复杂度翻倍,且超出"两步工序"的 UX 直觉
- 不新引入 Provider / 状态类
- 不做卡片分享到第三方、保存到相册 — 这些都不在主路径上,如有需求另开 change
- 不在空文字时强禁"确认" — 放行,允许纯渐变卡片作为合法帖子
- 不重构 `ComposePost.initState` 的现有逻辑,只在末尾追加一段预填 media 的赋值

## Decisions

### 决策 1: 用 `Navigator.pushReplacement` 而非 "结果回传 + 再 push"

**选择**:`TextNotePage._confirm()` 内部直接 `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ComposePost(...)))`,`ComposePost` 接管当前页位置。

**理由**:
- `TextNotePage` 用了 `PopScope(canPop: false)` + 系统返回手势拦截(`text_note_page.dart:249`)+ 自定义"放弃"对话框。任何编程式 `Navigator.pop(...)` 都会被 `PopScope` 拦截并触发"放弃"确认,语义错位
- `pushReplacement` 不走 pop 路径,不会被 `PopScope` 拦截,栈会变成干净的 `[HomePage, ComposePost]`,用户从 `ComposePost` 返回直接回到 HomePage,可预测
- 其他备选:
  - "结果回传 + 再 push":需要 TextNotePage 编程式 pop,而 PopScope 会拦截 → 不可行
  - "结果回传 + removeRoute + push":需要 home.dart 在 TextNotePage 注册路由 key,并协调两次导航操作 → 引入跨模块状态,代价远大于 pushReplacement 的轻微耦合
- TextNotePage 对 ComposePost 的"耦合"只是「import 这个 widget 类、知道它接 `initialContent` + `initialMediaDrafts` 两个参数」,符号层面,不涉及内部状态,后期若需要解耦再抽适配层

**否决**:
- 完全不耦合(用一个泛化的 handoff + orchestrator 模式)— 上面已经论证,代价高,收益低

### 决策 2: `ComposePost.initialMediaDrafts` 作为**可选**入参 + 直接赋 `_mediaDrafts`

**选择**:在 `ComposePost` widget 加 `final List<MediaDraftItem>? initialMediaDrafts;`(默认 null),`initState` 里:

```dart
if (widget.initialMediaDrafts != null && widget.initialMediaDrafts!.isNotEmpty) {
  _mediaDrafts = [...widget.initialMediaDrafts!];
}
```

**理由**:
- 直接赋值比遍历调 `_addMedia(item)` 干净 — `_addMedia` 内部会 setState 和做越界检查,在 `initState` 阶段只需要 seed 数据,不需要 UI 增量更新
- 用 `[... ]` 拷贝避免 `widget.initialMediaDrafts` 被外部后续修改误伤
- 与现有 `initialContent` 的处理风格保持一致(都是 widget 入参 → initState 赋值,不动现有逻辑)
- 不修改 `editingPostId` 路径 — 即"编辑模式"已被显式设定时,`initialMediaDrafts` 被忽略(以原帖的 media 为准,不覆盖),由 if-else 守卫处理(见决策 5)

**否决**:
- 复用 `editingPostId` 入参传 `'handoff'` 这类标记 — 语义混乱,未来维护者一眼看不懂
- 在 `didChangeDependencies` 里塞 — 没必要,初始化就是单次

### 决策 3: 放行空文字(纯渐变卡片也算合法)

**选择**:把 `_canPublish` getter 改名为 `_canConfirm`,判定从 `_hasContent && !_isSubmitting` 改为 `!_isConfirming`(只判"未在截图中",不判内容)。

**理由**:
- 用户可能只想分享一张纯渐变的视觉卡(类似 Instagram Stories 的色卡场景),强禁会让按钮处于永久灰态,困惑
- 卡片本身就是有"完整媒体"的合法帖子,服务端 `mediaType=1`(image)零侵入
- 取消 `_hasContent` 守卫也意味着不再需要在用户敲第一字前禁用按钮,UX 更直接

**否决**:
- 保持 `_hasContent` 守卫 — 与"纯色卡创作"心智冲突
- 加单独的 "纯色卡" 模式按钮 — UI 增加复杂度,产品价值低

### 决策 4: typedef `TextNoteHandoff` 内联,不新增文件

**选择**:在 `text_note_page.dart` 顶部定义 `typedef TextNoteHandoff = ({String text, MediaDraftItem imageDraft});`(Dart 3 record)。

**理由**:
- handoff 只是 `pushReplacement` 时的**中间表达式**类型(把 (text, imageDraft) 一次性放进 `ComposePost` 构造函数),不会被跨页面传递 — 所以单独建文件无意义
- Dart 3 record 直接表达两个字段,比新建一个 class 文件更轻量
- typedef 留在 `text_note_page.dart` 顶部,既不污染 `text_card_preview.dart`,也不需要新文件路径

**否决**:
- 新建 `text_note_handoff.dart` 单文件 — 一个字段集合单建文件是 over-engineering
- 用 `Map<String, dynamic>` — 失类型,编译期无法保护

### 决策 5: 编辑模式优先于 handoff media

**选择**:`ComposePost.initState` 中显式:

```dart
if (widget.editingPostId == null &&
    widget.initialMediaDrafts != null &&
    widget.initialMediaDrafts!.isNotEmpty) {
  _mediaDrafts = [...widget.initialMediaDrafts!];
}
```

**理由**:
- 编辑模式有自己的 media 恢复链路(`_onDraftSelected` → `_buildDraftsFromMediaList`),不应被入参覆盖
- TextNotePage 的 handoff 路径不会设置 `editingPostId`,两者天然互斥,但加显式守卫让代码意图清晰

### 决策 6: i18n 文案变更

- 新增 `textCardConfirm`(zh: "确认" / en: "Confirm")
- 删除 `textCardPublishSuccess`(TextNotePage 不再发 post,这个 snack 不会再显示;`app_zh.arb` 和 `app_en.arb` 同步清理,确保 `flutter gen-l10n` 重新生成时不残留死 key)
- `textCardPublishFailed` → `textCardConfirmFailed`(语义更准确:失败发生在 capture,不在 publish)

### 决策 7: 与现有 v1 调整(tasks §9)兼容

`add-text-note-feature` v1 调整已经做了以下修正,我们不重新做:

- 「取消」换行(`Container + Center`)
- 移除「保存到相册」按钮 + 清理 `gal` 相关代码
- inline 编辑(`TextField` 嵌卡片)
- `docs/code-locations/write-text.md` 第 9 节同步更新

本次新增/变更与上述 v1 形态叠加,不重做任何一段。

## Risks / Trade-offs

- **[R1] 视觉不再"所见即所发"**
  → 用户在 `TextNotePage` 看的是卡片,在 `ComposePost` 看到的是单张图 + 文字。多出一段"正文 + 上方图片预览"的视觉,可能让用户感觉"卡片怎么变了"。
  Mitigation:`ComposePost` 的媒体预览默认展示上传后的图片(就是卡片),跟卡片视觉一致(`MediaDraftItem` 在 ComposePost 渲染走标准 image 预览;若未来发现视觉差异过大,可在 _buildMediaThumb 里加 "渐变 + 文字" 的特殊渲染分支,但这是另一项工作)

- **[R2] 临时文件在用户退出 ComposePost 时残留**
  → `MediaDraftItem.localFile` 指向 temp 目录下的 PNG,若用户从 `ComposePost` 返回,文件未上传,会一直留到 OS 清 temp 目录
  Mitigation:与现状对齐(`_resolveDraftMedia` 也是把本地文件上传后才回填 `remoteUrl`);ComposePost 的草稿保存逻辑也会复用上传;此外 iOS `getTemporaryDirectory()` 在 app 升级 / 重启时会被系统清,长期残留风险小

- **[R3] `pushReplacement` 与 `ComposePost.initState` 的初始化时序**
  → `_mediaDrafts = [...initialMediaDrafts!]` 在 `initState` 中执行,意味着 widget tree 第一次 build 时已经预填好。但若 `ComposePost` 被外面用同样的 key 多次构建(`home.dart` 用 `_composePostKey = GlobalKey<ComposePostState>()` 持 tab=2 的 ComposePost),这里 key 复用可能导致奇怪状态
  Mitigation:`TextNotePage.pushReplacement` 出来的 `ComposePost` 走**新**的 route,持有全新 `MaterialPageRoute` 默认 key,不与 home.dart 的 `_composePostKey` 冲突

- **[R4] `l10n.textCardPublishSuccess` 删除的回归风险**
  → 旧 key 在 v1 调整后其实已经没有 text_note_page.dart 引用了(对照 v1 `9.2` 任务的语义, snack 逻辑没删干净是另一个 cleanup),但代码审计层面可能有人回头引用
  Mitigation:`flutter gen-l10n` 会校验所有 `AppLocalizations` getter,任何残留引用会编译失败 → 自然暴露

- **[R5] 空文字按钮放行后的视觉退化**
  → 文字 0 时,卡片截图只渲染渐变背景 + hint 占位(`textCardHint`),"发布"出去的帖子就是一张纯色卡,可能不如预期美观
  Mitigation:本意就是允许这种创作形式;若产品后续觉得不合适,在 `ComposePost` 端的预览层做"必须有内容"校验即可,TextNotePage 这一步不必再守

## Open Questions

无 — 所有关键决策已与用户锁定(由用户明确委托 Claude 决策):

1. 导航形态 = A: `pushReplacement`
2. ComposePost 返回 = 回到 Home(不回到 TextNotePage)
3. 空文字 = 放行
