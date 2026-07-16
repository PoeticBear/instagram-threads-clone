# 任务清单 — change-text-note-handoff

> 关联设计:`design.md` | 规格:`specs/text-note/spec.md`

## 1. ComposePost 加媒体入参

- [x] 1.1 在 `client/lib/pages/composePost/post.dart`:`class ComposePost` 加可选入参 `final List<MediaDraftItem>? initialMediaDrafts;`,并把它放进 `const ComposePost({..., this.initialMediaDrafts})`
- [x] 1.2 在 `ComposePostState.initState()` 末尾追加:
  ```dart
  if (widget.editingPostId == null &&
      widget.initialMediaDrafts != null &&
      widget.initialMediaDrafts!.isNotEmpty) {
    _mediaDrafts = [...widget.initialMediaDrafts!];
  }
  ```
- [x] 1.3 不要修改 `dispose` / 不要改动 `_addMedia` / 不要触碰 `_onDraftSelected`(编辑模式自带 media 恢复链路,守卫隔离避免互盖)

## 2. TextNotePage 改造(核心)

- [x] 2.1 把 `_publish()` 方法改名为 `_confirm()`,命名全模块一致(`_isConfirming`、`_ConfirmException`、`_confirmCardSafely` 也对应)
- [x] 2.2 AppBar 按钮文案:`l10n.post` → `l10n.textCardConfirm`;按钮置灰判定从 `_canPublish` 改为 `_canConfirm = !_isConfirming`
- [x] 2.3 `_confirm()` 实现裁剪:
  - 保留:`FocusScope.of(context).unfocus()`、HapticFeedback、截图(`_captureCardSafely`)、写临时文件、构造 `MediaDraftItem.fromLocalImage`
  - 删除:`Provider.of<AuthState>` 取用户、`PostModel` / `UserModel` 构造、`Provider.of<PostState>` 调用、`PostState.createPost`、`MediaDraftItem` 上传链路触发
  - 新增:末尾用 `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ComposePost(initialContent: text, initialMediaDrafts: [imageDraft])))`(与现有 home.dart `_showComposeMenu` 走 `MaterialPageRoute` 风格一致)
  - 失败 snack 文案换成 `l10n.textCardConfirmFailed`(背景 `appColors.destructive`)
  - 成功后**不**弹 `textCardPublishSuccess` snack(整个成功 snack 路径删除)
- [x] 2.4 在文件顶部定义 typedef `typedef TextNoteHandoff = ({String text, MediaDraftItem imageDraft});`,在 `_confirm` 中用 record 构造 `MediaDraftItem` 与 `text` 一起透传给 ComposePost(可视代码可读性,可省略,但保留更清晰)
- [x] 2.5 import 列表裁剪:
  - 删:`provider/provider.dart`、`state/auth.state.dart`、`state/post.state.dart`、`model/post.module.dart`、`model/user.module.dart`
  - 新增:`pages/composePost/post.dart`(为 ComposePost widget 用)
  - 保留:`dart:async`、`dart:io`、`flutter/cupertino.dart`、`flutter/material.dart`、`flutter/services.dart`、`path_provider/path_provider.dart`、`screenshot/screenshot.dart`、`l10n/generated/app_localizations.dart`、`model/media_draft_item.dart`、`theme/app_colors.dart`、`pages/textNote/text_card_preview.dart`
- [x] 2.6 `_PublishException` 类改名为 `_ConfirmException`(`class _ConfirmException`);catch 路径同步更新
- [x] 2.7 `_isSubmitting` 字段改为 `_isConfirming`(仅命名,语义为"确认流程进行中")

## 3. l10n 同步

