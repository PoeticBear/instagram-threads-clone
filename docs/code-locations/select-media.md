# 选择媒体（Select Media）— 代码定位 + 简要分析

> 本文档定位 iOS 客户端中「选择媒体」功能的全部代码（相册选择 + 相机拍摄 + 上传 + 预览），并对核心实现做简要分析。
> 「选择媒体」主要服务于「发布帖子」流程，但**头像选择**（注册 / 编辑资料）也复用了同一套 `image_picker` 体系，作为旁系功能一并列出。

---

## 1. 涉及文件总览

| 类别 | 路径 | 行数 | 职责 |
| --- | --- | --- | --- |
| 发布页 | `client/lib/pages/composePost/post.dart` | ~1700 | 相册 / 相机入口、底部 sheet、本地草稿管理、批量接收相机页结果 |
| 相机页 | `client/lib/pages/composePost/compose_camera_page.dart` | ~1400 | 拍照、录视频、首帧缩略图、对焦 / 曝光 / 九宫格 / 倒计时、物理镜头、受控画质、多张照片会话 |
| 拍后确认页 | `client/lib/pages/composePost/compose_camera_confirm_page.dart` | — | 拍后静态图片滤镜（原图 / 黑白 / 暖色 / 冷色 / 高对比度） |
| 镜头工具 | `client/lib/pages/composePost/camera_lens_helper.dart` | — | 按 `lensType` 排序并产出 0.5×/1×/长焦入口 |
| 画质档位 | `client/lib/pages/composePost/camera_quality_preset.dart` | — | 720p/30fps / 1080p/30fps |
| 结果校验器 | `client/lib/utils/camera_result_validator.dart` | — | 图片 10MB / 视频 100MB / GIF 10MB / 视频 ≤ 300 秒 |
| 数据模型 | `client/lib/model/media_draft_item.dart` | 232 | 草稿态媒体条目（含工厂方法、时长格式化） |
| 数据模型 | `client/lib/model/camera_capture_result.dart` | — | 相机页 → 发布页的返回值（单张 / 列表） |
| 数据模型 | `client/lib/model/post.module.dart` | — | 服务端 `MediaType` 常量（1=image / 2=video / 3=gif） |
| 工具 | `client/lib/utils/video_processor.dart` | 163 | 视频元信息探测 / 首帧缩略图 / 压缩（默认上限 300 秒） |
| 服务层 | `client/lib/services/upload_service.dart` | 233 | 预签名 URL + 流式 PUT 上传到 COS |
| 状态层 | `client/lib/state/post.state.dart` | — | `createPost` 入口（内部走 `UploadService`） |
| 状态层 | `client/lib/state/draft.state.dart` | — | 草稿保存时同样调用 `UploadService` |
| 头像（旁系） | `client/lib/pages/profile/edit.dart` | — | 编辑资料时 `getImage(...)` |
| 头像（旁系） | `client/lib/auth/signup/signup.dart` | — | 注册时 `getImage(...)` |
| 依赖包 | `client/pubspec.yaml` | — | `image_picker ^0.8.7` / `camera ^0.10.6` / `camera_platform_interface ^2.5.0` / `video_compress ^3.1.3` / `video_player ^2.9.2` / `cached_network_image ^3.2.3` / `image_cropper ^10.0.0+1` / `image ^4.1.3` |

---

## 2. 核心代码定位（带行号）

### 2.1 发布页：媒体选择入口

