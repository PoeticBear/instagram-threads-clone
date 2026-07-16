# 写文字 — 代码定位

> 本文档汇总 iOS 客户端「写文字」功能涉及的所有源代码位置，包括 UI 层、状态层、服务层、模型、工具方法以及入口集成点。
> 后续若收到「定位写文字页面」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 写文字主页 `TextNotePage`

- **路径**：`client/lib/pages/textNote/text_note_page.dart`
- **核心组件**：
  - `class TextNotePage extends StatefulWidget`（`text_note_page.dart`）— 主页面
  - `class _TextNotePageState extends State<TextNotePage>` — 主状态类
- **`change-text-note-handoff` 后的流程变化**：「写文字」页面不再闭环发帖。右上「确认」截屏后用 `Navigator.pushReplacement` 把 `TextNotePage` 替换为 `ComposePost`，把 (text, imageDraft) 透传过去；用户继续在 `ComposePost` 编辑 / 加更多图 / 投票 / 位置 / 定时，最终在 `ComposePost` 右上的「发布」提交。栈终态：`[HomePage, ComposePost]`，**不**会回到 `TextNotePage`。
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 备注 |
  | --- | --- | --- |
  | 状态字段 | `_textController` / `_screenshotController` / `_textFocusNode` / `_selectedStyle` / `_isConfirming` | `_isConfirming` 是"确认流程进行中"标志（替代旧的 `_isSubmitting`） |
  | 派生 getter | `_hasContent` / `_canConfirm` / `_bodyText` | `_canConfirm = !_isConfirming`（**放行空文字**，纯渐变卡也算合法） |
  | 关闭确认 | `_confirmDiscardIfNeeded` / `_handleBack`（配合 `PopScope` 拦截系统返回手势） | |
  | 确认（→ 交接 ComposePost） | `_confirm` → `FocusScope.unfocus` 收键盘 → `_captureCardSafely` → 写临时 PNG → `MediaDraftItem.fromLocalImage` → `Navigator.pushReplacement(MaterialPageRoute(...))` 到 `ComposePost(initialContent: text, initialMediaDrafts: [draft])` | 不再发 post；不发任何成功 snack（route 替换即接管） |
  | typedef | `typedef TextNoteHandoff = ({String text, MediaDraftItem imageDraft});` | 仅作代码可读性 / 调试追踪（Dart 3 record，`pushReplacement` 不传值） |
  | 截图工具 | `_captureCardSafely`（包 `addPostFrameCallback` + 80ms delay 等渲染稳定） | |
  | Build | `build` / `_buildAppBar` / `_buildCardEditor` | `_buildAppBar` 右上按钮文案从 `l10n.post` 改为 `l10n.textCardConfirm` |

### 1.2 卡片编辑器 `_buildCardEditor`（inline 在主页里）

> v1 调整为「**输入即所见**」 —— TextField 直接嵌在 Screenshot 包裹的渐变卡片里，用户键入的文字直接渲染在卡片上，所见即所交接给 ComposePost。`change-text-note-handoff` 后流程改为先交接再发布，"所见即所发"更新为"所见即所交接"。

- **位置**：`client/lib/pages/textNote/text_note_page.dart::_buildCardEditor`
- **关键属性**：
  - `maxLines: null` + `keyboardType: multiline` + `textInputAction: newline` — 支持任意多行 + 回车换行
  - `textAlign: TextAlign.center` — 居中
  - `cursorColor: Colors.white` + `cursorWidth: 2` — 白光标
  - `style.color = white` + `fontWeight: w600` + `shadows` — 跟原 `TextCardPreview` 一致的视觉
  - `decoration: InputBorder.none` + `hintText: l10n.textCardHint` — 无边框，hint 提示「说点什么...」
  - `maxLength: kInputMaxChars` (500)
- **字号自适应**：通过 `fontSizeFor(charCount)` / `lineHeightFor(charCount)` 计算（定义在 `text_card_preview.dart`），按字数 40/80 阈值切 24/18/16sp
- **截图机制**：`_screenshotController.capture(delay: 80ms)` 截整个卡片（含 TextField 已渲染的文字）。确认前 `unfocus()` 收起键盘 + 隐光标，确保截图干净。

