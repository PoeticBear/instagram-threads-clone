## ADDED Requirements

### Requirement: 视频上限统一为 300 秒

发布帖子相机的拍摄、计时显示、上传校验与文案必须使用单一视频上限 300 秒。任何录像时长相关数值、文案、注释与默认参数 SHALL 一致。

#### Scenario: 相机录像达到 300 秒自动停止
- **WHEN** 用户连续录制，录制计时达到 5:00
- **THEN** 系统 SHALL 自动调用 `stopVideoRecording()`，生成首帧缩略图，返回结果；不再向用户提供继续录制

#### Scenario: 上传校验拒绝超过 300 秒的视频
- **WHEN** `UploadService.uploadMedia` 收到一个 `mediaType == video` 且实际时长 > 300 秒的文件
- **THEN** 系统 SHALL 返回失败并提示“视频超过 5 分钟”，不进入 COS 上传流程

#### Scenario: 错误文案与视频上限一致
- **WHEN** 用户在相册或相机入口选择了一段超长视频
- **THEN** 失败提示 SHALL 显式包含“5 分钟”或“300 秒”，不出现“1 分钟”或“60 秒”

### Requirement: 录制生命周期与关闭安全收尾

相机页 SHALL 在应用进入后台、页面被关闭、用户切换镜头或模式时安全停止正在进行的录像，不留下未完成视频或不一致的录制状态。

#### Scenario: 应用进入后台时正在录制
- **WHEN** `didChangeAppLifecycleState` 收到 `inactive` 且 `_isRecording == true`
- **THEN** 系统 SHALL 先 `await controller.stopVideoRecording()`，按正常停止流程生成缩略图并返回结果；停止异常 SHALL 进入错误状态，丢弃未保存视频

#### Scenario: 录制中点击关闭按钮
- **WHEN** `_isRecording == true` 时用户点击相机页关闭按钮
- **THEN** 系统 SHALL 先停止录像并完成首帧生成，再 `Navigator.pop` 返回结果；不允许直接 `dispose` 控制器丢弃视频

#### Scenario: 应用恢复后状态一致
- **WHEN** 应用从 `inactive` 回到 `resumed`
- **THEN** 系统 SHALL 清空 `_hasError`，重新 `_startCamera`，并把 `_isRecording` 设为 false；UI SHALL 不再显示录制计时或停止按钮

### Requirement: 相机控制器重建串行化

任何会重建 `CameraController` 的操作（模式切换、镜头切换、画质切换、生命周期恢复）SHALL 串行执行，新的初始化 SHALL 取消或丢弃未完成的旧初始化结果，避免新旧状态互相覆盖。

#### Scenario: 用户在切换完成前快速点击不同切换按钮
- **WHEN** `_isSwitchingCamera / _isSwitchingMode` 为 true 时用户再次点击切换
- **THEN** 系统 SHALL 忽略新点击，直到当前重建完成；最终 `_controller` SHALL 对应最后一次提交的请求

#### Scenario: 重建期间异步初始化完成回调到达
- **WHEN** 旧 controller 已被 dispose、新的初始化异步回调到达 `_myGeneration != _pendingGeneration`
- **THEN** 系统 SHALL 不修改当前 UI 状态，仅消费最新一次回调的结果

### Requirement: 相机拍摄结果接入统一校验

相机拍摄完成的 `CameraCaptureResult` SHALL 与相册媒体走同一套文件大小、实际时长与基础元数据校验，校验失败 SHALL 不加入发帖媒体列表。

#### Scenario: 拍摄视频超过 100MB
- **WHEN** `CameraCaptureResult.isVideo == true` 且 `File(path).lengthSync() > 100 * 1024 * 1024`
- **THEN** 系统 SHALL 丢弃结果，提示“视频超过 100MB”，不进入 `MediaDraftItem` 列表

#### Scenario: 拍摄图片超过 10MB
- **WHEN** `CameraCaptureResult.isVideo == false` 且 `File(path).lengthSync() > 10 * 1024 * 1024`
- **THEN** 系统 SHALL 丢弃结果，提示“图片超过 10MB”，不进入 `MediaDraftItem` 列表

#### Scenario: 视频实际时长为 0 或超过 300 秒
- **WHEN** `VideoProcessor.getMediaInfo` 返回 `durationMs <= 0` 或 `> 300000`
- **THEN** 系统 SHALL 丢弃结果，提示“视频时长无效”，不进入 `MediaDraftItem` 列表

### Requirement: 视频首帧缩略图失败时使用安全占位

视频首帧缩略图生成失败 SHALL 不再把视频文件本身作为 `thumbnail` 写入；UI SHALL 使用统一的视频占位资源。

#### Scenario: `VideoProcessor.getThumbnail` 抛异常
- **WHEN** 拍摄完成后 `getThumbnail` 失败
- **THEN** `CameraCaptureResult.thumbnail` SHALL 为 `null`，相机页与发帖页 SHALL 使用统一的“视频占位”资源作为缩略图，不调用 `Image.file(thumbnail)`

