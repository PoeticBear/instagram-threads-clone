## Purpose

`text-note` capability 覆盖 iOS 客户端「写文字」功能 — 用户在底部 Tab「+」按钮的 Popup 菜单中选「写文字」进入一个新页面;页面采用「输入即所见」交互(TextField 直接嵌在渐变卡片里),生成 3:4 比例的文字卡片。最终**不**在写文字页内闭环发布,而是右上「确认」触发截图后用 `Navigator.pushReplacement` 接管给 `ComposePost`,由 `ComposePost` 完成最终发布(详见 [`compose-post` spec](./../compose-post/spec.md))。

> 起源 `change-text-note-handoff` 加 delta 时叠加的 `add-text-note-feature` 增量 — 本文件是合并后的最终态。

---

## ADDED Requirements

### Requirement: 写文字入口从底部"+"按钮 Popup 菜单进入

The system SHALL 在用户点击底部导航栏中间"+"按钮时,弹出 Popup 菜单(从下往上滑出);Popup 菜单 SHALL 至少包含「写文字」「普通图文」两个选项;点击「写文字」SHALL 进入写文字页面;点击「普通图文」SHALL 进入现有 `ComposePost` 页面。

#### Scenario: 点击"+"弹出菜单
- **WHEN** 用户点击底部导航栏中间"+"按钮
- **THEN** 系统从屏幕底部向上滑出 Popup 菜单,菜单内显示「写文字」和「普通图文」两个选项

#### Scenario: 在 Popup 中选择"写文字"
- **WHEN** 用户在 Popup 菜单中点击「写文字」
- **THEN** Popup 关闭,系统 push 写文字页面,用户可输入文字内容

#### Scenario: 在 Popup 中选择"普通图文"
- **WHEN** 用户在 Popup 菜单中点击「普通图文」
- **THEN** Popup 关闭,系统切换到现有 `ComposePost` 页面,行为与改动前一致

### Requirement: 写文字页面支持实时预览渐变文字卡片

The system SHALL 在写文字页面提供 3:4 比例的卡片预览;卡片 SHALL 始终居中显示用户当前输入的文字内容;用户键入文字时,卡片预览 SHALL 实时更新(无明显延迟)。

#### Scenario: 输入文字时卡片实时更新
- **WHEN** 用户在写文字页面的输入框中键入字符
- **THEN** 上方卡片预览在 200ms 内更新显示该字符

#### Scenario: 支持换行
- **WHEN** 用户在输入框中按下回车键
- **THEN** 卡片预览在对应位置插入换行,文字按多行布局渲染

#### Scenario: 空内容状态
- **WHEN** 用户未输入任何文字(内容为空)
- **THEN** 卡片预览显示占位提示文字(灰色)

### Requirement: 写文字页面提供 4 套预设渐变卡片样式

The system SHALL 在写文字页面提供至少 4 套渐变样式供用户选择;每套样式 SHALL 由纯 Flutter 代码绘制(`Container` + `BoxDecoration` + `LinearGradient`),不需要任何图片素材;选中样式 SHALL 在选择器中有视觉高亮(边框或缩放)。

#### Scenario: 默认选中第一套样式
- **WHEN** 用户进入写文字页面
- **THEN** 默认选中第一套渐变样式,卡片预览使用该样式渲染

#### Scenario: 切换样式
- **WHEN** 用户在样式选择器中点击其他样式的缩略图
- **THEN** 卡片预览切换为该样式,该缩略图显示选中状态(边框高亮)

### Requirement: 卡片字号自适应

The system SHALL 根据用户输入文字的字数自动调整卡片内文字的字号;字数 ≤ 40 时 SHALL 使用 24sp;字数 41~80 时 SHALL 使用 18sp;字数 > 80 时 SHALL 使用 16sp 并截断文字(末尾显示省略号)。

#### Scenario: 短文本字号
- **WHEN** 用户输入 ≤ 40 个字符
- **THEN** 卡片文字字号为 24sp

#### Scenario: 中等长度字号
- **WHEN** 用户输入 41~80 个字符
- **THEN** 卡片文字字号为 18sp

