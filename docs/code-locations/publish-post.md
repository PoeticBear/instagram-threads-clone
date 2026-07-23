# 发布帖子（Compose Post）— 代码定位

> 本文档汇总 iOS 客户端「发布帖子」页面涉及的所有源代码位置，包括 UI 层、状态层、服务层、模型、工具方法以及入口集成点。
> 后续若收到「定位发布帖子页面」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 核心页面（UI 层）

### 1.1 主发布页 `ComposePost`

- **路径**：`client/lib/pages/composePost/post.dart`
- **行数**：1667
- **核心组件**：
  - `class ComposePost`（`post.dart:23`）— StatefulWidget
  - `class ComposePostState extends State<ComposePost>`（`post.dart:48`）— 主状态类
- **支持的模式**：
  - 新建帖子（默认）
  - 编辑帖子（`editingPostId != null` 时进入）
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 状态字段 | `_textEditingController` / `_mediaDrafts` / `_showPollEditor` / `_pollControllers` / `_replyType` / `_isSubmitting` / `_location` / `_scheduledTime` / `_isSensitive` / `_contentWarningController` | `post.dart:49-66` |
  | 常量限制 | `_maxMediaCount` / `_maxPollOptions` / `_minPollOptions` / `_maxContentLength` / `_maxVideoDurationMs` / `_maxVideoSizeBytes` / `_maxGifSizeBytes` | `post.dart:67-76` |
  | 内容可发判断 | `_hasContent` / `_canPost` / `_canAddMoreMedia` | `post.dart:107-120` |
  | 返回 / 草稿对话框 | `_handleBack` / `handleTabSwitch` / `_showSaveDraftDialog` / `_clearContent` / `_doBack` | `post.dart:122-234` |
  | 媒体增删 | `_addMedia` / `_removeMedia` / `_replaceMedia` | `post.dart:239-264` |
  | 投票编辑器 | `_togglePollEditor` / `_addPollOption` / `_removePollOption` / `_getValidPollOptions` | `post.dart:266-301` |
  | 相册选择 | `_pickImage` / `_pickGif` / `_pickVideo` / `_enrichVideoDuration` | `post.dart:305-403` |
  | 媒体选择底部弹层 | `_showMediaPickerSheet` / `_sheetItem` | `post.dart:406-467` |
  | Toast 提示 | `_showSnack` | `post.dart:469-478` |
  | 相机入口 | `_openCamera`（push `ComposeCameraPage`） | `post.dart:482-505` |
  | 草稿加载 / 保存 | `_showDraftListSheet` / `_onDraftSelected` / `_buildDraftsFromMediaList` / `_resolveDraftMedia` / `_saveCurrentDraft` | `post.dart:510-684` |
  | 提交发布 | `_createPostModel` / `_submit`（区分新建 / 编辑） | `post.dart:688-798` |
  | 位置选择 | `_showLocationDialog` | `post.dart:802-851` |
  | 定时发布 | `_showSchedulePicker` | `post.dart:855-930` |
  | 回复权限 | `_showReplyTypeSheet` / `_replyTypeOption` / `_replyTypeIcon` | `post.dart:934-998` |
  | Build | `build`（AppBar + 媒体预览 + 投票编辑器 + 位置 / 定时 chip） | `post.dart:1003-1255` |
  | 子组件构建 | `_buildAvatar` / `_buildMediaPreview` / `_buildMediaThumb` / `_buildAddMediaTile` / `_buildPollEditor` / `_buildBottomToolbar` / `_toolbarIcon` | `post.dart:1259-1666` |

### 1.2 相机页 `ComposeCameraPage`

- **路径**：`client/lib/pages/composePost/compose_camera_page.dart`
- **行数**：~1400（增强后）
- **核心组件**：
  - `class ComposeCameraPage` — 拍照 + 录视频 + 多张照片会话 + 拍摄辅助
  - `enum CameraMode { photo, video }`
  - `class _ComposeCameraPageState`
