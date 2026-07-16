import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/model/media_draft_item.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/pages/composePost/post.dart';
import 'package:threads/pages/textNote/text_card_preview.dart';

/// 「写文字」页面交接给 `ComposePost` 的中间数据。
///
/// `change-text-note-handoff` 把流程从「TextNotePage 内闭环发 post」
/// 改为「确认 → `pushReplacement` 到 `ComposePost(initialContent, initialMediaDrafts)`」。
///
/// - [text]:用户在 TextNotePage 输入的正文(可空字符串,允许纯渐变卡)
/// - [imageDraft]:卡片渲染截图对应的 `MediaDraftItem`,`localFile` 指向临时 PNG
///
/// 该 typedef 仅用于代码可读性 / 调试追踪 —— `pushReplacement` 不传值给目标,
/// ComposePost 接管后续发布 / 保存草稿 / 取消逻辑。
typedef TextNoteHandoff = ({String text, MediaDraftItem imageDraft});

// ─────────────────────────────────────────────────────────────────────────────
// 写文字 — 主页面
// ─────────────────────────────────────────────────────────────────────────────
//
// 「写文字」采用「输入即所见」交互：渐变卡片本身就是一个 TextField，
// 用户键入的文字直接渲染在卡片上。
//
// 流程（change-text-note-handoff）：右上「确认」触发截图，写入临时 PNG，
// 构造 MediaDraftItem，然后用 `Navigator.pushReplacement` 跳到 `ComposePost`
// 把 `initialContent`（正文）+ `initialMediaDrafts`（卡片 PNG）一起接管。
// 真正的发帖在 `ComposePost` 中完成 — 用户可在普通图文页加更多图 / 文 / 投票等。
//
// 截图范围：整个渐变卡片（RepaintBoundary 内含 TextField）；
// 确认前会 unfocus 收起键盘，确保截图不含键盘 / 光标。
//
// 设计文档：openspec/changes/change-text-note-handoff/{design,proposal}.md
// ─────────────────────────────────────────────────────────────────────────────

class TextNotePage extends StatefulWidget {
  const TextNotePage({Key? key}) : super(key: key);

  @override
  State<TextNotePage> createState() => _TextNotePageState();
}

class _TextNotePageState extends State<TextNotePage> {
  // ─── 状态 ───
  final TextEditingController _textController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();
  final FocusNode _textFocusNode = FocusNode();
  TextCardStyle _selectedStyle = kDefaultCardStyle;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // 页面打开自动聚焦 TextField，让用户进来就能输入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  // ─── 派生 ───

  bool get _hasContent => _textController.text.trim().isNotEmpty;
  // 放行空文字（纯渐变卡也算合法）。
  bool get _canConfirm => !_isConfirming;
  String get _bodyText => _textController.text.trim();

