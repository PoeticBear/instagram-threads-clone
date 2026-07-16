## 1. 数据 & 常量层

- [x] 1.1 在 `client/lib/pages/textNote/text_card_preview.dart` 顶部定义 4 套渐变预设常量 `kCardGradients`(`warmOrange` / `purpleBlue` / `mint` / `darkNight`),并暴露一个 `enum TextCardStyle { warmOrange, purpleBlue, mint, darkNight }` + `kDefaultCardStyle = TextCardStyle.warmOrange`
- [x] 1.2 定义字号自适应常量 `_fontSizes`(≤40→24 / 41~80→18 / >80→16)和行高常量 `_lineHeights`
- [x] 1.3 定义卡片最大字数常量 `_maxChars = 80`、最大可输入字数常量 `_maxInputChars = 500`

## 2. 卡片预览组件

- [x] 2.1 实现 `TextCardPreview` StatelessWidget(`client/lib/pages/textNote/text_card_preview.dart`):接受 `text` + `style` + `width` 三个参数;渲染 3:4 比例的 `Container`,背景为对应渐变 + 居中白色文字
- [x] 2.2 在 `TextCardPreview` 内实现字号自适应逻辑(根据 `text.length` 选择 `_fontSizes` 中的字号);实现超长截断(> 80 字截断 + 末尾加 `…`)
- [x] 2.3 文字样式:`color: white` / `fontWeight: w600` / 微阴影(`shadows: [Shadow(color: black54, blurRadius: 4)]`)保证对比度
- [x] 2.4 实现 `TextCardStylePicker` Widget:横向滚动的 4 张缩略图(每张 64×64,圆角 8),点击切换选中态(选中加 2px 边框高亮 + 缩放 1.05)

## 3. Popup 菜单组件

- [x] 3.1 实现 `TextNoteMenuSheet` StatelessWidget(`client/lib/pages/textNote/text_note_menu_sheet.dart`):从下往上滑出的菜单,列出「写文字」「普通图文」两个入口(每条带 Icon + 标题)
- [x] 3.2 菜单样式:圆角顶部(16)+ 顶部 drag handle(36×4 灰色胶囊)+ SafeArea 包裹 + 菜单项高度 56,点击触发 `Navigator.pop(context, mode)` 返回 `TextNoteMenuMode` 枚举

## 4. 写文字主页面

- [x] 4.1 创建 `client/lib/pages/textNote/text_note_page.dart`,定义 `class TextNotePage extends StatefulWidget`;持有状态:`_textController` / `_selectedStyle` / `_isSubmitting` / `_isSaving`
- [x] 4.2 实现 AppBar:返回按钮(带关闭确认)+ 「写文字」标题 + 「保存到相册」IconButton + 「发布」TextButton
- [x] 4.3 实现关闭确认对话框 `_showDiscardDialog`(只有有内容时才弹):「取消」「丢弃」两个选项,中文化通过 `AppLocalizations`
- [x] 4.4 页面布局:Stack(ScreenshotController 包裹的 TextCardPreview 居中) + Column(底部输入框 TextField + 样式选择器 TextCardStylePicker)
- [x] 4.5 实现 TextField:多行(maxLines: 5)、字数统计、绑定 `_textController`,键入时 `setState(() {})` 触发预览更新;右上角实时显示字数 / `_maxInputChars`
- [x] 4.6 实现 `_canPublish` getter:`_textController.text.trim().isNotEmpty && !_isSubmitting`
- [x] 4.7 实现 `_saveToGallery` 方法:`ScreenshotController.capture()` → 写临时文件 → `Gal.putImage`;成功 toast `savedToGallery`,失败 toast `saveFailed`
- [x] 4.8 实现 `_publish` 方法:截图 → MediaDraftItem → `PostState.createPost(model, mediaDrafts: [draft])`(内部走 uploadMedia + post/create,与 ComposePost 一致)
- [x] 4.9 发布 / 保存相册都用 `addPostFrameCallback` 包裹截图调用,确保渲染完成后再 capture(对应 design R3)
- [x] 4.10 处理 `dispose`:释放 `_textController`;`ScreenshotController` 自身无需 dispose;TextField 控制器必须 dispose

