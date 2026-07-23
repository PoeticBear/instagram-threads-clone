## 1. 现有相机稳定性与视频规则统一

- [x] 1.1 在 `compose_camera_page.dart` 把 `_maxVideoDurationSec` 固定为 300，录制 UI 计时上限显示 `/ 5:00`
- [x] 1.2 在 `post.dart` 把 `_maxVideoDurationMs` 固定为 300000，并清理 60 秒相关注释
- [x] 1.3 在 `video_processor.dart` 把默认值改为 300 秒，方法注释与上传链路上限同步
- [x] 1.4 在 `app_zh.arb` 和 `app_en.arb` 中把“视频超过 X 秒”改为“5 分钟”/“300 秒”，不再出现 1 分钟
- [x] 1.5 在 `compose_camera_page.dart` 处理 `inactive` 时先 `stopVideoRecording()`，再 dispose controller；恢复时清空 `_hasError` 并重新 `_startCamera`
- [x] 1.6 关闭按钮在录制中先停止录制再 pop，不直接 dispose
- [x] 1.7 在 `compose_camera_page.dart` 引入 `_pendingGeneration / _myGeneration`，让 `_startCamera` 串行化旧异步回调
- [x] 1.8 修正双指缩放：`onScaleStart` 保存 `_zoomBase`、`onScaleUpdate` 用 `clamp(_zoomBase * details.scale, min, max)`、`onScaleEnd` 写回 `setZoomLevel`

## 2. 相机结果统一校验与缩略图安全降级

- [x] 2.1 抽出 `camera_result_validator.dart`：按 `isVideo` 校验文件大小（图片 10MB、视频 100MB、GIF 10MB）
- [x] 2.2 在视频校验中调用 `VideoProcessor.getMediaInfo`，失败或时长越界时返回失败原因
- [x] 2.3 把 `VideoProcessor.getThumbnail` 失败时不再把视频文件本身作为 `thumbnail`，统一返回 null
- [x] 2.4 在 `compose_camera_page.dart` 拍摄完成后调用校验器，失败时 Toast 错误并继续在相机页
- [x] 2.5 在发帖页 `_addMedia` 入口接收批量 `CameraCaptureResult`，对每项跑校验，失败项跳过并 Toast
- [x] 2.6 视频时长优先使用 `getMediaInfo` 实际时长；读取失败再回退到墙钟差

## 3. 拍摄辅助：点击对焦、曝光点、曝光补偿、九宫格、3 秒倒计时

- [x] 3.1 在 `compose_camera_page.dart` 引入对焦状态：对焦点 `_focusPoint`、`_focusAtMs`、Timer；支持性来自 `controller.value.focusPointSupported`
- [x] 3.2 在预览 `GestureDetector` 的 `onTapUp` 中按 `BoxFit.cover` 计算归一化坐标，前置镜头镜像 x
- [x] 3.3 tap 同时调用 `setFocusPoint` 与 `setExposurePoint`，并显示 2 秒对焦框 overlay（`IgnorePointer`）
- [x] 3.4 `_startCamera` 完成后读取 `getMin/MaxExposureOffset / getExposureOffsetStepSize`，建立曝光补偿状态与滑杆刻度
- [x] 3.5 曝光补偿滑杆 UI：垂直滑杆，clamp 到设备范围；调整时 `setExposureOffset`
- [x] 3.6 镜头切换、模式切换、生命周期 inactive 时 clamp 曝光值并清理对焦框
- [x] 3.7 九宫格 overlay：4 条线，`IgnorePointer`，提供开关按钮与 `SharedPreferences` 持久化，l10n 文案
- [x] 3.8 3 秒倒计时：`_countdownTimer`、`_countdownValue`，快门点击触发 `Timer.periodic`；切换镜头、模式、关闭、inactive 时取消；视频模式同样支持

## 4. 物理镜头与受控画质

