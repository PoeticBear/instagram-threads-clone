import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/model/media_draft_item.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/draft.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/model/draft.module.dart';
import 'package:threads/model/camera_capture_result.dart';
import 'package:threads/utils/video_processor.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/draft_list_sheet.dart';
import 'package:threads/pages/composePost/compose_camera_page.dart';
import 'package:threads/pages/composePost/location_picker_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/widget/mention_overlay.dart';

class ComposePost extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  final VoidCallback? onCancel;

  /// 编辑模式：传非空 postId 即进入编辑模式
  final String? editingPostId;

  /// 编辑模式：预填的帖子内容
  final String? initialContent;

  /// 编辑模式：原帖是否标记为敏感
  final bool? initialIsSensitive;

  /// 编辑模式：原帖的敏感内容警告
  final String? initialContentWarning;

  /// 「写文字」页面交接（`change-text-note-handoff`）：预填媒体草稿。
  /// 仅在 `editingPostId == null` 时生效；编辑模式继续走原帖 media 恢复链路。
  final List<MediaDraftItem>? initialMediaDrafts;
  const ComposePost({
    Key? key,
    this.onPostSuccess,
    this.onCancel,
    this.editingPostId,
    this.initialContent,
    this.initialIsSensitive,
    this.initialContentWarning,
    this.initialMediaDrafts,
  }) : super(key: key);

  @override
  State<ComposePost> createState() => ComposePostState();
}

class ComposePostState extends State<ComposePost> {
  late TextEditingController _textEditingController;

  /// 多类型媒体草稿（image / video / gif）。
  /// - 新选的本地资源：`localFile` 非空，`remoteUrl` 为空
  /// - 草稿恢复的远端资源：`localFile` 为空，`remoteUrl` 非空
  /// - 上传成功后会原地替换为 remoteUrl（可继续编辑 / 删除）
  List<MediaDraftItem> _mediaDrafts = [];

  bool _showPollEditor = false;
  List<TextEditingController> _pollControllers = [];
  int _replyType = 1;
  bool _isSubmitting = false;

  /// 保存草稿中（含媒体上传）：用于草稿按钮显示加载动画
  bool _isSavingDraft = false;
  String? _location;
  // 地图选址时与 _location 一起带回的经纬度
  double? _latitude;
  double? _longitude;
  DateTime? _scheduledTime;
  // 编辑模式：敏感内容
  bool _isSensitive = false;
  late TextEditingController _contentWarningController;

  static const int _maxMediaCount = 10;
  static const int _maxPollOptions = 4;
  static const int _minPollOptions = 2;
  static const int _maxContentLength = 500;

  // 视频 / 媒体相关限制 — 视频上限统一为 300 秒（5 分钟）；服务端不强制时长上限。
  static const int _maxVideoDurationMs = 300 * 1000; // ≤ 300 秒（5 分钟）
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int _maxGifSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10MB

  // ─── @mention 用户选择面板 ───
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<UserInfo> _filteredUsers = const [];
  // 当前 @token（含 @）在文本中的起始 offset，-1 表示无激活 token
  int _mentionTokenStart = -1;
  // 防抖 Timer：用户连续输入时只发最后一次请求
  Timer? _mentionDebounce;
  // 已选中的 mention 用户：username → userId（需求 1：身份绑定）。
  // 选中补全面板里的用户时写入；正文编辑时按 username 是否仍出现在文本里
  // 自动同步过滤。提交帖子时把 values 写入 PostModel.mentionedUserIds。
  // 注：键是 username 字符串而非区间，故同一 username 多次出现只保留一个 userId，
  // 这与"@同一个用户多次提及只通知一次"的服务端语义一致。
  final Map<String, int> _mentionUserIds = {};

  bool get _isEditing => widget.editingPostId != null;

  @override
  void initState() {
    super.initState();
    _textEditingController =
        TextEditingController(text: widget.initialContent ?? '');
    _contentWarningController =
        TextEditingController(text: widget.initialContentWarning ?? '');
    _isSensitive = widget.initialIsSensitive ?? false;
    _initPollControllers();
    // 「写文字」页面交接：非编辑模式下预填媒体草稿（卡片 PNG）。
    // 编辑模式由 `_onDraftSelected` 自行恢复原帖 media,守卫隔离避免互盖。
    if (widget.editingPostId == null &&
        widget.initialMediaDrafts != null &&
        widget.initialMediaDrafts!.isNotEmpty) {
      _mediaDrafts = [...widget.initialMediaDrafts!];
    }
    _textEditingController.addListener(_onTextChanged);
  }