- **关键能力模块**：
  | 模块 | 方法 / 字段 | 行号 |
  | --- | --- | --- |
  | 状态字段 | `_controller` / `_cameraIndex` / `_isSwitchingCamera` / `_isTakingPicture` / `_flashMode` / `_currentZoom` / `_zoomBase` / `_minZoom` / `_maxZoom` / `_hasError` / `_mode` / `_isRecording` / `_recordingStartAt` / `_isSwitchingMode` / `_pendingGeneration` / `_myGeneration` / `_focusPoint` / `_focusShownAt` / `_minExposure` / `_maxExposure` / `_exposureStep` / `_currentExposure` / `_showGrid` / `_countdownSeconds` / `_countdownTimer` / `_countdownValue` / `_captures` / `_quality` | 文件内按区块分布 |
  | 视频时长限制 | `_maxVideoDurationSec` = 300 / `_recordingTickInterval` = 200ms | 文件中段 |
  | 生命周期 | `initState` / `dispose` / `didChangeAppLifecycleState`（inactive 先 `stopRecording`、resumed 清 `_hasError`） | |
  | 相机初始化 | `_initCamera` / `_startCamera` / `_pickPreferredBackIndex`（含控制器串行化、曝光范围读取、缩放与闪光灯应用） | |
  | 模式切换 | `_switchMode` | |
  | 拍照 | `_takePicture` / `_openConfirmPage` / `_safeDelete` | |
  | 视频录制 | `_toggleRecording` / `_startRecording` / `_stopRecording`（优先用 `getMediaInfo` 实际时长） / `_scheduleAutoStop` | |
  | 镜头选择 | `_selectLens` / `CameraLensHelper`（`camera_lens_helper.dart`） | |
  | 画质切换 | `_toggleQuality` / `CameraQualityPreset`（`camera_quality_preset.dart`） | |
  | 点击对焦 | `_onPreviewTap` / `_previewTapToNorm`（前置 x 镜像） / `_buildFocusRing` | |
  | 曝光补偿 | `_setExposure` / `_buildExposureSlider`（垂直滑杆） | |
  | 九宫格 | `_toggleGrid` / `_GridOverlay` / `_GridPainter` | |
  | 倒计时 | `_runCountdown` / `_cancelCountdown` / `_cycleCountdown` / `_buildCountdownOverlay` | |
  | 缩放 | `_onScaleStart`（保存 `_zoomBase`） / `_onScaleUpdate` | |
  | 闪光灯 | `_toggleFlash` | |
  | 会话管理 | `_onClosePressed`（清理 `_captures` 临时文件） / `_onCompletePressed`（批量返回） / `_onDeleteCapture` | |
  | 偏好持久化 | `_loadPrefs`（quality / grid / countdown） | |
  | Build | `build` + `_buildPreview`（含 grid + focus + countdown overlay） + `_buildHeader`（增加 grid 按钮） + `_buildCaptureStrip` + `_buildCountdownToggle` + `_buildLensPills` + `_buildQualityToggle` + `_buildExposureSlider` + `_buildFlipButton` + `_buildShutter` + `_buildError` | |

### 1.3 拍后确认页 `ComposeCameraConfirmPage`

- **路径**：`client/lib/pages/composePost/compose_camera_confirm_page.dart`
- **职责**：拍照完成后弹出，5 个静态滤镜（原图 / 黑白 / 暖色 / 冷色 / 高对比度），底部"重拍 / 使用"。
- **pop 值**：
  - `CameraCaptureResult.photo(_currentPath)` — 用户点"使用"
  - `null` — 用户点"重拍"
- **超时**：滤镜处理超过 2 秒即视为失败，提示错误并允许继续使用原图或重拍。
- **依赖**：使用 `image: ^4.1.3`（已声明）做静态处理；产物写入系统临时目录。

### 1.4 镜头工具 `CameraLensHelper`

- **路径**：`client/lib/pages/composePost/camera_lens_helper.dart`
- **职责**：把 `List<CameraDescription>` 按 `lensDirection` 与 `lensType` 排序，得到带 UI 标签的镜头列表。
- **关键方法**：`backLenses`（按 ultraWide → wide → telephoto 排序） / `frontLenses`。

### 1.5 画质档位 `CameraQualityPreset`

- **路径**：`client/lib/pages/composePost/camera_quality_preset.dart`
- **取值**：`sd720p30` / `hd1080p30`（默认）
- **关键字段**：`shortLabel` / `resolutionPreset` / `fps = 30`
- **持久化**：保存到 `SharedPreferences['compose_camera_quality']`。

---

## 2. 入口集成点（页面路由）

### 2.1 底部导航栏第 3 个 Tab（首页常驻）

- **路径**：`client/lib/pages/home.dart`
- **关键行**：
  - 持有 `_composePostKey = GlobalKey<ComposePostState>()`（`home.dart:25`）
  - `_pages[2] = ComposePost(...)`（`home.dart:35-39`）
  - `_switchTab` 拦截离开发帖 Tab 时调用 `_composePostKey.currentState?.handleTabSwitch(...)`（`home.dart:71-81`）
  - 底部 Tab Bar：`_tabBarItem(tabIndex: 2, icon: Iconsax.edit, ...)`（`home.dart:127`）

### 2.2 Feed 页「发帖」悬浮按钮

- **路径**：`client/lib/pages/feed/feed.dart`
- **关键行**：`Navigator.push(... builder: (_) => ComposePost(...))`（`feed.dart:215-227`）

### 2.3 FeedPostWidget「编辑」入口

