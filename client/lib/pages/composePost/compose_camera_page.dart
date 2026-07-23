import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/utils/video_processor.dart';
import 'package:threads/utils/camera_result_validator.dart';
import 'package:threads/pages/composePost/camera_lens_helper.dart';
import 'package:threads/pages/composePost/camera_quality_preset.dart';
import 'package:threads/pages/composePost/compose_camera_confirm_page.dart';
import '../../main.dart';
import '../../model/camera_capture_result.dart';

/// 相机页面（拍照 + 录视频）
/// - [initialMode] 决定默认进入拍照还是视频 Tab
/// - [remainingCapacity] 照片模式最多还能拍几张（来自发布页剩余媒体配额）
/// - pop 值：
///   - 单视频录制完成 → [CameraCaptureResult]
///   - 照片模式多张会话完成 → `List<CameraCaptureResult>`
class ComposeCameraPage extends StatefulWidget {
  const ComposeCameraPage({
    super.key,
    this.initialMode = CameraMode.photo,
    this.remainingCapacity = 1,
  });

  final CameraMode initialMode;
  final int remainingCapacity;

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

  // 控制器重建串行化：每次 _startCamera 自增 _pendingGeneration，
  // 异步初始化回调里只有 _myGeneration == _pendingGeneration 才提交状态。
  // _myGeneration 实际只在 _startCamera 内部使用；保留作为串行化的语义标识。
  // ignore: unused_field
  int _pendingGeneration = 0;
  // ignore: unused_field
  int _myGeneration = -1;

  // 双指缩放：onScaleStart 保存基准 zoom，避免累乘误差
  double _zoomBase = 1.0;

  // 模式 pill 水平平移量（preview 纵向滑动手势驱动；切模式后回弹）
  double _modePillDx = 0.0;
  // 动画 generation counter：每次 _onVerticalDragUpdate / _onVerticalDragEnd 自增，
  // 旧的回弹 Task 检测到 generation 变化后立即退出，避免动画串台
  int _pillAnimGen = 0;

  // 点击对焦 / 曝光点
  Offset? _focusPoint; // 归一化坐标 (0..1)，相对预览可视区域
  DateTime? _focusShownAt;

  // 曝光补偿
  double _minExposure = 0.0;
  double _maxExposure = 0.0;
  double _exposureStep = 0.0;
  double _currentExposure = 0.0;

  // 九宫格
  bool _showGrid = false;

  // 倒计时（0 = 关闭，3 = 3 秒）
  int _countdownSeconds = 0;
  Timer? _countdownTimer;
  int _countdownValue = 0;

  // 照片会话：已拍列表
  final List<CameraCaptureResult> _captures = [];

  // 画质档位（持久化到 SharedPreferences）
  CameraQualityPreset _quality = CameraQualityPreset.hd1080p30;