| 能力 | 方法 | 行号 |
| --- | --- | --- |
| 「+」按钮触发底部 sheet | `_showMediaPickerSheet` | `post.dart:406-452` |
| Sheet 行按钮构造 | `_sheetItem` | `post.dart:454-467` |
| 相册选图（带 100 质量） | `_pickImage` | `post.dart:305-318` |
| 相册选 GIF（扩展名 + 10MB 校验） | `_pickGif` | `post.dart:320-345` |
| 相册选视频（100MB / 300s 校验 + 异步补 duration） | `_pickVideo` + `_enrichVideoDuration` | `post.dart:347-403` |
| 跳到相机页 | `_openCamera` | `post.dart:482-505` |
| 添加 / 删除 / 替换草稿 | `_addMedia` / `_removeMedia` / `_replaceMedia` | `post.dart:239-264` |
| 媒体上限校验 | `_canAddMoreMedia`（10 张） | `post.dart:68, 120` |
| 媒体预览 UI | `_buildMediaPreview` / `_buildMediaThumb` / `_buildAddMediaTile` | `post.dart:1301-1444` |
| 工具栏图标 | `_buildBottomToolbar` 内 `_toolbarIcon` | `post.dart:1523-1666` |
| Toast 错误提示 | `_showSnack` | `post.dart:469-478` |

### 2.2 相机页：拍照 / 录视频

| 能力 | 方法 | 行号 |
| --- | --- | --- |
| 初始化 + 生命周期 | `initState` / `dispose` / `didChangeAppLifecycleState` | `compose_camera_page.dart:53-79` |
| CameraController 初始化（含音频开关） | `_initCamera` / `_startCamera` | `compose_camera_page.dart:83-129` |
| 拍照 / 视频模式切换 | `_switchMode` | `compose_camera_page.dart:133-152` |
| 拍照 | `_takePicture` | `compose_camera_page.dart:156-172` |
| 录制启停 | `_startRecording` / `_stopRecording` / `_toggleRecording` | `compose_camera_page.dart:176-246` |
| 300s 自动停止定时器 | `_scheduleAutoStop` | `compose_camera_page.dart:248-263` |
| 前后摄像头切换 / 闪光灯 / 缩放 | `_switchCamera` / `_toggleFlash` / `_handleZoom` | `compose_camera_page.dart:267-304` |
| UI 组件 | `_buildPreview` / `_buildHeader` / `_buildShutter` / `_buildFlipButton` / `_buildError` | `compose_camera_page.dart:308-668` |
| 视频时长上限常量 | `_maxVideoDurationSec = 300` | `compose_camera_page.dart:49` |

### 2.3 数据模型

**`MediaDraftItem`（`client/lib/model/media_draft_item.dart:41-224`）**

- 字段：`id` / `type` / `localFile` / `remoteUrl` / `thumbPath` / `remoteThumbUrl` / `durationMs` / `fileSizeBytes` / `width` / `height` / `isUploading` / `uploadProgress` / `errorMessage`
- 工厂方法：`fromLocalImage` / `fromLocalVideo` / `fromLocalGif` / `fromRemote`
- 派生 getter：`isImage` / `isVideo` / `isGif` / `needsUpload` / `hasRenderable` / `mediaTypeInt` / `durationSeconds` / `durationLabel`
- 不可变：所有变更通过 `copyWith(...)` 完成

**`DraftMediaType`（`client/lib/model/media_draft_item.dart:6-33`）**

- 三态枚举 `image` / `video` / `gif`，与后端 `MediaType` 1/2/3 一一对应

**`CameraCaptureResult`（`client/lib/model/camera_capture_result.dart`）**

- 相机页通过 `Navigator.pop(...)` 返回：`path` / `durationMs` / `thumbnail`，含 `photo(path)` / `video({path, durationMs, thumbnail})` 工厂

### 2.4 服务层 / 工具

**`UploadService.uploadMedia`（`client/lib/services/upload_service.dart:23-60`）**

```
1) 校验文件大小
2) 根据 mediaType + 扩展名推断 MIME
3) POST upload/presigned_url → 拿 presigned.uploadUrl + presigned.cosUrl
4) file.openRead() 流式 PUT 到 uploadUrl（8KB chunk 进度回调）
5) 返回 cosUrl（远端可访问地址）
```

- 视频 / GIF 走 `file.openRead()` 流式上传，避免 OOM（`upload_service.dart:183-230`）
- 上限：图片 10MB / 视频 100MB / GIF 10MB（`upload_service.dart:14-17`）
- MIME 推断表见 `_inferContentType`（`upload_service.dart:280-305`）

