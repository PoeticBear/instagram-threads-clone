import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/model/camera_capture_result.dart';

/// 拍照后确认页：原图预览 + 5 个拍后静态滤镜。
/// - 用户点击"使用" → 通过 Navigator.pop 返回 CameraCaptureResult（path = 当前显示文件）
/// - 用户点击"重拍" → 删除所有临时文件，Navigator.pop 返回 null
/// - 滤镜失败 / 超时 → 显示错误，允许继续使用原图或重拍
class ComposeCameraConfirmPage extends StatefulWidget {
  final String path;

  const ComposeCameraConfirmPage({super.key, required this.path});

  @override
  State<ComposeCameraConfirmPage> createState() =>
      _ComposeCameraConfirmPageState();
}

class _ComposeCameraConfirmPageState extends State<ComposeCameraConfirmPage> {
  late String _currentPath;
  String? _originalPath;
  _Filter _filter = _Filter.original;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _originalPath = widget.path;
  }

  @override
  void dispose() {
    // 临时滤镜文件在重拍时已主动删除；其他文件由调用方 ComposeCameraPage 决定清理。
    super.dispose();
  }

  Future<void> _applyFilter(_Filter filter) async {
    if (_originalPath == null) return;
    if (_filter == filter && _currentPath == _originalPath) return;

    setState(() {
      _filter = filter;
      _processing = true;
      _error = null;
    });

    try {
      String outPath;
      if (filter == _Filter.original) {
        outPath = _originalPath!;
      } else {
        final produced = await _processWithTimeout(filter, _originalPath!);
        if (produced == null) {
          if (mounted) {
            setState(() {
              _processing = false;
              _error = '滤镜处理失败';
            });
          }
          return;
        }
        outPath = produced;
      }
      if (!mounted) return;
      setState(() {
        _currentPath = outPath;
        _processing = false;
      });
    } catch (e) {
      debugPrint('applyFilter failed: $e');
      if (mounted) {
        setState(() {
          _processing = false;
          _error = '滤镜处理失败';
        });
      }
    }
  }

  Future<String?> _processWithTimeout(_Filter filter, String src) async {
    try {
      final result = await Future.any<String?>([
        _doProcess(filter, src),
        Future.delayed(const Duration(seconds: 2), () => null),
      ]);
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _doProcess(_Filter filter, String src) async {
    final bytes = await File(src).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final processed = _applyToImage(filter, decoded);
    final outBytes = img.encodeJpg(processed, quality: 85);
    final out = await _writeTempFile(outBytes);
    return out.path;
  }

  img.Image _applyToImage(_Filter filter, img.Image src) {
    switch (filter) {
      case _Filter.original:
        return src;
      case _Filter.grayscale:
        return img.grayscale(img.Image.from(src));
      case _Filter.warm:
        return img.colorOffset(img.Image.from(src), red: 18, green: 8, blue: -10);
      case _Filter.cool:
        return img.colorOffset(img.Image.from(src), red: -10, green: 0, blue: 18);
      case _Filter.highContrast:
        return img.adjustColor(img.Image.from(src), contrast: 1.35, saturation: 1.1);
    }
  }

  Future<File> _writeTempFile(List<int> bytes) async {
    final dir = Directory.systemTemp;
    final ts = DateTime.now().microsecondsSinceEpoch;
    final f = File('${dir.path}/compose_cam_filter_$ts.jpg');
    return f.writeAsBytes(bytes, flush: true);
  }

  void _onUse() {
    if (_processing) return;
    final result = CameraCaptureResult.photo(_currentPath);
    Navigator.of(context).pop(result);
  }

  void _onRetake() {
    // 删除所有临时文件（包括原图与滤镜产物），通知调用方重拍
    _safeDelete(widget.path);
    // 删除 _currentPath 如果不等于 _originalPath（即有过滤镜）
    if (_currentPath != widget.path) {
      _safeDelete(_currentPath);
    }
    Navigator.of(context).pop(null);
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：标题 + 关闭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _onRetake,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.cameraConfirmTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // 中：原图 / 滤镜后图
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(
                    File(_currentPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white24, size: 64),
                    ),
                  ),
                  if (_processing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  if (_error != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 下：滤镜条
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _Filter.values.map((f) {
                  final selected = f == _filter;
                  return GestureDetector(
                    onTap: _processing ? null : () => _applyFilter(f),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _labelFor(f, l10n),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // 底部：重拍 / 使用
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _processing ? null : _onRetake,
                      child: Text(
                        l10n.cameraRetake,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.repost,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _processing ? null : _onUse,
                      child: Text(
                        l10n.cameraUse,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(_Filter f, AppLocalizations l10n) {
    switch (f) {
      case _Filter.original:
        return l10n.cameraFilterOriginal;
      case _Filter.grayscale:
        return l10n.cameraFilterGrayscale;
      case _Filter.warm:
        return l10n.cameraFilterWarm;
      case _Filter.cool:
        return l10n.cameraFilterCool;
      case _Filter.highContrast:
        return l10n.cameraFilterHighContrast;
    }
  }
}

enum _Filter { original, grayscale, warm, cool, highContrast }
