import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/bug_report_service.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 截屏后弹出的 Bug 反馈表单（内部测试专用，仅 Debug 构建）。
///
/// 流程：打开时异步取相册最新一张作为截图预览（截屏写相册有 ~0.5s 延迟，
/// 但用户打开表单 + 填写描述的这段时间已远超该延迟，故能稳定取到）；
/// 用户填写描述后点提交，调 [BugReportService] 上报
/// （当前为 stub：写本地沙盒 + log）。
class BugFeedbackSheet extends StatefulWidget {
  const BugFeedbackSheet({Key? key, this.triggerTime}) : super(key: key);

  /// 本次截屏的触发时刻，用于在相册中精确判定哪张图是「本次」截屏
  /// （截屏通知早于写盘）。由 [ScreenshotDetectorService.lastTriggeredAt] 传入。
  final DateTime? triggerTime;

  /// 以 bottom sheet 形式弹出。调用方负责通过
  /// [ScreenshotDetectorService.markSheetShowing] 标记展示状态以抑制重复弹窗。
  static Future<void> show(BuildContext context, {DateTime? triggerTime}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => BugFeedbackSheet(triggerTime: triggerTime),
    );
  }

  @override
  State<BugFeedbackSheet> createState() => _BugFeedbackSheetState();
}

class _BugFeedbackSheetState extends State<BugFeedbackSheet> {
  final _controller = TextEditingController();
  bool _loadingShot = true;
  bool _shotFailed = false;
  String? _screenshotPath;
  bool _submitting = false;
  String? _toast;

  @override
  void initState() {
    super.initState();
    _loadLatestScreenshot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 取「本次截屏」的那张图作为附件。
  ///
  /// 关键点：iOS 的截屏通知在截屏动作发生时就发出，但截图写入相册是异步
  /// 的、晚于通知。表单一打开立即取相册最新一张，往往拿到的是「截屏之前
  /// 的旧图」。故用 [widget.triggerTime] 作为判定下限轮询相册，直到最新
  /// 一张的创建时间 ≥ 触发时刻（容差 3s）才认定为本次截屏。
  Future<void> _loadLatestScreenshot() async {
    String? path;
    var failed = false;
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        failed = true;
      } else {
        path = await _waitForFreshScreenshot();
        if (path == null) failed = true;
      }
    } catch (_) {
      failed = true;
    }

    if (!mounted) return;
    setState(() {
      _screenshotPath = path;
      _shotFailed = failed;
      _loadingShot = false;
    });
  }

  /// 轮询相册最新一张，直到其创建时间落在本次截屏窗口内。
  /// 超时（4s）则兜底返回见过的最新一张（可能非本次，但好过空）。
  Future<String?> _waitForFreshScreenshot() async {
    final threshold =
        widget.triggerTime?.subtract(const Duration(seconds: 3));
    final start = DateTime.now();
    const maxWait = Duration(seconds: 4);
    const pollInterval = Duration(milliseconds: 300);
    const fallbackWindow = Duration(seconds: 15);

    String? latestPath;
    while (true) {
      final asset = await _getLatestImageAsset();
      if (asset != null) {
        final file = await asset.file;
        if (file != null) {
          latestPath = file.path;
          final fresh = threshold == null
              ? DateTime.now().difference(asset.createDateTime).abs() <
                  fallbackWindow
              : !asset.createDateTime.isBefore(threshold);
          if (fresh) return latestPath;
        }
      }
      if (DateTime.now().difference(start) >= maxWait) return latestPath;
      await Future.delayed(pollInterval);
    }
  }

  Future<AssetEntity?> _getLatestImageAsset() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return null;
    final assets = await albums.first.getAssetListPaged(page: 0, size: 1);
    return assets.isEmpty ? null : assets.first;
  }

  Future<void> _submit() async {
    final desc = _controller.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (desc.isEmpty) {
      _showToast(l10n.bugReportDescriptionRequired);
      return;
    }

    setState(() => _submitting = true);
    final userId = context.read<AuthState>().userModel?.userId;
    final ok = await BugReportService.instance.submit(
      description: desc,
      screenshotPath: _screenshotPath,
      userId: userId?.toString(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    _showToast(ok ? l10n.bugReportSubmitted : l10n.bugReportSubmitFailed);
    if (ok) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: bottomInset + 20,
          ),
          decoration: BoxDecoration(
            color: appColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHandle(appColors),
                _buildTitleRow(appColors, l10n),
                const SizedBox(height: 16),
                _buildScreenshotPreview(appColors, l10n),
                const SizedBox(height: 16),
                _buildDescriptionField(appColors, l10n),
                const SizedBox(height: 16),
                _buildSubmitButton(appColors, l10n),
              ],
            ),
          ),
        ),
        if (_toast != null)
          Positioned(
            top: 14,
            left: 24,
            right: 24,
            child: _buildToast(_toast!),
          ),
      ],
    );
  }

  Widget _buildHandle(AppColors appColors) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: appColors.dividerSecondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildTitleRow(AppColors appColors, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.bugReportTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: appColors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(CupertinoIcons.xmark,
                size: 20, color: appColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotPreview(AppColors appColors, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.bugReportScreenshot,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: appColors.textSecondary,
            ),
          ),
        ),
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loadingShot
              ? _loadingChild(appColors, l10n)
              : _screenshotPath != null
                  ? Image.file(
                      File(_screenshotPath!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _placeholder(appColors),
                    )
                  : _placeholder(appColors),
        ),
        if (_shotFailed && !_loadingShot)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.bugReportScreenshotFailed,
              style: TextStyle(fontSize: 11, color: appColors.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _loadingChild(AppColors appColors, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 8),
          Text(
            l10n.bugReportScreenshotLoading,
            style: TextStyle(fontSize: 12, color: appColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(AppColors appColors) => Center(
        child: Icon(CupertinoIcons.photo, size: 34, color: appColors.textMuted),
      );

  Widget _buildDescriptionField(AppColors appColors, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controller,
        maxLines: 4,
        minLines: 3,
        textInputAction: TextInputAction.newline,
        style: TextStyle(fontSize: 15, color: appColors.textPrimary),
        decoration: InputDecoration.collapsed(
          hintText: l10n.bugReportDescriptionHint,
          hintStyle: TextStyle(fontSize: 15, color: appColors.textHint),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppColors appColors, AppLocalizations l10n) {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: appColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : Text(
                  l10n.bugReportSubmit,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToast(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
