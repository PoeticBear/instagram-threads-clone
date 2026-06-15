# 选择媒体功能重构 — 技术实施方案

> 范围：`client/lib/pages/composePost/post.dart` 中「选择媒体」入口的改造
> 目标版本：待定（实施后 bump `client/pubspec.yaml` 的 `version: x.y.z+N`）
> 制定日期：2026-06-15

---

## 一、背景与目标

### 1.1 当前痛点

发布页 (`ComposePost`) 的「+」按钮点击后，会弹出底部 sheet 让用户手动选「图片 / 视频 / GIF」三个互斥类型，且每个类型都是 **单选即关闭相册**：

- 用户想发 1 图 + 1 视频，必须 **打开相册两次**（一次选图、一次选视频），体验差
- 用户想发多张图片，每次选一张就被系统强制关闭相册，必须反复打开
- 三选一 sheet 与「图片 / 视频可混发」的产品定位不一致（前端已经能混发，只是入口强制分流）

### 1.2 改造目标

| # | 目标 | 验收标准 |
| --- | --- | --- |
| 1 | 「+」点击后 **直接打开系统相册**，不弹中间 sheet | 工具栏只剩 1 个相册图标，点击 = 直接进 PHPickerViewController |
| 2 | 相册中 **同时支持图片与视频** | 在 iOS 系统相册中能勾选混合内容 |
| 3 | 一次会话可 **多选** 多个媒体 | 选完点「Done」才退出相册，保留用户全部勾选 |
| 4 | 多选结果按 **追加** 方式并入草稿 | 已选 3 张再选 2 张 → 草稿变 5 张 |
| 5 | 超出 10 张上限时 **截断 + 提示** | 草稿最多 10 张，SnackBar 告知用户 |

---

## 二、关键设计决策（已与产品确认）

| 决策点 | 选择 | 理由 |
| --- | --- | --- |
| 相机入口 | **保留**独立相机按钮 | `ComposeCameraPage` 的 60s 视频录制 + 自定义 UI 不能被 PHPicker 自带相机按钮替代 |
| 合并策略 | **追加**到现有草稿 | 与 iOS 系统相册的连续使用习惯一致；用户主动删除已有草稿更直观 |
| 超出上限处理 | **截取前 10 + SnackBar 提示** | 比「全部拒绝」更友好；保留用户已选内容 |
| 相册实现 | **系统 PHPickerViewController**（通过 `image_picker.pickMultipleMedia`） | 零新增依赖、原生体验、iOS 14+ 自动无需相册权限 |

---

## 三、技术选型

### 3.1 为什么用 `image_picker.pickMultipleMedia`

`image_picker` 当前锁定的 `^0.8.7`（`client/pubspec.yaml:27`）已经支持 `pickMultipleMedia()`，签名如下：

```dart
Future<List<XFile>> pickMultipleMedia({
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  int? limit,
  bool requestFullMetadata = true,
});
```

- 内部在 iOS 上调 `PHPickerViewController`（`NSPhotoLibraryUsageDescription` **不需要**）
- 在 Android 上调 `ACTION_PICK_IMAGES` / `PickMultipleVisualMedia`（API 33+ 自动，< 33 走兼容路径）
- 一次返回混合的 `XFile` 列表，调用方按 `XFile.mimeType` / 扩展名区分类型

### 3.2 备选方案对比（说明为什么没选）

| 方案 | 否决理由 |
| --- | --- |
| `wechat_assets_picker` | 引入 ~2MB 体积、UI 与 App 整体风格不一致、需要再写 native 适配 |
| `photo_manager` | 仅提供数据访问，需自建 UI，工作量翻倍 |
| 完全自实现 | iOS 需写 Swift 调 `PHPickerViewController` + 平台通道，ROI 极低 |

---

## 四、详细实施步骤

### 步骤 1：新增 `_pickMultipleMedia()` 方法

**位置**：`client/lib/pages/composePost/post.dart`（在 `_showMediaPickerSheet` 上方插入）