  void _initPollControllers() {
    _pollControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_onTextChanged);
    _mentionDebounce?.cancel();
    _hideOverlay();
    _textEditingController.dispose();
    _contentWarningController.dispose();
    for (final c in _pollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── @mention 用户选择面板 ────────────────────────────────

  /// 文本变化监听：刷新字数统计 + 检测 @mention。
  void _onTextChanged() {
    setState(() {});
    // 同步 mention userId 集合：正文里不再出现的 username 自动移除，
    // 保证最终提交的 mentionedUserIds 与当前正文一致（需求 1）。
    _syncMentionUserIds();
    final token = _detectMentionToken();
    if (token == null) {
      _mentionTokenStart = -1;
      _hideOverlay();
      return;
    }
    _mentionTokenStart = token.start;
    _filterAndShow(token.query);
  }

  /// 同步 [_mentionUserIds]：检查已记录的每个 username 是否仍以
  /// `@username` 形式出现在正文中，把不再出现的移除（用户删除/改名/覆盖时同步）。
  ///
  /// **不使用固定字符集的正则**——历史上用 `@[A-Za-z0-9_]+` 会把 `dev-12`
  /// 这种含 `-` 的用户名截断成 `dev`，从而误判 `dev-12` 已被删除（线上 Bug）。
  /// 改为对每个已知 username 做精确字符串匹配 + 左右边界检查，可匹配任何
  /// 服务端允许的用户名字符集（`.` / `-` / `_` 等）。
  ///
  /// 同 username 多次出现的场景：只要 username 仍在文本里，对应 userId 就保留。
  void _syncMentionUserIds() {
    if (_mentionUserIds.isEmpty) return;
    final text = _textEditingController.text;
    final toRemove = <String>[];
    _mentionUserIds.forEach((username, _) {
      final atUsername = '@$username';
      final idx = text.indexOf(atUsername);
      if (idx < 0) {
        toRemove.add(username);
        return;
      }
      // 排除邮箱：@ 前若是 word 字符则不算 mention（与 _detectMentionToken 一致）。
      if (idx > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[idx - 1])) {
        toRemove.add(username);
        return;
      }
      // 右边界：@username 后若仍是用户名字符，则它只是更长 username 的前缀
      // （例如 username=dev 而 text=@dev-12，dev 不应被保留）。
      final after = idx + atUsername.length;
      if (after < text.length &&
          RegExp(r'[A-Za-z0-9_.\-]').hasMatch(text[after])) {
        toRemove.add(username);
      }
    });
    for (final u in toRemove) {
      _mentionUserIds.remove(u);
    }
  }

  /// 从光标位置向前查找最近的合法 @token。
  ///
  /// 支持：
  /// - 光标在文本中间（如 `@alice 你好 @bo|b`）
  /// - 多个 @ 共存（取光标前最近的那个）
  /// - 排除邮箱（`@` 前是 word 字符则不算 mention）
  ///
  /// 返回 `(start, query)`：start 是含 @ 的起始 offset，query 是不含 @ 的查询串。
  /// 只输了一个 @（query 为空）时返回 null —— 不弹面板。
  ({int start, String query})? _detectMentionToken() {
    final text = _textEditingController.text;
    final selection = _textEditingController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return null;

    // 1. 从光标向前找最近的 '@'
    int i = cursor - 1;
    while (i >= 0) {
      final ch = text[i];
      if (ch == '@') break;
      // token 内部只允许字母 / 数字 / 下划线；遇到空格或标点 → 非 token
      if (!RegExp(r'[A-Za-z0-9_]').hasMatch(ch)) return null;
      i--;
    }
    if (i < 0) return null; // 没找到 @

    // 2. @ 前必须是边界（排除 alice@bob 这种邮箱场景）
    if (i > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[i - 1])) return null;