  // ─── AppBar 关闭逻辑 ───

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasContent) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.textCardDiscardTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.textCardDiscardMessage,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.textCardDiscardConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    final ok = await _confirmDiscardIfNeeded();
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  // ─── 确认（交接给 ComposePost）───

  Future<void> _confirm() async {
    if (_isConfirming) return; // 防双击

    final l10n = AppLocalizations.of(context)!;

    // 关键：确认前先收起键盘，避免截到键盘 / 光标
    FocusScope.of(context).unfocus();
    setState(() => _isConfirming = true);
    HapticFeedback.heavyImpact();

    try {
      // 1) 截图卡片
      final bytes = await _captureCardSafely();
      if (bytes == null) throw _ConfirmException();
      if (!mounted) return;

      // 2) 写临时文件 + 包装为 MediaDraftItem
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'text_note_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;

      final draft = MediaDraftItem.fromLocalImage(
        file,
        fileSizeBytes: bytes.lengthInBytes,
      );

      // 3) pushReplacement 替换为 ComposePost，把 (text, imageDraft) 透传过去
      //    正文 → initialContent，卡片 PNG → initialMediaDrafts 的首个 image。
      //    闭包内只引用提前捕获的局部变量，不捕获 TextNotePage 的 context。
      final TextNoteHandoff handoff = (
        text: _bodyText,
        imageDraft: draft,
      );
      // pushReplacement 把 TextNotePage 替换为 ComposePost。当前路由栈是
      // [HomePage, ComposePost],ComposePost 自身不持有"返回首页"的能力 —
      // 其 `_submit` 成功 / 取消都只会调 `widget.onPostSuccess?.call()` /
      // `widget.onCancel?.call()`,没有 onPostSuccess 时就什么都不做。
      // 在 builder 闭包内捕获 `routeContext`,给两个回调都显式走 pop,让
      // ComposePost 在任一路径都回到 HomePage。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (routeContext) => ComposePost(
            initialContent: handoff.text,
            initialMediaDrafts: [handoff.imageDraft],
            onPostSuccess: () => Navigator.of(routeContext).pop(),
            onCancel: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
    } on _ConfirmException {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      _showSnack(l10n.textCardConfirmFailed, destructive: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      _showSnack(l10n.textCardConfirmFailed, destructive: true);
    }
  }

  /// 在下一帧渲染完成后截图卡片。返回 PNG bytes，失败返回 null。
  Future<Uint8List?> _captureCardSafely() async {
    final completer = Completer<Uint8List?>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final bytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 80),
        );
        completer.complete(bytes);
      } catch (_) {
        completer.complete(null);
      }
    });
    return completer.future;
  }

  void _showSnack(String message, {bool destructive = false}) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: destructive ? appColors.destructive : appColors.repost,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    // 卡片宽度 = 屏幕宽度 - 左右 padding(各 32)
    final cardWidth = mediaQuery.size.width - 64;
    final cardHeight = cardWidth * 4 / 3;
    final charCount = _textController.text.trim().length;
    final fontSize = fontSizeFor(charCount);
    final lineHeight = lineHeightFor(charCount);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: appColors.background,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(appColors, l10n),
        body: SafeArea(
          child: Column(
            children: [
              // ── 中部：可编辑渐变卡片（输入即所见） ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
                  child: Center(
                    child: _buildCardEditor(
                      cardWidth: cardWidth,
                      cardHeight: cardHeight,
                      fontSize: fontSize,
                      lineHeight: lineHeight,
                      l10n: l10n,
                    ),
                  ),
                ),
              ),

              // 字数统计（卡片下方右对齐）
              Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 4),
                child: Text(
                  '$charCount / $kInputMaxChars',
                  style: TextStyle(
                    color: charCount >= kInputMaxChars
                        ? appColors.destructive
                        : (charCount > kInputMaxChars / 2
                            ? Colors.orange
                            : appColors.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ),

              // ── 样式选择器 ──
              TextCardStylePicker(
                selected: _selectedStyle,
                onSelected: (style) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedStyle = style);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 可编辑卡片：渐变背景 + 内嵌 TextField。
  /// 输入的文字直接渲染在卡片上，所见即所交接给 ComposePost。
  /// Screenshot 包裹整个卡片，确认时 capture() 拿到的就是要交接给 ComposePost 的图。
  Widget _buildCardEditor({
    required double cardWidth,
    required double cardHeight,
    required double fontSize,
    required double lineHeight,
    required AppLocalizations l10n,
  }) {
    final gradient = kCardGradients[_selectedStyle]!;
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            maxLines: null,
            expands: false,
            maxLength: kInputMaxChars,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            cursorColor: Colors.white,
            cursorWidth: 2,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              hintText: l10n.textCardHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors appColors, AppLocalizations l10n) {
    return AppBar(
      backgroundColor: appColors.background,
      elevation: 0,
      toolbarHeight: 56,
      leading: GestureDetector(
        onTap: _handleBack,
        behavior: HitTestBehavior.opaque,
        // 用 Container 包裹固定水平 padding + alignment: center，避开 Padding>Center
        // 嵌套把可用宽度压成 24px 触发 Text 换行的坑。
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            l10n.cancel,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(color: appColors.textPrimary, fontSize: 16),
          ),
        ),
      ),
      title: Text(
        l10n.writeText,
        style: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        // 确认 → 接管给 ComposePost
        GestureDetector(
          onTap: _canConfirm ? _confirm : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: _isConfirming
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appColors.accent,
                      ),
                    )
                  : Text(
                      l10n.textCardConfirm,
                      style: TextStyle(
                        color: _canConfirm ? appColors.accent : appColors.divider,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmException implements Exception {
  _ConfirmException();
  @override
  String toString() => '_ConfirmException';
}