```dart
// 替换 _pickImage / _pickGif / _pickVideo / _enrichVideoDuration
/// 系统相册多选入口（图片 + 视频可混选）
/// - 追加到 _mediaDrafts，不清空已选
/// - 超出 _maxMediaCount 时截断前 N 张并提示
Future<void> _pickMultipleMedia() async {
  // 1) 上限保护：剩余配额 = _maxMediaCount - _mediaDrafts.length
  final remaining = _maxMediaCount - _mediaDrafts.length;
  if (remaining <= 0) {
    _showSnack(AppLocalizations.of(context)!.mediaCountLimitReached(_maxMediaCount));
    return;
  }

  // 2) 调起系统多选
  final picker = ImagePicker();
  final List<XFile> picked;
  try {
    picked = await picker.pickMultipleMedia(
      // 不传 imageQuality / maxWidth：保留原始尺寸
      limit: remaining, // iOS 18+ / Android 14+ 生效；低版本系统下系统仍可能返回更多
    );
  } catch (e) {
    developer.log('pickMultipleMedia failed: $e', name: 'ComposePost');
    return; // 用户取消时也走这里，不打扰
  }
  if (picked.isEmpty || !mounted) return;

  // 3) 解析 + 校验每张媒体
  final accepted = <MediaDraftItem>[];
  final rejected = <String>[]; // 失败原因，按文件聚合
  for (final xfile in picked) {
    if (accepted.length >= remaining) {
      // 在客户端二次截断（覆盖 limit 参数不生效的低版本系统）
      rejected.add(AppLocalizations.of(context)!.mediaTruncated(_maxMediaCount));
      break;
    }
    final result = await _buildMediaDraftFromXFile(xfile);
    if (result.item != null) {
      accepted.add(result.item!);
    } else {
      rejected.add(result.error ?? 'unknown');
    }
  }

  // 4) 写入 state（仅成功的）
  if (accepted.isNotEmpty) {
    setState(() {
      // 开启投票时清空投票（与现有 _addMedia 互斥逻辑保持一致）
      if (_showPollEditor) {
        _showPollEditor = false;
        for (final c in _pollControllers) {
          c.clear();
        }
      }
      _mediaDrafts.addAll(accepted);
    });
  }

  // 5) 反馈：成功条数 + 失败原因（最多展示 1 条避免刷屏）
  if (mounted) {
    if (accepted.isNotEmpty) {
      _showSnack(AppLocalizations.of(context)!.mediaPicked(accepted.length));
    }
    if (rejected.isNotEmpty) {
      _showSnack(rejected.first);
    }
  }
}

/// 内部辅助：把单个 XFile 解析为 MediaDraftItem
/// 返回 (item?, errorMessage?)
/// - 图片：只校验大小 ≤ 20MB
/// - 视频：校验大小 ≤ 100MB、时长 ≤ 60s（探测失败也允许通过，时长 UI 不显示即可）
/// - GIF：扩展名 .gif 且 ≤ 20MB
Future<({MediaDraftItem? item, String? error})> _buildMediaDraftFromXFile(
  XFile xfile,
) async {
  final path = xfile.path;
  final file = File(path);
  final mime = xfile.mimeType?.toLowerCase() ?? '';
  final ext = path.toLowerCase();

  // ── 视频判断（mime 优先，扩展名兜底）
  final isVideo = mime.startsWith('video/') ||
      ext.endsWith('.mp4') ||
      ext.endsWith('.mov') ||
      ext.endsWith('.m4v');
  final isGif = mime == 'image/gif' || ext.endsWith('.gif');

  if (isVideo) {
    // 大小校验
    final size = await file.length();
    if (size > _maxVideoSizeBytes) {
      return (item: null, error: AppLocalizations.of(context)!.videoSizeOverLimit(
            (size / 1024 / 1024).toStringAsFixed(1),
          ));
    }
    // 时长校验
    try {
      final meta = await VideoProcessor.getMediaInfo(path);
      if (meta.durationMs > _maxVideoDurationMs) {
        return (item: null, error: AppLocalizations.of(context)!.videoDurationOverLimit(
              (meta.durationMs / 1000).toStringAsFixed(1),
            ));
      }
      return (
        item: MediaDraftItem.fromLocalVideo(
          file,
          durationMs: meta.durationMs,
          fileSizeBytes: size,
        ),
        error: null,
      );
    } on VideoProcessException catch (e) {
      // 探测失败：仍允许通过，时长显示为空即可
      developer.log('getMediaInfo failed: ${e.message}', name: 'ComposePost');
      return (
        item: MediaDraftItem.fromLocalVideo(file, durationMs: 0, fileSizeBytes: size),
        error: null,
      );
    }
  }

  if (isGif) {
    final size = await file.length();
    if (size > _maxGifSizeBytes) {
      return (item: null, error: AppLocalizations.of(context)!.gifSizeOverLimit(
            (size / 1024 / 1024).toStringAsFixed(1),
          ));
    }
    return (
      item: MediaDraftItem.fromLocalGif(file, fileSizeBytes: size),
      error: null,
    );
  }

  // 兜底：图片
  final size = await file.length();
  if (size > _maxImageSizeBytes) {
    return (item: null, error: AppLocalizations.of(context)!.imageSizeOverLimit(
          (size / 1024 / 1024).toStringAsFixed(1),
        ));
  }
  return (
    item: MediaDraftItem.fromLocalImage(file, fileSizeBytes: size),
    error: null,
  );
}
```

