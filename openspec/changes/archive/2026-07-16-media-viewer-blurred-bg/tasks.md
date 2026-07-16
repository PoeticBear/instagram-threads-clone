## 1. 重构 _ImageViewerItem 为双层 Stack 结构

- [x] 1.1 在 `client/lib/pages/media/media_viewer_page.dart` 中，将 `_ImageViewerItem` 类重命名为 `_ImageViewerPage`（更准确地表达"整页布局"语义）
- [x] 1.2 新 `_ImageViewerPage.build` 返回 `Stack(fit: StackFit.expand, children: [...])` 三层结构
- [x] 1.3 第一层（底层模糊）：`ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover))))`
- [x] 1.4 第二层（暗化叠加）：`Container(color: Colors.black.withValues(alpha: 0.25))`
- [x] 1.5 第三层（前景原图）：保留原 `Center > InteractiveViewer(minScale: 0.5, maxScale: 4.0) > CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, placeholder: ..., errorWidget: ...)`
- [x] 1.6 验证 `dart:ui` 的 `ImageFilter` 已通过现有 `import 'dart:ui';` 引入

## 2. 调整 PageView.itemBuilder 调用

- [x] 2.1 在 `MediaViewerPage.build` 的 `PageView.builder.itemBuilder` 中，将 `_ImageViewerItem(url: item.url ?? '')` 改为 `_ImageViewerPage(url: item.url ?? '')`
- [x] 2.2 视频分支 `item.isVideo` 保持原样走 `_VideoViewerItem` —— 不动

## 3. 静态校验

- [x] 3.1 `flutter analyze lib/pages/media/media_viewer_page.dart` 无新增 error / warning
- [x] 3.2 `flutter analyze` 全局无新增 error / warning（项目原有 warning 除外）

## 4. 功能保护验证（运行时）

> §4 需在真机 / 模拟器上运行 App 才能验证；§4.1 的代码结构（Stack 三层 + ImageFiltered blur + cover 铺满）已由代码 review 完成，但视觉验收仍需运行 App 确认。

- [ ] 4.1 图片页加载完成后整屏被图片的模糊版本铺满，前景居中显示清晰原图
- [ ] 4.2 前景原图双指缩放 / 平移行为不变（minScale 0.5 / maxScale 4.0）
- [ ] 4.3 多图 PageView 横滑时模糊背景与前景清晰图同步切换
- [ ] 4.4 视频页保持纯黑背景，不出现模糊背景
- [ ] 4.5 图片页加载期间显示纯黑（不出现白屏）
- [ ] 4.6 顶部浮层 / 右下角旋转按钮（仅视频）/ 底部互动横条 在新模糊背景上正常显示
- [ ] 4.7 横条 4 按钮（点赞 / 回复 / 转发 / 分享）行为不变
