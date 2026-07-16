## Why

`MediaViewerPage` 全屏查看图片时，当前背景是纯黑（Scaffold `backgroundColor: Colors.black`），图片以 `BoxFit.contain` 居中显示。视觉效果比较生硬——整页 70%+ 的面积是死黑色块，图片与背景之间缺乏视觉呼应，用户体验上"沉浸感"不足。

希望优化为「以图片为基底 + 模糊」的氛围背景：让图片本身的模糊版本铺满整屏作为底色，前景保留清晰的原图（contain 居中 + InteractiveViewer 缩放），整页色彩饱和、有"沉浸氛围"。Spotify / Apple Music / 小红书大图预览均采用此风格。

## What Changes

- **新增**：在 `MediaViewerPage` 的图片页（`_ImageViewerItem`）中，将单层 CachedNetworkImage 替换为三层 Stack：
  - 底层：`ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30))` 包 `Container(decoration: BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover)))` —— 图片 cover 铺满 + 高斯模糊
  - 中间层：`Container(color: Colors.black.withValues(alpha: 0.25))` —— 暗化叠加，让前景原图视觉更突出
  - 顶层：保留原 `Center > InteractiveViewer > CachedNetworkImage(fit: BoxFit.contain)` —— 清晰原图，支持双指缩放/平移
- **新增**：将当前 `_ImageViewerItem` 重命名为 `_ImageViewerPage`，内部改为返回该 Stack
- **保护**：视频页（`_VideoViewerItem`）**完全不变**，保持纯黑背景（视频本身交互复杂：旋转、播放控件、进度条，模糊背景容易冲突）
- **保护**：顶部浮层、右下角旋转按钮、底部互动统计横条、PageView 多图横滑、InteractiveViewer 双指缩放、PostState 订阅与 4 按钮行为 全部保持不变
- **保护**：`Scaffold(backgroundColor: Colors.black)` 仍保留作为兜底色——图片加载完成前显示纯黑，加载完成后被模糊背景覆盖

## Capabilities

### New Capabilities
- `media-viewer-blurred-bg`: MediaViewerPage 图片页的氛围背景契约——双层结构（cover 模糊底层 + contain 清晰前景）、模糊半径 30、暗化叠加 0.25、视频豁免

### Modified Capabilities
无（`media-viewer-interaction-bar` 是独立的 change 还在进行中，互不影响）

## Impact

**受影响代码**
- `client/lib/pages/media/media_viewer_page.dart` — 核心改动，仅 `_ImageViewerItem` 单文件内部结构重组

**不受影响**
- 视频页（`_VideoViewerItem`）
- 顶部浮层 / 右下角旋转按钮 / 底部互动统计横条
- 调用方（FeedPost / PostDetailPage / Profile 的 `_openMediaViewer`）
- `PostModel`、`PostState`、i18n、AppColorsExtension

**新增依赖**
- 无（复用现有 `cached_network_image`、Flutter 自带 `ImageFiltered` / `ImageFilter`）

**性能考量**
- `ImageFilter.blur` 每帧重渲染，开销中等；sigma 30 是常见平衡值
- PageView 自带 keep alive，只有当前页 + 邻页参与渲染
- 不引入 `BackdropFilter`（性能更差），而是直接对原图做模糊装饰