### 步骤 2：删除 / 标记弃用旧的 picker 方法

`client/lib/pages/composePost/post.dart` 中删除以下方法（行号以现状为准）：

- `_pickImage`（`post.dart:305-318`）
- `_pickGif`（`post.dart:320-345`）
- `_pickVideo`（`post.dart:347-386`）
- `_enrichVideoDuration`（`post.dart:388-403`）
- `_showMediaPickerSheet`（`post.dart:406-452`）
- `_sheetItem`（`post.dart:454-467`，仅供 sheet 用）

> 工具栏中如果其他位置（未来）需要 sheet 行按钮，再按需恢复。

### 步骤 3：调整 `_addMedia` 的互斥逻辑

`client/lib/pages/composePost/post.dart:239-251` 的 `_addMedia` 仍保留（相机返回的 `MediaDraftItem` 还在用），但 `setState` 中清空投票的逻辑可下沉到 `_pickMultipleMedia`（已在步骤 1 中实现）。

### 步骤 4：更新工具栏

**位置**：`client/lib/pages/composePost/post.dart:1572-1581`

```dart
// 旧：
_toolbarIcon(
  onTap: _showPollEditor ? null : _openCamera,    // 📷 相机
  icon: Iconsax.camera,
  color: _showPollEditor ? appColors.divider : appColors.textPrimary,
),
_toolbarIcon(
  onTap: _showPollEditor ? null : _showMediaPickerSheet,  // 🖼 相册 sheet
  icon: Iconsax.picture_frame,
  color: _showPollEditor ? appColors.divider : appColors.textPrimary,
),

// 新：
_toolbarIcon(
  onTap: _showPollEditor ? null : _openCamera,     // 📷 相机（保留）
  icon: Iconsax.camera,
  color: _showPollEditor ? appColors.divider : appColors.textPrimary,
),
_toolbarIcon(
  onTap: (_showPollEditor || !_canAddMoreMedia) ? null : _pickMultipleMedia,  // 🖼 相册多选
  icon: Iconsax.gallery,
  color: (_showPollEditor || !_canAddMoreMedia)
      ? appColors.divider
      : appColors.textPrimary,
),
```

> 关键变化：
> - `Iconsax.picture_frame` → `Iconsax.gallery`（语义更准确，避免与「视频相册」混淆）
> - onTap 直接调 `_pickMultipleMedia`，不再走 sheet
> - 开启投票 OR 已达上限时置灰（满足追加场景下的视觉反馈）

### 步骤 5：更新计数与视觉提示

`client/lib/pages/composePost/post.dart:1180-1193` 的媒体预览 `Wrap` 之后，可加一行：

```dart
// ── 媒体计数提示（仅在 ≥ 1 张时显示）
if (_mediaDrafts.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 52, top: 4),
    child: Text(
      '${_mediaDrafts.length} / $_maxMediaCount',
      style: TextStyle(color: appColors.textSecondary, fontSize: 12),
    ),
  ),
```

`+` 号占位瓦片（`_buildAddMediaTile`）在 `Wrap` 中的渲染条件已自动受 `_canAddMoreMedia` 控制（`post.dart:1190`），无需额外改动。

### 步骤 6：国际化文案

需要在以下文件新增 key：

- `client/lib/l10n/app_en.arb`
- `client/lib/l10n/app_zh.arb`
- `client/lib/l10n/generated/app_localizations*.dart`（运行 `flutter gen-l10n` 自动生成）

| key | 中文 | 英文 |
| --- | --- | --- |
| `mediaPicked` | "已添加 N 个媒体" | "Added N media item(s)" |
| `mediaTruncated` | "已达媒体数量上限，仅保留前 N 个" | "Media limit reached. Only the first N are kept." |
| `mediaCountLimitReached` | "已达媒体数量上限（{count}），请先删除" | "Media limit ({count}) reached. Please delete some first." |
| `imageSizeOverLimit` | "图片超过 20MB 上限（{size}MB）" | "Image exceeds 20MB limit ({size}MB)" |
| `videoSizeOverLimit` | "视频超过 100MB 上限（{size}MB）" | "Video exceeds 100MB limit ({size}MB)" |
| `videoDurationOverLimit` | "视频时长 {duration}s 超过 60s 上限" | "Video duration {duration}s exceeds 60s limit" |
| `gifSizeOverLimit` | "GIF 超过 20MB 上限（{size}MB）" | "GIF exceeds 20MB limit ({size}MB)" |

