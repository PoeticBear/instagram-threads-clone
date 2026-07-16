## MODIFIED Requirements

### Requirement: 写文字页面通过「确认 → 交接 ComposePost」完成发帖链路

The system SHALL 在用户点击「确认」按钮时,捕获当前渲染卡片为 PNG 字节,写入临时目录并构造 `MediaDraftItem`,然后通过 `Navigator.pushReplacement` 将 `ComposePost` 推入导航栈,其中 `ComposePost` 的 `initialContent` SHALL 为用户输入的正文文本,`initialMediaDrafts` SHALL 为一个只包含该卡片 PNG 对应 `MediaDraftItem` 的列表;用户 SHALL 继续在 `ComposePost` 中可任意添加更多媒体 / 修改正文 / 启用投票 / 设置位置 / 设置定时 / 标记敏感内容,并最终在该页面右上「发布」中提交。

#### Scenario: 确认成功转入 ComposePost

- **WHEN** 用户在 TextNotePage 输入了正文(可以为空),选择了某套卡片样式,且当前不在 `_isConfirming` 状态
- **WHEN** 用户点击 AppBar 右上角「确认」按钮
- **THEN** 系统执行截图并写入临时文件,完成 `MediaDraftItem` 构造,**并且** `TextNotePage` 被替换为 `ComposePost`,其中 `_textEditingController.text` 等于用户正文,`_mediaDrafts` 至少包含该卡片 PNG 对应的 image 草稿

#### Scenario: 确认成功时 TextNotePage 不再弹「发布成功」snack

- **WHEN** 用户点击「确认」按钮且截图 + 写文件均成功
- **THEN** `TextNotePage` **不**弹出任何成功反馈 snack;用户感知为"页面已自然转入 ComposePost"

#### Scenario: 确认失败(截图抛错或写文件失败)

- **WHEN** 用户点击「确认」按钮,但 `ScreenshotController.capture()` 抛错,或写临时文件抛错
- **THEN** 系统在 `TextNotePage` 上弹出 `l10n.textCardConfirmFailed` snack(背景色为 `appColors.destructive`),`_isConfirming` 复位为 `false`,`TextNotePage` 保持打开,用户可重试「确认」或经左上「取消」走放弃流程

#### Scenario: 确认期间二次点击不触发新流程

- **WHEN** 用户点击「确认」按钮后处于 `_isConfirming == true` 状态(无论是否完成)
- **AND** 用户再次点击按钮区域(可能点击的是 spinner)
- **THEN** 第二次点击 SHALL 不会重入 `_confirm`,后续状态以第一次为准

#### Scenario: 确认替换后栈结构

- **WHEN** 「确认」成功替换 TextNotePage
- **THEN** 当前导航栈 SHALL 为 `[HomePage, ComposePost]`,**不**包含 `TextNotePage`;用户在 ComposePost 上系统返回手势或返回按钮 SHALL 直接回到 HomePage,**不**回到 TextNotePage

### Requirement: 写文字页面支持空文字确认(纯渐变卡片合法)

The system SHALL 在用户正文为空(包含纯空格)时,「确认」按钮 SHALL 仍可点击(只要未处于 `_isConfirming` 状态);点击后 SHALL 仍走"截图卡片 PNG → 转入 `ComposePost(initialContent: '', initialMediaDrafts: [imageDraft])`"的完整路径。

#### Scenario: 空文字点确认

- **WHEN** TextNotePage 中 `_textController.text.trim()` 为空,用户选择了某套卡片样式
- **WHEN** 用户点击「确认」按钮
- **THEN** 系统按与有文字相同的流程截图卡片(此时卡片只显示 hint 占位),转入 ComposePost,`_textEditingController.text == ''`,`_mediaDrafts` 仍包含卡片 PNG 草稿

#### Scenario: 空文字时按钮不灰显

- **WHEN** TextNotePage 中正文为空
- **THEN** 「确认」按钮 SHALL 显示为可点的 accent 色(非灰),点击可触发上述流程

## REMOVED Requirements

### Requirement: 写文字页面通过复用 createPost 完成发布

**Reason**: 原流程(`TextNotePage` 内直接 `PostState.createPost`)已被新流程(确认 → 交接 `ComposePost`)取代。`PostState.createPost` 由用户在 `ComposePost` 中触发,链路完全不变,只是触发位置迁移到普通图文页。