### 1.3 卡片渲染组件 `TextCardPreview`（保留作为 Feed 渲染备选）

- **路径**：`client/lib/pages/textNote/text_card_preview.dart`
- **核心组件**：
  - `enum TextCardStyle { warmOrange, purpleBlue, mint, darkNight }` — 4 套预设样式
  - `final Map<TextCardStyle, List<Color>> kCardGradients` — 4 套渐变色（统一 `Alignment.topLeft → Alignment.bottomRight`）
  - `const TextCardStyle kDefaultCardStyle = TextCardStyle.warmOrange`
  - `class TextCardPreview extends StatelessWidget` — **3:4 渐变卡片的「只读」渲染版本**，字号自适应 + 截断 + 省略号。当前页面没使用（v1 改为 inline 编辑），但保留供未来 Feed 渲染写文字帖子时复用。
  - `class TextCardStylePicker extends StatelessWidget` — 横向滚动 4 张缩略图（64×64），选中态加 2px 边框 + 缩放 1.05。**当前页面使用中**。
  - `class _StyleThumb extends StatelessWidget` — 单张缩略图
- **关键常量**：
  | 常量 | 值 | 用途 |
  | --- | --- | --- |
  | `kCardMaxChars` | 80 | `TextCardPreview` 只读版本最大展示字数（超出截断 + 省略号） |
  | `kInputMaxChars` | 500 | 用户输入框最大字数 |
  | `kFontSizeLarge / Medium / Small` | 24 / 18 / 16 | 字号自适应 |
  | `kLineHeightLarge / Medium / Small` | 1.4 / 1.35 / 1.3 | 行高自适应 |
  | `kCardEmptyHint` | `'·'` | 只读版本空内容占位符 |
  | `kCardTruncatedSuffix` | `'…'` | 截断省略号 |
- **辅助函数**：
  - `fontSizeFor(int charCount) → double` — 同时被 `_buildCardEditor` 使用
  - `lineHeightFor(int charCount) → double` — 同时被 `_buildCardEditor` 使用
  - `truncateForCard(String text) → String` — 只读版本用

### 1.4 Popup 菜单组件 `TextNoteMenuSheet`

- **路径**：`client/lib/pages/textNote/text_note_menu_sheet.dart`
- **核心组件**：
  - `enum TextNoteMenuMode { textNote, normalPost }` — 菜单返回值枚举
  - `class TextNoteMenuSheet extends StatelessWidget` — 从下往上滑出的菜单
  - `class _MenuItem extends StatelessWidget` — 单条菜单项
- **菜单样式**：
  - 圆角顶部 16，外边距 8
  - 顶部 drag handle（36×4 灰色胶囊）
  - SafeArea 包裹
  - 菜单项高度 56

---

## 2. 入口集成点

### 2.1 底部导航栏中间"+"按钮 → Popup 菜单

- **路径**：`client/lib/pages/home.dart`
- **关键行**：
  - 引入 `text_note_menu_sheet.dart` + `text_note_page.dart`
  - `_switchTab(int targetTab)`：`targetTab == 2` 时改为调用 `_showComposeMenu()`（`home.dart`）
  - `_showComposeMenu()`：`showModalBottomSheet<TextNoteMenuMode>` 弹菜单；返回 `textNote` 则 `Navigator.push(TextNotePage)`，返回 `normalPost` 则 `setState(() => tab = 2)`
  - **变更说明（`change-text-note-handoff`）**：`home.dart` 自身**不**改动 — TextNotePage 内部处理到 ComposePost 的跳转，无需 home.dart 协调；栈结构由 TextNotePage 内的 `pushReplacement` 把 `[HomePage, TextNotePage]` 变成 `[HomePage, ComposePost]`

### 2.2 Feed 页 FAB / 编辑入口（保持不动）