#### Scenario: 超长文本截断
- **WHEN** 用户输入 > 80 个字符
- **THEN** 卡片文字字号为 16sp,且文字截断到前 80 个字符 + 省略号

### Requirement: 卡片不带作者水印

The system SHALL 不在卡片上渲染作者头像、昵称、用户名等任何作者信息的水印;卡片 SHALL 仅展示纯文字。

#### Scenario: 卡片内容检查
- **WHEN** 用户渲染文字卡片(预览或截图)
- **THEN** 卡片内不包含任何头像 / 昵称 / 用户名等水印元素

### Requirement: 写文字页面文案全 i18n 化

The system SHALL 所有用户可见字符串(AppBar 标题、菜单项、按钮文案、占位提示)均通过 `AppLocalizations` 读取;`app_zh.arb` 和 `app_en.arb` SHALL 同步更新所有新增 key。

#### Scenario: 中文环境显示中文
- **WHEN** 用户系统语言为简体中文
- **THEN** 写文字页面的所有文案显示为简体中文

#### Scenario: 英文环境显示英文
- **WHEN** 用户系统语言为英文
- **THEN** 写文字页面的所有文案显示为英文

### Requirement: 写文字页面支持关闭确认

The system SHALL 在用户输入了内容但未发布时,通过 AppBar 的关闭按钮(或系统返回手势)尝试关闭页面,先弹出「确认丢弃当前内容?」对话框,用户确认后才关闭。

#### Scenario: 空内容时关闭
- **WHEN** 用户未输入任何文字并尝试关闭页面
- **THEN** 直接关闭页面,不弹确认对话框

#### Scenario: 有内容时确认
- **WHEN** 用户输入了文字并尝试关闭页面
- **THEN** 弹出「确认丢弃当前内容?」对话框,用户点击「丢弃」才关闭,点击「取消」保持页面

### Requirement: 写文字页面仅维护 iOS

The system SHALL 不为 Android 写任何适配代码;`AndroidManifest.xml`、`android/app/src/main/` 等 Android 原生层 SHALL 不动。

#### Scenario: 代码范围
- **WHEN** 审查写文字功能的所有源码改动
- **THEN** 不包含 Android 平台特定的代码、配置或资源

---

## MODIFIED Requirements

### Requirement: 写文字页面通过「确认 → 交接 ComposePost」完成发帖链路

