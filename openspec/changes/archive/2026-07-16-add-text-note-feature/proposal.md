## Why

当前客户端的发帖路径只有一条——点底部「+」直接进入 `ComposePost`,适合图文 / 视频 / 投票类内容,但**纯文字短帖**(没有配图、只想写几句话)的体验缺失:用户被迫要么纯文本发布(Feed 流里没有视觉锚点),要么必须选一张图。小红书的「写文字」功能填补了这条产品缝隙——纯文字也能生成一张排版美观的「文字卡片」作为视觉承载体。

此外,目前「+」按钮没有 Popup 菜单,后续若新增发帖模式(投票 / 引用 / 长文 / 视频笔记等)都需要入口扩展点。本次改动一并把「+」改为 Popup 菜单,留出后续扩展位。

## What Changes

- **新增「+」按钮 Popup 菜单**:`pages/home.dart` 底部 Tab 点击逻辑改为弹出菜单(从下往上滑出),第一项「写文字」跳新页面,「普通图文」走现有 `ComposePost`。原有 FAB / Feed 页 FAB 入口仍直进 `ComposePost`,保持兼容。
- **新增「写文字」页面** `pages/textNote/text_note_page.dart`:实时预览 3:4 渐变文字卡片 + 多行 TextField 输入框 + 4 套渐变样式选择器(纯代码绘制)。
- **新增卡片渲染组件** `pages/textNote/text_card_preview.dart`:封装渐变背景 + 居中文字 + 字号自适应(≤40 字 24sp / 40-80 字 18sp / >80 字 16sp + 截断省略号),支持 `\n` 换行,无作者水印。
- **新增 Popup 菜单组件** `pages/textNote/text_note_menu_sheet.dart`:从下往上滑出的菜单,列出发帖模式入口。
- **新增 4 套预设渐变**:`warmOrange` / `purpleBlue` / `mint` / `darkNight`,颜色常量写在 `text_card_preview.dart` 顶部。
- **新增 i18n key**:`writeText` / `normalPost` / `textCardHint` / `postCardStyle` / `textCardSaveToGallery` / `textCardPublishSuccess` / `textCardPublishFailed`,更新 `app_zh.arb` 和 `app_en.arb`。
- **新增代码定位文档** `docs/code-locations/write-text.md`,汇总新页面的所有代码位置;更新 `docs/code-locations/publish-post.md` 标注新入口。

## Capabilities

### New Capabilities

- `text-note`:小红书风格的「写文字」功能完整链路——底部「+」按钮 Popup 菜单入口、文字卡片实时预览、4 套预设渐变样式选择、文字内容输入与排版、复用 `createPost` 发布并把渲染卡片作为 image media 上传、可选保存到相册。

### Modified Capabilities

无(本次仅新增能力,不动现有 spec 的需求)。

## Impact

**新增 / 修改文件**

- 新增:`client/lib/pages/textNote/text_note_page.dart`
- 新增:`client/lib/pages/textNote/text_card_preview.dart`
- 新增:`client/lib/pages/textNote/text_note_menu_sheet.dart`
- 新增:`docs/code-locations/write-text.md`
- 修改:`client/lib/pages/home.dart`(`+` Tab 点击逻辑)
- 修改:`client/lib/l10n/app_zh.arb`、`client/lib/l10n/app_en.arb`(新增 key)
- 修改:`docs/code-locations/publish-post.md`(标注新入口)

**依赖包**(`pubspec.yaml`)

- `screenshot` — Widget 截图(已在 share_profile_sheet.dart 使用,无需新加)
- `gal` — 保存到相册(已在 share_profile_sheet.dart 使用,无需新加)
- `path_provider` — 临时文件(已在 share_profile_sheet.dart 使用,无需新加)
- `cached_network_image` / `provider` / `iconsax` — 已有依赖

**服务端**

- 复用现有 `POST /post/create` 接口,`mediaType=1`(image)。
- 不需要服务端配合新增接口或字段。

**平台**

- 仅维护 iOS,Android 不适配(对齐项目规范)。

**状态层**

- 写文字页面是本地 StatefulWidget,无需新增 Provider / 状态类。
- 发布时复用现有 `PostState.createPost`,不引入新状态。