- **Feed FAB**：`client/lib/pages/feed/feed.dart:215-227` — 仍直进 `ComposePost`
- **FeedPostWidget 编辑**：`client/lib/widget/feedpost.dart:1164-1175` — 仍直进 `ComposePost`

> 设计决策：底部 Tab「+」是主要入口，展示 Popup 菜单；FAB / 编辑入口属于快捷场景，保持原路径减少操作步骤。

---

## 3. 状态层（Provider）

无新增 Provider / 状态类。`TextNotePage` 是 `StatefulWidget`，所有状态本地维护（`_isConfirming` 等）：

- **不**直接调用 `PostState.createPost` — 真正的发布在 `ComposePost` 中完成（用户通过 `pushReplacement` 接管后，在 `ComposePost` 右上的「发布」触发同一 `PostState.createPost` 链路）。
- `provider` 包依赖从 `text_note_page.dart` import 列表中清理（`change-text-note-handoff`）。

---

## 4. 服务层（API / 上传）

### 4.1 `PostState.createPost`

- **路径**：`client/lib/state/post.state.dart`
- **关键方法**：
  - `Future<PostCreationResult> createPost(PostModel model, {List<MediaDraftItem>? mediaDrafts, ...})`（`post.state.dart:231`）
  - 内部走 `uploadService.uploadMedia(item.localFile, mediaType: ...)` → `postService.createPost(content, mediaUrls, mediaTypes)`
  - 返回 `PostCreationResult`，含 `isSuccess` / `errorMessage` / `stage`（用于失败定位）

### 4.2 `UploadService.uploadMedia`

- **路径**：`client/lib/services/upload_service.dart`
- **关键方法**：
  - `Future<String> uploadMedia(File file, {required int mediaType, int? durationMs})`（`upload_service.dart:26`）

### 4.3 `MediaDraftItem.fromLocalImage`

- **路径**：`client/lib/model/media_draft_item.dart`
- **关键工厂**：`MediaDraftItem.fromLocalImage(File file, {String? id, int? fileSizeBytes, int? width, int? height})`

---

## 5. 数据模型

| 模型 | 路径 | 用途 |
| --- | --- | --- |
| `PostModel` | `client/lib/model/post.module.dart` | 提交帖子的 DTO（`bio` = 文字内容，`mediaList` 由 `mediaDrafts` 在 `createPost` 内部组装） |
| `MediaDraftItem` | `client/lib/model/media_draft_item.dart` | 把截好的卡片 PNG 包装成可上传的媒体草稿 |
| `UserModel` | `client/lib/model/user.module.dart` | 发帖用户信息（从 `AuthState.userModel` 取） |
| `MediaType.image = 1` | `client/lib/model/post.module.dart:7` | 卡片作为 `image` 类型上传（与现有图片帖子对齐） |

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **生成代码**：`client/lib/l10n/generated/app_localizations*.dart`
- **关键 key 集合**（`change-text-note-handoff` 调整后）：
  | key | 中文 | 英文 | 备注 |
  | --- | --- | --- | --- |
  | `writeText` | 写文字 | Write text | AppBar 标题 |
  | `normalPost` | 普通图文 | Normal post | Popup 菜单第二项 |
  | `textCardHint` | 说点什么... | Say something... | 卡片内 TextField hint |
  | `textCardConfirm` | 确认 | Confirm | **新增**：AppBar 右上按钮文案（替代旧 `post`） |
  | `textCardConfirmFailed` | 发布失败，请重试 | Failed to post, please try again | **重命名**：原 `textCardPublishFailed`；保持 user-facing 文案不变，仅 key 名更准确 |
  | `textCardDiscardTitle` | 放弃这条写文字吗？ | Discard this text? | |
  | `textCardDiscardMessage` | 当前内容尚未发布，返回后不会保留。 | Your draft will not be saved if you leave now. | |
  | `textCardDiscardConfirm` | 放弃 | Discard | |
- **下线 key**：`textCardPublishSuccess`（`TextNotePage` 不再直接发 post，删除 key 与 getter）；`post` 仍保留供其他页面用
- **复用现有 key**：`cancel` / `publishFailedWithReason`（不再被 TextNotePage 引用，但 `ComposePost` 等其他位置仍用，保留）