**Migration**: 该需求被 `write-text-page.md` 的「写文字页面通过「确认 → 交接 ComposePost」完成发帖链路」MODIFIED 版完全取代。原场景"发布成功 → 关闭写文字页 → Feed 出现新帖"演变为 "确认成功 → 替换为 ComposePost → 用户最终在 ComposePost 发帖 → Feed 出现新帖"。

### Requirement: 写文字页面支持把卡片保存到相册

**Reason**: 已在 `add-text-note-feature` v1 调整(`tasks.md` §9.2)中将「保存到相册」按钮从 AppBar action 移除,`_saveToGallery` 及 `gal` import 已清理。本 change 一并清理 spec 以保持 spec/code 一致。

**Migration**: 无。`write-text.md` 代码定位文档已记录当前形态(无「保存到相册」入口)。若后续需要,从 `share_profile_sheet.dart` 的实现复用即可,单独开 change。

### Requirement: 写文字页面支持无内容时禁用发布

**Reason**: 新流程允许空文字(纯渐变卡片合法),原"无内容禁用发布"的需求不再适用。`TextNotePage` 端不再做内容空校验;若产品后续要在 `ComposePost` 端再做"必须有正文"的校验,属于 `ComposePost` 的独立需求,不在本 change 范围。

**Migration**: 该需求语义已被「写文字页面支持空文字确认(纯渐变卡片合法)」覆盖。

### Requirement: 写文字页面文案全 i18n 化 关于 `l10n.textCardPublishSuccess` 的隐含依赖

**Reason**: 现有文案全 i18n 化的元需求(所有字符串通过 `AppLocalizations` 读取)仍然成立。本条目只是显式记一下本次对具体 key 的变更:新增 `textCardConfirm`、下线 `textCardPublishSuccess`、`textCardPublishFailed` 重命名为 `textCardConfirmFailed`。i18n 总原则没变,只更具体的 key 集合。

**Migration**: 见新条目「`l10n.textCardConfirm` 按钮文案」于本 spec 文件末尾。

---

## ADDED Requirements

### Requirement: ComposePost 支持通过 `initialMediaDrafts` 入参预填媒体列表

The system SHALL `ComposePost` widget 签名增加可选入参 `final List<MediaDraftItem>? initialMediaDrafts`,在 `initState` 中,**当且仅当 `widget.editingPostId == null` 且 `widget.initialMediaDrafts` 非空**时,直接赋值 `_mediaDrafts = [...widget.initialMediaDrafts!]`;在编辑模式下,`initialMediaDrafts` SHALL 被忽略,以原帖自有 media 恢复链路为准。

#### Scenario: 从 TextNotePage 跳入,媒体预填

- **WHEN** 通过 `Navigator.pushReplacement` 进入 `ComposePost(initialContent: text, initialMediaDrafts: [draft])`
- **THEN** ComposePost 第一帧渲染时,底部媒体区域 SHALL 显示用户的卡片 PNG 缩略图作为首个 MediaDraftItem

#### Scenario: 编辑模式下不响应 initialMediaDrafts

- **WHEN** 通过 `Navigator.push(ComposePost(editingPostId: 'xxx', initialMediaDrafts: [draft]))` 调用
- **THEN** `_mediaDrafts` SHALL 不被 `initialMediaDrafts` 覆盖,继续走原有 `_onDraftSelected` 恢复逻辑

#### Scenario: 普通调用不受影响

- **WHEN** `ComposePost()` 不传 `initialMediaDrafts`
- **THEN** 行为与本需求之前完全一致,`_mediaDrafts` 初始为空

### Requirement: `l10n.textCardConfirm` 按钮文案

The system SHALL TextNotePage 右上角按钮文案使用新增的 i18n key `textCardConfirm`(zh-Hans: "确认";en: "Confirm"),区别于已有的 `l10n.post`(post = "发布")。`app_zh.arb` 和 `app_en.arb` SHALL 同步维护本 key;`flutter gen-l10n` 重新生成的 `app_localizations*.dart` SHALL 暴露 `String textCardConfirm` getter。

#### Scenario: 中英文环境显示

- **WHEN** 用户系统语言为简体中文,或英文
- **THEN** TextNotePage 右上按钮 SHALL 显示 "确认" 或 "Confirm",**不**显示 "发布" 或 "Post"
