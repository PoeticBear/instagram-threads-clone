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
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/draft.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/model/draft.module.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/widget/draft_list_sheet.dart';
import 'package:threads/pages/composePost/compose_camera_page.dart';

class ComposePost extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  final VoidCallback? onCancel;
  const ComposePost({Key? key, this.onPostSuccess, this.onCancel}) : super(key: key);

  @override
  State<ComposePost> createState() => _ComposePostState();
}

class _ComposePostState extends State<ComposePost> {
  late TextEditingController _textEditingController;
  List<File> _imageFiles = [];
  bool _showPollEditor = false;
  List<TextEditingController> _pollControllers = [];
  int _replyType = 1;
  bool _isSubmitting = false;
  String? _location;

  static const int _maxImages = 10;
  static const int _maxPollOptions = 4;
  static const int _minPollOptions = 2;
  static const int _maxContentLength = 500;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
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
    for (final c in _pollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────

  bool get _hasContent {
    final hasText = _textEditingController.text.trim().isNotEmpty;
    final hasImages = _imageFiles.isNotEmpty;
    final hasPoll = _showPollEditor &&
        _pollControllers.any((c) => c.text.trim().isNotEmpty);
    return hasText || hasImages || hasPoll;
  }

  bool get _canPost {
    if (_isSubmitting) return false;
    return _hasContent;
  }

  void _handleBack(BuildContext context) {
    if (!_hasContent) {
      _doBack();
      return;
    }
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _doBack();
            },
            child: Text(AppLocalizations.of(context)!.discard),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _saveCurrentDraft();
              if (mounted) _doBack();
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  void _doBack() {
    _textEditingController.clear();
    for (final c in _pollControllers) {
      c.clear();
    }
    setState(() {
      _imageFiles.clear();
      _showPollEditor = false;
      _replyType = 1;
      _location = null;
    });
    widget.onCancel?.call();
  }

  void _addImage(File file) {
    setState(() {
      // 添加图片时关闭投票（互斥）
      if (_showPollEditor) {
        _showPollEditor = false;
        for (final c in _pollControllers) {
          c.clear();
        }
      }
      if (_imageFiles.length < _maxImages) {
        _imageFiles.add(file);
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  void _togglePollEditor() {
    setState(() {
      _showPollEditor = !_showPollEditor;
      if (_showPollEditor) {
        // 开启投票时清空图片（互斥）
        _imageFiles.clear();
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (xFile != null) {
      _addImage(File(xFile.path));
    }
  }

  void _openCamera() async {
    final filePath = await Navigator.push<String>(
      context,
      CupertinoPageRoute(builder: (_) => const ComposeCameraPage()),
    );
    if (filePath != null) {
      _addImage(File(filePath));
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

  void _onDraftSelected(DraftInfo draft) {
    setState(() {
      _textEditingController.text = draft.content;
      if (draft.pollOptions != null && draft.pollOptions!.isNotEmpty) {
        _showPollEditor = true;
        _imageFiles.clear();
        _pollControllers = draft.pollOptions!
            .map((opt) => TextEditingController(text: opt))
            .toList();
        if (_pollControllers.length < _minPollOptions) {
          while (_pollControllers.length < _minPollOptions) {
            _pollControllers.add(TextEditingController());
          }
        }
      }
      if (draft.replyType != null) {
        _replyType = draft.replyType!;
      }
    });
  }

  Future<void> _saveCurrentDraft() async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final content = _textEditingController.text.trim();
    if (content.isEmpty && _imageFiles.isEmpty && !_showPollEditor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.nothingToSaveDraft),
          backgroundColor: appColors.surface,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final draftState = Provider.of<DraftState>(context, listen: false);
    final saved = await draftState.saveDraft(
      content: content,
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
          duration: Duration(seconds: 1),
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
      createdAt: DateTime.now().toUtc().toString(),
      key: myUser.userId?.toString(),
    );
  }

  Future<void> _submit() async {
    if (!_canPost) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    print('🚀 _submit 开始: text="${_textEditingController.text}" images=${_imageFiles.length} poll=$_showPollEditor replyType=$_replyType');

    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    var state = Provider.of<PostState>(context, listen: false);
    PostModel postModel = await _createPostModel();

    final pollOptions = _getValidPollOptions();

    print('🚀 _submit 参数: imageFiles=${_imageFiles.length} pollOptions=$pollOptions replyType=${_replyType != 1 ? _replyType : null}');

    final postId = await state.createPost(
      postModel,
      imageFiles: _imageFiles.isNotEmpty ? _imageFiles : null,
      pollOptions: pollOptions,
      replyType: _replyType != 1 ? _replyType : null,
      location: _location,
    );

    print('🚀 _submit 结果: postId=$postId');

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (postId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.publishSuccess),
          backgroundColor: appColors.repost,
          duration: Duration(seconds: 1),
        ),
      );
      _textEditingController.clear();
      for (final c in _pollControllers) {
        c.clear();
      }
      setState(() {
        _imageFiles.clear();
        _showPollEditor = false;
        _replyType = 1;
        _location = null;
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

  // ─── Reply Permission Sheet ──────────────────────────────

  void _showReplyTypeSheet() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surfaceTertiary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
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
              SizedBox(height: 8),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _handleBack(context),
                  child: Text(AppLocalizations.of(context)!.back,
                      style: TextStyle(color: appColors.textPrimary, fontSize: 16)),
                ),
                Expanded(
                  child: Center(
                    child: Text(AppLocalizations.of(context)!.newPost,
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(width: 48), // balance Cancel width
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
              padding: EdgeInsets.all(14),
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
                          SizedBox(height: 6),
                          Container(
                            width: 2,
                            height: 30,
                            color: appColors.dividerSecondary,
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
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
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  '$charCount / $_maxContentLength',
                                  style: TextStyle(
                                    color: charCount > 450 ? Colors.orange : appColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Image previews ──
                  if (_imageFiles.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: 52, top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < _imageFiles.length; i++)
                            _buildImagePreview(appColors, _imageFiles[i], i),
                          if (_imageFiles.length < _maxImages)
                            _buildAddImageTile(appColors),
                        ],
                      ),
                    ),

                  // ── Poll editor ──
                  if (_showPollEditor)
                    Padding(
                      padding: EdgeInsets.only(left: 52, top: 12),
                      child: _buildPollEditor(appColors),
                    ),

                  // ── Location chip ──
                  if (_location != null)
                    Padding(
                      padding: EdgeInsets.only(left: 52, top: 8),
                      child: GestureDetector(
                        onTap: _showLocationDialog,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.location, size: 14, color: appColors.textMuted),
                            SizedBox(width: 4),
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

  Widget _buildAvatar(AppColors appColors, String url, double size) {
    if (url.isEmpty) {
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

  Widget _buildImagePreview(AppColors appColors, File file, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
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

  Widget _buildAddImageTile(AppColors appColors) {
    return GestureDetector(
      onTap: _pickImage,
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _pollControllers.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: appColors.textMuted),
                    SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.addOption,
                        style: TextStyle(color: appColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          SizedBox(height: 8),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: appColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Camera button
            IconButton(
              onPressed: _showPollEditor ? null : _openCamera,
              icon: Icon(Iconsax.camera,
                  size: 22,
                  color: _showPollEditor ? appColors.divider : appColors.textPrimary),
            ),
            // Image button
            IconButton(
              onPressed: _showPollEditor ? null : _pickImage,
              icon: Icon(Iconsax.picture_frame,
                  size: 22,
                  color: _showPollEditor ? appColors.divider : appColors.textPrimary),
            ),
            // Poll button
            IconButton(
              onPressed: _imageFiles.isNotEmpty ? null : _togglePollEditor,
              icon: Icon(Iconsax.chart_square,
                  size: 22,
                  color: _imageFiles.isNotEmpty ? appColors.divider
                      : (_showPollEditor ? appColors.accent : appColors.textPrimary)),
            ),
            // Reply type button
            IconButton(
              onPressed: _showReplyTypeSheet,
              icon: Icon(_replyTypeIcon, size: 22, color: appColors.textMuted),
            ),
            // Drafts button
            IconButton(
              onPressed: _showDraftListSheet,
              icon: Icon(Iconsax.note_text, size: 22, color: appColors.textMuted),
            ),
            // Location button
            IconButton(
              onPressed: _showLocationDialog,
              icon: Icon(Iconsax.location,
                  size: 22,
                  color: _location != null ? appColors.accent : appColors.textMuted),
            ),
            Spacer(),
            // Save draft text button
            if (_hasContent)
              GestureDetector(
                onTap: _saveCurrentDraft,
                child: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text(
                    AppLocalizations.of(context)!.draft,
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            // Post button
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
                      AppLocalizations.of(context)!.post,
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
}