---

## 7. 主题 / 颜色

- 卡片渐变色为硬编码常量（写在 `kCardGradients`），不依赖 `AppColorsExtension` — 因为是「内容卡片」而非「UI 元素」，跟随小红书的视觉直觉
- 卡片文字色固定白色 + 微阴影，保证在 4 套渐变上的对比度
- UI 层（AppBar / 字数统计 / 选择器边框）通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取
- 入口：`client/lib/theme/app_colors.dart`（`AppColorsExtension` + `AppColors`）

---

## 8. 相关 / 间接依赖

| 依赖 | 路径 | 用途 |
| --- | --- | --- |
| `screenshot` 包 | `pubspec.yaml` | `ScreenshotController` 截图 |
| `path_provider` 包 | `pubspec.yaml` | `getTemporaryDirectory` 临时文件（截图写入 + 上传） |
| ~~`provider` 包~~ | `pubspec.yaml` | **变化**：`text_note_page.dart` 已不再 import `provider`（`change-text-note-handoff` 不再调用 `Provider.of`），但 `provider` 仍保留（`ComposePost` 等其他页面在用） |
| `MediaDraftItem` | `model/media_draft_item.dart` | 把本地文件打包成可上传草稿；同时作为 `ComposePost.initialMediaDrafts` 入参类型 |

> 移除项：v1 原本计划在 AppBar 加「保存到相册」按钮（用 `gal` 包），v1 调整后删除。`gal` 包仍保留在 `pubspec.yaml`（给 `share_profile_sheet.dart` 用），但写文字页面不再依赖。

---

## 9. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改写文字页面 UI | `TextNotePage` / `_buildAppBar` / `_buildCardEditor` | `client/lib/pages/textNote/text_note_page.dart` |
| 修改卡片编辑交互（输入即所见） | `_buildCardEditor` | `client/lib/pages/textNote/text_note_page.dart` |
| 修改卡片只读渲染（Feed 用） | `TextCardPreview` / `kCardGradients` | `client/lib/pages/textNote/text_card_preview.dart` |
| 修改样式选择器 | `TextCardStylePicker` | `client/lib/pages/textNote/text_card_preview.dart` |
| 修改 Popup 菜单 | `TextNoteMenuSheet` / `TextNoteMenuMode` | `client/lib/pages/textNote/text_note_menu_sheet.dart` |
| **修改确认 / 交接流程** | `_confirm` / `_captureCardSafely` / `pushReplacement` / `unfocus` | `client/lib/pages/textNote/text_note_page.dart` |
| **修改 `ComposePost` 媒体入参** | `initialMediaDrafts` | `client/lib/pages/composePost/post.dart` |
| 修改"+"按钮入口 | `_switchTab` / `_showComposeMenu` | `client/lib/pages/home.dart`（`change-text-note-handoff` **不修改** `home.dart`，仅 `TextNotePage` 内部处理跳转） |
| 修改 / 新增渐变样式 | `TextCardStyle` / `kCardGradients` | `client/lib/pages/textNote/text_card_preview.dart` |
| 添加 / 修改文案 | `l10n.textCardConfirm` 等 key | `client/lib/l10n/app_zh.arb` + `app_en.arb`（需跑 `flutter gen-l10n`） |

---

_最后更新：2026-07-16 — `change-text-note-handoff`：把"立即发布"改为"确认 → `pushReplacement` 给 `ComposePost`"。AppBar 右按钮 "发布" → "确认"；`_publish` / `_isSubmitting` / `_canPublish` / `_publishingText` 重命名为 `_confirm` / `_isConfirming` / `_canConfirm` / `_bodyText`；`ComposePost` 新增 `initialMediaDrafts` 入参；l10n 新增 `textCardConfirm`、下线 `textCardPublishSuccess`、重命名 `textCardPublishFailed` → `textCardConfirmFailed`；放行空文字（纯渐变卡合法）；home.dart 入口逻辑保持不变。_