**`VideoProcessor`（`client/lib/utils/video_processor.dart:11-136`）**

- `getMediaInfo(path)` → 探测时长、宽高、文件大小
- `getThumbnail(path)` → 生成首帧 jpg 缩略图（用于视频预览）
- `compress(...)` → 中等质量 / 30fps / 保留音轨（**当前未被发布页调用，预留给将来优化**）
- `deleteAllCache()` / `cancelCompression()` → 资源清理

---

## 3. 简要分析

### 3.1 整体流程图

```
┌──────────────────────────────────────────────────────────────────┐
│                  ComposePost (post.dart)                         │
│                                                                  │
│  [+] 按钮  ──► _showMediaPickerSheet()                            │
│                   │                                              │
│        ┌──────────┼──────────┐                                    │
│        ▼          ▼          ▼                                    │
│   _pickImage   _pickGif   _pickVideo                              │
│        │          │          │                                    │
│        │          │    ┌─────┴──────┐                             │
│        │          │    │ 校验 100MB │                             │
│        │          │    │ VideoProcessor                          │
│        │          │    │ .getMediaInfo (60s)                      │
│        │          │    └─────┬──────┘                             │
│        │          │          │                                    │
│        │          │    _enrichVideoDuration (异步补 duration)     │
│        └──────────┴────┬─────┘                                    │
│                        ▼                                          │
│              _addMedia(MediaDraftItem)                           │
│                        │                                          │
│                        ▼                                          │
│           _mediaDrafts (本地草稿)                                 │
│                        │                                          │
│                        ▼                                          │
│              [媒体预览 / 缩略图]                                  │
│                                                                  │
│  [📷] 按钮  ──► _openCamera()                                     │
│                        │                                          │
│                        ▼                                          │
│         ComposeCameraPage (拍照/录视频)                          │
│                        │                                          │
│                        ▼                                          │
│            Navigator.pop(CameraCaptureResult)                    │
│                        │                                          │
│                        ▼                                          │
│         _addMedia(MediaDraftItem.fromLocalImage/Video)           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  提交时：state.createPost(...)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│             PostState.createPost (post.state.dart)               │
│                                                                  │
│  对每个 MediaDraftItem：                                          │
│    1) needsUpload && localFile != null ?                         │
│         → UploadService.uploadMedia(file, mediaType, duration)   │
│    2) 否则用 remoteUrl                                            │
│    3) 收集 (url, mediaTypeInt) 平行数组                          │
│                                                                  │
│  调 PostService.createPost({                                     │
│    content, mediaUrls, mediaTypes,                               │
│    pollOptions, replyType, scheduledTime, ...                    │
│  })                                                               │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  草稿保存路径：DraftState.saveDraft
                              ▼
              同样走 UploadService.uploadMedia → cosUrl
```

### 3.2 关键设计点

#### ① 本地草稿与服务端 URL 双轨表示（`MediaDraftItem`）

- **`localFile != null`**：新选的本地资源，还未上传
- **`remoteUrl != null`**：草稿恢复 / 已上传后的远端地址
- **`needsUpload` getter** 一行判断是否要走上传管线
- 这样的设计让 **UI 渲染**（图片预览走 `Image.file` / `CachedNetworkImage`）和 **数据上传**（按 `needsUpload` 过滤）逻辑解耦

#### ② 互斥：媒体 vs 投票

- `_addMedia` 内部：若已开投票，会自动清空所有投票项（`post.dart:243-249`）
- `_togglePollEditor`：开启投票时清空所有媒体（`post.dart:266-275`）
- 原因：当前后端单条帖子要么走 `mediaUrls[]` 要么走 `pollOptions[]`，二选一

#### ③ 流式上传避免 OOM（`UploadService._streamPut`）

- 大文件（视频 / GIF）走 `file.openRead()` + `request.addStream`，分块写入
- 进度回调按 chunk 长度累加（`upload_service.dart:126-133`）
- 这是发布页能稳定处理 100MB 视频的关键

