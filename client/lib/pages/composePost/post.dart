import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
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
  const ComposePost({
    Key? key,
    this.onPostSuccess,
    this.onCancel,
    this.editingPostId,
    this.initialContent,
    this.initialIsSensitive,
    this.initialContentWarning,
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
  String? _location;
  DateTime? _scheduledTime;
  // 编辑模式：敏感内容
  bool _isSensitive = false;
  late TextEditingController _contentWarningController;

  static const int _maxMediaCount = 10;
  static const int _maxPollOptions = 4;
  static const int _minPollOptions = 2;
  static const int _maxContentLength = 500;

  // 视频相关限制（与后端 / VideoProcessor 保持一致）
  static const int _maxVideoDurationMs = 60 * 1000;
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024;
  static const int _maxGifSizeBytes = 20 * 1024 * 1024;

  bool get _isEditing => widget.editingPostId != null;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: widget.initialContent ?? '');
    _contentWarningController = TextEditingController(text: widget.initialContentWarning ?? '');
    _isSensitive = widget.initialIsSensitive ?? false;
    _initPollControllers();
  }

  void _initPollControllers() {
    _pollControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _contentWarningController.dispose();
    for (final c in _pollControllers) {
      c.dispose();
    }
    super.dispose();
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
            child: Text(AppLocalizations.of(context)!.save),
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

  /// 替换某个本地草稿为已上传版本（上传成功后回调）
  void _replaceMedia(int index, MediaDraftItem updated) {
    setState(() {
      _mediaDrafts[index] = updated;
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

  // ─── Media pickers ────────────────────────────────────────

  Future<void> _pickImage() async {
    if (!_canAddMoreMedia) {
      _showSnack('已达媒体数量上限 ($_maxMediaCount)');
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (xFile != null) {
      _addMedia(MediaDraftItem.fromLocalImage(File(xFile.path)));
    }
  }

  Future<void> _pickGif() async {
    if (!_canAddMoreMedia) {
      _showSnack('已达媒体数量上限 ($_maxMediaCount)');
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      // imageQuality 对 GIF 无效；GIF 由 MIME 推断识别
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final size = await file.length();
    if (size > _maxGifSizeBytes) {
      _showSnack('GIF 超过 20MB 上限（当前 ${(size / 1024 / 1024).toStringAsFixed(1)}MB）');
      return;
    }
    // 仅当扩展名为 .gif 时才当作 GIF 处理
    final ext = xFile.path.toLowerCase();
    if (!ext.endsWith('.gif')) {
      _showSnack('请选择 .gif 格式的动图');
      return;
    }
    _addMedia(MediaDraftItem.fromLocalGif(file, fileSizeBytes: size));
  }

  Future<void> _pickVideo() async {
    if (!_canAddMoreMedia) {
      _showSnack('已达媒体数量上限 ($_maxMediaCount)');
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null) return;

    final file = File(xFile.path);
    final size = await file.length();
    if (size > _maxVideoSizeBytes) {
      _showSnack('视频超过 100MB 上限（当前 ${(size / 1024 / 1024).toStringAsFixed(1)}MB）');
      return;
    }

    // 探测时长 / 宽高，校验不超过 60s
    try {
      final meta = await VideoProcessor.getMediaInfo(file.path);
      if (meta.durationMs > _maxVideoDurationMs) {
        _showSnack(
          '视频时长 ${(meta.durationMs / 1000).toStringAsFixed(1)}s 超过 60s 上限',
        );
        return;
      }
    } on VideoProcessException catch (e) {
      _showSnack('读取视频信息失败: ${e.message}');
      return;
    }

    _addMedia(
      MediaDraftItem.fromLocalVideo(
        file,
        durationMs: 0, // 由 _openCamera 路径精确写入；从相册选择暂以 0 占位
        fileSizeBytes: size,
      ),
    );
    // 异步获取精确 duration 并 patch 到 draft
    _enrichVideoDuration(_mediaDrafts.indexWhere((d) => d.localFile?.path == file.path), file.path);
  }

  /// 异步从 metadata 补充视频精确时长（相册选择路径）
  void _enrichVideoDuration(int draftIndex, String path) {
    if (draftIndex < 0) return;
    VideoProcessor.getMediaInfo(path).then((meta) {
      if (!mounted) return;
      if (draftIndex >= _mediaDrafts.length) return;
      final current = _mediaDrafts[draftIndex];
      if (current.localFile?.path != path) return;
      _replaceMedia(
        draftIndex,
        current.copyWith(durationMs: meta.durationMs),
      );
    }).catchError((_) {
      // 静默：duration 缺失时 UI 仅不显示时长标签
    });
  }

  /// 「+」按钮弹出底部 sheet：图片 / 视频 / GIF
  void _showMediaPickerSheet() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetItem(
                context: sheetContext,
                icon: Iconsax.gallery,
                label: '图片',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage();
                },
              ),
              _sheetItem(
                context: sheetContext,
                icon: Iconsax.video,
                label: '视频',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo();
                },
              ),
              _sheetItem(
                context: sheetContext,
                icon: Iconsax.image,
                label: 'GIF',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickGif();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return ListTile(
      leading: Icon(icon, color: appColors.textPrimary, size: 22),
      title: Text(label,
          style: TextStyle(color: appColors.textPrimary, fontSize: 16)),
      onTap: onTap,
    );
  }

  void _showSnack(String message) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: appColors.destructive,
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
    final result = await Navigator.push<CameraCaptureResult>(
      context,
      CupertinoPageRoute(builder: (_) => const ComposeCameraPage()),
    );
    if (result == null) return;

    if (result.isVideo) {
      // 视频：从 thumbnail 提取首帧图路径
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

  Future<void> _openVideoCamera() async {
    if (!_canAddMoreMedia) {
      _showSnack('已达媒体数量上限 ($_maxMediaCount)');
      return;
    }
    final result = await Navigator.push<CameraCaptureResult>(
      context,
      CupertinoPageRoute(
        builder: (_) => const ComposeCameraPage(initialMode: CameraMode.video),
      ),
    );
    if (result == null) return;
    if (result.isVideo) {
      _addMedia(
        MediaDraftItem.fromLocalVideo(
          File(result.path),
          durationMs: result.durationMs,
          thumbPath: result.thumbnail?.path,
        ),
      );
    }
  }

  // ─── Draft ────────────────────────────────────────────────

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
      final mt = (mediaTypes != null && i < mediaTypes.length) ? mediaTypes[i] : 1;
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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
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
      } catch (_) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.draftSaveFailed),
            backgroundColor: appColors.destructive,
          ),
        );
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
    final draftState = Provider.of<DraftState>(context, listen: false);

    // 上传本地媒体，收集 (url, mediaType) 平行数组
    final resolved = await _resolveDraftMedia();
    if (!mounted) return;
    if (hasMedia && resolved == null) return; // 上传失败已提示

    final mediaUrls = resolved?.map((e) => e.key).toList();
    final mediaTypes = resolved?.map((e) => e.value).toList();

    final saved = await draftState.saveDraft(
      content: content,
      mediaUrls: (mediaUrls != null && mediaUrls.isNotEmpty) ? mediaUrls : null,
      mediaTypes: (mediaTypes != null && mediaTypes.isNotEmpty) ? mediaTypes : null,
      pollOptions: _getValidPollOptions(),
      replyType: _replyType != 1 ? _replyType : null,
      location: _location,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.draftSaveFailed),
          backgroundColor: appColors.destructive,
        ),
      );
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
    );
  }

  Future<void> _submit() async {
    if (!_canPost) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var state = Provider.of<PostState>(context, listen: false);

    String? postId;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.publishFailed),
            backgroundColor: appColors.destructive,
          ),
        );
      }
      return;
    }

    // ── 新建模式 ──
    PostModel postModel = await _createPostModel();
    final pollOptions = _getValidPollOptions();
    postId = await state.createPost(
      postModel,
      mediaDrafts: _mediaDrafts.isNotEmpty ? _mediaDrafts : null,
      pollOptions: pollOptions,
      replyType: _replyType != 1 ? _replyType : null,
      location: _location,
      scheduledTime: _scheduledTime?.toUtc().toIso8601String(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (postId != null) {
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
        _scheduledTime = null;
      });
      widget.onPostSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.publishFailed),
          backgroundColor: appColors.destructive,
        ),
      );
    }
  }

  // ─── Location ────────────────────────────────────────────

  void _showLocationDialog() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final controller = TextEditingController(text: _location ?? '');
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          AppLocalizations.of(context)!.addLocation,
          style: TextStyle(color: appColors.textPrimary),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: AppLocalizations.of(context)!.enterLocation,
            placeholderStyle: TextStyle(color: appColors.textMuted),
            style: TextStyle(color: appColors.textPrimary),
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() => _location = null);
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context)!.clearLocation),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final value = controller.text.trim();
              setState(() => _location = value.isEmpty ? null : value);
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  // ─── Schedule ───────────────────────────────────────────

  void _showSchedulePicker() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;

    DateTime initialTime =
        _scheduledTime ?? DateTime.now().add(const Duration(hours: 1));
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
                          color: appColors.accent, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    if (selectedTime
                        .isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
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
              _replyTypeOption(1, Iconsax.global, AppLocalizations.of(context)!.everyoneCanReply),
              _replyTypeOption(2, Iconsax.user, AppLocalizations.of(context)!.followersCanReply),
              _replyTypeOption(3, Iconsax.people, AppLocalizations.of(context)!.followingCanReply),
              _replyTypeOption(4, Icons.alternate_email, AppLocalizations.of(context)!.mentionedCanReply),
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
      leading: Icon(icon, color: isSelected ? appColors.textPrimary : appColors.textSecondary, size: 22),
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
      case 2: return Iconsax.user;
      case 3: return Iconsax.people;
      case 4: return Icons.alternate_email;
      default: return Iconsax.global;
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var authState = Provider.of<AuthState>(context);
    final charCount = _textEditingController.text.length;
    final profilePic = authState.userModel?.profilePic ?? '';
    final displayName = authState.userModel?.displayName ?? '';

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
                      style: TextStyle(color: appColors.textPrimary, fontSize: 16)),
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
                      // Left: avatar + thread line
                      Column(
                        children: [
                          _buildAvatar(appColors, profilePic, 40),
                          const SizedBox(height: 6),
                          Container(
                            width: 2,
                            height: 30,
                            color: appColors.dividerSecondary,
                          ),
                        ],
                      ),
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
                            TextField(
                              maxLength: _maxContentLength,
                              maxLengthEnforcement: MaxLengthEnforcement.enforced,
                              keyboardAppearance: Theme.of(context).brightness,
                              style: TextStyle(color: appColors.textPrimary, fontSize: 16),
                              controller: _textEditingController,
                              onChanged: (_) => setState(() {}),
                              maxLines: null,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                hintText: AppLocalizations.of(context)!.saySomething,
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: appColors.textHint,
                                ),
                              ),
                            ),
                            if (charCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$charCount / $_maxContentLength',
                                  style: TextStyle(
                                    color: charCount > 450 ? Colors.orange : appColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            // 编辑模式：敏感内容开关 + 内容警告
                            if (_isEditing) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => setState(() => _isSensitive = !_isSensitive),
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
                                      AppLocalizations.of(context)!.markAsSensitive,
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
                                    border: Border.all(color: appColors.divider),
                                  ),
                                  child: TextField(
                                    controller: _contentWarningController,
                                    maxLength: 200,
                                    style: TextStyle(
                                        color: appColors.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context)!
                                          .contentWarningHint,
                                      hintStyle: TextStyle(
                                          color: appColors.textHint, fontSize: 14),
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
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < _mediaDrafts.length; i++)
                            _buildMediaPreview(appColors, _mediaDrafts[i], i),
                          if (_canAddMoreMedia) _buildAddMediaTile(appColors),
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
                        onTap: _showLocationDialog,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.location, size: 14, color: appColors.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _location!,
                                style: TextStyle(color: appColors.textSecondary, fontSize: 13),
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
                            Icon(Iconsax.clock, size: 14, color: appColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${_scheduledTime!.year}-${_scheduledTime!.month.toString().padLeft(2, '0')}-${_scheduledTime!.day.toString().padLeft(2, '0')} '
                              '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: appColors.accent, fontSize: 13),
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
        child: Icon(Icons.person, size: size * 0.6, color: appColors.textSecondary),
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
  Widget _buildMediaPreview(AppColors appColors, MediaDraftItem item, int index) {
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
          ? Image.file(File(item.thumbPath!), fit: BoxFit.cover, width: 80, height: 80)
          : item.remoteThumbUrl != null
              ? CachedNetworkImage(
                  imageUrl: item.remoteThumbUrl!,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                  placeholder: (_, __) => Container(color: appColors.surface),
                  errorWidget: (_, __, ___) =>
                      Container(color: appColors.surface, child: const Icon(Icons.videocam)),
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
        return Image.file(item.localFile!, fit: BoxFit.cover, width: 80, height: 80);
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
            child: Icon(Icons.broken_image, color: appColors.textMuted, size: 20),
          ),
        );
      }
    }

    // GIF
    if (item.isGif) {
      if (item.localFile != null) {
        return Image.file(item.localFile!, fit: BoxFit.cover, width: 80, height: 80);
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
            child: Icon(Icons.broken_image, color: appColors.textMuted, size: 20),
          ),
        );
      }
    }

    return Container(color: appColors.surface);
  }

  Widget _buildAddMediaTile(AppColors appColors) {
    return GestureDetector(
      onTap: _showMediaPickerSheet,
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
                      style: TextStyle(color: appColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.optionLabel(i + 1),
                        hintStyle: TextStyle(color: appColors.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: appColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      icon: Icon(Icons.close, size: 18, color: appColors.textMuted),
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
                        style: TextStyle(color: appColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _togglePollEditor,
              child: Text(AppLocalizations.of(context)!.removePoll,
                  style: TextStyle(color: appColors.destructive.withValues(alpha: 0.8), fontSize: 13)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          color: _canPost ? appColors.accent : appColors.divider,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: appColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _toolbarIcon(
              onTap: _showPollEditor ? null : _openCamera,
              icon: Iconsax.camera,
              color: _showPollEditor ? appColors.divider : appColors.textPrimary,
            ),
            _toolbarIcon(
              onTap: _showPollEditor ? null : _showMediaPickerSheet,
              icon: Iconsax.picture_frame,
              color: _showPollEditor ? appColors.divider : appColors.textPrimary,
            ),
            _toolbarIcon(
              onTap: _showPollEditor ? null : _openVideoCamera,
              icon: Iconsax.video,
              color: _showPollEditor ? appColors.divider : appColors.textPrimary,
            ),
            _toolbarIcon(
              onTap: _mediaDrafts.isNotEmpty ? null : _togglePollEditor,
              icon: Iconsax.chart_square,
              color: _mediaDrafts.isNotEmpty
                  ? appColors.divider
                  : (_showPollEditor ? appColors.accent : appColors.textPrimary),
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
              onTap: _showLocationDialog,
              icon: Iconsax.location,
              color: _location != null ? appColors.accent : appColors.textMuted,
            ),
            _toolbarIcon(
              onTap: _showSchedulePicker,
              icon: Iconsax.clock,
              color: _scheduledTime != null ? appColors.accent : appColors.textMuted,
            ),
            const Spacer(),
            if (_hasContent)
              GestureDetector(
                onTap: _saveCurrentDraft,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    AppLocalizations.of(context)!.draft,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
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
                      _scheduledTime != null
                          ? AppLocalizations.of(context)!.schedulePost
                          : AppLocalizations.of(context)!.post,
                      style: TextStyle(
                        color: _canPost ? appColors.accent : appColors.divider,
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
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}