> 老文案保留（`imageOverSize` / `videoOverSize` / `gifOverSize` / `videoDurationOverSize` / `mediaOverLimit`）— 草稿恢复 / 草稿保存错误提示路径还会用。

### 步骤 7：运行 `flutter pub get` + 静态检查

```bash
cd client
flutter pub get
flutter gen-l10n
flutter analyze
```

> `pubspec.yaml` 无需新增依赖（`image_picker: ^0.8.7` 已含 `pickMultipleMedia`）。

---

## 五、数据结构与接口变更

### 5.1 `MediaDraftItem` 模型

**无变更**。`MediaDraftItem.fromLocalImage` / `fromLocalVideo` / `fromLocalGif` 三个工厂方法都保留，步骤 1 中根据 `mimeType` / 扩展名选择调用。

### 5.2 新增的 `ComposePostState` 方法签名

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_pickMultipleMedia` | `Future<void> _pickMultipleMedia()` | 公开入口（类内私有） |
| `_buildMediaDraftFromXFile` | `Future<({MediaDraftItem? item, String? error})> _buildMediaDraftFromXFile(XFile xfile)` | 内部辅助 |

### 5.3 删除的方法

| 方法 | 原行号 | 替代方案 |
| --- | --- | --- |
| `_pickImage` | `post.dart:305-318` | `_buildMediaDraftFromXFile` |
| `_pickGif` | `post.dart:320-345` | `_buildMediaDraftFromXFile` |
| `_pickVideo` | `post.dart:347-386` | `_buildMediaDraftFromXFile` |
| `_enrichVideoDuration` | `post.dart:388-403` | 探测逻辑下沉到 `_buildMediaDraftFromXFile`（同步获取 meta） |
| `_showMediaPickerSheet` | `post.dart:406-452` | 删除 |
| `_sheetItem` | `post.dart:454-467` | 删除 |

### 5.4 API 契约无变化

- 上传路径仍走 `UploadService.uploadMedia(file, mediaType, durationMs)`，参数不变
- 服务端契约不变（`mediaUrls` + `mediaTypes` 平行数组结构保留）

---

## 六、UI 变更对比

### 6.1 工具栏（Before → After）

```
Before                                          After
┌──────────────────────────────────┐            ┌──────────────────────────────────┐
│ 📷   🖼   📊   🌐           [草稿][发布] │   →   │ 📷   🖼   📊   🌐           [草稿][发布] │
│ 相机  相册  投票  权限                  │            │ 相机  相册  投票  权限                  │
└──────────────────────────────────┘            └──────────────────────────────────┘
点击 🖼：                                         点击 🖼：
  └→ showModalBottomSheet                          └→ pickMultipleMedia()
        ├ 图片（→ pickImage）                              └→ PHPickerViewController
        ├ 视频（→ pickVideo）                                （图片 + 视频可混选，多选）
        └ GIF（→ pickGif）
```

> 图标数量不变，行为从「间接」变「直接」。

### 6.2 媒体预览区（Before → After）

```
Before
[图1] [图2] [图3] [+]   ← + 总在最后

