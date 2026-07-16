## Context

`MediaViewerPage`（`client/lib/pages/media/media_viewer_page.dart`）当前全屏查看图片时使用纯黑背景（`Scaffold(backgroundColor: Colors.black)`），图片以 `BoxFit.contain` 居中显示在 `_ImageViewerItem` 中。视觉效果比较生硬——整页 70%+ 面积是死黑色块，图片与背景之间缺乏视觉呼应。

视频页（`_VideoViewerItem`）保持纯黑（视频本身有旋转按钮、播放控件、进度条等复杂 UI，模糊背景容易冲突）。

本 change 仅改动图片页（`_ImageViewerItem`）的内部结构：把单层 CachedNetworkImage 替换为三层 Stack（cover 模糊 + 暗化 + contain 清晰）。

## Goals / Non-Goals

**Goals**
- 图片页背景从「纯黑」变为「图片本身的模糊铺满版」
- 前景保留清晰的原图（contain + InteractiveViewer 缩放）
- 模糊版本与前景原图来自同一 URL，颜色氛围统一
- 多图 PageView 同步切换，背景跟随
- 视频页、现有 UI 元素、PostState 订阅、4 按钮行为 全部不动

**Non-Goals**
- 不改动视频页
- 不改动 `_VideoViewerItem` 的任何代码
- 不改动顶部浮层、右下旋转按钮、底部互动横条
- 不改动 PostModel / PostState / 调用方
- 不引入新依赖（复用 Flutter 自带 `ImageFiltered` + `ImageFilter.blur`，复用 `cached_network_image`）
- 不写 Android 适配
- 不做模糊强度的运行时配置（sigma 固定 30）

## Decisions

### 决策 1：用 `ImageFilter.blur` 装饰原图，而不是 `BackdropFilter`

**选择**：用 `ImageFiltered(imageFilter: ImageFilter.blur(...))` 直接包裹底层的 `Container(decoration: BoxDecoration(image: ...))`。

**理由**：
- `ImageFiltered` 对已经渲染好的原图做像素级模糊装饰，是 GPU 加速的纹理处理
- `BackdropFilter` 需要采样「下方所有 widget」的屏幕像素，实时合成，开销远高于 ImageFiltered
- 我们的目标是模糊「原图本身」，不是模糊「下面的合成结果」，所以 ImageFiltered 语义上更对、性能更好

**替代方案考虑**：
- `BackdropFilter(filter: ImageFilter.blur(...), child: Image(...))` → 错用，BackdropFilter 不会模糊 Image 自己
- 直接用 `Container(filter: ...)`（Flutter 早期 API）→ 已废弃，等价于 ImageFiltered
- 在服务端预渲染模糊版本 → 增加带宽与缓存成本，不必要

### 决策 2：模糊半径 sigma 30

**选择**：`sigmaX: 30, sigmaY: 30`。

**理由**：
- Spotify / Apple Music / 小红书大图预览普遍使用 sigma 25-40
- sigma 太小（< 20）看不出明显模糊，氛围感弱
- sigma 太大（> 50）模糊后边缘会出现"色块外溢"现象，且 GPU 开销明显上升
- 30 是常见平衡值，能看出原图整体色调，但完全看不清细节

**替代方案考虑**：
- sigma 20 → 太轻
- sigma 40-50 → 性能开销上升，色块外溢
- 动态根据屏幕尺寸计算 sigma → 过度设计，单一值足够

### 决策 3：暗化叠加层 alpha 0.25

**选择**：`Container(color: Colors.black.withValues(alpha: 0.25))`。

**理由**：
- 让前景清晰原图比背景模糊图有更高对比度，避免视觉混乱
- alpha 0.25 = 75% 原色 + 25% 黑色，仍能保留背景的色调氛围
- 不至于把背景完全压暗到看不出原图颜色

**替代方案考虑**：
- alpha 0（不加暗化层）→ 前景与背景对比度不足，浅色图看不清前景
- alpha 0.5+ → 背景被压得太暗，氛围感消失
- 用渐变替代暗化 → 过度设计

### 决策 4：cover 模糊铺满 + contain 清晰居中（双层结构）

**选择**：底层用 `BoxFit.cover` 铺满 + 模糊，前景用 `BoxFit.contain` 居中 + InteractiveViewer。

