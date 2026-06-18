import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 「投票卡片」Widget：
/// - 投票中：可点击的选项列表（带防抖 + spinner）
/// - 已投 / 已过期：带百分比进度条的结果态
class PollWidget extends StatefulWidget {
  final String postId;
  final PollData pollData;
  final EdgeInsetsGeometry padding;

  /// 结果态（已投 / 已过期）的卡片 tap 回调，由父组件传入以跳详情。
  /// 投票态时此回调不触发，选项 tap 由内部 `_handleVote` 接管。
  final VoidCallback? onCardTap;

  const PollWidget({
    super.key,
    required this.postId,
    required this.pollData,
    this.onCardTap,
    this.padding = const EdgeInsets.only(left: 55, right: 10, top: 8),
  });

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  /// 投票进行中标记：用于防抖（拒绝二次点击）和 spinner 展示
  bool _isVoting = false;

  /// 倒计时定时器：每 30s 触发一次 rebuild，更新「剩余 N 分钟」
  Timer? _countdownTimer;

  PollData get _pollData => widget.pollData;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ──────────────────── 倒计时文案 ────────────────────

  String _formatRemainingTime(AppLocalizations l10n) {
    final expireTime = _pollData.expireTime;
    if (expireTime == null) return '';
    final remaining = expireTime.difference(DateTime.now());
    if (remaining.isNegative) return l10n.pollEnded;
    final hours = remaining.inHours;
    if (hours > 0) return l10n.pollRemainingHours(hours);
    final minutes = remaining.inMinutes;
    return l10n.pollRemainingMinutes(minutes);
  }

  // ──────────────────── 投票交互（防抖 + 失败 SnackBar） ────────────────────