After
[图1] [图2] [图3] [+] 7 / 10   ← + 仅在 _canAddMoreMedia 时显示，底部加计数
```

---

## 七、边界与异常

| 场景 | 行为 |
| --- | --- |
| 用户未选任何媒体直接「Done」 | `_pickMultipleMedia` 正常返回，`picked.isEmpty` 直接 return |
| 选了 1 张视频，但解析元信息失败 | 允许通过，时长显示为空（与现状 `_enrichVideoDuration` 失败行为一致） |
| 选了 12 张但配额只剩 5 张 | 客户端二次截断 → 加 5 张进草稿 + SnackBar「已达媒体数量上限，仅保留前 10 个」 |
| 选了 GIF 但 > 20MB | 该张拒绝，其余继续；失败原因 SnackBar 提示 |
| 用户在相册中选了 1 张图 + 1 张 70s 视频 | 图加入、视频拒绝（时长超 60s），SnackBar 提示 |
| `_canAddMoreMedia == false` 时点击 🖼 | 工具栏图标置灰 + onTap 为 null，不可点击（替代原 `_showSnack('已达媒体数量上限')`） |
| 编辑模式（`_isEditing == true`） | 不渲染工具栏的相机 / 相册 / 投票 / 权限图标（现状已如此，`post.dart:1525-1562`） |
| 系统 PHPicker 在 Android 13- 不支持 `limit` 参数 | 客户端二次截断兜底（步骤 1 中已实现） |

---

## 八、测试要点

| 用例 | 预期 |
| --- | --- |
| 单选 1 张图 | 草稿 = 1 张图，SnackBar「已添加 1 个媒体」 |
| 多选 3 图 + 2 视频（混合） | 草稿按选择顺序追加 5 张，UI 渲染：图 1/2/3、视频 4/5（带 ▶ + 时长） |
| 多选 12 张图（剩余配额 10） | 草稿 = 10 张，SnackBar「已达媒体数量上限，仅保留前 10 个」 |
| 选 1 张 200MB 视频 | 拒绝，SnackBar「视频超过 100MB 上限（200.0MB）」 |
| 选 1 张 70s 视频 | 拒绝，SnackBar「视频时长 70.0s 超过 60s 上限」 |
| 选 1 张 30MB GIF | 拒绝，SnackBar「GIF 超过 20MB 上限（30.0MB）」 |
| 选 1 张 25MB 图片 | 拒绝，SnackBar「图片超过 20MB 上限（25.0MB）」 |
| 已选 10 张时点击 🖼 | 图标置灰，点击无反应（无 SnackBar，避免骚扰） |
| 已选 8 张再选 5 张 | 草稿 = 10 张，SnackBar「已达媒体数量上限，仅保留前 10 个」（实际只追加 2 张，提示文案仍说 10） |
| 编辑模式打开「+」入口 | 工具栏不渲染相册图标，仅显示「保存编辑」按钮 |
| 跨设备 | iOS 14+ / Android 13+ 用 `limit` 截断；低版本走二次截断 |

> 建议在 `client/test/post_pick_multiple_media_test.dart` 加一组 widget test（mock `ImagePicker` 平台通道返回 `List<XFile>`）。

---

## 九、风险与回滚

| 风险 | 缓解 |
| --- | --- |
| `pickMultipleMedia` 在低版本系统上未实现 `limit` 参数 | 客户端二次截断（已设计） |
| Android 13 以下需要 `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` 权限 | `image_picker` 内部已处理，App 端无需手动加权限 |
| 用户已用旧逻辑（GIF 通过 sheet 单独选） | sheet 已删除；若有 bug 紧急回滚，git revert 即可（commit 信息明确：feat: 多选相册） |
| iOS PHPickerViewController 选择顺序 | iOS 系统保证按用户勾选顺序返回，前端直接信任 |
| 国际化文案缺失 | `flutter gen-l10n` 会失败 → CI 立刻挂；本地手测 zh + en 各跑一遍 |

### 回滚方案

- 单 feature commit，可 `git revert` 直接回到旧 sheet 入口
- 删除/新增的 6 个方法都是 _private_，外部无引用

---

## 十、修改文件清单

| 文件 | 改动类型 | 行数预估 |
| --- | --- | --- |
| `client/lib/pages/composePost/post.dart` | 改：删除 6 方法 / 新增 2 方法 / 改 1 行 toolbar | -50 / +130 |
| `client/lib/l10n/app_zh.arb` | 改：新增 7 条 key | +14 |
| `client/lib/l10n/app_en.arb` | 改：新增 7 条 key | +14 |
| `client/lib/l10n/generated/app_localizations*.dart` | 自动生成（`flutter gen-l10n`） | +N（auto） |
| `client/pubspec.yaml` | 不变 | 0 |
| `client/test/post_pick_multiple_media_test.dart` | 新增：单测 | +80（可选） |

> **总计**：约 150 行新增 + 50 行删除，纯客户端改动，后端零改动。

---

## 十一、实施顺序（建议）

1. **第 1 步**：写新增的 `_pickMultipleMedia` + `_buildMediaDraftFromXFile`，**保留**旧方法不删（用 `_Deprecated` 注解）
2. **第 2 步**：更新工具栏 onTap 指向新方法，跑通 → 验证 ✅
3. **第 3 步**：删除旧 6 个方法
4. **第 4 步**：补 l10n 文案 + `flutter gen-l10n`
5. **第 5 步**（可选）：写单测
6. **第 6 步**：实机 iOS + Android 各跑一遍边界用例清单（第八节）
7. **第 7 步**：commit 提交，bump `pubspec.yaml` 的 `version: x.y.z+N`

---

_等待用户确认后进入实施阶段。_