## 5. 首页底部导航栏改造

- [x] 5.1 修改 `client/lib/pages/home.dart`:`_switchTab` 中 `targetTab == 2` 改为先 `showModalBottomSheet` 弹 `TextNoteMenuSheet`,根据返回值决定 push `TextNotePage` 或切换 `tab = 2` 进入 `ComposePost`
- [x] 5.2 不动现有 `_composePostKey` 草稿拦截逻辑(「普通图文」入口仍走原路径,草稿拦截保留)
- [x] 5.3 不动 Feed 页 FAB(`feed.dart:215`)和 FeedPostWidget 编辑入口(`feedpost.dart:1164`),保持直进 `ComposePost`

## 6. 国际化文案

- [x] 6.1 更新 `client/lib/l10n/app_zh.arb`:新增 `writeText` / `normalPost` / `textCardHint` / `textCardPublishSuccess` / `textCardPublishFailed` / `textCardDiscardTitle` / `textCardDiscardMessage` / `textCardDiscardConfirm`(其余如 savedToGallery / saveFailed 复用现有 key)
- [x] 6.2 更新 `client/lib/l10n/app_en.arb`:同样的 key 英文翻译
- [x] 6.3 跑 `flutter gen-l10n` 重新生成 `app_localizations*.dart`

## 7. 文档

- [x] 7.1 创建 `docs/code-locations/write-text.md`:汇总所有写文字相关代码位置(主页面 / 卡片组件 / 菜单组件 / 渐变常量 / i18n key),遵循 `docs/code-locations/publish-post.md` 的章节结构
- [x] 7.2 更新 `docs/code-locations/publish-post.md`:在「入口集成点」章节追加 2.4 节「写文字 Popup 入口」,指向 `home.dart:_switchTab` + `text_note_menu_sheet.dart`

## 8. 验证

- [x] 8.1 `cd client && flutter analyze` 无新增报错(项目历史 warning 不在范围)
- [x] 8.2 `cd client && flutter build ios --debug --no-codesign` 构建通过(Built build/ios/iphoneos/Runner.app)
- [ ] 8.3 iOS 模拟器手动验证:点"+" → 弹菜单 → 选"写文字" → 输入文字 → 切换样式 → 点"发布"(验证 Feed 出现新帖)
- [ ] 8.4 边界验证:输入 0 / 1 / 40 / 80 / 200 字分别看卡片字号表现;输入含 `\n` 的多行文字看换行渲染

---

## 9. v1 调整(follow-up)

- [x] 9.1 修「取消」换行:`Padding > Center` 嵌套把可用宽度压成 24px 触发 Text 换行。改为 `Container(padding + alignment: center)` + `maxLines: 1, softWrap: false`。
- [x] 9.2 移除「保存到相册」按钮:AppBar action 删除;`_saveToGallery` / `_isSavingToGallery` / `gal` import 全部清理。
- [x] 9.3 改为 inline 编辑（输入即所见）:删除底部 TextField + `_buildTextInput`;新增 `_buildCardEditor` 把 TextField 直接嵌在 Screenshot 包裹的渐变卡片里。`_publish` 增加 `FocusScope.unfocus()` 收键盘 + 隐光标,`_captureCardSafely` 的 `delay` 调到 80ms。`TextCardPreview` 只读组件保留作为 Feed 渲染备选,`TextCardStylePicker` / `kCardGradients` / 字号自适应函数继续使用。
- [x] 9.4 `docs/code-locations/write-text.md` 同步更新(inline 编辑说明 + 删除「保存到相册」相关段)。
- [x] 9.5 analyze + iOS build 复测通过(28.7s)。