The system SHALL 在用户点击「确认」按钮时,捕获当前渲染卡片为 PNG 字节,写入临时目录并构造 `MediaDraftItem`,然后通过 `Navigator.pushReplacement` 将 `ComposePost` 推入导航栈,其中 `ComposePost` 的 `initialContent` SHALL 为用户输入的正文文本,`initialMediaDrafts` SHALL 为一个只包含该卡片 PNG 对应 `MediaDraftItem` 的列表(详见 [`compose-post` spec · initialMediaDrafts](./../compose-post/spec.md#));用户 SHALL 继续在 `ComposePost` 中可任意添加更多媒体 / 修改正文 / 启用投票 / 设置位置 / 设置定时 / 标记敏感内容,并最终在该页面右上「发布」中提交。

#### Scenario: 确认成功转入 ComposePost
- **WHEN** 用户在 TextNotePage 输入了正文(可以为空),选择了某套卡片样式,且当前不在 `_isConfirming` 状态
- **THEN** 系统执行截图并写入临时文件,完成 `MediaDraftItem` 构造,**并且** `TextNotePage` 被替换为 `ComposePost`,其中 `_textEditingController.text` 等于用户正文,`_mediaDrafts` 至少包含该卡片 PNG 对应的 image 草稿

#### Scenario: 确认成功时 TextNotePage 不再弹「发布成功」snack
- **WHEN** 用户点击「确认」按钮且截图 + 写文件均成功
- **THEN** `TextNotePage` **不**弹出任何成功反馈 snack;用户感知为"页面已自然转入 ComposePost"

#### Scenario: 确认失败(截图抛错或写文件失败)
- **WHEN** 用户点击「确认」按钮,但 `ScreenshotController.capture()` 抛错,或写临时文件抛错
- **THEN** 系统在 `TextNotePage` 上弹出 `l10n.textCardConfirmFailed` snack(背景色为 `appColors.destructive`),`_isConfirming` 复位为 `false`,`TextNotePage` 保持打开,用户可重试「确认」或经左上「取消」走放弃流程

#### Scenario: 确认期间二次点击不触发新流程
- **WHEN** 用户点击「确认」按钮后处于 `_isConfirming == true` 状态
- **THEN** 第二次点击 SHALL 不会重入 `_confirm`,后续状态以第一次为准

#### Scenario: 确认替换后栈结构
- **WHEN** 「确认」成功替换 TextNotePage
- **THEN** 当前导航栈 SHALL 为 `[HomePage, ComposePost]`,**不**包含 `TextNotePage`;用户在 ComposePost 上系统返回手势或返回按钮 SHALL 直接回到 HomePage,**不**回到 TextNotePage

### Requirement: 写文字页面支持空文字确认(纯渐变卡片合法)

The system SHALL 在用户正文为空(包含纯空格)时,「确认」按钮 SHALL 仍可点击(只要未处于 `_isConfirming` 状态);点击后 SHALL 仍走"截图卡片 PNG → 转入 `ComposePost(initialContent: '', initialMediaDrafts: [imageDraft])`"的完整路径。

#### Scenario: 空文字点确认
- **WHEN** TextNotePage 中 `_textController.text.trim()` 为空,用户选择了某套卡片样式
- **THEN** 系统按与有文字相同的流程截图卡片(此时卡片只显示 hint 占位),转入 ComposePost,`_textEditingController.text == ''`,`_mediaDrafts` 仍包含卡片 PNG 草稿

#### Scenario: 空文字时按钮不灰显
- **WHEN** TextNotePage 中正文为空
- **THEN** 「确认」按钮 SHALL 显示为可点的 accent 色(非灰),点击可触发上述流程

### Requirement: l10n.textCardConfirm 按钮文案

The system SHALL TextNotePage 右上角按钮文案使用新增的 i18n key `textCardConfirm`(zh-Hans: "确认";en: "Confirm"),区别于已有的 `l10n.post`(post = "发布")。`app_zh.arb` 和 `app_en.arb` SHALL 同步维护本 key;`flutter gen-l10n` 重新生成的 `app_localizations*.dart` SHALL 暴露 `String textCardConfirm` getter。

#### Scenario: 中英文环境显示
- **WHEN** 用户系统语言为简体中文,或英文
- **THEN** TextNotePage 右上按钮 SHALL 显示 "确认" 或 "Confirm",**不**显示 "发布" 或 "Post"

---

## REMOVED Requirements

### Requirement: 写文字页面通过复用 createPost 完成发布

**Reason**: 原流程(`TextNotePage` 内直接 `PostState.createPost`)已被新流程(确认 → 交接 `ComposePost`)取代。`PostState.createPost` 由用户在 `ComposePost` 中触发,链路完全不变,只是触发位置迁移到普通图文页。

**Migration**: 该需求被上面「写文字页面通过「确认 → 交接 ComposePost」完成发帖链路」MODIFIED 版完全取代。原场景"发布成功 → 关闭写文字页 → Feed 出现新帖"演变为 "确认成功 → 替换为 ComposePost → 用户最终在 ComposePost 发帖 → Feed 出现新帖"。

### Requirement: 写文字页面支持把卡片保存到相册

**Reason**: 已在 v1 调整(tasks §9.2)中将「保存到相册」按钮从 AppBar action 移除,`_saveToGallery` 及 `gal` import 已清理。

**Migration**: 无。`docs/code-locations/write-text.md` 已记录当前形态(无「保存到相册」入口)。若后续需要,从 `share_profile_sheet.dart` 的实现复用即可。

### Requirement: 写文字页面支持无内容时禁用发布

**Reason**: 新流程允许空文字(纯渐变卡片合法),原"无内容禁用发布"的需求不再适用。`TextNotePage` 端不再做内容空校验;若产品后续要在 `ComposePost` 端再做"必须有正文"的校验,属于 `ComposePost` 的独立需求。

**Migration**: 该需求语义已被上面「写文字页面支持空文字确认(纯渐变卡片合法)」覆盖。