#### ④ 视频时长的双路径补全

- **相机路径**：录制完成时直接计算 `DateTime.now().difference(_recordingStartAt)`（`compose_camera_page.dart:215-218`）
- **相册路径**：`pickVideo` 同步校验通过后，**异步** 调 `VideoProcessor.getMediaInfo` 补精确 duration（`post.dart:389-403`）
- 设计意图：UI 不阻塞、精确时长事后 patch

#### ⑤ 媒体类型一致性保障

- 前端枚举 `DraftMediaType` ↔ 服务端常量 `MediaType(1=image/2=video/3=gif)` 通过 `mediaTypeInt` / `fromMediaTypeInt` 双向转换（`media_draft_item.dart:11-32`）
- 上传时按 `mediaType` 选 MIME 推断（`upload_service.dart:35, 186-211`）
- GIF 单独走 `MediaType.gif = 3`（**前端判断：扩展名必须为 `.gif`**，`post.dart:339-343`）

#### ⑥ iOS 权限处理

- `image_picker` 在 iOS 上首次调用会弹系统授权对话框，无需额外配置 Info.plist（框架自动注入 `NSPhotoLibraryUsageDescription`）
- `camera` 走 `ComposeCameraPage` 内的 `_startCamera`，失败时 `_hasError = true` 并渲染授权错误页（`compose_camera_page.dart:621-668`）
- 视频录制需要麦克风权限，通过 `enableAudio: _mode == CameraMode.video` 触发（`compose_camera_page.dart:109`），对应 `NSMicrophoneUsageDescription`

### 3.3 限制 & 边界

| 项 | 上限 | 来源 |
| --- | --- | --- |
| 媒体数量 | ≤ 10 | `post.dart:68` (`_maxMediaCount`) |
| 帖子内容长度 | ≤ 500 字符 | `post.dart:70` (`_maxContentLength`) |
| 视频时长 | ≤ 300s | `post.dart:74` / `compose_camera_page.dart:49` |
| 视频大小 | ≤ 100MB | `post.dart:75` / `upload_service.dart:15` |
| GIF 大小 | ≤ 10MB | `post.dart:76` / `upload_service.dart:16` |
| 图片大小 | ≤ 10MB | `upload_service.dart:14` |
| 投票选项数 | 2 ~ 4 | `post.dart:68-69` |
| 调度发布 | 5min 后 ~ 365 天后 | `post.dart:861, 919` |

### 3.4 已知「隐藏」的功能

- `_showDraftListSheet`（`post.dart:510-520`）和工具栏的草稿 / 位置 / 定时入口（`post.dart:1594-1609`）**已通过注释暂时屏蔽**，恢复时取消 `//` 即可。
- `VideoProcessor.compress` 工具已实现但**当前未被发布页调用**，作为预留给将来「自动压缩过大视频」的钩子。

### 3.5 旁系：头像选择（不经过 UploadService）

- `client/lib/pages/profile/edit.dart:57-66` 与 `client/lib/auth/signup/signup.dart:40-49` 都定义了简化版 `getImage(context, source, onImageSelected)`：
  - 仅支持 `image_picker` 相册 / 摄像头
  - 直接 `onImageSelected(File)` 回调给上层（**不走**预签名 URL COS 上传）
  - 上层会自己处理头像上传（个人资料 / 注册流程）
- 这套简化 API 适用于「单张图片、不需要异步上传进度」的场景

---