  // 视频时长上限：300 秒（5 分钟）
  static const int _maxVideoDurationSec = 300;
  // 自动停止容差（每 200ms 检查一次）
  static const Duration _recordingTickInterval = Duration(milliseconds: 200);
  // 对焦框 2 秒后自动消失
  static const Duration _focusOverlayDuration = Duration(milliseconds: 2000);
  // 预览区纵向滑动切模式的位移阈值（logical px）
  static const double _kSwitchModeDragThreshold = 50.0;
  // mode pill 跟随平移的最大绝对偏移（视觉上限，避免跟手过分）
  static const double _kModePillMaxAbsDx = 80.0;
  // mode pill 回弹动画总时长
  static const Duration _kModePillAnimDuration = Duration(milliseconds: 240);
  // SharedPreferences key
  static const String _kQualityPrefKey = 'compose_camera_quality';
  static const String _kGridPrefKey = 'compose_camera_grid';
  static const String _kCountdownPrefKey = 'compose_camera_countdown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    _loadPrefs();
    _initCamera();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final q = p.getString(_kQualityPrefKey);
      if (q != null) {
        _quality = CameraQualityPreset.values.firstWhere(
          (e) => e.name == q,
          orElse: () => CameraQualityPreset.hd1080p30,
        );
      }
      _showGrid = p.getBool(_kGridPrefKey) ?? false;
      _countdownSeconds = p.getInt(_kCountdownPrefKey) ?? 0;
      if (mounted) setState(() {});
    } catch (_) {
      // 静默：读取失败不影响相机主流程
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // 倒计时与录制都需先停止，避免后台产生状态不一致
      _cancelCountdown();
      _hideFocus();
      if (_isRecording) {
        _stopRecording(); // 不 await：后台不允许 UI 调度
      } else {
        _controller?.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      _hasError = false;
      _isRecording = false;
      _recordingStartAt = null;
      _startCamera();
    }
  }

  // ─── Camera lifecycle ───────────────────────────────────

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      setState(() => _hasError = true);
      return;
    }
    // 默认优先选后置 wide 镜头
    _cameraIndex = _pickPreferredBackIndex() ?? 0;
    await _startCamera();
  }

  int? _pickPreferredBackIndex() {
    for (int i = 0; i < cameras.length; i++) {
      final c = cameras[i];
      if (c.lensDirection == CameraLensDirection.back &&
          c.lensType == CameraLensType.wide) {
        return i;
      }
    }
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.back) {
        return i;
      }
    }
    return null;
  }

  /// 初始化 CameraController。
  /// - 视频模式开启音频（需麦克风权限）
  /// - 切换模式时也会调用本方法重建 controller
  Future<void> _startCamera() async {
    if (cameras.isEmpty || _cameraIndex >= cameras.length) return;

    // 串行化：每次重建自增 generation
    _pendingGeneration++;
    final myGen = _pendingGeneration;
    _myGeneration = myGen;

    final resolution = _quality.resolutionPreset;
    final fps = _quality.fps;

    final newController = CameraController(
      cameras[_cameraIndex],
      resolution,
      enableAudio: _mode == CameraMode.video,
      fps: fps,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    // 先把 _controller 指向新实例，避免旧 controller 的 ValueListenable
    // 在异步初始化期间被 build() 读到
    _controller = newController;

    try {
      await newController.initialize();
      if (myGen != _pendingGeneration) {
        // 已有更新重建请求：本实例的回调应丢弃
        return;
      }
      await newController.setFlashMode(_flashMode);

      _minZoom = await newController.getMinZoomLevel();
      _maxZoom = await newController.getMaxZoomLevel();
      _currentZoom = _minZoom.clamp(_minZoom, _maxZoom);

      // 读取曝光范围；当前 offset clamp 到合法区间
      try {
        _minExposure = await newController.getMinExposureOffset();
        _maxExposure = await newController.getMaxExposureOffset();
        _exposureStep = await newController.getExposureOffsetStepSize();
        if (_exposureStep <= 0) _exposureStep = 0.1;
        _currentExposure = _currentExposure.clamp(_minExposure, _maxExposure);
        await newController.setExposureOffset(_currentExposure);
      } catch (_) {
        _minExposure = 0;
        _maxExposure = 0;
        _exposureStep = 0.1;
      }

      // 对焦 / 曝光点 overlay 清掉
      _hideFocus();

      if (mounted) setState(() {});
    } on CameraException catch (e) {
      // 用户拒绝授权或初始化失败
      debugPrint('Camera init failed: ${e.code} ${e.description}');
      if (myGen == _pendingGeneration && mounted) {
        setState(() => _hasError = true);
      }
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

    // 倒计时：先倒数再拍
    if (_countdownSeconds > 0 && !_isRecording) {
      await _runCountdown();
      if (!mounted) return;
      // 倒计时期间用户可能切镜头 / 切模式 / 关闭页面：所有这些都取消倒计时并跳到这里
      if (_captures.length >= widget.remainingCapacity) {
        // 容量满；不再触发
        return;
      }
    }

    setState(() => _isTakingPicture = true);
    HapticFeedback.mediumImpact();

    try {
      final xFile = await _controller!.takePicture();
      if (mounted) {
        // 进入拍后确认页；用户"使用"后通过 _onPhotoConfirmed 进入 _captures
        await _openConfirmPage(xFile.path);
      }
    } catch (e) {
      debugPrint('Take picture failed: $e');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  /// 打开拍后确认页；用户"使用"返回有效文件路径，"重拍"返回 null
  Future<void> _openConfirmPage(String path) async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<CameraCaptureResult>(
      MaterialPageRoute(builder: (_) => ComposeCameraConfirmPage(path: path)),
    );
    if (!mounted) return;
    if (result == null) {
      // 重拍：什么都不做；用户继续在拍照页面拍下一张
      return;
    }
    // 通过校验再加入 _captures
    final v = await CameraResultValidator.validate(result);
    if (!mounted) return;
    if (!v.ok) {
      _showSnack(v.message ?? '媒体无效');
      // 删除临时文件
      await _safeDelete(result.path);
      if (result.thumbnail != null) {
        await _safeDelete(result.thumbnail!.path);
      }
      return;
    }
    setState(() {
      _captures.insert(0, result);
    });
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ─── Video actions ─────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      // 视频模式也支持倒计时
      if (_countdownSeconds > 0) {
        await _runCountdown();
        if (!mounted) return;
      }
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    try {
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
      // 优先用实际媒体时长
      int durationMs = startAt == null
          ? 0
          : DateTime.now().difference(startAt).inMilliseconds;
      try {
        final meta = await VideoProcessor.getMediaInfo(xFile.path);
        if (meta.durationMs > 0) durationMs = meta.durationMs;
      } catch (_) {/* 静默：保留墙钟差 */}

      // 生成首帧缩略图（失败时不再 fallback 到视频文件）
      File? thumb;
      try {
        thumb = await VideoProcessor.getThumbnail(xFile.path);
      } catch (e) {
        debugPrint('Generate thumbnail failed: $e');
      }

      if (!mounted) return;
      final result = CameraCaptureResult.video(
        path: xFile.path,
        durationMs: durationMs,
        thumbnail: thumb,
      );
      // 视频同样走统一校验
      final v = await CameraResultValidator.validate(result);
      if (!mounted) return;
      if (!v.ok) {
        _showSnack(v.message ?? '视频无效');
        await _safeDelete(result.path);
        if (thumb != null) await _safeDelete(thumb.path);
        return;
      }
      // 视频模式下不进入 _captures，直接 pop
      Navigator.of(context).pop(result);
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
      if (mounted) setState(() {});
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

    int? newIndex;
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == targetDir) {
        newIndex = i;
        break;
      }
    }
    if (newIndex == null) {
      if (mounted) setState(() => _isSwitchingCamera = false);
      return;
    }
    _cameraIndex = newIndex;

    await _controller?.dispose();
    _controller = null;
    await _startCamera();

    if (mounted) setState(() => _isSwitchingCamera = false);
  }

  Future<void> _selectLens(CameraLensInfo lens) async {
    if (_isSwitchingCamera || _isRecording) return;
    if (cameras.isEmpty || lens.cameraIndex == _cameraIndex) return;
    setState(() => _isSwitchingCamera = true);
    HapticFeedback.lightImpact();

    _cameraIndex = lens.cameraIndex;

    await _controller?.dispose();
    _controller = null;
    await _startCamera();

    if (mounted) setState(() => _isSwitchingCamera = false);
  }

  Future<void> _toggleQuality() async {
    if (_isSwitchingCamera || _isRecording) return;
    final next = _quality == CameraQualityPreset.sd720p30
        ? CameraQualityPreset.hd1080p30
        : CameraQualityPreset.sd720p30;
    setState(() => _isSwitchingCamera = true);
    _quality = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kQualityPrefKey, next.name);
    } catch (_) {}
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

  Future<void> _toggleGrid() async {
    final next = !_showGrid;
    setState(() => _showGrid = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kGridPrefKey, next);
    } catch (_) {}
  }

  Future<void> _cycleCountdown() async {
    // 0 → 3 → 0
    final next = _countdownSeconds == 0 ? 3 : 0;
    setState(() => _countdownSeconds = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kCountdownPrefKey, next);
    } catch (_) {}
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomBase = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null) return;
    final newZoom = (_zoomBase * details.scale).clamp(_minZoom, _maxZoom);
    if ((newZoom - _currentZoom).abs() < 0.001) return;
    _controller!.setZoomLevel(newZoom);
    setState(() => _currentZoom = newZoom);
  }

  // ─── Vertical drag to switch photo / video mode ───────────

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // 任何新的拖拽会 invalidate 当前回弹动画
    _pillAnimGen++;
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _modePillDx = (_modePillDx + delta).clamp(
        -_kModePillMaxAbsDx,
        _kModePillMaxAbsDx,
      );
    });
  }

  Future<void> _onVerticalDragEnd(DragEndDetails details) async {
    final dx = _modePillDx;
    final myGen = ++_pillAnimGen; // 自增并锁定本次动画的 generation
    Future<void> snapBack(double from, double to) async {
      const steps = 12;
      final stepMs =
          (_kModePillAnimDuration.inMilliseconds / steps).round().clamp(8, 32);
      for (int i = 1; i <= steps; i++) {
        if (myGen != _pillAnimGen) return;
        await Future.delayed(Duration(milliseconds: stepMs));
        if (myGen != _pillAnimGen) return;
        if (!mounted) return;
        final t = i / steps;
        final eased = Curves.easeOut.transform(t);
        setState(() {
          _modePillDx = from + (to - from) * eased;
        });
      }
    }

    if (dx.abs() < _kSwitchModeDragThreshold) {
      await snapBack(dx, 0);
      if (mounted) setState(() => _modePillDx = 0);
      return;
    }

    if (_mode == CameraMode.photo && dx <= -_kSwitchModeDragThreshold) {
      await _switchMode(CameraMode.video);
    } else if (_mode == CameraMode.video &&
        dx >= _kSwitchModeDragThreshold) {
      await _switchMode(CameraMode.photo);
    }
    await snapBack(dx, 0);
    if (mounted) setState(() => _modePillDx = 0);
  }

  // ─── Tap to focus / exposure ─────────────────────────────

  Offset? _previewTapToNorm(Offset localPosition, Size previewSize) {
    if (previewSize.width <= 0 || previewSize.height <= 0) return null;
    double nx = localPosition.dx / previewSize.width;
    double ny = localPosition.dy / previewSize.height;
    nx = nx.clamp(0.0, 1.0);
    ny = ny.clamp(0.0, 1.0);
    final isFront = cameras.isNotEmpty &&
        cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
    if (isFront) {
      nx = 1.0 - nx; // 前置镜头 x 镜像
    }
    return Offset(nx, ny);
  }

  Future<void> _onPreviewTap(TapUpDetails details, Size previewSize) async {
    if (_isRecording) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final norm = _previewTapToNorm(details.localPosition, previewSize);
    if (norm == null) return;

    setState(() {
      _focusPoint = norm;
      _focusShownAt = DateTime.now();
    });

    try {
      if (c.value.focusPointSupported) {
        await c.setFocusPoint(norm);
      }
    } catch (_) {/* 静默 */}
    try {
      if (c.value.exposurePointSupported) {
        await c.setExposurePoint(norm);
      }
    } catch (_) {/* 静默 */}

    // 2 秒后自动隐藏对焦框
    Future.delayed(_focusOverlayDuration, () {
      if (!mounted) return;
      final shown = _focusShownAt;
      if (shown == null) return;
      if (DateTime.now().difference(shown) >= _focusOverlayDuration - const Duration(milliseconds: 100)) {
        setState(() => _focusPoint = null);
      }
    });
  }

  void _hideFocus() {
    if (_focusPoint != null) {
      setState(() => _focusPoint = null);
    }
  }

  // ─── Exposure compensation ──────────────────────────────

  Future<void> _setExposure(double value) async {
    final c = _controller;
    if (c == null) return;
    final clamped = value.clamp(_minExposure, _maxExposure);
    try {
      await c.setExposureOffset(clamped);
      setState(() => _currentExposure = clamped);
    } catch (_) {/* 静默 */}
  }

  // ─── Countdown ─────────────────────────────────────────

  Future<void> _runCountdown() async {
    if (_countdownSeconds <= 0) return;
    _cancelCountdown();
    for (int i = _countdownSeconds; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownTimer = Timer(const Duration(seconds: 1), () {});
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    setState(() => _countdownValue = 0);
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdownValue != 0 && mounted) {
      setState(() => _countdownValue = 0);
    }
  }

  // ─── Helpers ──────────────────────────────────────────

  void _showSnack(String message) {
    if (!mounted) return;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: appColors.destructive,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onClosePressed() async {
    if (_isRecording) {
      await _stopRecording();
      if (!mounted) return;
      // _stopRecording 已经 pop 了
      return;
    }
    // 关闭页面：清理 _captures 中未返回的临时文件
    for (final c in _captures) {
      await _safeDelete(c.path);
      if (c.thumbnail != null) await _safeDelete(c.thumbnail!.path);
    }
    _captures.clear();
    if (mounted) Navigator.of(context).pop();
  }

  void _onCompletePressed() {
    // 照片模式下批量返回
    final list = List<CameraCaptureResult>.from(_captures);
    Navigator.of(context).pop(list);
  }

  void _onDeleteCapture(CameraCaptureResult r) {
    setState(() => _captures.remove(r));
    _safeDelete(r.path);
    if (r.thumbnail != null) _safeDelete(r.thumbnail!.path);
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

    final preview = _controller!.value.previewSize;
    if (preview == null) {
      return Container(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidget = SizedBox(
          width: preview.height,
          height: preview.width,
          child: _isSwitchingCamera
              ? Container(color: Colors.black)
              : CameraPreview(_controller!),
        );
        // 纵向滑动切换拍照/视频模式的可用性判定：
        // 录制中、倒计时进行中、模式重建中、初始化失败时全部禁用
        final verticalDragEnabled = !_isRecording &&
            _countdownValue == 0 &&
            !_isSwitchingMode &&
            !_hasError;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onPreviewTap(d, constraints.biggest),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onVerticalDragUpdate: verticalDragEnabled ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: verticalDragEnabled ? _onVerticalDragEnd : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(fit: BoxFit.cover, child: previewWidget),
              // 九宫格 overlay
              if (_showGrid) const _GridOverlay(),
              // 对焦框 overlay
              if (_focusPoint != null) _buildFocusRing(),
              // 倒计时 overlay
              if (_countdownValue > 0) _buildCountdownOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFocusRing() {
    final fp = _focusPoint;
    if (fp == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final left = fp.dx * c.maxWidth - 32;
        final top = fp.dy * c.maxHeight - 32;
        return Positioned(
          left: left,
          top: top,
          width: 64,
          height: 64,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellowAccent, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownOverlay() {
    return IgnorePointer(
      child: Center(
        child: Text(
          '$_countdownValue',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
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
                onTap: _onClosePressed,
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
              // 中：模式 pill（录制中隐藏；预览区纵向滑动时跟随水平平移）
              Expanded(
                child: Center(
                  child: _isRecording
                      ? const SizedBox.shrink()
                      : Transform.translate(
                          offset: Offset(_modePillDx, 0),
                          child: _buildModePill(l10n),
                        ),
                ),
              ),
              // 右：闪光灯 / 录制指示器
              if (_isRecording)
                _buildRecordingIndicator()
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
    // 顶部显示上限与 _maxVideoDurationSec 保持一致（5:00）
    final maxMm = (_maxVideoDurationSec ~/ 60).toString().padLeft(1, '0');
    final maxSs = (_maxVideoDurationSec % 60).toString().padLeft(2, '0');

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
            '$mm:$ss / $maxMm:$maxSs',
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
    final backLenses = CameraLensHelper.backLenses(cameras);
    final showLensRow = backLenses.length > 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 24, top: 20),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上排：拍照模式显示「缩略图条 + 完成」；视频模式显示「倒计时切换」
              if (_mode == CameraMode.photo)
                _buildCaptureStrip()
              else
                _buildCountdownToggle(),
              const SizedBox(height: 12),
              // 中排：镜头切换 + 画质
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showLensRow)
                    ..._buildLensPills(backLenses)
                  else
                    _buildQualityToggle(),
                  if (showLensRow) ...[
                    const SizedBox(width: 12),
                    _buildQualityToggle(),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              // 下排：快门 + EV 滑杆 + 翻转 + 九宫格
              SizedBox(
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildShutter(),
                    if (_minExposure < _maxExposure)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: _buildExposureSlider(),
                      ),
                    Positioned(
                      right: 0,
                      top: 18,
                      child: _buildFlipButton(),
                    ),
                    // 九宫格：紧贴翻转按钮左侧；录制中隐藏
                    if (!_isRecording)
                      Positioned(
                        right: 68,
                        top: 18,
                        child: _buildGridToggleButton(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureStrip() {
    if (_captures.isEmpty) return const SizedBox(height: 56);
    final l10n = AppLocalizations.of(context)!;
    final remaining = widget.remainingCapacity - _captures.length;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          // 完成按钮
          GestureDetector(
            onTap: _onCompletePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${l10n.cameraDone} (${_captures.length}/${widget.remainingCapacity})',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _captures.length,
              itemBuilder: (ctx, i) {
                final c = _captures[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(c.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(width: 56, height: 56, color: Colors.white12),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => _onDeleteCapture(c),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (remaining > 0)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownToggle() {
    return SizedBox(
      height: 56,
      child: Center(
        child: GestureDetector(
          onTap: _cycleCountdown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _countdownSeconds > 0
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.timer_15,
                  size: 18,
                  color: _countdownSeconds > 0 ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  _countdownSeconds > 0
                      ? '${_countdownSeconds}s'
                      : AppLocalizations.of(context)!.cameraCountdownOff,
                  style: TextStyle(
                    color: _countdownSeconds > 0 ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLensPills(List<CameraLensInfo> lenses) {
    final widgets = <Widget>[];
    for (int i = 0; i < lenses.length; i++) {
      final lens = lenses[i];
      final active = lens.cameraIndex == _cameraIndex;
      widgets.add(_buildPillButton(
        label: lens.label,
        active: active,
        disabled: _isSwitchingCamera || _isRecording,
        onTap: () => _selectLens(lens),
      ));
      if (i != lenses.length - 1) widgets.add(const SizedBox(width: 8));
    }
    return widgets;
  }

  Widget _buildQualityToggle() {
    return GestureDetector(
      onTap: (_isSwitchingCamera || _isRecording) ? null : _toggleQuality,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _quality.shortLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required bool active,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.25)
              : (disabled ? Colors.white12 : Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildExposureSlider() {
    if (_minExposure >= _maxExposure) return const SizedBox.shrink();
    // 0 EV 在滑杆量程内的相对位置（0..1），超出范围时不绘制锚线
    final zeroFraction = ((0 - _minExposure) / (_maxExposure - _minExposure))
        .clamp(0.0, 1.0);
    return SizedBox(
      width: 36,
      child: RotatedBox(
        quarterTurns: 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // LayoutBuilder 位于 RotatedBox 内，看到的是旋转前的坐标系：
            // - constraints.maxWidth 是 Slider 横向的视觉可用宽度（旋转后变成纵向高度）
            // - 在未旋转坐标系下绘制一道"竖线"位于 zeroFraction 处，
            //   旋转后会呈现在纵向滑杆上的"水平横线"，代表 0 EV 位置
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Slider(
                    value: _currentExposure.clamp(_minExposure, _maxExposure),
                    min: _minExposure,
                    max: _maxExposure,
                    // 强制 7 档；不再跟随底层 getExposureOffsetStepSize
                    divisions: 7,
                    onChanged:
                        _isRecording || _controller == null ? null : _setExposure,
                  ),
                ),
                if (zeroFraction > 0 && zeroFraction < 1)
                  Positioned(
                    left: constraints.maxWidth * zeroFraction - 1,
                    top: 4,
                    bottom: 4,
                    child: IgnorePointer(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 九宫格开关按钮（60×60 圆形 + Iconsax.grid_15；激活态变浅底）
  /// 与翻转按钮同高同尺寸，紧贴其左侧；由调用方在录制中隐藏。
  Widget _buildGridToggleButton() {
    return GestureDetector(
      onTap: _toggleGrid,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _showGrid
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(Iconsax.grid_15, color: Colors.white, size: 28),
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

/// 九宫格辅助线 overlay（纯 UI，IgnorePointer）
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final w = size.width;
    final h = size.height;
    // 两条竖线
    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), paint);
    canvas.drawLine(Offset(w * 2 / 3, 0), Offset(w * 2 / 3, h), paint);
    // 两条横线
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), paint);
    canvas.drawLine(Offset(0, h * 2 / 3), Offset(w, h * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
