## Purpose

`media-viewer-blurred-bg` capability 描述 `MediaViewerPage` 全屏查看图片时「以图片为基底 + 模糊」的氛围背景契约——图片页采用三层 Stack（cover 模糊底层 + 暗化叠加 + contain 清晰前景），让整屏被图片本身的模糊版本铺满，前景保留清晰原图。视频页豁免，保持纯黑。

> 本文件由已归档 change `media-viewer-blurred-bg` 的 delta 同步生成。

---

## ADDED Requirements

### Requirement: 图片页背景为图片自身的模糊版本

MediaViewerPage 的图片页 MUST 在图片下方渲染一层「图片本身的模糊铺满版」作为氛围背景，模糊版本与前景原图来自同一 URL。

#### Scenario: 加载完成后模糊背景可见

- **WHEN** 进入图片页且图片已加载完成
- **THEN** 整屏 MUST 被该图片的模糊版本铺满（BoxFit.cover），模糊版本与前景清晰图来自同一 url

#### Scenario: 模糊版本使用 ImageFilter.blur 而非 BackdropFilter

- **WHEN** 实现模糊背景层
- **THEN** MUST 使用 `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30))` 直接对原图做模糊装饰；MUST NOT 使用 `BackdropFilter`（BackdropFilter 采样屏幕像素，性能开销远大于直接装饰）

### Requirement: 模糊半径 sigmaX/Y = 30

模糊背景层的 MUST 使用 `sigmaX: 30, sigmaY: 30` 的高斯模糊半径。

#### Scenario: 模糊程度适中

- **WHEN** 用户查看一张普通分辨率图片（≤ 4K）
- **THEN** 背景 MUST 呈现明显模糊但仍可辨认原图整体色调与氛围，sigma 偏离 30 的 ±10 范围内需视为不符合规格

### Requirement: 暗化叠加层 alpha = 0.25

模糊背景层之上 MUST 叠加一层 `Container(color: Colors.black.withValues(alpha: 0.25))` 暗化层，让前景清晰原图视觉更突出。

#### Scenario: 暗化层视觉分层

- **WHEN** 模糊背景与前景原图同时显示
- **THEN** 前景原图 MUST 比背景模糊图有更高的视觉对比度，避免两者"打架"

#### Scenario: 暗化不破坏背景氛围

- **WHEN** 暗化叠加层渲染完成后
- **THEN** 背景的色调 MUST 仍可辨认（MUST NOT 完全黑掉）

### Requirement: 前景原图保留 BoxFit.contain 居中 + InteractiveViewer

前景 MUST 保持 `Center > InteractiveViewer(minScale: 0.5, maxScale: 4.0) > CachedNetworkImage(fit: BoxFit.contain)` 的渲染结构。

#### Scenario: 前景原图清晰可见

- **WHEN** 图片加载完成
- **THEN** 前景 MUST 显示完整清晰原图（不被裁切，保留原始宽高比），居中显示

#### Scenario: 双指缩放行为不变

- **WHEN** 用户在前景图上双指缩放 / 平移
- **THEN** InteractiveViewer 行为 MUST 与改动前完全一致（minScale 0.5 / maxScale 4.0）

#### Scenario: 缩放后前景不会"溢出"模糊背景覆盖范围

- **WHEN** 用户将前景原图放大到 4x
- **THEN** 模糊背景层仍 MUST 覆盖整个屏幕（cover 模式铺满），前景图即使放大也不超出模糊背景的视觉范围

### Requirement: 视频页保持纯黑背景（豁免）

视频页 MUST 保持当前的纯黑背景，不应用模糊背景效果。

#### Scenario: 视频播放时无模糊背景

- **WHEN** PageView 滑动到或停留在一个视频 item
- **THEN** 视频下方 MUST 仍为黑色（`Colors.black`），MUST NOT 渲染模糊背景层

#### Scenario: 图片 / 视频切换时背景立即切换

- **WHEN** 用户在 PageView 中从图片页滑到视频页（反之亦然）
- **THEN** 当前页背景 MUST 立即切换为对应模式（图片→模糊、视频→黑色）

### Requirement: 多图 PageView 横滑时模糊背景同步切换

当 PageView 在多个图片 item 之间横滑时，模糊背景 MUST 与前景清晰图同步切换（同一 PageController 驱动）。

#### Scenario: 横滑时背景跟随

- **WHEN** 用户从第 1 张图滑到第 2 张图
- **THEN** 模糊背景层 MUST 同步从第 1 张的模糊版本过渡到第 2 张的模糊版本，与前景清晰图同步

#### Scenario: 邻页预渲染

- **WHEN** PageView 渲染当前页 + 邻页
- **THEN** 邻页的模糊背景 MUST 已被预渲染（PageView keep alive 默认行为），滑动时无白屏闪烁

### Requirement: 现有功能不受影响

以下现有功能 MUST 保持完全不变：

- 顶部浮层（X 按钮 + "n/N" 页码）
- 右下角旋转按钮（仅视频横屏）
- 底部互动统计横条（点赞 / 回复 / 转发 / 分享）
- PostState 订阅与 4 按钮实时同步
- Scaffold 的 `backgroundColor: Colors.black` 仍作为图片加载前的兜底色

#### Scenario: 图片加载前显示纯黑

- **WHEN** 用户进入图片页但图片尚未加载完成
- **THEN** Scaffold 的黑色背景 MUST 显示，避免在图片加载期间出现白屏或透明

#### Scenario: 现有 UI 元素不受影响

- **WHEN** 顶部浮层 / 右下角旋转按钮 / 底部横条 渲染时
- **THEN** 它们 MUST 在新的模糊背景之上正常显示，视觉层次清晰