**理由**：
- cover 保证整屏被填满，没有黑边
- contain 保证原图完整可见（不被裁切）
- 双层结构清晰：背景"氛围"、前景"主体"
- InteractiveViewer 缩放时前景不会"溢出" cover 模糊图覆盖范围（cover 图本身就比 contain 图大）

**替代方案考虑**：
- 单层 cover 铺满（不再 contain）→ 用户看不到原图全貌，被裁切
- 单层 contain 居中（不模糊）→ 当前行为，氛围弱
- 两层都用 contain 居中 → 模糊图也会留黑边，氛围感弱

### 决策 5：视频页豁免，不应用模糊背景

**选择**：`_VideoViewerItem` 完全保持原样，纯黑背景。

**理由**：
- 视频页 UI 复杂：右下角旋转按钮、视频控件、VideoProgressIndicator
- 模糊背景 + 这些控件容易产生视觉冲突（控件浮在模糊视频上，对比度问题）
- 视频本身有动态画面，背景模糊会更分散注意力
- 保持纯黑能让视频视觉更聚焦

**替代方案考虑**：
- 视频也用模糊背景 → 视觉冲突、性能开销（视频本身就重）
- 视频第一帧模糊作为静态背景 → 实现复杂、效果不自然

### 决策 6：在 PageView itemBuilder 内分支处理图片 / 视频

**选择**：`PageView.builder.itemBuilder` 中，`item.isVideo` 走原 `_VideoViewerItem`，否则走新 `_ImageViewerPage`。

**理由**：
- 改动局部，仅 `_ImageViewerItem` 重构
- 视频分支零改动，回归风险最小
- 复用现有 PageController 同步机制

**替代方案考虑**：
- 把视频也改成 Stack 模糊+前景 → 不必要的复杂度

### 决策 7：复用 `CachedNetworkImageProvider` 而不是 `CachedNetworkImage`

**选择**：底层模糊用 `CachedNetworkImageProvider(url)` 作为 `BoxDecoration.image` 的数据源。

**理由**：
- `CachedNetworkImageProvider` 是 provider 形式，可以直接喂给 `BoxDecoration.image`
- `CachedNetworkImage` 是 widget 形式，会受 `BoxFit` 影响
- 我们需要的是「图片数据 + 自己控制 fit」，provider 更灵活
- CachedNetworkImage 内部也是用 CachedNetworkImageProvider + RawImage，拆开用性能等价

**替代方案考虑**：
- `CachedNetworkImage(fit: BoxFit.cover)` 包在 ImageFiltered 里 → BoxFit 被 cover 锁死，无法灵活
- `Image.network(url)` → 没有缓存，每次重新下载

## Risks / Trade-offs

- **[Risk] 模糊性能开销** → ImageFiltered 在 GPU 上做模糊，单帧开销约 1-3ms（iPhone 12+），中低端设备（iPhone X 之前）可能掉帧。Mitigation: sigma 30 是保守值；如确有问题可降到 sigma 25；PageView keep alive 只渲染当前+邻页，影响范围可控
- **[Risk] 双指放大时前景溢出 cover 模糊图** → cover 模式本就铺满整屏，前景 InteractiveViewer 最大 4x 缩放仍在 cover 图覆盖范围内（contain 图比 cover 图小，放大后 contain 图填满的部分仍 < cover 图覆盖的范围）。Mitigation: 已通过 spec 5.4 约束
- **[Risk] 图片加载慢时背景延迟出现** → 用户看到「先黑 → 后模糊」的过渡。Mitigation: Scaffold 黑色背景保留作为加载兜底；CachedNetworkImage 已有缓存
- **[Risk] 极浅色图片 + 暗化 0.25 后氛围感弱** → 浅色图（如纯白）模糊后加暗化会显得灰白。Mitigation: 这是预期效果（暗化就是为了让前景更突出），alpha 0.25 不会完全压死色调
- **[Trade-off] 多图 PageView 横滑时双层图片同时渲染** → 内存翻倍（每张图 2 个 Image 实例）。Mitigation: CachedNetworkImage 共享底层缓存，只多一份解码纹理；3-4 张图时内存增量 < 30MB
- **[Risk] 视频横屏模式下，模糊背景不出现是预期行为，但用户可能疑惑** → 已在 spec 中明确视频豁免
