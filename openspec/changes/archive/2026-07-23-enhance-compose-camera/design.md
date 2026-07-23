## Context

发布帖子相机 `client/lib/pages/composePost/compose_camera_page.dart` 是发布媒体流程的核心入口，从 `ComposePost._openCamera` 推入，承担拍照、录像、视频自动停止、缩略图生成与结果返回。

现有能力：

- 拍照：单次快门后立即 `Navigator.pop`，返回 `CameraCaptureResult.photo(path)`。
- 录像：拍照/视频模式切换由 `_startCamera` 重建 `CameraController`；闪光灯仅 `torch`；双指缩放基于 `details.scale * _currentZoom` 在每次 `onScaleUpdate` 中累乘，存在基准误差。
- 镜头：按 `lensDirection` 区分前后，未消费 `CameraDescription.lensType`。
- 分辨率：固定 `ResolutionPreset.veryHigh`，未设 `fps`。
- 生命周期：`WidgetsBindingObserver.didChangeAppLifecycleState` 在 inactive 直接 `controller.dispose()` 并置空，录像状态标志未同步重置；手动关闭页面在录制中也未做安全收尾。
- 媒体校验：相册选择有完整文件大小与视频时长校验；相机返回结果不校验文件大小、不读取实际视频时长，缩略图失败时把视频文件本身作为 `thumbnail` 写入。
- 视频上限：实际允许 300 秒，但界面计时显示 `/ 1:00`，`VideoProcessor` 默认值、错误文案与部分注释仍是 60 秒。
- 依赖：`camera 0.10.6`、`camera_avfoundation 0.9.23+2`、`camera_platform_interface 2.13.0`；相机暴露 `setFocusPoint`、`setExposurePoint`、`getMin/MaxExposureOffset`、`setExposureOffset`、`lensType`、`ResolutionPreset`、`fps`；不暴露显式视频防抖 setter。

约束：

- 项目仅维护 iOS，不为 Android 写兼容或降级。
- 不引入新的 iOS 原生相机桥接，不自建 AVFoundation 会话。
- 不引入实时图像流、实时视频滤镜或高速连拍。
- 不修改 `ComposePost` widget 对外签名（`compose-post` 规格不变）。
- 不改变帖子创建、媒体上传与服务端数据契约。

## Goals / Non-Goals

**Goals：**

- 把现有相机拍摄链路稳定到“任何触发都能干净收尾”。
- 为照片拍摄引入点击对焦、点击曝光点、曝光补偿、九宫格、3 秒倒计时。
- 让镜头选择基于设备能力，区分 0.5×、1×、长焦，避免硬编码索引。
- 提供 720p/30fps 与 1080p/30fps 两个受控画质档位，默认 1080p/30fps。
- 支持一次会话内多张照片拍摄，相机页不自动退出，可点击完成后批量返回。
- 提供拍摄确认页和少量拍后静态图片滤镜。
- 全部能力在 iOS 真机通过回归。

**Non-Goals：**

- 不实现录像中物理镜头无缝切换，不实现超长焦以外的虚拟多摄融合。
- 不开放 4K 或独立帧率选择，不做目标格式严格匹配。
- 不做实时照片滤镜、实时视频滤镜或视频帧处理。
- 不做长按高速连拍；不暴露显式视频防抖等级。
- 不为新能力新增 iOS 隐私权限条目，不新增 `NSPhotoLibraryAddUsageDescription`。
- 不修改服务端 API、不修改 `ComposePost` widget 签名。

## Decisions

### 1. 视频上限统一为 300 秒

选择 300 秒作为唯一规则并贯穿：

- `_maxVideoDurationSec` = 300。
- `post.dart` 的 `_maxVideoDurationMs` = 300000。
- 录像 UI 计时显示 `/ 5:00`。
- `VideoProcessor` 默认上限 `maxDurationSec` = 300，方法注释同步。
- `l10n` 中 “视频超过 X 秒” 错误文案统一改为 300。
- 任何 60 秒相关提示不再使用。

依据：

- 实际代码已按 300 秒运行，对外限制实际就是 300 秒。
- 用户反馈和发帖场景更倾向“一次录完”而非强制切段。
- 与现有 `upload_service.dart` 上传链路默认值一致。

### 2. 控制器串行化与缩放基准修正

- 引入 `_pendingGeneration`，每次 `_startCamera` 自增；初始化时记录 `_myGeneration`，初始化完成回调里若 `mounted` 且 `_myGeneration == _pendingGeneration` 才提交状态，否则丢弃。
- `_takePicture`、`_startRecording`、`_stopRecording`、`_switchCamera`、`_switchMode`、镜头切换、画质切换复用同一把“重建中”状态。
- 双指缩放改为 `onScaleStart` 中保存 `_zoomBase`，`onScaleUpdate` 中 `clamp(_zoomBase * details.scale, min, max)`，`onScaleEnd` 中 `setZoomLevel(clamp(...))`，消除累乘误差。