  Future<void> _handleVote(int optionId) async {
    if (_isVoting) return; // 第一道闸：拒绝并发投票
    setState(() => _isVoting = true);

    final postState = Provider.of<PostState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final success = await postState.voteOnPoll(widget.postId, optionId);

    if (!mounted) return;
    setState(() => _isVoting = false);

    if (!success) {
      // voteOnPoll 返回 false 表示投票失败，但接口未把具体原因抛回；
      // 调试阶段在控制台打印一条日志，UI 上保留通用提示。
      debugPrint('[PollWidget] voteOnPoll 返回 false，postId=${widget.postId} optionId=$optionId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.voteFailed} (voteOnPoll=false，无具体错误)'),
          backgroundColor: appColors.destructive,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ──────────────────── 百分比计算（最大余数法，保证累加 = 100%） ────────────────────

  List<int> _computePercentages(List<PollOption> options, int totalVotes) {
    if (totalVotes <= 0 || options.isEmpty) {
      return List.filled(options.length, 0);
    }
    final raw = options.map((o) => o.votesCount * 100.0 / totalVotes).toList();
    final floored = raw.map((v) => v.floor()).toList();
    final remainder = raw.asMap().entries
        .map((e) => MapEntry(e.key, e.value - floored[e.key]))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var deficit = 100 - floored.reduce((a, b) => a + b);
    for (var i = 0; i < remainder.length && deficit > 0; i++, deficit--) {
      floored[remainder[i].key] += 1;
    }
    return floored;
  }

  // ──────────────────── Build ────────────────────

  @override
  Widget build(BuildContext context) {
    // 客户端兜底：服务端 isExpired 字段可能因时钟偏差 / 缓存延迟不准确
    final isExpiredLocally = _pollData.expireTime != null &&
        _pollData.expireTime!.isBefore(DateTime.now());
    // 统一标记"投票已结束"，驱动 banner / opacity / footer 抑制
    final isEnded = _pollData.isExpired || isExpiredLocally;
    final showResults = _pollData.hasVoted || isEnded;

    // 在 build 顶部算一次百分比，避免每个选项重复计算
    final percentages =
        _computePercentages(_pollData.options, _pollData.totalVotes);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已结束状态：顶部 banner 明确告知用户"投票已截止"
          if (isEnded) _buildEndedBanner(context),
          ..._pollData.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            if (showResults) {
              return _buildResultOption(
                context: context,
                option: option,
                percentage: percentages[index],
                isEnded: isEnded,
              );
            } else {
              return _BuildVotingOption(
                key: ValueKey('vote_option_${option.id}'),
                option: option,
                isVoting: _isVoting,
                onTap: () => _handleVote(option.id),
              );
            }
          }),
          const SizedBox(height: 6),
          _buildFooter(context, showResults, isEnded: isEnded),
        ],
      ),
    );
  }

  // ──────────────────── 结果态（百分比进度条 + 无障碍 Semantics） ────────────────────

  Widget _buildResultOption({
    required BuildContext context,
    required PollOption option,
    required int percentage,
    required bool isEnded,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final isVoted = _pollData.userVotedOptionId == option.id;

    // ─── 样式 token ───
    // isEnded=true 时失去"已投"的强调（border 加粗 + 字体 w600），
    // 整体通过外层 Opacity 进一步压暗；保留 check/circle 图标形状
    // 是为了仍能区分"我投了哪个"，只是不作为视觉焦点。
    final Color borderColor = (isVoted && !isEnded)
        ? appColors.textPrimary
        : (isEnded ? appColors.divider : appColors.border);
    final double borderWidth = (isVoted && !isEnded) ? 1.5 : 1.0;
    final FontWeight textWeight =
        (isVoted && !isEnded) ? FontWeight.w600 : FontWeight.normal;

    // 无障碍：让 VoiceOver / TalkBack 朗读「选项 X, 60%, 你已投票, 投票已结束」
    final semanticsLabel = [
      option.optionText,
      if (isVoted) l10n.pollYouVoted,
      '$percentage%',
      if (isEnded) l10n.pollEnded,
    ].join(', ');

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 底色
              Container(
                width: double.infinity,
                height: 40,
                color: appColors.surface,
              ),
              // 进度条
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 40,
                  color: appColors.surfaceSecondary,
                ),
              ),
              // 文字 + 图标 + 百分比
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      isVoted ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isVoted
                          ? appColors.textPrimary
                          : appColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(
                          color: appColors.textPrimary,
                          fontSize: 14,
                          fontWeight: textWeight,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: appColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 已结束：外层 Opacity 整体压暗到 0.6（不影响 hit test，仍可点跳详情）
    final Widget contentInner =
        isEnded ? Opacity(opacity: 0.6, child: content) : content;

    // 结果态外包 GestureDetector：让用户可点跳详情（投票态不受影响）
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: widget.onCardTap == null
          ? contentInner
          : GestureDetector(
              onTap: widget.onCardTap,
              behavior: HitTestBehavior.opaque,
              child: contentInner,
            ),
    );
  }

  // ──────────────────── 底部文案（票数 + 你已投票 + 倒计时） ────────────────────

  Widget _buildFooter(
    BuildContext context,
    bool showResults, {
    required bool isEnded,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[l10n.pollVotesCount(_pollData.totalVotes)];
    if (showResults && _pollData.hasVoted) {
      parts.add(l10n.pollYouVoted);
    }
    // 已结束时不重复"投票已结束"——顶部 banner 已明确告知
    if (!isEnded && _pollData.expireTime != null) {
      parts.add(_formatRemainingTime(l10n));
    }
    final text = Text(
      parts.join(' · '),
      style: TextStyle(color: appColors.textMuted, fontSize: 12),
    );
    // 结果态 + 父级提供 onCardTap 时，footer 区域也可点跳详情
    if (showResults && widget.onCardTap != null) {
      return GestureDetector(
        onTap: widget.onCardTap,
        behavior: HitTestBehavior.opaque,
        child: text,
      );
    }
    return text;
  }

  // ──────────────────── "已结束" 状态 Banner ────────────────────
  //
  // 仅在 isEnded=true 时渲染。沿用项目惯例
  // （scheduled_posts_page.dart:80-99）：
  //   Icon(size:14, color:textMuted) + SizedBox(6) + Text(textMuted, size:12)
  // 选 CupertinoIcons.clock 而非 Icons.lock*（后者专用于隐私/密码场景）。
  Widget _buildEndedBanner(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(CupertinoIcons.clock, size: 14, color: appColors.textMuted),
          const SizedBox(width: 6),
          Text(
            l10n.pollEnded,
            style: TextStyle(
              color: appColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个投票选项（投票中状态）：
/// - 接收父级传入的 `isVoting` 标记 → 整行变灰 + 替换左侧图标为 spinner
/// - `onTap: null` → 第二道闸，物理上拒绝 tap 事件
class _BuildVotingOption extends StatefulWidget {
  final PollOption option;
  final bool isVoting;
  final VoidCallback onTap;

  const _BuildVotingOption({
    super.key,
    required this.option,
    required this.isVoting,
    required this.onTap,
  });

  @override
  State<_BuildVotingOption> createState() => _BuildVotingOptionState();
}

class _BuildVotingOptionState extends State<_BuildVotingOption> {
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final disabled = widget.isVoting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        // 用 Material + InkWell 取代 GestureDetector：标准 Flutter 卡片点击模式，
        // 提供稳定 hit test + 水波纹视觉反馈，比裸 GestureDetector 更可靠。
        child: Material(
          color: appColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: disabled ? null : widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: appColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  disabled
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.circle_outlined,
                          size: 16, color: appColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.option.optionText,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
