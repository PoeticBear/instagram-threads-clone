## Context

项目是一个 Flutter 客户端,Instagram Threads 风格,只维护 iOS。发帖流程目前只有 `ComposePost` 一条路径(`client/lib/pages/composePost/post.dart`,1667 行),承载图文 / 视频 / GIF / 投票 / 草稿 / 位置 / 定时 / 回复权限等所有发帖模式。

用户希望在 `ComposePost` 之外增加一条**纯文字短帖**路径,体验上对齐小红书的「写文字」功能:
- 「+」按钮从直进 `ComposePost` 改为弹 Popup 菜单
- 菜单第一项「写文字」进入新页面
- 新页面是文字编辑器 + 实时预览卡片 + 4 套渐变样式选择器
- 文字卡片用 Flutter Widget 渲染 + `screenshot` 包截图
- 发布复用现有 `PostService.createPost`(零服务端改动)

`share_profile_sheet.dart` 已经实现了「Widget 截图 → 保存到相册」的完整链路(`screenshot` + `gal` + `path_provider`),可作为本次的参考实现,基本技术风险已被验证。

## Goals / Non-Goals

**Goals**

- 在「+」按钮处提供 Popup 菜单,「写文字」是新入口,「普通图文」保留并指向 `ComposePost`
- 「写文字」页面提供流畅的实时预览(键入即更新卡片)
- 4 套渐变卡片预设,纯代码绘制,不需要图片素材
- 卡片 3:4 比例,纯文字居中,支持 `\n` 换行,无作者水印
- 字号自适应:保证卡片视觉协调
- 发布流程:`ScreenshotController` → PNG bytes → `UploadService.uploadMedia` → `PostService.createPost`
- 顺便支持「保存到相册」入口,复用 `gal` 包
- 全 i18n 化,中英文双语同步
- 完全 iOS 适配,不写 Android 代码

**Non-Goals**

- 不实现「写长文」(本期不开发,后续单独 change)
- 不做卡片模板切换 / 字体选择 / 字号手动调
- 不引入新的服务端接口或字段
- 不引入新的 Provider / 状态类
- 不实现写文字的草稿(纯内存,关闭即丢)
- 不做卡片分享(系统 Share Sheet)、不生成单独的 `mediaType=5` 字段

## Decisions

### 决策 1: Popup 菜单的容器选择

**选择**:`showModalBottomSheet`(`client/lib/pages/textNote/text_note_menu_sheet.dart`)

**理由**:
- 项目内已有大量 `showModalBottomSheet` 用法(`ComposePost._showDraftListSheet`、`_showReplyTypeSheet` 等),统一风格
- 从下往上滑出的视觉正好是 iOS Action Sheet 风格,与小红书一致
- 不用 `CupertinoActionSheet`,因为它的样式偏「系统级确认」,而我们要的是「选模式」,需要更自由的布局

**否决**:
- `showCupertinoModalPopup` — 通常用于系统日期选择器,放菜单视觉不协调
- 全屏 `Navigator.push` — 重量级,不适合快捷入口

### 决策 2: 卡片渲染用 Widget 截图,而非 Canvas 自绘

**选择**:用 Flutter `Container` + `BoxDecoration` + `LinearGradient` 渲染卡片 Widget,再用 `ScreenshotController.capture()` 截图成 PNG。

**理由**:
- 复用 `screenshot` 包,`share_profile_sheet.dart` 已验证可用
- 文字渲染用系统 TextPainter 比 Canvas 简单得多,自动支持中文 / emoji / 多语言
- 字号自适应、排版、断行直接用 `Text` Widget 自带能力
- 后续要扩展渐变 / 字体 / 装饰,改 Widget 即可,不需重写绘制逻辑

**否决**:
- `CustomPainter` 自绘 — 工作量大,字号自适应、断行都要自己实现
- 服务端渲染 — 用户明确说服务端不参与

### 决策 3: 字号自适应阈值(40 / 80)

**选择**:
- 字数 ≤ 40:字号 24sp,行高 1.4
- 字数 41 ~ 80:字号 18sp,行高 1.35
- 字数 > 80:字号 16sp,行高 1.3,且文字截断到 80 字 + `...`

**理由**:
- 24sp 在 3:4 卡片上,单行约可容纳 14 ~ 16 个汉字;40 字 ≈ 3 行,视觉饱满
- 18sp 在 3:4 卡片上,单行约可容纳 18 ~ 20 个汉字;80 字 ≈ 4 行,仍可读
- 超过 80 字强制截断,避免溢出破坏视觉(避免出现「卡片装不下」的尴尬)

**否决**:
- 单一字号 + 卡片高度自动撑开 — 卡片宽高比固定 3:4,字号大必然溢出
- 实时动态字号(每字计算) — 实现复杂,收益小

### 决策 4: 4 套渐变预设的具体颜色

