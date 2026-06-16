import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/theme/app_colors.dart';

/// 带头像关注加号的可复用组件。
///
/// 设计目标：在 Feed / 搜索结果 / 关注列表 / 用户卡片等任意模块中复用同一组件，
/// 统一关注加号的展示和交互行为。**自身不持有业务状态**——`isFollowing` 由调用方
/// 传入（典型来源：PostModel.isFollowing / UserModel.isFollowing），`onFollow`
/// 由调用方注入（典型实现：调 PostState.followPostAuthor 乐观更新）。
///
/// 显示判定（仅当全部满足时显示加号）：
///   1. `userId` 非空
///   2. `currentUserId` 非空
///   3. `userId != currentUserId`（不是自己）
///   4. `isFollowing != true`（null/false 都视为未关注）
///
/// 视觉规范：Instagram / TikTok 风格 —— 圆形蓝色背景（`AppColors.accent`），
/// 白色 `+` 图标，外圈 1.5px 描边色 = `AppColors.surface`（在不同背景色下
/// 都能保持清晰边界）。
class UserAvatarWithFollow extends StatefulWidget {
  const UserAvatarWithFollow({
    super.key,
    required this.avatarUrl,
    this.size = 35,
    this.userId,
    this.currentUserId,
    this.isFollowing,
    this.onAvatarTap,
    this.onFollow,
    this.userName,
  });

  /// 头像图片 URL。空串走 `Icons.person` 占位。
  final String avatarUrl;

  /// 头像直径（正方形）。默认 35。
  final double size;

  /// 作者 userId。`null` 时不显示加号（视为「未知用户」）。
  final int? userId;

  /// 当前登录 userId。等于 `userId` 时不显示加号（自己）。
  final int? currentUserId;

  /// 关注状态。
  /// - `true` → 不显示加号
  /// - `false` / `null` → 显示加号（UI 视 null 为「未关注」）
  final bool? isFollowing;

  /// 点击头像回调。`null` 时头像不可点击。
  final VoidCallback? onAvatarTap;

  /// 点击加号回调。组件会 `await` 此回调；抛错时加号自动消失逻辑由调用方负责
  /// （典型实现：调用方在 PostState.followPostAuthor 失败时回滚 isFollowing）。
  final Future<void> Function()? onFollow;

  /// 用户显示名 / username，用于无障碍朗读。
  final String? userName;

  @override
  State<UserAvatarWithFollow> createState() => _UserAvatarWithFollowState();
}

class _UserAvatarWithFollowState extends State<UserAvatarWithFollow> {
  /// 防止用户在网络请求未返回时重复点击。
  bool _isLoading = false;

  /// 三道闸门 + isFollowing 判定（私有）。
  bool get _shouldShowFollow =>
      widget.userId != null &&
      widget.currentUserId != null &&
      widget.userId != widget.currentUserId &&
      widget.isFollowing != true;

  Future<void> _handleFollowTap() async {
    if (_isLoading) return;
    final callback = widget.onFollow;
    if (callback == null) return;
    setState(() => _isLoading = true);
    try {
      await callback();
    } catch (_) {
      // 加号是否消失由调用方控制（典型实现是 PostState 自动回滚 isFollowing，
      // 本组件接收新值后 build 期自然消失）。此处不展示错误 toast —— 错误
      // 处理统一在 PostState 内部或更上层的 UI 接管。
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final showFollow = _shouldShowFollow;

    // 加号圆的尺寸与描边
    final badgeSize = widget.size * 0.36;
    final badgeIconSize = widget.size * 0.36 * 0.55; // ≈ size * 0.2
    final badgeStrokeWidth = 1.5;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 底层：头像（与 FeedPostWidget 内 avatar() 闭包风格一致）
        GestureDetector(
          onTap: widget.onAvatarTap,
          behavior: HitTestBehavior.opaque,
          child: widget.avatarUrl.isEmpty
              ? Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person,
                    size: widget.size * 0.6,
                    color: appColors.textSecondary,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: CachedNetworkImage(
                    imageUrl: widget.avatarUrl,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
        // 顶层：加号徽标（仅在 shouldShow 时渲染）
        if (showFollow)
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: l10n.followUser(widget.userName ?? ''),
              child: GestureDetector(
                onTap: _handleFollowTap,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _isLoading ? 0.6 : 1.0,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: appColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: appColors.surface,
                        width: badgeStrokeWidth,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: badgeIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