## 4. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改媒体数量上限 | `_maxMediaCount` | `client/lib/pages/composePost/post.dart:68` |
| 修改视频时长 / 大小限制 | `_maxVideoDurationMs` / `_maxVideoSizeBytes` | `post.dart:74-75` + `upload_service.dart:15` |
| 修改 MIME 推断 | `_inferContentType` | `client/lib/services/upload_service.dart:280-305` |
| 修改上传策略（流式 / 一次性） | `_streamPut` | `upload_service.dart:183-230` |
| 修改媒体预览 UI | `_buildMediaPreview` / `_buildMediaThumb` | `post.dart:1301-1428` |
| 修改相机拍照 / 录制 | `_takePicture` / `_startRecording` / `_stopRecording` | `compose_camera_page.dart:156-246` |
| 接入视频压缩 | `VideoProcessor.compress` | `client/lib/utils/video_processor.dart:54-101`（在 `_addMedia` 之前调用即可） |
| 替换相册选择器 | `image_picker` / `_pickImage` | `post.dart:305-318`，所有 `_pickXxx` 都在同一文件 |
| 替换相机实现 | `camera` 包 / `ComposeCameraPage` | `compose_camera_page.dart` 整文件 |
| 添加新的媒体类型 | `DraftMediaType` + `MediaType` + MIME 表 | `media_draft_item.dart:6-33` + `post.module.dart:5-13` + `upload_service.dart:280-305` |

---

_最后更新：2026-07-23 — 由 Claude 自动化梳理（基于代码静态分析 + 关键模块阅读），并对齐服务端 `openapi_docs/_misc.json` 文件上传规范（图片 10MB / 视频 100MB / GIF 10MB / 视频时长 300s / 帖子媒体数 ≤ 10）。_

## 4. 增强相机能力总览（OpenSpec `enhance-compose-camera`）

本节为 `enhance-compose-camera` 变更的代码定位补充，对应发布帖子相机的稳定化与受控增强。新增 / 修改涉及：

- 拍后确认与滤镜：`compose_camera_confirm_page.dart`
- 镜头与画质工具：`camera_lens_helper.dart`、`camera_quality_preset.dart`
- 结果校验器：`camera_result_validator.dart`
- `compose_camera_page.dart`：
  - 控制器重建串行化（`_pendingGeneration` / `_myGeneration`）
  - 关闭按钮在录制中先 `stopRecording`；`inactive` 时同样先停止录制
  - 点击对焦 / 点击曝光点 + 2 秒对焦框 overlay
  - 曝光补偿垂直滑杆（按设备 `getMin/MaxExposureOffset` 自动 clamp）
  - 九宫格辅助线（开关持久化）
  - 3 秒倒计时（视频 / 拍照均支持；`inactive` 期间自动取消）
  - 物理镜头切换（按 `lensType` 列出 0.5× / 1× / 长焦）
  - 受控画质档位（720p/30fps / 1080p/30fps，持久化）
  - 多张照片会话（`_captures` 列表 + 完成按钮批量返回 `List<CameraCaptureResult>`）
  - 视频缩略图失败时不再把视频文件当图片写入；UI 使用占位兜底

### 4.1 调用链（拍照会话）

```text
ComposePost._openCamera(remainingCapacity)
   ↓ Navigator.push
ComposeCameraPage
   ↓ 用户点击快门
_takePicture() → _openConfirmPage()
   ↓ Navigator.push
ComposeCameraConfirmPage
   ├─ 5 滤镜 + 重拍 / 使用
   └─ 返回 CameraCaptureResult.photo(_currentPath)
   ↓
回到 ComposeCameraPage：校验 → 加入 _captures
   ↓ 用户点"完成"
Navigator.pop(List<CameraCaptureResult>)
   ↓
ComposePost 逐项转 MediaDraftItem → _addMedia
```

### 4.2 调用链（视频录制）

```text
ComposePost._openCamera(remainingCapacity)
   ↓ Navigator.push
ComposeCameraPage（视频 Tab）
   ↓ 用户点击录制
_startRecording() → 倒计时（可选） → startVideoRecording
   ↓ 用户点击停止 或 5:00 自动停止
_stopRecording()
   ├─ 优先用 getMediaInfo 实际时长
   ├─ 缩略图失败时 thumbnail = null（不再 fallback 到视频路径）
   └─ 统一校验
   ↓
Navigator.pop(CameraCaptureResult.video(...))
   ↓
ComposePost 直接转 MediaDraftItem.fromLocalVideo
```