### 3. 生命周期与关闭收尾

- `inactive` 时若 `_isRecording`，先调用 `controller.stopVideoRecording()`，将结果按正常结束录像的流程处理（生成缩略图、`Navigator.pop` 或交给批量结果）；如停止异常，进入错误路径并丢弃未保存视频。
- 关闭按钮在录制时改为先停止录制再返回，不再让 `dispose` 直接 dispose 一个正在录制的 controller。
- `didChangeAppLifecycleState.resumed` 之后重新 `_startCamera` 并清空 `_hasError`。

### 4. 拍摄结果校验与缩略图降级

- 相机返回结果统一走与相册选择一致的文件大小校验：图片 10MB、视频 100MB、GIF 10MB。
- 视频使用 `VideoProcessor.getMediaInfo` 读取实际时长；若时长 0 或 > 300 秒则丢弃结果并提示。
- 缩略图生成失败时，`thumbPath` 置 null，UI 兜底显示一个统一的“视频占位”小图（项目内已有复用图），不再把视频路径当图片路径解码。
- 视频时长优先使用媒体文件实际时长，仅当无法读取时才回退到墙钟差。

### 5. 点击对焦 + 曝光点 + 曝光补偿

- 在 `CameraPreview` 上叠加 `GestureDetector`。
- tap 坐标先归一化到 0..1，再映射到 `BoxFit.cover` 下的摄像头坐标；前置镜头时对 x 做 1-x 镜像。
- 同一坐标同时调用 `controller.setFocusPoint` 与 `controller.setExposurePoint`。
- 仅在 `focusPointSupported` 或 `exposurePointSupported` 为 false 时禁用对应能力，并隐藏 UI。
- 对焦请求期间显示对焦框 overlay，2 秒后自动消失；控制器重建或生命周期 inactive 时立刻清理。
- 曝光补偿滑杆：

  - 在 `_startCamera` 完成后读取 `getMinExposureOffset`、`getMaxExposureOffset`、`getExposureOffsetStepSize`。
  - 控制器重建后重新读取并 clamp 当前值；保存用户偏好到 `SharedPreferences` 的单一 key。
  - UI 使用垂直滑杆或圆形 EV 转盘，二选一选择最简：圆形 EV 转盘（`+1.0` ~ `-1.0`，8 档）。
  - 视频录像期间允许调整曝光；调整时同步 `setExposureOffset`。

### 6. 九宫格与 3 秒倒计时

- 九宫格：纯 UI overlay，`IgnorePointer` 包裹；提供 l10n 文案与可记忆偏好；默认 off。
- 倒计时：状态 `_countdownSeconds = 0 | 3`，提供开关，默认 off；点击快门先 `Timer.periodic 1s` 倒数，倒数期间显示 3/2/1，再触发原本的拍照或录像；倒计时期间切换镜头、模式、关闭页面、App 进入后台立即取消计时器；视频模式也支持 3 秒倒计时。

### 7. 物理镜头选择

- 启动时已经在 `main.dart` 缓存全局 `cameras`；新增工具 `cameraLensInfo(List<CameraDescription>)`，按 `lensDirection` 分组后置与前置，再按 `lensType` 排序：

  - 后置：`ultraWide` → 0.5×，`wide` → 1×，`telephoto` → 2×（缺啥不显示啥）。
  - 前置：只列 1×。
- 镜头入口作为底部条 button，标题按上述映射；UI 不声明真实光学倍率，不宣称与系统相机等价。
- 镜头切换重建 `CameraController`，期间显示 loading，禁止录像中切换。
- 镜头切换后必须重新读取曝光范围和 zoom 范围并 clamp 当前值。

### 8. 受控画质选项

- 引入枚举 `CameraQualityPreset { sd720p30, hd1080p30 }`，默认 `hd1080p30`。
- 映射到 `(ResolutionPreset, int fps)`：

  - `sd720p30` → `ResolutionPreset.medium`、`fps = 30`。
  - `hd1080p30` → `ResolutionPreset.veryHigh`、`fps = 30`。
- `_startCamera` 接收该枚举，构建 controller；记录到用户偏好，恢复相机时优先读取偏好。
- UI 仅在镜头选择旁显示一个画质切换按钮，二选一即时切换，允许短暂 loading。
- 不在 UI 中暴露 4K，不暴露独立帧率；不阻止底层回退，但不做进一步探测。

### 9. 多张照片会话拍摄

- 进入相机页时由 `ComposePost._openCamera` 传入 `remainingCapacity = _maxMediaCount - _mediaDrafts.length`。
- 相机页状态改为 `_captures: List<CameraCaptureResult>`、`_canShoot = remainingCapacity > 0`。
- 拍照后：

  - 列表插入首位，达到容量后禁用快门。
  - 顶部显示已拍数量与最后一张缩略图。
  - 提供“完成”按钮返回 `List<CameraCaptureResult>`。
  - 提供“删除”入口移除某张并释放其临时文件。