- **路径**：`client/lib/widget/feedpost.dart`
- **关键行**：`Navigator.push(... builder: (_) => ComposePost(editingPostId: ..., initialContent: ...))`（`feedpost.dart:1164-1175`）

### 2.4 写文字 Popup 入口（v1.0.0+23 新增；`change-text-note-handoff` 后调整）

底部 Tab 中间「+」按钮点击后，改为弹出 Popup 菜单（`TextNoteMenuSheet`），由用户选择「写文字」或「普通图文」。

- **Popup 菜单**：`client/lib/pages/textNote/text_note_menu_sheet.dart` — 列出「写文字」「普通图文」两个入口，返回 `TextNoteMenuMode` 枚举
- **写文字页面（change-text-note-handoff 调整后）**：`client/lib/pages/textNote/text_note_page.dart` — 选「写文字」时 push 进入；右上「确认」触发截图后用 `Navigator.pushReplacement` 把 `TextNotePage` 替换为 `ComposePost(initialContent: text, initialMediaDrafts: [draft])`；ComposePost 接管后续编辑与发布（卡片 PNG 作为 image media，正文作为正文）
- **入口改造**：`client/lib/pages/home.dart` — `_switchTab(targetTab == 2)` 改为先弹 Popup 菜单，根据返回值决定 push `TextNotePage` 或切换 `tab = 2` 进入 `ComposePost`（home.dart 自身**不**改动；TextNotePage 内部完成到 ComposePost 的跳转）
- **代码定位文档**：[`docs/code-locations/write-text.md`](write-text.md)

> FAB / 编辑入口仍直进 `ComposePost`（保持兼容，不弹菜单）。

---

## 3. 状态层（Provider）

### 3.1 `PostState`（全局单例）

- **路径**：`client/lib/state/post.state.dart`
- **职责**：管理帖子列表缓存，并对外提供创建 / 编辑帖子的网络入口。
- **关键方法**：
  - `Future<String?> createPost(PostModel model, {List<MediaDraftItem>? mediaDrafts, ...})`（`post.state.dart:142-`）
  - `Future<PostModel?> updatePost({required String postId, String? content, bool? isSensitive, String? contentWarning})`（`post.state.dart:640-660`）
  - `void _updatePostInList(String postId, PostModel updated)`（`post.state.dart:725-`）— 编辑后本地列表同步

### 3.2 `DraftState`（全局单例）

- **路径**：`client/lib/state/draft.state.dart`
- **职责**：草稿列表加载、详情拉取、保存草稿。
- **关键方法**：
  - `loadDrafts()`（列表）
  - `loadDraftForEditing(draftId)`（拉取详情补全 mediaList / location）
  - `saveDraft({content, mediaUrls, mediaTypes, pollOptions, replyType, location})`（上传媒体后保存）

### 3.3 `ComposePostState`（独立的旧 State）

- **路径**：`client/lib/state/compose.state.dart`
- **职责**：@mention 自动补全（基于 `SearchState` 搜索用户名），与新版 `ComposePost` 页面解耦。
- **关键字段**：`showUserList` / `enableSubmitButton` / `description` / `usernameRegex` / `displayUserList` / `getDescription(username)` / `onUserSelected` / `onDescriptionChanged(text, searchState)`

---

## 4. 服务层（API / 上传）

### 4.1 `PostService`

- **路径**：`client/lib/services/post_service.dart`
- **职责**：与 `openapi_docs/` 中帖子相关接口对齐的网络层。
- **关键方法**：
  - `createPost({content, mediaUrls, mediaTypes, pollOptions, replyType, scheduledTime, isSensitive, contentWarning})` — 新建帖子
  - `updatePost({postId, content, isSensitive, contentWarning})` — 编辑帖子

### 4.2 `UploadService`

- **路径**：`client/lib/services/upload_service.dart`
- **关键方法**：
  - `uploadMedia(File file, {required int mediaType, int? durationMs})` — 上传图片 / 视频 / GIF，返回远端 URL
- **调用方**：`ComposePostState._resolveDraftMedia()`（`post.dart:602-633`）

### 4.3 视频处理工具

- **路径**：`client/lib/utils/video_processor.dart`
- **关键方法**：
  - `getMediaInfo(path)` — 读取时长、宽高（用于相册选择视频的 60s 校验）
  - `getThumbnail(path)` — 生成首帧缩略图（`compose_camera_page.dart:223` 录制完成后调用）

---

## 5. 数据模型