#### Scenario: 缩略图生成返回合法文件
- **WHEN** `getThumbnail` 返回有效 jpg 路径
- **THEN** 系统 SHALL 把该路径作为 `thumbnail` 写入，`Image.file` 正常渲染

### Requirement: 点击对焦与点击曝光点

相机预览 SHALL 支持点击设置对焦点与曝光点；不支持的设备 SHALL 隐藏对应 UI 而非崩溃。

#### Scenario: 用户在预览中点击一次
- **WHEN** 用户点击预览区域且 `focusPointSupported == true && exposurePointSupported == true`
- **THEN** 系统 SHALL 同时 `setFocusPoint(normX, normY)` 与 `setExposurePoint(normX, normY)`，并在该坐标显示 2 秒的对焦框 overlay

#### Scenario: 前置镜头下点击坐标镜像
- **WHEN** 当前镜头 `lensDirection == front`
- **THEN** 系统 SHALL 把 x 坐标镜像为 `1 - x` 后再传给 `setFocusPoint` / `setExposurePoint`

#### Scenario: 设备不支持对焦或曝光点
- **WHEN** `focusPointSupported == false` 或 `exposurePointSupported == false`
- **THEN** 系统 SHALL 不调用对应 API，UI SHALL 不显示对焦框，不抛异常

#### Scenario: 控制器重建或进入后台时清理对焦框
- **WHEN** `_startCamera` 重新完成或 `didChangeAppLifecycleState == inactive`
- **THEN** 系统 SHALL 立刻隐藏对焦框并取消对焦动画 Timer

### Requirement: 曝光补偿滑杆

相机页 SHALL 提供曝光补偿滑杆，范围为当前设备最小/最大曝光偏移，步长为 `getExposureOffsetStepSize`；用户偏好 SHALL 在控制器重建后被重新应用并 clamp。

#### Scenario: 控制器初始化完成后读取范围
- **WHEN** `controller.initialize()` 完成
- **THEN** 系统 SHALL 调用 `getMinExposureOffset / getMaxExposureOffset / getExposureOffsetStepSize`，并据此构建滑杆刻度

#### Scenario: 滑杆调整曝光补偿
- **WHEN** 用户拖动滑杆至 `targetOffset`
- **THEN** 系统 SHALL 调用 `setExposureOffset(clamp(targetOffset, min, max))`；滑杆位置 SHALL 与返回值同步

#### Scenario: 切换镜头或模式后曝光补偿被 clamp
- **WHEN** 用户切换到不支持原偏移值的新镜头
- **THEN** 系统 SHALL 把当前偏移 clamp 到新镜头的合法范围，再调用 `setExposureOffset`

### Requirement: 九宫格辅助线

相机页 SHALL 提供可开关的九宫格辅助线；默认关闭；开启后 SHALL 在预览画面上叠加四条辅助线，并允许穿透到点击对焦和缩放手势。

#### Scenario: 用户打开九宫格
- **WHEN** 用户点击九宫格开关
- **THEN** 预览 SHALL 显示 4 条辅助线；开关状态持久化到 `SharedPreferences`

#### Scenario: 九宫格覆盖层不拦截手势
- **WHEN** 九宫格 overlay 处于显示状态
- **THEN** overlay widget SHALL 使用 `IgnorePointer` 或 `behavior: HitTestBehavior.translucent`；tap 对焦、双指缩放 SHALL 正常触发

### Requirement: 3 秒倒计时

相机页 SHALL 提供固定 3 秒倒计时开关，默认关闭；倒计时期间 SHALL 显示 3、2、1 数字，结束后触发拍照或开始录像；倒计时 SHALL 在切换镜头、切换模式、关闭页面、App 进入后台或重复点击快门时被取消。

#### Scenario: 倒计时完成后触发拍照
- **WHEN** 倒计时开关为 3 秒且用户点击快门
- **THEN** 系统 SHALL 按 1 秒间隔显示 3、2、1，倒数到 0 时调用 `_takePicture()`；倒计时期间禁用快门

#### Scenario: 倒计时期间切换镜头
- **WHEN** 倒计时处于 3 或 2 状态且用户点击镜头切换
- **THEN** 系统 SHALL 取消倒计时 Timer，不执行 `_takePicture()`

#### Scenario: 倒计时期间 App 进入后台
- **WHEN** `didChangeAppLifecycleState == inactive` 触发
- **THEN** 系统 SHALL 取消倒计时 Timer；恢复后 SHALL 不会自动补拍

#### Scenario: 倒计时也支持视频模式
- **WHEN** 当前为视频模式且倒计时开关为 3 秒
- **THEN** 倒计时结束后 SHALL 调用 `_startRecording()`，而不是 `_takePicture()`

### Requirement: 基于设备能力的物理镜头选择

相机页 SHALL 仅展示设备实际枚举到的物理镜头，按 `lensType` 映射为 0.5×、1×、长焦入口；切换 SHALL 重建控制器，期间显示 loading；录像中 SHALL 禁止切换镜头。

