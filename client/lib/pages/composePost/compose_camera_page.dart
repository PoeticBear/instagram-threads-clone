import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/utils/video_processor.dart';
import '../../main.dart';
import '../../model/camera_capture_result.dart';

/// 相机页面（拍照 + 录视频）
/// - [initialMode] 决定默认进入拍照还是视频 Tab
/// - pop 值：[CameraCaptureResult]
class ComposeCameraPage extends StatefulWidget {
  const ComposeCameraPage({super.key, this.initialMode = CameraMode.photo});

  final CameraMode initialMode;

  @override
  State<ComposeCameraPage> createState() => _ComposeCameraPageState();
}

/// 相机模式（公开，供外部调用方选择默认 Tab）
enum CameraMode { photo, video }

class _ComposeCameraPageState extends State<ComposeCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isSwitchingCamera = false;
  bool _isTakingPicture = false;
  FlashMode _flashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _hasError = false;

  // 模式与录制
  late CameraMode _mode;
  bool _isRecording = false;
  DateTime? _recordingStartAt;
  // 切换拍照/视频模式时为 true，期间预览区显示 loading。
  // 防止在旧 CameraController dispose 之后，框架仍持有它的 ValueListenable<CameraValue>，
  // 进而抛出 "buildPreview() was called on a disposed CameraController"。
  bool _isSwitchingMode = false;

  // 视频时长上限（与后端 / VideoProcessor 保持一致：60s）
  static const int _maxVideoDurationSec = 60;
  // 自动停止容差（每 200ms 检查一次）
  static const Duration _recordingTickInterval = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  // ─── Camera lifecycle ───────────────────────────────────

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    // Find back camera
    _cameraIndex = 0;
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.back) {
        _cameraIndex = i;
        break;
      }
    }
    await _startCamera();
  }

  /// 初始化 CameraController。
  /// - 视频模式开启音频（需麦克风权限）
  /// - 切换模式时也会调用本方法重建 controller
  Future<void> _startCamera() async {
    if (cameras.isEmpty || _cameraIndex >= cameras.length) return;

    _controller = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: _mode == CameraMode.video,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      if (mounted) setState(() {});
    } on CameraException catch (e) {
      // 用户拒绝授权或初始化失败
      debugPrint('Camera init failed: ${e.code} ${e.description}');
      if (mounted) setState(() => _hasError = true);
    }
  }

  // ─── Mode switching ────────────────────────────────────

  Future<void> _switchMode(CameraMode newMode) async {
    if (_mode == newMode || _isRecording) return;
    setState(() {
      _mode = newMode;
      _isSwitchingMode = true; // 预览区立即进入 loading 态
    });
    HapticFeedback.selectionClick();

    // 让当前帧的 setState 先 commit（loading 态渲染出来后再 dispose 旧 controller），
    // 否则 ValueListenableBuilder<CameraValue> 在重建时会拿到已 dispose 的 controller。
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // 重建 controller 以切换 enableAudio
    await _controller?.dispose();
    _controller = null;
    await _startCamera();

    if (mounted) setState(() => _isSwitchingMode = false);
  }

  // ─── Photo actions ─────────────────────────────────────

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    HapticFeedback.mediumImpact();

    try {
      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(CameraCaptureResult.photo(xFile.path));
      }
    } catch (e) {
      debugPrint('Take picture failed: $e');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  // ─── Video actions ─────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    try {
      // startVideoRecording 内部会触发系统保存对话框（iOS），可由包含 UIVideoAtPathIsCompatibleKey 处理
      await _controller!.startVideoRecording();
      _recordingStartAt = DateTime.now();
      if (mounted) setState(() => _isRecording = true);
      _scheduleAutoStop();
    } catch (e) {
      debugPrint('Start recording failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cameraStartRecordingFailed)),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;

    HapticFeedback.mediumImpact();
    setState(() => _isRecording = false);
    final startAt = _recordingStartAt;
    _recordingStartAt = null;

    try {
      final xFile = await controller.stopVideoRecording();
      final durationMs = startAt == null
          ? 0
          : DateTime.now().difference(startAt).inMilliseconds;

      // 生成首帧缩略图（不阻塞返回，失败时降级无图）
      File? thumb;
      try {
        final thumbFile = await VideoProcessor.getThumbnail(xFile.path);
        thumb = thumbFile;
      } catch (e) {
        debugPrint('Generate thumbnail failed: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        CameraCaptureResult.video(
          path: xFile.path,
          durationMs: durationMs,
          thumbnail: thumb ?? File(xFile.path),
        ),
      );
    } catch (e) {
      debugPrint('Stop recording failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cameraStopRecordingFailed(e.toString()))),
        );
      }
    }
  }

  /// 自动停止定时器：到 _maxVideoDurationSec 时强制停止
  void _scheduleAutoStop() {
    Future.delayed(_recordingTickInterval, () {
      if (!mounted || !_isRecording) return;
      final startAt = _recordingStartAt;
      if (startAt == null) return;
      final elapsed = DateTime.now().difference(startAt).inSeconds;
      if (elapsed >= _maxVideoDurationSec) {
        _stopRecording();
        return;
      }
      // 持续触发 setState 以刷新计时器 UI
      setState(() {});
      _scheduleAutoStop();
    });
  }

  // ─── Common actions ────────────────────────────────────

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    HapticFeedback.lightImpact();

    final currentDir = cameras[_cameraIndex].lensDirection;
    final targetDir = currentDir == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == targetDir) {
        _cameraIndex = i;
        break;
      }
    }

    await _controller?.dispose();
    _controller = null;
    await _startCamera();

    if (mounted) setState(() => _isSwitchingCamera = false);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }

  void _handleZoom(ScaleUpdateDetails details) {
    if (_controller == null) return;
    final newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
    _controller!.setZoomLevel(newZoom);
    setState(() => _currentZoom = newZoom);
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          if (_hasError)
            _buildError(appColors)
          else
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(appColors),
                  const Spacer(),
                  _buildBottomControls(appColors),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_controller == null || !_controller!.value.isInitialized || _isSwitchingMode) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onScaleUpdate: _handleZoom,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: _isSwitchingCamera
              ? Container(color: Colors.black)
              : CameraPreview(_controller!),
        ),
      ),
    );
  }

  /// 头部单行：左 [✕] ｜ 中 [拍照|视频] pill ｜ 右 [⚡/●REC]
  /// - pill 几何居中（用 Expanded + Center 包裹）
  /// - 录制中 pill 隐藏，让 [●REC] 计时器在右位显示
  /// - 行高固定 44px，与左右圆形按钮同高，视觉对齐
  Widget _buildHeader(AppColors appColors) {
    final isBackCamera = cameras.isNotEmpty &&
        cameras[_cameraIndex].lensDirection == CameraLensDirection.back;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              // 左：关闭按钮
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
              // 中：模式 pill（录制中隐藏）
              Expanded(
                child: Center(
                  child: _isRecording
                      ? const SizedBox.shrink()
                      : _buildModePill(l10n),
                ),
              ),
              // 右：闪光灯 / 录制指示器
              if (_isRecording)
                _buildRecordingIndicator()
              else
                GestureDetector(
                  onTap: isBackCamera && _mode == CameraMode.photo
                      ? _toggleFlash
                      : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _flashMode == FlashMode.torch
                          ? Iconsax.flash_15
                          : Iconsax.flash_slash5,
                      color: (isBackCamera && _mode == CameraMode.photo)
                          ? Colors.white
                          : Colors.white24,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 拍照 / 视频 模式切换 pill
  Widget _buildModePill(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            label: l10n.cameraModePhoto,
            active: _mode == CameraMode.photo,
            onTap: () => _switchMode(CameraMode.photo),
          ),
          _buildModeChip(
            label: l10n.cameraModeVideo,
            active: _mode == CameraMode.video,
            onTap: () => _switchMode(CameraMode.video),
          ),
        ],
      ),
    );
  }

  /// 录制中顶部红点 + 计时器
  Widget _buildRecordingIndicator() {
    final startAt = _recordingStartAt;
    final elapsed = startAt == null
        ? Duration.zero
        : DateTime.now().difference(startAt);
    final clamped = elapsed.inSeconds.clamp(0, _maxVideoDurationSec);
    final mm = (clamped ~/ 60).toString().padLeft(1, '0');
    final ss = (clamped % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$mm:$ss / 1:00',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(AppColors appColors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 24, top: 20),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildShutter(),
              Positioned(
                right: 0,
                child: _buildFlipButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 翻转前后摄像头按钮（60×60 圆形 + Iconsax.refresh）
  Widget _buildFlipButton() {
    return GestureDetector(
      onTap: _isRecording ? null : _switchCamera,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(Iconsax.refresh, color: Colors.white, size: 28),
      ),
    );
  }

  /// 快门按钮：拍照圆形 / 视频方块（录制中变红）
  Widget _buildShutter() {
    if (_mode == CameraMode.photo) {
      return GestureDetector(
        onTap: _isTakingPicture ? null : _takePicture,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: _isTakingPicture ? Colors.white24 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 4),
          ),
          child: _isTakingPicture
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                )
              : null,
        ),
      );
    }

    // 视频模式：单击切换录制状态
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _toggleRecording,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.transparent : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording ? Colors.red : Colors.white54,
            width: 4,
          ),
        ),
        child: _isRecording
            ? Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildError(AppColors appColors) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.camera, size: 64, color: Colors.white24),
              const SizedBox(height: 24),
              Text(
                l10n.cameraAccessRequired,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.cameraAccessHint,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.cameraGoBack,
                    style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