**选择**:
```dart
const warmOrange  = [Color(0xFFFF9966), Color(0xFFFF5E62)]; // 暖橙
const purpleBlue  = [Color(0xFF8E2DE2), Color(0xFF4A00E0)]; // 紫蓝
const mint        = [Color(0xFF11998E), Color(0xFF38EF7D)]; // 薄荷
const darkNight   = [Color(0xFF232526), Color(0xFF414345)]; // 暗夜
```

**理由**:
- 暖橙 / 紫蓝 / 薄荷 / 暗夜覆盖了**暖、冷、绿、灰**四象限,任一类型的文字都至少有一套合适的背景
- 4 套够看,选择器横向滚动不重
- 渐变方向统一为 `begin: Alignment.topLeft, end: Alignment.bottomRight`(左下到右上),保证视觉一致

**否决**:
- 8 套以上 — 选择器滚动冗长,首屏只能看到 3~4 个
- 用户自定义颜色 — 本期不做

### 决策 5: 媒体类型固定为 `mediaType=1`(image)

**选择**:`media_urls=[cardUrl]` + `media_types=[1]`

**理由**:
- 客户端上传的就是 PNG 图片(渲染卡片截图),对服务端而言只是一张普通图片
- 后端已有完整 image 处理链路(上传 / 压缩 / 缩略图 / Feed 渲染),零侵入
- 即便 `MediaType.textAttachment = 5` 常量已在前端定义,后端是否支持仍是未知数

**否决**:
- `mediaType=5` — 服务端是否已实现 type=5 的存储与渲染不可知,本期不冒险
- 完全不上传图片,只传文字 — 失去「文字卡片」的视觉价值

### 决策 6: 「+」按钮行为改动 vs 兼容

**选择**:底部 Tab「+」按钮点击改为弹 Popup;**Feed 页 FAB / 编辑帖子入口保持直进 `ComposePost`** 不动。

**理由**:
- 底部 Tab「+」是「主要」入口,适合展示完整菜单
- FAB 入口 / 编辑入口属于「快捷」场景,继续直进 `ComposePost` 减少操作步骤
- 后续若 Popup 菜单里加更多模式(投票、引用、视频),FAB / 编辑入口可按需升级

**否决**:
- 全部统一弹 Popup — 编辑帖子入口弹菜单很奇怪(用户改自己发的图文,为什么还要选「写文字」?)
- 完全保留直进 `ComposePost` — 失去 Popup 菜单的产品价值

### 决策 7: 不引入新的 Provider / 状态类

**选择**:`TextNotePage` 是 `StatefulWidget`,所有状态(text / selectedStyle / isSubmitting)都在本地维护;发布时直接 `Provider.of<PostState>(context, listen: false)` 复用。

**理由**:
- 写文字页面是「短生命周期、单一用户」的,本地状态足够
- 新建 Provider 会增加启动开销、复杂度,收益不显
- 已有 `PostState` 完全够用,`createPost` 接口签名也匹配

## Risks / Trade-offs

- **[R1] 截图分辨率与 Feed 显示不匹配**  
  → 卡片渲染尺寸按 3:4 比例,默认宽度按设备宽度,导出 PNG 通常 1080×1440 @2x/3x,Feed 渲染端需要支持该尺寸。Mitigation:服务端 image 处理已有自动压缩链路,如果效果不好再调导出尺寸(`ScreenshotController` 支持 `pixelRatio` 参数)。
  
- **[R2] 渐变色 + 文字对比度问题**  
  → 4 套渐变都是「中等到深」的背景,白色文字对比度都 ≥ 4.5:1(AA 级),但 `darkNight` 渐变(`#232526 → #414345`)在弱光下偏暗,可能让文字难读。Mitigation:文字加 `fontWeight: w600` + 微阴影(`shadows: [Shadow(color: black54, blurRadius: 4)]`),增加可读性。

- **[R3] 卡片截图时机问题**  
  → 用户点击「发布」时,需要先等卡片完全渲染再截图。如果在 `setState` 后立刻截图,可能截到旧内容。Mitigation:用 `WidgetsBinding.instance.addPostFrameCallback` 包裹截图调用,确保当前帧渲染完成后再 capture。
  
- **[R4] 「写文字」页面与其他页面的返回栈管理**  
  → 用户从 Feed → 弹 Popup → 写文字页 → 发布成功 → 应该回到 Feed。Mitigation:`Navigator.push` 用 `MaterialPageRoute`(默认行为);发布成功后 `Navigator.popUntil((r) => r.isFirst)` 或 `Navigator.pop()` 回到首页(已实现方案见 tasks)。
  
- **[R5] 草稿功能暂未实现**  
  → 用户关闭页面 / 切后台时未保存的写文字内容会丢失,与现有 `ComposePost` 的「自动保存草稿」行为不一致。Mitigation:在 AppBar 关闭按钮处给一个「确认丢弃」对话框,提示用户当前内容未保存;本期明确告知不提供草稿(可在 AppBar 显示「不保存草稿」标签)。

## Open Questions

无 — 所有关键决策已与用户确认。