| 模型 | 路径 | 关键字段 |
| --- | --- | --- |
| `PostModel` | `client/lib/model/post.module.dart` | `user` / `bio` / `createdAt` / `key` / `mediaUrls` / `mediaTypes` / `pollOptions` / `replyType` / `location` / `scheduledTime` / `isSensitive` / `contentWarning` / `isEdited` |
| `MediaDraftItem` | `client/lib/model/media_draft_item.dart` | `localFile` / `remoteUrl` / `thumbPath` / `remoteThumbUrl` / `type` / `durationMs` / `fileSizeBytes` / `isVideo` / `isImage` / `isGif` / `needsUpload` / `durationLabel` |
| `DraftMediaType` | `client/lib/model/media_draft_item.dart` | `enum { image, video, gif }` + `mediaTypeInt` ↔ `fromMediaTypeInt` |
| `DraftInfo` / `DraftDetail` | `client/lib/model/draft.module.dart` | `id` / `content` / `pollOptions` / `replyType` / `mediaUrls` / `mediaTypes` / `location` |
| `CameraCaptureResult` | `client/lib/model/camera_capture_result.dart` | `path` / `durationMs` / `thumbnail` / `isVideo` + 工厂 `photo(path)` / `video({path, durationMs, thumbnail})` |
| `UserModel` | `client/lib/model/user.module.dart` | `userId` / `userName` / `displayName` / `profilePic` / `email` |

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **生成代码**：`client/lib/l10n/generated/app_localizations*.dart`
- **常用 key**（以发布页为例）：
  - `newPost` / `editPost` / `back` / `saySomething`
  - `saveDraft` / `saveDraftHint` / `save` / `discard` / `cancel` / `draft` / `draftSaved` / `draftSaveFailed` / `draftLoaded` / `nothingToSaveDraft`
  - `addLocation` / `enterLocation` / `clearLocation`
  - `schedulePost` / `clearSchedule` / `confirmButton` / `scheduleTimeTooEarly` / `schedulePublishSuccess`
  - `whoCanReply` / `everyoneCanReply` / `followersCanReply` / `followingCanReply` / `mentionedCanReply`
  - `post` / `saveEdits` / `postUpdated` / `publishSuccess` / `publishFailed`
  - `markAsSensitive` / `contentWarningHint`
  - `optionLabel(n)` / `addOption` / `removePoll`
  - `cameraModePhoto` / `cameraModeVideo` / `cameraAccessRequired` / `cameraAccessHint` / `cameraGoBack` / `cameraStartRecordingFailed` / `cameraStopRecordingFailed(e)`

---

## 7. 主题 / 颜色

- 颜色统一通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 读取。
- 入口：`client/lib/theme/app_colors.dart`（`AppColorsExtension` + `AppColors`）。

---

## 8. 相关 / 间接依赖

- 头像 / 网络图：`client/lib/widget/feedpost.dart` 中封装的 `CachedNetworkImage` 工具（亦在 `post.dart` 复用）。
- 草稿列表弹层：`client/lib/widget/draft_list_sheet.dart`（`ComposePostState._showDraftListSheet` 调用）。
- 国际化上下文：`AppLocalizations.of(context)!`（来自 `client/lib/l10n/generated/app_localizations.dart`）。
- 系统反馈：`ScaffoldMessenger.of(context).showSnackBar(...)`（成功 / 失败提示）。
- 触觉反馈：`HapticFeedback.heavyImpact()`（提交）、`mediumImpact`（拍照 / 录制）、`lightImpact`（切换摄像头）、`selectionClick`（模式切换）。

---

## 9. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改发布页 UI | `ComposePost` / `_buildBottomToolbar` | `client/lib/pages/composePost/post.dart` |
| 修改相机页 | `ComposeCameraPage` / `CameraMode` | `client/lib/pages/composePost/compose_camera_page.dart` |
| 修改新建 / 编辑帖子接口 | `createPost` / `updatePost` | `client/lib/services/post_service.dart` + `client/lib/state/post.state.dart` |
| 修改草稿逻辑 | `DraftState` / `_saveCurrentDraft` | `client/lib/state/draft.state.dart` + `client/lib/pages/composePost/post.dart` |
| 修改媒体上传 | `UploadService` / `_resolveDraftMedia` | `client/lib/services/upload_service.dart` + `post.dart:602-633` |
| 修改视频时长 / 缩略图 | `VideoProcessor` / `_maxVideoDurationSec` | `client/lib/utils/video_processor.dart` + `compose_camera_page.dart` |
| 修改发布页入口（FAB / Tab / 编辑） | `ComposePost(` | `client/lib/pages/home.dart:35` / `client/lib/pages/feed/feed.dart:217` / `client/lib/widget/feedpost.dart:1166` |
| 添加 / 修改文案 | `l10n.xxx` | `client/lib/l10n/app_zh.arb` + `app_en.arb` |

---

_最后更新：2026-06-15 — 由 Claude 自动化梳理（基于代码静态分析）。_
