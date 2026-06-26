import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/theme/app_colors.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/services/auth_service.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/widget/circle_avatar.dart';
import 'package:threads/widget/mention_overlay.dart';

class ReplyBottomSheet extends StatefulWidget {
  final String postId;
  /// 嵌套回复时传入被回复的那条一级 reply。
  /// - 为 null（默认）:当前行为不变，提交一级回复到帖子，弹层继续显示回复列表。
  /// - 非 null:弹层顶部显示「回复 @xxx」预览卡，输入框 hint 切换为「回复 @xxx...」，
  ///   提交时携带 parentId,成功提交后直接关闭弹层（子回复在 PostDetailPage 内联展示）。
  final Reply? parentReply;

  const ReplyBottomSheet({
    required this.postId,
    this.parentReply,
    super.key,
  });

  @override
  State<ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<ReplyBottomSheet> {
  List<Reply> _replies = [];
  bool _isLoading = true;
  bool _isPosting = false;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ─── @mention 用户选择面板 ───
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<UserInfo> _filteredUsers = const [];
  // 当前 @token（含 @）在文本中的起始 offset，-1 表示无激活 token
  int _mentionTokenStart = -1;
  // 防抖 Timer：用户连续输入时只发最后一次请求
  Timer? _mentionDebounce;
  // 已选中的 mention 用户：username → userId。
  // 选中补全面板里的用户时写入；正文编辑时按 username 是否仍出现在文本里
  // 自动同步过滤。提交回复时把 values 作为 mentionedUserIds 传给服务端。
  final Map<String, int> _mentionUserIds = {};

  @override
  void initState() {
    super.initState();
    _replyController.addListener(_onTextChanged);
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.removeListener(_onTextChanged);
    _mentionDebounce?.cancel();
    _hideOverlay();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── @mention 用户选择面板 ────────────────────────────────

  /// 文本变化监听：检测 @mention 并刷新浮层。
  void _onTextChanged() {
    // 同步 mention userId 集合：正文里不再出现的 username 自动移除。
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
  void _syncMentionUserIds() {
    if (_mentionUserIds.isEmpty) return;
    final text = _replyController.text;
    final toRemove = <String>[];
    _mentionUserIds.forEach((username, _) {
      final atUsername = '@$username';
      final idx = text.indexOf(atUsername);
      if (idx < 0) {
        toRemove.add(username);
        return;
      }
      // 排除邮箱：@ 前若是 word 字符则不算 mention。
      if (idx > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[idx - 1])) {
        toRemove.add(username);
        return;
      }
      // 右边界：@username 后若仍是用户名字符，则它只是更长 username 的前缀。
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
  /// 返回 (start, query)：start 是含 @ 的起始 offset，query 是不含 @ 的查询串。
  /// 只输了一个 @（query 为空）时返回 null —— 不弹面板。
  ({int start, String query})? _detectMentionToken() {
    final text = _replyController.text;
    final selection = _replyController.selection;
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
  /// 光标移到空格之后，关闭面板；同时记录 username → userId。
  void _onUserSelected(UserInfo user) {
    if (_mentionTokenStart < 0) {
      _hideOverlay();
      return;
    }
    final text = _replyController.text;
    final cursor = _replyController.selection.baseOffset;
    final replacement = '@${user.username} ';
    final newText = text.replaceRange(_mentionTokenStart, cursor, replacement);
    _replyController.text = newText;
    final newCursor = _mentionTokenStart + replacement.length;
    _replyController.selection = TextSelection.collapsed(offset: newCursor);
    _mentionTokenStart = -1;
    if (user.username.isNotEmpty && user.userId > 0) {
      _mentionUserIds[user.username] = user.userId;
    }
    _hideOverlay();
  }

  Future<void> _loadReplies() async {
    try {
      final postService =
          Provider.of<PostState>(context, listen: false).postService;
      final replies = await postService.getReplies(widget.postId);
      if (mounted) {
        setState(() {
          _replies = replies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    // 先同步一次 mention 集合（用户可能直接点发送而未触发最后一次文本变化），
    // 再把被提及用户的 userId 列表随回复一起提交（服务端字段 mentioned_user_ids）。
    _syncMentionUserIds();
    final mentionedUserIds = _mentionUserIds.values.toList();

    setState(() {
      _isPosting = true;
    });

    final postState = Provider.of<PostState>(context, listen: false);

    // ===== 嵌套回复（对回复进行回复）路径 =====
    if (widget.parentReply != null) {
      try {
        print('🔵 _postReply(nested) 开始: postId=${widget.postId}, parentReplyId=${widget.parentReply!.id}');
        await postState.createChildReply(
          postId: widget.postId,
          parentReply: widget.parentReply!,
          content: content,
          mentionedUserIds: mentionedUserIds,
        );
        print('🔵 _postReply(nested) 成功');
        if (mounted) {
          // 嵌套回复后直接关闭弹层,子回复在 PostDetailPage 内的子列表中展示。
          // pop(true) 通知调用方同步父级 repliesCount。
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        print('🔵 _postReply(nested) 失败: $e');
        if (mounted) {
          setState(() {
            _isPosting = false;
          });
          NetworkErrorNotifier.showApiError(e);
        }
      }
      return;
    }

    // ===== 一级回复（原始路径） =====
    try {
      print('🔵 _postReply 开始: postId=${widget.postId}, content=$content');
      final newReply = await postState.postService.createReply(
        postId: widget.postId,
        content: content,
        mentionedUserIds: mentionedUserIds,
      );
      print('🔵 _postReply 成功: replyId=${newReply.id}');
      if (mounted) {
        postState.incrementReplyCount(widget.postId);
        setState(() {
          _replies.insert(0, newReply);
          _replyController.clear();
          _isPosting = false;
        });
      }
    } catch (e) {
      print('🔵 _postReply 失败: $e');
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
        NetworkErrorNotifier.showApiError(e);
      }
    }
  }

  Future<void> _toggleLike(Reply reply, int index) async {
    final postService =
        Provider.of<PostState>(context, listen: false).postService;

    // Optimistic update
    setState(() {
      _replies[index] = Reply(
        id: reply.id,
        postId: reply.postId,
        userId: reply.userId,
        username: reply.username,
        displayName: reply.displayName,
        profilePic: reply.profilePic,
        content: reply.content,
        imageUrl: reply.imageUrl,
        createdAt: reply.createdAt,
        likesCount: reply.isLiked ? reply.likesCount - 1 : reply.likesCount + 1,
        isLiked: !reply.isLiked,
        isPinned: reply.isPinned,
        isHidden: reply.isHidden,
      );
    });

    try {
      if (reply.isLiked) {
        await postService.unlikeReply(reply.id);
      } else {
        await postService.likeReply(reply.id);
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _replies[index] = reply;
        });
      }
    }
  }

  void _showReplyOptions(Reply reply, int index) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final authState = Provider.of<AuthState>(context, listen: false);
    final myUserId = authState.userId;
    final isAuthor =
        myUserId.isNotEmpty && myUserId == reply.userId.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: appColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                reply.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                color: appColors.textPrimary,
                size: 22,
              ),
              title: Text(
                reply.isPinned ? AppLocalizations.of(context)!.unpinReply : AppLocalizations.of(context)!.pinReply,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePinReply(reply, index);
              },
            ),
            if (isAuthor)
              ListTile(
                leading: Icon(
                  CupertinoIcons.delete,
                  color: appColors.like,
                  size: 22,
                ),
                title: Text(
                  l10n.deleteReply,
                  style: TextStyle(
                    color: appColors.like,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteReply(reply, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 删除前二次确认。
  Future<void> _confirmDeleteReply(Reply reply, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteReply),
        content: Text(l10n.deleteReplyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.deleteReply,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteReply(reply, index);
    }
  }

  /// 调用接口删除回复，乐观更新本地列表，失败回滚并提示。
  Future<void> _deleteReply(Reply reply, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final postState = Provider.of<PostState>(context, listen: false);

    // 备份当前位置，便于失败回滚（其它项可能因排序变化，按 id 移除更稳）。
    final backup = reply;
    final backupIndex = index;
    setState(() {
      _replies.removeWhere((r) => r.id == reply.id);
    });

    try {
      await postState.postService.deleteReply(reply.id);
      if (!mounted) return;
      postState.decrementReplyCount(widget.postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.replyDeleted),
          backgroundColor: appColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Rollback：把删掉的项放回原位置（越界时追加到末尾）。
      setState(() {
        final insertAt =
            backupIndex.clamp(0, _replies.length);
        _replies.insert(insertAt, backup);
      });
      NetworkErrorNotifier.showApiError(e);
    }
  }

  Future<void> _togglePinReply(Reply reply, int index) async {
    final postState = Provider.of<PostState>(context, listen: false);

    // Optimistic update
    setState(() {
      _replies[index] = Reply(
        id: reply.id,
        postId: reply.postId,
        userId: reply.userId,
        username: reply.username,
        displayName: reply.displayName,
        profilePic: reply.profilePic,
        content: reply.content,
        imageUrl: reply.imageUrl,
        createdAt: reply.createdAt,
        likesCount: reply.likesCount,
        isLiked: reply.isLiked,
        isPinned: !reply.isPinned,
        isHidden: reply.isHidden,
      );
    });

    try {
      final replyId = int.tryParse(reply.id) ?? 0;
      if (reply.isPinned) {
        await postState.unpinReply(replyId);
      } else {
        await postState.pinReply(replyId);
      }
      if (mounted) {
        _sortReplies();
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _replies[index] = reply;
        });
        NetworkErrorNotifier.showApiError(e);
      }
    }
  }

  /// Sort replies so pinned ones appear at the top.
  void _sortReplies() {
    setState(() {
      _replies.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    });
  }

  /// 嵌套回复场景下的「回复 @xxx」预览卡片。
  /// 显示在拖动条与 Title 之间,样式偏次要(灰底,无边框)。
  Widget _buildParentPreview() {
    final parent = widget.parentReply!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final name = parent.displayName.isNotEmpty ? parent.displayName : parent.username;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: appColors.surface,
      child: Row(
        children: [
          Icon(Iconsax.message, size: 16, color: appColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.replyToUser(name),
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Reply reply, int index) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final authState = Provider.of<AuthState>(context, listen: false);
    final myUserId = authState.userId;
    final isAuthor =
        myUserId.isNotEmpty && myUserId == reply.userId.toString();
    return GestureDetector(
      onLongPress: () => _showReplyOptions(reply, index),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCircleAvatar(avatarUrl: reply.profilePic ?? '', size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.displayName,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        Utility.getdob(reply.createdAt.toIso8601String(), context: context),
                        style: TextStyle(
                          color: appColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                      if (reply.isPinned) ...[
                        SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.pin,
                          size: 12,
                          color: appColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    reply.content,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _toggleLike(reply, index),
                    child: Row(
                      children: [
                        Icon(
                          reply.isLiked ? Iconsax.heart5 : Iconsax.heart,
                          size: 14,
                          color: reply.isLiked ? appColors.like : appColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${reply.likesCount}',
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isAuthor)
              PopupMenuButton<String>(
                tooltip: AppLocalizations.of(context)!.deleteReply,
                icon: Icon(Icons.more_horiz,
                    color: appColors.textMuted, size: 20),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                color: appColors.surface,
                position: PopupMenuPosition.under,
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDeleteReply(reply, index);
                  }
                },
                itemBuilder: (menuContext) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.delete,
                            color: appColors.like, size: 18),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(menuContext)!.deleteReply,
                          style: TextStyle(
                            color: appColors.like,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final isNested = widget.parentReply != null;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Top drag handle
          Container(
            margin: EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              l10n.replies,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // 嵌套回复时,在 Title 与 Divider 之间插入「回复 @xxx」预览卡
          if (isNested) _buildParentPreview(),
          Divider(
            color: appColors.divider,
            height: 0.5,
          ),
          // Reply list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appColors.textSecondary,
                    ),
                  )
                : _replies.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noRepliesYet,
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: _replies.length,
                        separatorBuilder: (context, index) => Divider(
                          color: appColors.divider,
                          height: 0.5,
                          indent: 56,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) =>
                            _buildReplyItem(_replies[index], index),
                      ),
          ),
          Divider(
            color: appColors.divider,
            height: 0.5,
          ),
          // Bottom input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            color: appColors.background,
            child: Row(
              children: [
                Expanded(
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _replyController,
                      style: TextStyle(
                          color: appColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isNested
                            ? l10n.writeAReplyTo(
                                widget.parentReply!.displayName.isNotEmpty
                                    ? widget.parentReply!.displayName
                                    : widget.parentReply!.username)
                            : l10n.writeAReply,
                        hintStyle: TextStyle(color: appColors.textSecondary),
                        filled: true,
                        fillColor: appColors.surface,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postReply(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _isPosting
                      ? Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: appColors.textPrimary,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _postReply,
                          icon: Icon(Iconsax.send_2, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: appColors.textPrimary,
                            foregroundColor: appColors.background,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
