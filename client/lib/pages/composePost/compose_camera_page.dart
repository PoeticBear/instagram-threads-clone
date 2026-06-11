import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import '../../main.dart';

class ComposeCameraPage extends StatefulWidget {
  const ComposeCameraPage({super.key});

  @override
  State<ComposeCameraPage> createState() => _ComposeCameraPageState();
}

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  /// camera 包在 iOS 上会自动触发系统原生授权弹窗，无需手动调用 permission_handler。
  Future<void> _startCamera() async {
    if (cameras.isEmpty || _cameraIndex >= cameras.length) return;

    _controller = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
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

  // ─── Actions ────────────────────────────────────────────

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    HapticFeedback.mediumImpact();

    try {
      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(xFile.path);
      }
    } catch (e) {
      debugPrint('Take picture failed: $e');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

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
          if (!_hasError) ...[
            _buildTopControls(appColors),
            _buildBottomControls(appColors),
          ],
          if (_hasError) _buildError(appColors),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
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

  Widget _buildTopControls(AppColors appColors) {
    final isBackCamera =
        cameras.isNotEmpty && cameras[_cameraIndex].lensDirection == CameraLensDirection.back;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
            GestureDetector(
              onTap: isBackCamera ? _toggleFlash : null,
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
                  color: isBackCamera ? Colors.white : Colors.white24,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(AppColors appColors) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: 60),
              GestureDetector(
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
                      ? Center(
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
              ),
              GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.refresh, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
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
              Icon(Iconsax.camera, size: 64, color: Colors.white24),
              SizedBox(height: 24),
              Text(
                l10n.cameraAccessRequired,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                l10n.cameraAccessHint,
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