- [x] 4.1 新增工具 `camera_lens_helper.dart`，按 `lensDirection + lensType` 排序并产出 0.5×/1×/长焦入口
- [x] 4.2 `ComposeCameraPage` 接收可用后置镜头列表，渲染底部镜头切换按钮
- [x] 4.3 镜头切换走 `_startCamera` 串行路径，loading 期间禁用其他切换；录像中拒绝切换
- [x] 4.4 `_startCamera` 完成后按新镜头重新读取曝光范围、zoom 范围并 clamp
- [x] 4.5 引入 `CameraQualityPreset { sd720p30, hd1080p30 }` 与画质切换 UI，默认 `hd1080p30`，持久化偏好
- [x] 4.6 `_startCamera` 根据 `CameraQualityPreset` 设置 `ResolutionPreset + fps = 30`；不暴露 4K 或独立帧率

## 5. 多张照片会话拍摄

- [x] 5.1 修改 `ComposeCameraPage` 构造函数支持 `remainingCapacity`；N 为 0 时禁用快门并提示
- [x] 5.2 `ComposePost._openCamera` 计算 `_maxMediaCount - _mediaDrafts.length` 并传入
- [x] 5.3 相机页维护 `_captures: List<CameraCaptureResult>`、缩略图条与完成按钮，达到容量禁用快门
- [x] 5.4 拍照完成不立即 `pop`，改为进入 `ComposeCameraConfirmPage`（与步骤 6 一并实现）；视频仍直接返回
- [x] 5.5 “完成”按钮 `Navigator.pop(List<CameraCaptureResult>)`，关闭或中途退出清理未返回临时文件
- [x] 5.6 `ComposePost._openCamera` 的 `then` 回调逐项调用 `_addMedia`，保留 `_mediaDrafts` 已有顺序逻辑

## 6. 拍后静态图片滤镜与确认页

- [x] 6.1 在 `pubspec.yaml` 加入图片处理依赖（仅静态图片处理，不引入视频处理依赖）
- [x] 6.2 新增 `compose_camera_confirm_page.dart`：原图预览、滤镜列表、底部“重拍/使用”
- [x] 6.3 实现 5 个滤镜：原图、黑白、暖色、冷色、高对比度；处理结果写入新临时文件
- [x] 6.4 处理超过 2 秒或失败时显示错误并允许继续使用原图
- [x] 6.5 “使用”后把新文件路径作为 `CameraCaptureResult.path` 加入会话或返回发布页
- [x] 6.6 “重拍”删除原图与滤镜临时文件，重新调用 `_takePicture()`，不返回任何结果
- [x] 6.7 确认页与多张照片会话联动：拍完 → 确认 → 加入 `_captures`

## 7. 文案、图标与状态

- [x] 7.1 在 `app_zh.arb` 和 `app_en.arb` 增加对焦、曝光、九宫格、倒计时、镜头、画质、会话、滤镜、占位图相关 key
- [x] 7.2 抽取统一的“视频占位”资源供视频缩略图失败场景使用（实际实现：`Image.file(... errorBuilder: Container(color: Colors.white12))`，不新增资源）
- [x] 7.3 在 `docs/code-locations/publish-post.md` 与 `select-media.md` 增补新能力定位与状态机说明
- [x] 7.4 在 `docs/changelog` 模板中保留本变更对应 entry 占位

## 8. 真机回归与发布准备

- [ ] 8.1 在 iPhone 15/15 Pro 真机上验证：拍照、录像、对焦/曝光、九宫格、3 秒倒计时、镜头切换、画质切换、多张照片会话、拍后滤镜（需用户在真机执行）
- [ ] 8.2 验证后台、权限弹窗、控制中心期间录制的安全收尾（需用户在真机执行）
- [ ] 8.3 验证视频超过 100MB / 实际时长 > 300 秒 的拒绝路径（需用户在真机执行）
- [ ] 8.4 在 iPhone 13、iPhone 14 基础款上验证 ultraWide 缺失与单镜头时的降级 UI（需用户在真机执行）
- [ ] 8.5 验证发帖页最终媒体预览与上传链路无回归（旧链路 + 新返回模型）（需用户在真机执行）
- [ ] 8.6 按项目 CLAUDE.md 发布 TestFlight 流程：bump 构建号 → build ipa → xcodebuild exportArchive → 上传 → changelog（需用户在终端执行）

> 任务 8.x 需要真机和终端，由用户手动执行；本 session 已完成代码层面的全部修改。