- [x] 3.1 `client/lib/l10n/app_zh.arb` 新增 `textCardConfirm`: "确认"
- [x] 3.2 `client/lib/l10n/app_en.arb` 新增 `textCardConfirm`: "Confirm"
- [x] 3.3 `app_zh.arb` 把 `textCardPublishFailed` 改名为 `textCardConfirmFailed`(语义:确认失败,不再叫"发布失败") — 值保留"发布失败，请重试"(用户认知不变)
- [x] 3.4 `app_en.arb` 同步重命名 `textCardPublishFailed` → `textCardConfirmFailed` — 值保留"Failed to post, please try again"
- [x] 3.5 从 `app_zh.arb` / `app_en.arb` 删除 `textCardPublishSuccess` 全段(TextNotePage 不再消费此 key;grep 已确认无任何 .dart 文件残留引用)
- [x] 3.6 跑 `flutter gen-l10n` 重新生成 `client/lib/l10n/generated/app_localizations*.dart`,确认 `textCardConfirm` / `textCardConfirmFailed` getter 存在,`textCardPublishSuccess` 已消失

## 4. 文档

- [x] 4.1 更新 `docs/code-locations/write-text.md`:
  - §1.1 改写流程描述:不再"立即发布"→"确认 → pushReplacement ComposePost 接管"
  - §1.1 表格里 `_publish` / `_canPublish` / `_isSubmitting` 改为 `_confirm` / `_canConfirm` / `_isConfirming`
  - §2.1 更新入口说明:TextNotePage 当前栈行为是 pushReplacement([HomePage, ComposePost]);home.dart 不需要修改
  - §3 顶部说明:无新增 Provider;复用 ComposePost 的 `createPost`
  - §6 i18n 表增 `textCardConfirm`;删 `textCardPublishSuccess`;`textCardPublishFailed` → `textCardConfirmFailed`
  - 末尾追加变更记录条目:v1.x — 切换为"确认 → 交接 ComposePost"(`change-text-note-handoff`)
- [x] 4.2 更新 `docs/code-locations/publish-post.md`:
  - §2.4 "写文字 Popup 入口" 描述更新:TextNotePage 现在通过 `Navigator.pushReplacement` 跳到 ComposePost,而非直接发帖
  - 末尾如有过期描述 "TextNotePage → 选「写文字」时 push 进入 ... 复用 `createPost` 发布",改为"TextNotePage → 选「写文字」时 push 进入 → 用户确认 → pushReplacement 到 ComposePost 接管,最终由 ComposePost 走现有 createPost 发布"

## 5. 验证

- [x] 5.1 `cd client && flutter analyze` 无新增报错(`textCardPublishSuccess` 残留引用会编译失败 → 自然暴露)。结论:`flutter analyze` 在 `text_note_page.dart` / `composePost/post.dart` 上零问题(54 个 pre-existing 问题均在其他文件,与本 change 无关)
- [x] 5.2 `cd client && flutter build ios --debug --no-codesign` 通过(确认 `MaterialPageRoute` 改动与新 import 不破坏编译)。结论:`✓ Built build/ios/iphoneos/Runner.app`(32.3s,exit 0)
- [ ] 5.3 iOS 模拟器手动验证三组场景:
  - **路径 A — 普通图文**:点"+" → 弹菜单 → 选「普通图文」→ 直接进 ComposePost,行为与改动前一致
  - **路径 B — 写文字 → 确认**:点"+" → 弹菜单 → 选「写文字」→ 输入文字(任意长度)/ 选样式 / 点「确认」→ **栈变为 [ComposePost],TextNotePage 已移除,ComposePost 正文区已预填刚才的文字,媒体缩略图区显示卡片 PNG**
  - **路径 C — 空文字 + 纯卡片**:点"+" → 弹菜单 → 选「写文字」→ 不输入文字 / 选样式 / 点「确认」→ **按钮放行**,进入 ComposePost,正文为空,仅带卡片图
- [ ] 5.4 边界验证:
  - TextNotePage 阶段输入文字 + 点左上「取消」→ 弹 `textCardDiscardTitle` / `textCardDiscardMessage` 确认框(原逻辑保留)
  - 从 TextNotePage 接管到 ComposePost 后,直接点 ComposePost 右上「发布」→ 正常发帖,Feed 出现新帖(图片正常上传 + 渲染)
  - 从 ComposePost 返回(系统返回手势)→ 回到 HomePage,**不会**回到 TextNotePage
- [ ] 5.5 国际化验证:
  - 切换模拟器语言到中文 / 英文各跑一次路径 B,确认按钮文案 / snack 文案 / 放弃确认文案 均同步本地化