    // 3. 提取 @ 和光标之间的字符作为 query
    final query = text.substring(i + 1, cursor);
    if (query.isEmpty) return null; // 只输了一个 @，不弹
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(query)) return null;
    return (start: i, query: query);
  }

  /// 调用服务端接口搜索用户并显示面板（带 250ms 防抖）。
  /// 用户连续输入时只发最后一次请求；接口失败 / 空结果 → 关闭面板。
  void _filterAndShow(String query) {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      try {
        final users = await SearchService(apiClient: getIt())
            .searchMentionUsers(query);
        if (!mounted) return;
        if (users.isEmpty) {
          _hideOverlay();
          return;
        }
        _filteredUsers = users;
        _showOverlay();
      } catch (_) {
        if (!mounted) return;
        _hideOverlay();
      }
    });
  }

  /// 创建并插入用户选择面板（通过 LayerLink 锚定到 TextField 下方）。
  void _showOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;

    final overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.of(ctx).size.width - 28,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: MentionOverlay(
            users: _filteredUsers,
            onSelected: _onUserSelected,
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
    _mentionOverlay = overlay;
  }

  /// 关闭用户选择面板。
  void _hideOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
    _filteredUsers = const [];
  }

  /// 选中某个用户后，把光标前的 @xxx 替换为 `@username `（含尾随空格），
  /// 光标移到空格之后，关闭面板。
  ///
  /// 同时把 username → userId 写入 [_mentionUserIds]（需求 1：身份绑定），
  /// 随帖子提交服务端，作为持久化的提及关系（防止改名即失效）。
  void _onUserSelected(UserInfo user) {
    if (_mentionTokenStart < 0) {
      _hideOverlay();
      return;
    }
    final text = _textEditingController.text;
    final cursor = _textEditingController.selection.baseOffset;
    final replacement = '@${user.username} ';
    final newText = text.replaceRange(_mentionTokenStart, cursor, replacement);
    _textEditingController.text = newText;
    final newCursor = _mentionTokenStart + replacement.length;
    _textEditingController.selection =
        TextSelection.collapsed(offset: newCursor);
    _mentionTokenStart = -1;
    // 记录被提及用户 userId（仅当 username 非空时；user.userId 兜底 0 视为无效）。
    if (user.username.isNotEmpty && user.userId > 0) {
      _mentionUserIds[user.username] = user.userId;
    }
    _hideOverlay();
    setState(() {});
  }

  // ─── Helpers ──────────────────────────────────────────────

  bool get _hasContent {
    final hasText = _textEditingController.text.trim().isNotEmpty;
    final hasMedia = _mediaDrafts.isNotEmpty;
    final hasPoll = _showPollEditor &&
        _pollControllers.any((c) => c.text.trim().isNotEmpty);
    return hasText || hasMedia || hasPoll;
  }

  bool get _canPost {
    if (_isSubmitting) return false;
    return _hasContent;
  }

  bool get _canAddMoreMedia => _mediaDrafts.length < _maxMediaCount;

  void _handleBack(BuildContext context) {
    // 编辑模式：直接退出，不触发草稿保存
    if (_isEditing) {
      _doBack();
      return;
    }
    if (!_hasContent) {
      _doBack();
      return;
    }
    _showSaveDraftDialog(
      onCancel: () {},
      onDiscard: _doBack,
      onSave: () async {
        await _saveCurrentDraft();
        if (mounted) _doBack();
      },
    );
  }

  /// 从底部导航栏切换 Tab 时调用，拦截未保存内容
  void handleTabSwitch({
    VoidCallback? onSave,
    VoidCallback? onDiscard,
  }) {
    // 编辑模式：直接退出，不触发草稿保存
    if (_isEditing) {
      onDiscard?.call();
      return;
    }
    if (!_hasContent) {
      onDiscard?.call();
      return;
    }
    _showSaveDraftDialog(
      onCancel: () {},
      onDiscard: () {
        _clearContent();
        onDiscard?.call();
      },
      onSave: () async {
        await _saveCurrentDraft();
        if (mounted) {
          _clearContent();
          onSave?.call();
        }
      },
    );
  }

  void _showSaveDraftDialog({
    required VoidCallback onCancel,
    required VoidCallback onDiscard,
    required Future<void> Function() onSave,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.saveDraft,
            style: TextStyle(color: appColors.textPrimary)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(AppLocalizations.of(context)!.saveDraftHint,
              style: TextStyle(color: appColors.textSecondary, fontSize: 14)),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              onCancel();
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              onDiscard();
            },
            child: Text(AppLocalizations.of(context)!.discard),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onSave();
            },
            child: Text(AppLocalizations.of(context)!.saveAction),
          ),
        ],
      ),
    );
  }

  void _clearContent() {
    _textEditingController.clear();
    for (final c in _pollControllers) {
      c.clear();
    }
    setState(() {
      _mediaDrafts.clear();
      _showPollEditor = false;
      _replyType = 1;
      _location = null;
      _latitude = null;
      _longitude = null;
      _scheduledTime = null;
    });
  }

  void _doBack() {
    _clearContent();
    widget.onCancel?.call();
  }

  // ─── Media ────────────────────────────────────────────────

  /// 通用添加媒体入口（含互斥检查：开启投票会清空已有媒体）
  void _addMedia(MediaDraftItem item) {
    if (!_canAddMoreMedia) return;
    setState(() {
      // 添加媒体时关闭投票（互斥）
      if (_showPollEditor) {
        _showPollEditor = false;
        for (final c in _pollControllers) {
          c.clear();
        }
      }
      _mediaDrafts.insert(0, item);
    });
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaDrafts.removeAt(index);
    });
  }

  void _togglePollEditor() {
    setState(() {
      _showPollEditor = !_showPollEditor;
      if (_showPollEditor) {
        // 开启投票时清空所有媒体（互斥）
        _mediaDrafts.clear();
        _initPollControllers();
      }
    });
  }

  void _addPollOption() {
    if (_pollControllers.length < _maxPollOptions) {
      setState(() {
        _pollControllers.add(TextEditingController());
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollControllers.length > _minPollOptions) {
      setState(() {
        _pollControllers[index].dispose();
        _pollControllers.removeAt(index);
      });
    }
  }

  List<String>? _getValidPollOptions() {
    if (!_showPollEditor) return null;
    final options = _pollControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return options.length >= _minPollOptions ? options : null;
  }

  // ─── Multi-select media picker (system PHPickerViewController) ───

  /// 系统相册多选入口（图片 + 视频可混选）
  /// - 追加到 _mediaDrafts，不清空已选
  /// - 超出 _maxMediaCount 时截断前 N 张并提示
  Future<void> _pickMultipleMedia() async {
    // 1) 上限保护：剩余配额 = _maxMediaCount - _mediaDrafts.length
    final remaining = _maxMediaCount - _mediaDrafts.length;
    if (remaining <= 0) {
      _showSnack(
          AppLocalizations.of(context)!.mediaLimitReached(_maxMediaCount));
      return;
    }

    // 2) 调起系统多选
    final picker = ImagePicker();
    final List<XFile> picked;
    try {
      picked = await picker.pickMultipleMedia(
          // 不传 imageQuality / maxWidth：保留原始尺寸
          // 注：image_picker 0.8.x 的 pickMultipleMedia 不支持 limit 参数，
          // 上限由下面客户端二次截断兜底。
          );
    } catch (e) {
      developer.log('pickMultipleMedia failed: $e', name: 'ComposePost');
      return; // 用户取消时也走这里，不打扰
    }
    if (picked.isEmpty || !mounted) return;

    // 3) 解析 + 校验每张媒体
    final accepted = <MediaDraftItem>[];
    final rejected = <String>[]; // 失败原因，按文件聚合
    for (final xfile in picked) {
      if (accepted.length >= remaining) {
        // 在客户端二次截断（覆盖 limit 参数不生效的低版本系统）
        rejected
            .add(AppLocalizations.of(context)!.mediaTruncated(_maxMediaCount));
        break;
      }
      final result = await _buildMediaDraftFromXFile(xfile);
      if (result.item != null) {
        accepted.add(result.item!);
      } else {
        rejected.add(result.error ?? 'unknown');
      }
    }

    // 4) 写入 state（仅成功的）
    if (accepted.isNotEmpty) {
      setState(() {
        // 开启投票时清空投票（与现有 _addMedia 互斥逻辑保持一致）
        if (_showPollEditor) {
          _showPollEditor = false;
          for (final c in _pollControllers) {
            c.clear();
          }
        }
        _mediaDrafts.addAll(accepted);
      });
    }

    // 5) 反馈：成功条数 + 失败原因（最多展示 1 条避免刷屏）
    if (mounted) {
      if (accepted.isNotEmpty) {
        final appColors =
            Theme.of(context).extension<AppColorsExtension>()!.colors;
        _showSnack(
          AppLocalizations.of(context)!.mediaPicked(accepted.length),
          backgroundColor: appColors.repost,
        );
      }
      if (rejected.isNotEmpty) {
        _showSnack(rejected.first);
      }
    }
  }

  /// 内部辅助：把单个 XFile 解析为 MediaDraftItem
  /// 返回 (item?, errorMessage?)
  /// - 图片：只校验大小 ≤ 10MB
  /// - 视频：校验大小 ≤ 100MB、时长 ≤ 300 秒（5 分钟，探测失败也允许通过，时长 UI 不显示即可）
  /// - GIF：扩展名 .gif 且 ≤ 10MB
  Future<({MediaDraftItem? item, String? error})> _buildMediaDraftFromXFile(
    XFile xfile,
  ) async {
    final path = xfile.path;
    final file = File(path);
    final mime = xfile.mimeType?.toLowerCase() ?? '';
    final ext = path.toLowerCase();

    // ── 视频判断（mime 优先，扩展名兜底）
    final isVideo = mime.startsWith('video/') ||
        ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.m4v');
    final isGif = mime == 'image/gif' || ext.endsWith('.gif');

    if (isVideo) {
      // 大小校验
      final size = await file.length();
      if (size > _maxVideoSizeBytes) {
        return (
          item: null,
          error: AppLocalizations.of(context)!.videoTooLarge(
            (size / 1024 / 1024).toStringAsFixed(1),
          ),
        );
      }
      // 时长校验
      try {
        final meta = await VideoProcessor.getMediaInfo(path);
        if (meta.durationMs > _maxVideoDurationMs) {
          return (
            item: null,
            error: AppLocalizations.of(context)!.videoTooLong(
              (meta.durationMs / 1000).toStringAsFixed(1),
            ),
          );
        }
        return (
          item: MediaDraftItem.fromLocalVideo(
            file,
            durationMs: meta.durationMs,
            fileSizeBytes: size,
          ),
          error: null,
        );
      } on VideoProcessException catch (e) {
        // 探测失败：仍允许通过，时长显示为空即可
        developer.log('getMediaInfo failed: ${e.message}', name: 'ComposePost');
        return (
          item: MediaDraftItem.fromLocalVideo(file,
              durationMs: 0, fileSizeBytes: size),
          error: null,
        );
      }
    }

    if (isGif) {
      final size = await file.length();
      if (size > _maxGifSizeBytes) {
        return (
          item: null,
          error: AppLocalizations.of(context)!.gifTooLarge(
            (size / 1024 / 1024).toStringAsFixed(1),
          ),
        );
      }
      return (
        item: MediaDraftItem.fromLocalGif(file, fileSizeBytes: size),
        error: null,
      );
    }

    // 兜底：图片
    final size = await file.length();
    if (size > _maxImageSizeBytes) {
      return (
        item: null,
        error: AppLocalizations.of(context)!.imageTooLarge(
          (size / 1024 / 1024).toStringAsFixed(1),
        ),
      );
    }
    return (
      item: MediaDraftItem.fromLocalImage(file, fileSizeBytes: size),
      error: null,
    );
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? appColors.destructive,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Camera ───────────────────────────────────────────────

  Future<void> _openCamera() async {
    if (!_canAddMoreMedia) {
      _showSnack('已达媒体数量上限 ($_maxMediaCount)');
      return;
    }
    final remaining = _maxMediaCount - _mediaDrafts.length;
    // 相机页 pop 的结果可能是：
    // - CameraCaptureResult（视频录制完成）
    // - List<CameraCaptureResult>（照片模式批量返回）
    final dynamic result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute(
        builder: (_) => ComposeCameraPage(remainingCapacity: remaining),
      ),
    );
    if (result == null) return;

    if (result is CameraCaptureResult) {
      _addOneCapture(result);
    } else if (result is List<CameraCaptureResult>) {
      // 照片模式批量返回
      for (final c in result) {
        _addOneCapture(c);
        if (!_canAddMoreMedia) break;
      }
    }
  }

  void _addOneCapture(CameraCaptureResult result) {
    if (result.isVideo) {
      _addMedia(
        MediaDraftItem.fromLocalVideo(
          File(result.path),
          durationMs: result.durationMs,
          thumbPath: result.thumbnail?.path,
        ),
      );
    } else {
      _addMedia(MediaDraftItem.fromLocalImage(File(result.path)));
    }
  }

  // ─── Draft ────────────────────────────────────────────────

  // ignore: unused_element  // TODO: 工具栏入口暂时隐藏，恢复时取消此 ignore
  void _showDraftListSheet() {
    final draftState = Provider.of<DraftState>(context, listen: false);
    draftState.loadDrafts();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => DraftListSheet(
        onDraftSelected: (draft) => _onDraftSelected(draft),
      ),
    );
  }

  /// 从草稿列表选中草稿：先用 list 数据立即恢复基本字段（保持 UI 响应即时），
  /// 再异步调 loadDraftForEditing 拉详情，补全 mediaList / location。
  Future<void> _onDraftSelected(DraftInfo draft) async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final draftState = Provider.of<DraftState>(context, listen: false);

    // Step 1: 立即用 list 数据恢复基本字段
    setState(() {
      _textEditingController.text = draft.content;
      if (draft.pollOptions != null && draft.pollOptions!.isNotEmpty) {
        _showPollEditor = true;
        _mediaDrafts.clear();
        _pollControllers = draft.pollOptions!
            .map((opt) => TextEditingController(text: opt))
            .toList();
        if (_pollControllers.length < _minPollOptions) {
          while (_pollControllers.length < _minPollOptions) {
            _pollControllers.add(TextEditingController());
          }
        }
      } else {
        _mediaDrafts.clear();
        _showPollEditor = false;
      }
      if (draft.replyType != null) {
        _replyType = draft.replyType!;
      }
    });

    // Step 2: 异步拉详情补全 mediaList / location
    final detail = await draftState.loadDraftForEditing(draft.id);
    if (!mounted) return;
    if (detail == null) return; // 拉取失败时基本字段已恢复，忽略
    setState(() {
      if (detail.mediaUrls.isNotEmpty) {
        _mediaDrafts = _buildDraftsFromMediaList(
          detail.mediaUrls,
          detail.mediaTypes,
        );
      }
      if (detail.location != null && detail.location!.isNotEmpty) {
        _location = detail.location;
      }
      _latitude = detail.latitude;
      _longitude = detail.longitude;
    });
    if (_mediaDrafts.isNotEmpty || (detail.location?.isNotEmpty ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.draftLoaded),
          backgroundColor: appColors.surface,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 从后端返回的 mediaUrls + mediaTypes 重建草稿列表。
  /// 仅保留首个能解析的 mediaType（与服务端约定对齐）。
  List<MediaDraftItem> _buildDraftsFromMediaList(
    List<String> mediaUrls,
    List<int>? mediaTypes,
  ) {
    final out = <MediaDraftItem>[];
    for (int i = 0; i < mediaUrls.length; i++) {
      final url = mediaUrls[i];
      if (url.isEmpty) continue;
      final mt =
          (mediaTypes != null && i < mediaTypes.length) ? mediaTypes[i] : 1;
      out.add(
        MediaDraftItem.fromRemote(
          url: url,
          type: DraftMediaType.fromMediaTypeInt(mt),
        ),
      );
    }
    return out;
  }

  /// 把当前内容（本地 + 远端）打包成可保存的草稿数据
  /// - 本地文件全部上传
  /// - 返回 (mediaUrls, mediaTypes) 平行数组
  Future<List<MapEntry<String, int>>?> _resolveDraftMedia() async {
    if (_mediaDrafts.isEmpty) return null;
    final uploadService =
        Provider.of<PostState>(context, listen: false).uploadService;

    final out = <MapEntry<String, int>>[];
    for (int i = 0; i < _mediaDrafts.length; i++) {
      final item = _mediaDrafts[i];
      try {
        final url = item.needsUpload && item.localFile != null
            ? await uploadService.uploadMedia(
                item.localFile!,
                mediaType: item.mediaTypeInt,
                durationMs: item.durationMs,
              )
            : (item.remoteUrl ?? '');
        if (url.isEmpty) continue;
        out.add(MapEntry(url, item.mediaTypeInt));
      } catch (e) {
        if (!mounted) return null;
        NetworkErrorNotifier.showApiError(e);
        return null;
      }
    }
    return out;
  }

  Future<void> _saveCurrentDraft() async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final content = _textEditingController.text.trim();
    final hasMedia = _mediaDrafts.isNotEmpty;
    if (content.isEmpty && !hasMedia && !_showPollEditor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.nothingToSaveDraft),
          backgroundColor: appColors.surface,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isSavingDraft = true);
    try {
      final draftState = Provider.of<DraftState>(context, listen: false);

      // 上传本地媒体，收集 (url, mediaType) 平行数组
      final resolved = await _resolveDraftMedia();
      if (!mounted) return;
      if (hasMedia && resolved == null) return; // 上传失败已提示

      final mediaUrls = resolved?.map((e) => e.key).toList();
      final mediaTypes = resolved?.map((e) => e.value).toList();

      final saved = await draftState.saveDraft(
        content: content,
        mediaUrls:
            (mediaUrls != null && mediaUrls.isNotEmpty) ? mediaUrls : null,
        mediaTypes:
            (mediaTypes != null && mediaTypes.isNotEmpty) ? mediaTypes : null,
        pollOptions: _getValidPollOptions(),
        replyType: _replyType != 1 ? _replyType : null,
        location: _location,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.draftSaved),
            backgroundColor: appColors.repost,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        // saveDraft 返回 null = 服务端拒绝或未知错误。具体原因未通过异常传上来，
        // 调试阶段用通用占位提示。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.draftSaveFailed} (saveDraft 返回 null)'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
    } finally {
      // 无论成功 / 失败 / 提前 return，都关闭加载动画
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  // ─── Submit ───────────────────────────────────────────────

  Future<PostModel> _createPostModel() async {
    var authState = Provider.of<AuthState>(context, listen: false);
    var myUser = authState.userModel!;

    var commentedUser = UserModel(
      displayName: myUser.displayName ?? myUser.email?.split('@')[0] ?? '',
      profilePic: myUser.profilePic,
      userId: myUser.userId,
      userName: myUser.userName,
    );

    return PostModel(
      user: commentedUser,
      bio: _textEditingController.text,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      key: myUser.userId?.toString(),
      // 提交前再做一次同步，确保删除/改名后不再残留无效 userId（防御性）。
      mentionedUserIds: () {
        _syncMentionUserIds();
        return _mentionUserIds.values.toList();
      }(),
    );
  }

  Future<void> _submit() async {
    if (!_canPost) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var state = Provider.of<PostState>(context, listen: false);

    if (_isEditing) {
      // ── 编辑模式：仅可改 content / is_sensitive / content_warning ──
      final updated = await state.updatePost(
        postId: widget.editingPostId!,
        content: _textEditingController.text,
        isSensitive: _isSensitive,
        contentWarning: _isSensitive
            ? (_contentWarningController.text.trim().isEmpty
                ? null
                : _contentWarningController.text.trim())
            : null,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.postUpdated),
            backgroundColor: appColors.repost,
            duration: const Duration(seconds: 1),
          ),
        );
        widget.onPostSuccess?.call();
      } else {
        // updatePost 返回 null = 服务端拒绝或未知错误。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.publishFailed} (updatePost 返回 null)'),
            backgroundColor: appColors.destructive,
          ),
        );
      }
      return;
    }

    // ── 新建模式 ──
    PostModel postModel = await _createPostModel();
    final pollOptions = _getValidPollOptions();
    final scheduledTimeStr = _scheduledTime?.toUtc().toIso8601String();
    developer.log(
      '🕐 [SCHEDULE-DEBUG] _submit 准备提交: '
      '_scheduledTime(local)=$_scheduledTime '
      '→ 序列化后=$scheduledTimeStr '
      '(本机当前=${DateTime.now()} 本机当前UTC=${DateTime.now().toUtc()})',
      name: 'ComposePost',
    );
    final result = await state.createPost(
      postModel,
      mediaDrafts: _mediaDrafts.isNotEmpty ? _mediaDrafts : null,
      pollOptions: pollOptions,
      replyType: _replyType != 1 ? _replyType : null,
      location: _location,
      latitude: _latitude,
      longitude: _longitude,
      scheduledTime: scheduledTimeStr,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      final isScheduled = _scheduledTime != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isScheduled
              ? AppLocalizations.of(context)!.schedulePublishSuccess
              : AppLocalizations.of(context)!.publishSuccess),
          backgroundColor: appColors.repost,
          duration: const Duration(seconds: 1),
        ),
      );
      _textEditingController.clear();
      for (final c in _pollControllers) {
        c.clear();
      }
      setState(() {
        _mediaDrafts.clear();
        _showPollEditor = false;
        _replyType = 1;
        _location = null;
        _latitude = null;
        _longitude = null;
        _scheduledTime = null;
      });
      widget.onPostSuccess?.call();
    } else {
      // 发布失败 — 把服务端 / 网络的具体错误展示给用户，方便反馈与排障
      // 完整 stackTrace 已写入 developer.log，详见 PostState [stage="$stage"] 日志
      final l10n = AppLocalizations.of(context)!;
      final reason = result.errorMessage?.trim().isNotEmpty == true
          ? result.errorMessage!.trim()
          : '未知错误';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.publishFailedWithReason(reason),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: appColors.destructive,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ─── Location ────────────────────────────────────────────

  /// 打开地图选址全屏页。返回 PickedLocation(name, lat, lng) 时一并写入状态；
  /// 用户取消（返回 null）则保持原值不变。
  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      CupertinoPageRoute(
        builder: (_) => LocationPickerPage(
          initialCenter: (_latitude != null && _longitude != null)
              ? LatLng(_latitude!, _longitude!)
              : null,
          initialName: _location,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _location = result.name;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  // ─── Schedule ───────────────────────────────────────────

  /// 把时间归整到下一个整点（秒 / 毫秒 / 微秒清零）。
  ///
  /// CupertinoDatePicker 在 `dateAndTime` 模式下没有「秒」轮，但会把
  /// `initialDateTime` 的秒 / 微秒继承下去。如果初始时间带 :33.212372
  /// 这种精度,用户怎么拖 picker 都去不掉,最终提交出去的时间会带
  /// 莫名其妙的尾巴(例如选了 15:00 实际发出 `15:00:33.212372`)。
  /// 把默认值归整到整点可以保证 picker 继承的秒 / 微秒本身就是 0,
  /// 用户选什么具体时间,提交出去就是什么具体时间(仅时区偏移)。
  DateTime _roundUpToNextHour(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour + 1);
  }

  void _showSchedulePicker() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    // 默认值归整到下一个整点(不带秒 / 微秒),见 _roundUpToNextHour。
    // _scheduledTime 已存在时(用户之前选过)原样使用,保留用户意图。
    DateTime initialTime =
        _scheduledTime ?? _roundUpToNextHour(DateTime.now());
    final minimumTime = DateTime.now().add(const Duration(minutes: 5));
    if (initialTime.isBefore(minimumTime)) {
      initialTime = minimumTime;
    }
    DateTime selectedTime = initialTime;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 6),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(modalContext),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(l10n.cancel,
                      style: TextStyle(color: appColors.textSecondary)),
                  onPressed: () => Navigator.pop(modalContext),
                ),
                CupertinoButton(
                  child: Text(l10n.clearSchedule,
                      style: TextStyle(color: appColors.destructive)),
                  onPressed: () {
                    setState(() => _scheduledTime = null);
                    Navigator.pop(modalContext);
                  },
                ),
                CupertinoButton(
                  child: Text(l10n.confirmButton,
                      style: TextStyle(
                          color: appColors.accent,
                          fontWeight: FontWeight.w600)),
                  onPressed: () {
                    if (selectedTime.isBefore(
                        DateTime.now().add(const Duration(minutes: 5)))) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.scheduleTimeTooEarly),
                        backgroundColor: appColors.destructive,
                        duration: const Duration(seconds: 2),
                      ));
                      return;
                    }
                    setState(() => _scheduledTime = selectedTime);
                    Navigator.pop(modalContext);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: initialTime,
                minimumDate: minimumTime,
                maximumDate: DateTime.now().add(const Duration(days: 365)),
                use24hFormat: true,
                onDateTimeChanged: (DateTime newTime) {
                  selectedTime = newTime;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reply Permission Sheet ──────────────────────────────

  void _showReplyTypeSheet() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppLocalizations.of(context)!.whoCanReply,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(color: appColors.divider, height: 1),
              _replyTypeOption(1, Iconsax.global,
                  AppLocalizations.of(context)!.everyoneCanReply),
              _replyTypeOption(2, Iconsax.user,
                  AppLocalizations.of(context)!.followersCanReply),
              _replyTypeOption(3, Iconsax.people,
                  AppLocalizations.of(context)!.followingCanReply),
              _replyTypeOption(4, Icons.alternate_email,
                  AppLocalizations.of(context)!.mentionedCanReply),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _replyTypeOption(int value, IconData icon, String label) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final isSelected = _replyType == value;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? appColors.textPrimary : appColors.textSecondary,
          size: 22),
      title: Text(label,
          style: TextStyle(
            color: isSelected ? appColors.textPrimary : appColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          )),
      trailing: isSelected
          ? Icon(Icons.check, color: appColors.textPrimary, size: 20)
          : null,
      onTap: () {
        setState(() => _replyType = value);
        Navigator.pop(context);
      },
    );
  }

  IconData get _replyTypeIcon {
    switch (_replyType) {
      case 2:
        return Iconsax.user;
      case 3:
        return Iconsax.people;
      case 4:
        return Icons.alternate_email;
      default:
        return Iconsax.global;
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var authState = Provider.of<AuthState>(context);
    final charCount = _textEditingController.text.length;
    final userModel = authState.userModel;
    final profilePic = userModel?.profilePic ?? '';
    // 服务端对未填写 displayName 的用户返回空字符串（非 null），
    // 仅用 `?? ''` 会渲染成空白。需要显式判 isNotEmpty，按
    // displayName → userName → anonymousUser 的优先级兜底（与 feed.dart 快捷发帖区一致）。
    final displayName = (userModel?.displayName?.isNotEmpty == true
            ? userModel!.displayName
            : userModel?.userName) ??
        AppLocalizations.of(context)!.anonymousUser;

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        toolbarHeight: 56,
        leading: Container(),
        flexibleSpace: SafeArea(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _handleBack(context),
                  child: Text(AppLocalizations.of(context)!.back,
                      style: TextStyle(
                          color: appColors.textPrimary, fontSize: 16)),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                        _isEditing
                            ? AppLocalizations.of(context)!.editPost
                            : AppLocalizations.of(context)!.newPost,
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 48), // balance Cancel width
              ],
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── User header + text input ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: avatar (thread line 暂时移除)
                      _buildAvatar(appColors, profilePic, 40),
                      const SizedBox(width: 12),
                      // Right: name + text field + char count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: appColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            CompositedTransformTarget(
                              link: _layerLink,
                              child: TextField(
                                maxLength: _maxContentLength,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                keyboardAppearance:
                                    Theme.of(context).brightness,
                                style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 16),
                                controller: _textEditingController,
                                onChanged: (_) => _onTextChanged(),
                                maxLines: null,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: AppLocalizations.of(context)!
                                      .saySomething,
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    color: appColors.textHint,
                                  ),
                                ),
                              ),
                            ),
                            if (charCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$charCount / $_maxContentLength',
                                  style: TextStyle(
                                    color: charCount > 450
                                        ? Colors.orange
                                        : appColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            // 编辑模式：敏感内容开关 + 内容警告
                            if (_isEditing) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _isSensitive = !_isSensitive),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Icon(
                                      _isSensitive
                                          ? Iconsax.tick_circle5
                                          : Iconsax.warning_2,
                                      size: 16,
                                      color: _isSensitive
                                          ? appColors.accent
                                          : appColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .markAsSensitive,
                                      style: TextStyle(
                                        color: _isSensitive
                                            ? appColors.textPrimary
                                            : appColors.textSecondary,
                                        fontSize: 14,
                                        fontWeight: _isSensitive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isSensitive) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: appColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: appColors.divider),
                                  ),
                                  child: TextField(
                                    controller: _contentWarningController,
                                    maxLength: 200,
                                    style: TextStyle(
                                        color: appColors.textPrimary,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context)!
                                          .contentWarningHint,
                                      hintStyle: TextStyle(
                                          color: appColors.textHint,
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      counterText: '',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Media previews ──
                  if (_mediaDrafts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 52, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < _mediaDrafts.length; i++)
                                _buildMediaPreview(
                                    appColors, _mediaDrafts[i], i),
                              if (_canAddMoreMedia)
                                _buildAddMediaTile(appColors),
                            ],
                          ),
                          // 媒体计数
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_mediaDrafts.length} / $_maxMediaCount',
                              style: TextStyle(
                                color: appColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Poll editor ──
                  if (_showPollEditor)
                    Padding(
                      padding: const EdgeInsets.only(left: 52, top: 12),
                      child: _buildPollEditor(appColors),
                    ),

                  // ── Location chip ──
                  if (_location != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52, top: 8),
                      child: GestureDetector(
                        onTap: _openLocationPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.location,
                                size: 14, color: appColors.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _location!,
                                style: TextStyle(
                                    color: appColors.textSecondary,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Schedule time indicator ──
                  if (_scheduledTime != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52, top: 8),
                      child: GestureDetector(
                        onTap: _showSchedulePicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.clock,
                                size: 14, color: appColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${_scheduledTime!.year}-${_scheduledTime!.month.toString().padLeft(2, '0')}-${_scheduledTime!.day.toString().padLeft(2, '0')} '
                              '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  color: appColors.accent, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom toolbar ──
          _buildBottomToolbar(appColors),
        ],
      ),
    );
  }

  // ─── Widget builders ──────────────────────────────────────

  static bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.host.contains('example.com')) return false;
    return true;
  }

  Widget _buildAvatar(AppColors appColors, String url, double size) {
    if (!_isValidImageUrl(url)) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: appColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person,
            size: size * 0.6, color: appColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: CachedNetworkImage(
        imageUrl: url,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: appColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person,
              size: size * 0.6, color: appColors.textSecondary),
        ),
      ),
    );
  }

  /// 通用媒体预览：图片 / 视频缩略图（带 ▶ + 时长）/ GIF（动画）
  Widget _buildMediaPreview(
      AppColors appColors, MediaDraftItem item, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 80,
            child: _buildMediaThumb(appColors, item),
          ),
        ),
        if (item.isVideo && item.durationLabel.isNotEmpty)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.durationLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: appColors.background.withValues(alpha: 0.87),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: appColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaThumb(AppColors appColors, MediaDraftItem item) {
    // 视频：缩略图（本地或远端） + ▶ 角标
    if (item.isVideo) {
      final thumbWidget = item.thumbPath != null
          ? Image.file(File(item.thumbPath!),
              fit: BoxFit.cover, width: 80, height: 80)
          : item.remoteThumbUrl != null
              ? CachedNetworkImage(
                  imageUrl: item.remoteThumbUrl!,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                  placeholder: (_, __) => Container(color: appColors.surface),
                  errorWidget: (_, __, ___) => Container(
                      color: appColors.surface,
                      child: const Icon(Icons.videocam)),
                )
              : Container(
                  color: appColors.surface,
                  child: const Icon(Icons.videocam, color: Colors.white54),
                );
      return Stack(
        fit: StackFit.expand,
        children: [
          thumbWidget,
          Container(color: Colors.black.withValues(alpha: 0.18)),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      );
    }

    // 图片
    if (item.isImage) {
      if (item.localFile != null) {
        return Image.file(item.localFile!,
            fit: BoxFit.cover, width: 80, height: 80);
      }
      if (item.remoteUrl != null) {
        return CachedNetworkImage(
          imageUrl: item.remoteUrl!,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          placeholder: (_, __) => Container(color: appColors.surface),
          errorWidget: (_, __, ___) => Container(
            color: appColors.surface,
            child:
                Icon(Icons.broken_image, color: appColors.textMuted, size: 20),
          ),
        );
      }
    }

    // GIF
    if (item.isGif) {
      if (item.localFile != null) {
        return Image.file(item.localFile!,
            fit: BoxFit.cover, width: 80, height: 80);
      }
      if (item.remoteUrl != null) {
        return CachedNetworkImage(
          imageUrl: item.remoteUrl!,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          placeholder: (_, __) => Container(color: appColors.surface),
          errorWidget: (_, __, ___) => Container(
            color: appColors.surface,
            child:
                Icon(Icons.broken_image, color: appColors.textMuted, size: 20),
          ),
        );
      }
    }

    return Container(color: appColors.surface);
  }

  Widget _buildAddMediaTile(AppColors appColors) {
    return GestureDetector(
      onTap: _pickMultipleMedia,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appColors.divider, width: 1),
        ),
        child: Icon(Icons.add, size: 28, color: appColors.textMuted),
      ),
    );
  }

  Widget _buildPollEditor(AppColors appColors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _pollControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollControllers[i],
                      style:
                          TextStyle(color: appColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(context)!.optionLabel(i + 1),
                        hintStyle: TextStyle(
                            color: appColors.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: appColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appColors.textMuted),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_pollControllers.length > _minPollOptions)
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 18, color: appColors.textMuted),
                      onPressed: () => _removePollOption(i),
                    ),
                ],
              ),
            ),
          if (_pollControllers.length < _maxPollOptions)
            GestureDetector(
              onTap: _addPollOption,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: appColors.textMuted),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.addOption,
                        style: TextStyle(
                            color: appColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _togglePollEditor,
              child: Text(AppLocalizations.of(context)!.removePoll,
                  style: TextStyle(
                      color: appColors.destructive.withValues(alpha: 0.8),
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(AppColors appColors) {
    // 编辑模式：仅显示提交按钮（不可改媒体/投票/草稿/位置/定时/回复权限）
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: appColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _canPost ? _submit : null,
                child: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appColors.accent,
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context)!.postUpdated.isNotEmpty
                            ? AppLocalizations.of(context)!.saveEdits
                            : AppLocalizations.of(context)!.post,
                        style: TextStyle(
                          color:
                              _canPost ? appColors.accent : appColors.divider,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: appColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 左侧 7 个功能按钮: 用 Expanded + 横向滚动包裹,
            // 避免图标加大后挤压右侧 2 个操作按钮 (出现 RenderFlex overflow)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolbarIcon(
                      onTap: _showPollEditor ? null : _openCamera,
                      icon: Iconsax.camera,
                      color: _showPollEditor
                          ? appColors.divider
                          : appColors.textPrimary,
                    ),
                    _toolbarIcon(
                      onTap: (_showPollEditor || !_canAddMoreMedia)
                          ? null
                          : _pickMultipleMedia,
                      icon: Iconsax.gallery,
                      color: (_showPollEditor || !_canAddMoreMedia)
                          ? appColors.divider
                          : appColors.textPrimary,
                    ),
                    _toolbarIcon(
                      onTap:
                          _mediaDrafts.isNotEmpty ? null : _togglePollEditor,
                      icon: Iconsax.chart_square,
                      color: _mediaDrafts.isNotEmpty
                          ? appColors.divider
                          : (_showPollEditor
                              ? appColors.accent
                              : appColors.textPrimary),
                    ),
                    _toolbarIcon(
                      onTap: _showReplyTypeSheet,
                      icon: _replyTypeIcon,
                      color: appColors.textMuted,
                    ),
                    _toolbarIcon(
                      onTap: _showDraftListSheet,
                      icon: Iconsax.note_text,
                      color: appColors.textMuted,
                    ),
                    _toolbarIcon(
                      onTap: _openLocationPicker,
                      icon: Iconsax.location,
                      color: _location != null
                          ? appColors.accent
                          : appColors.textMuted,
                    ),
                    _toolbarIcon(
                      onTap: _showSchedulePicker,
                      icon: Iconsax.clock,
                      color: _scheduledTime != null
                          ? appColors.accent
                          : appColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_hasContent)
              GestureDetector(
                onTap: _isSavingDraft ? null : _saveCurrentDraft,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _isSavingDraft
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appColors.textSecondary,
                          ),
                        )
                      : Icon(
                          Iconsax.save_2,
                          size: 28,
                          color: appColors.textSecondary,
                        ),
                ),
              ),
            GestureDetector(
              onTap: _canPost ? _submit : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appColors.accent,
                        ),
                      )
                    : Icon(
                        _scheduledTime != null
                            ? Iconsax.timer_1
                            : Iconsax.send_1,
                        size: 30,
                        color: _canPost ? appColors.accent : appColors.divider,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarIcon({
    required VoidCallback? onTap,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}