- 视频录制保持现有行为：录完直接返回，不进入会话。
- 关闭或 App inactive 时按现有生命周期收尾；返回时未“完成”的中间拍摄文件清理。
- `CameraCaptureResult` 不新增字段，列表直接通过 `Navigator.pop(List<CameraCaptureResult>)` 返回；`ComposePost._openCamera` 在 `then` 回调里逐个转 `MediaDraftItem` 并复用 `_addMedia`。

### 10. 拍后静态图片滤镜

- 相机拍完一张照片后不立即退出，改为进入 `ComposeCameraConfirmPage`：

  - 顶部原图。
  - 滤镜列表：原图、黑白、暖色、冷色、高对比度。
  - 底部：重拍 / 使用。
- 滤镜实现使用声明的图片处理依赖，纯静态同步处理；处理后写入新临时文件，原文件保留。
- 使用滤镜后返回的仍是一个 `CameraCaptureResult`（`path` 指向新文件），按现有流程进入会话或返回发布页。
- 不接入实时图像流，不接入视频滤镜。

### 11. 视频首帧策略与录制收尾

- 视频缩略图必须先尝试 `VideoProcessor.getThumbnail`，失败时使用统一视频占位资源。
- 录像时长优先使用媒体文件 `getMediaInfo` 实际时长；读取失败时回退到墙钟差。
- 自动停止与手动停止走同一路径，避免在 `_stopRecording` 中重复实现收尾。

## Risks / Trade-offs

- **[风险] 九宫格与对焦 overlay 同时存在** → 全部 overlay 使用 `IgnorePointer`，对焦命中以最外层 `GestureDetector` 为准。
- **[风险] 镜头切换时的曝光补偿、闪光灯、缩放状态被重置** → `_startCamera` 完成后读取新的 min/max/exposurePointSupported/focusPointSupported 并 clamp 现有偏好值；闪光灯保持用户偏好。
- **[风险] 倒计时期间发生 lifecycle inactive** → Timer 在 `dispose` 与 `didChangeAppLifecycleState.inactive` 中一并 `cancel`，且不在 inactive 后再触发拍摄。
- **[风险] 多张照片会话占满临时存储** → 用户点击完成或取消时清理未返回列表中的临时文件；返回发布页后由发布页统一管理 `MediaDraftItem`。
- **[风险] 录像中关闭页面产生未完成视频** → 关闭按钮先 `stopVideoRecording()`；自动停止和手动停止路径合并。
- **[风险] 视频上限与 OpenAPI 注释不一致** → 提案明确 300 秒为唯一规则，删除所有 60 秒引用；不再假设 `_misc.json` 严格约束视频时长。
- **[风险] `camera` 插件无公开视频防抖 setter** → 不暴露防抖 UI，保持当前 `AVFoundation` 默认行为，明确写明“未配置显式防抖”。
- **[风险] 拍后滤镜在高分辨率图上处理慢** → 仅在确认页处理；分辨率按当前相机 preset 限制；超时则显示错误并不阻塞返回原图。
- **[风险] 多张照片会话改变了 `CameraCaptureResult` 的隐含使用** → 通过 `Navigator.pop` 返回值改成 `List<CameraCaptureResult>`，并集中处理；同步更新现有调用点的 `pop` 路径。

## Migration Plan

- 改动只影响 `client/lib/pages/composePost/`、`client/lib/model/camera_capture_result.dart`、`client/lib/utils/video_processor.dart`、`client/lib/l10n/app_zh.arb`、`client/lib/l10n/app_en.arb`。
- 不需要数据迁移；旧草稿中的媒体条目继续走相同上传与显示逻辑。
- 不引入新的服务端接口或契约。
- 部署建议：

  1. 阶段 0：稳定性与生命周期收尾、单视频上限统一，作为内部测试版先行。
  2. 阶段 1：点击对焦、曝光、九宫格、倒计时，先小范围发布验证。
  3. 阶段 2：物理镜头与受控画质。
  4. 阶段 3：多张照片会话与拍后滤镜。
- 回滚策略：所有改动通过功能开关（`SharedPreferences`）控制；开关关闭时相机页直接走原实现路径，便于按阶段回退。

## Open Questions

- 录制 UI 是否需要将计时格式从 `m:ss` 升级为更显眼的大字显示？
- 多张照片会话是否需要在顶部条中显示每张的小缩略图，还是只显示已拍数量与最后一张？
- 拍后滤镜的“原图 / 黑白 / 暖色 / 冷色 / 高对比度”是否需要进一步 A/B 决定是否保留全部 5 项。