#### Scenario: 设备具备 ultraWide / wide / telephoto
- **WHEN** `cameras` 中后置包含 `ultraWide / wide / telephoto`
- **THEN** 系统 SHALL 按顺序显示 0.5×、1×、2× 三个入口；点击切换后 `_cameraIndex` 更新并重建 `CameraController`

#### Scenario: 设备只有 wide 后置
- **WHEN** 后置只有一个 `wide` 镜头
- **THEN** 系统 SHALL 只显示 1× 入口，不显示 0.5× 或长焦

#### Scenario: 录像中点击镜头切换
- **WHEN** `_isRecording == true` 且用户点击 0.5× / 2× 入口
- **THEN** 系统 SHALL 忽略该点击，不重建控制器

#### Scenario: 镜头切换期间显示 loading
- **WHEN** 镜头切换尚未完成
- **THEN** 相机页 SHALL 显示 `_isSwitchingCamera` loading 状态，禁用其他切换按钮

### Requirement: 受控画质档位

相机页 SHALL 仅提供两个画质档位：720p/30fps 与 1080p/30fps；默认 1080p/30fps；切换 SHALL 重建控制器；不暴露 4K 或独立帧率。

#### Scenario: 用户切换画质
- **WHEN** 用户点击画质切换按钮
- **THEN** 系统 SHALL 用对应 `(ResolutionPreset, fps=30)` 重建 `CameraController`，并在成功后展示新画质

#### Scenario: 重建后保留曝光、对焦和九宫格偏好
- **WHEN** 画质切换导致 `_startCamera` 重新执行
- **THEN** 系统 SHALL 重新读取曝光范围、闪光灯偏好、九宫格状态并重新应用；对焦状态 SHALL 重置为未触发

#### Scenario: 默认画质
- **WHEN** 用户首次进入相机页且偏好不存在
- **THEN** 系统 SHALL 使用 1080p/30fps

### Requirement: 多张照片会话拍摄

照片模式 SHALL 改为会话内逐张拍摄：进入相机时由 `ComposePost._openCamera` 传入 `remainingCapacity`，相机页 SHALL 维持已拍列表，达到容量时禁用快门，点击完成后批量返回；视频录制 SHALL 仍按原单次返回。

#### Scenario: 进入相机时收到剩余配额
- **WHEN** `ComposePost._openCamera` 调用 `Navigator.push(ComposeCameraPage(remainingCapacity: N))`
- **THEN** 相机页 SHALL 初始允许拍摄 N 张；N 为 0 时 SHALL 直接禁用快门并显示提示

#### Scenario: 拍摄多张照片并完成
- **WHEN** 用户在照片模式依次拍摄 M 张（M <= N）并点击“完成”
- **THEN** 系统 SHALL `Navigator.pop(List<CameraCaptureResult>)` 返回 M 项结果；`ComposePost` SHALL 逐项转 `MediaDraftItem` 并调用 `_addMedia`

#### Scenario: 拍摄中达到配额
- **WHEN** 已拍数量 == remainingCapacity
- **THEN** 相机页 SHALL 禁用快门，但“完成”和“删除”入口仍可用

#### Scenario: 删除某张照片
- **WHEN** 用户从已拍列表中删除某项
- **THEN** 系统 SHALL 删除其临时文件并从 `_captures` 移除；剩余配额 SHALL 增加 1，快门重新可用

#### Scenario: 视频录制不走会话
- **WHEN** 用户在视频模式点击录制并完成
- **THEN** 系统 SHALL 直接 `Navigator.pop(CameraCaptureResult.video(...))`，不进入 `_captures` 列表

#### Scenario: 会话中关闭或返回上一步
- **WHEN** 用户中途关闭相机页
- **THEN** 系统 SHALL 删除所有未返回的临时照片文件，`_captures` 不返回给发布页

### Requirement: 拍后静态图片滤镜

照片拍摄完成 SHALL 进入确认页，用户 SHALL 能选择少量静态滤镜；不使用图像流、不处理视频帧。

#### Scenario: 拍摄完成后进入确认页
- **WHEN** 照片拍完
- **THEN** 系统 SHALL 弹出确认页，原图全屏预览；底部 SHALL 列出“原图 / 黑白 / 暖色 / 冷色 / 高对比度”

#### Scenario: 选择滤镜后保存新文件
- **WHEN** 用户点击滤镜选项
- **THEN** 系统 SHALL 用图片处理依赖同步生成新文件，写入临时目录，preview 切换为新文件；原图 SHALL 保留以便“重拍”

#### Scenario: 用户点击使用
- **WHEN** 用户点击“使用”
- **THEN** 系统 SHALL 把当前显示的文件路径作为 `CameraCaptureResult.path` 加入会话；继续会话或返回发布页

#### Scenario: 用户点击重拍
- **WHEN** 用户点击“重拍”
- **THEN** 系统 SHALL 删除所有当前生成的滤镜临时文件与原图临时文件，重新调用 `_takePicture()`，不返回任何结果

#### Scenario: 滤镜处理超时或失败
- **WHEN** 滤镜处理超过 2 秒或抛异常
- **THEN** 系统 SHALL 提示“滤镜处理失败”，允许用户继续使用原图或重拍，不阻塞流程