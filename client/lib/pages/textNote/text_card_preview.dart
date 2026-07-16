import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 写文字 — 卡片渲染组件 + 渐变预设常量
// ─────────────────────────────────────────────────────────────────────────────
//
// 本文件包含：
// 1. TextCardStyle 枚举 + 4 套渐变预设常量 kCardGradients
// 2. 字号自适应常量（按字数动态调整字号 / 行高）
// 3. TextCardPreview（实时预览卡片，3:4 比例，支持 \n 换行）
// 4. TextCardStylePicker（横向滚动 4 张缩略图，点击切换）
//
// 设计文档：openspec/changes/add-text-note-feature/design.md
// Spec：openspec/changes/add-text-note-feature/specs/text-note/spec.md
// ─────────────────────────────────────────────────────────────────────────────

/// 4 套预设渐变卡片样式。
///
/// 用户在写文字页面可在 4 套预设之间切换。顺序与样式选择器显示顺序一致。
enum TextCardStyle {
  warmOrange, // 暖橙
  purpleBlue, // 紫蓝
  mint, // 薄荷
  darkNight, // 暗夜
}

/// 默认选中的样式。设计决策：暖橙在视觉上最显眼，作为首选项。
const TextCardStyle kDefaultCardStyle = TextCardStyle.warmOrange;

/// 4 套渐变预设（颜色 + 渐变方向）。
///
/// 渐变方向统一为「左上 → 右下」，保证 4 套样式视觉一致。
/// 颜色取自 design.md 的「决策 4」。
final Map<TextCardStyle, List<Color>> kCardGradients = {
  TextCardStyle.warmOrange: const [
    Color(0xFFFF9966),
    Color(0xFFFF5E62),
  ],
  TextCardStyle.purpleBlue: const [
    Color(0xFF8E2DE2),
    Color(0xFF4A00E0),
  ],
  TextCardStyle.mint: const [
    Color(0xFF11998E),
    Color(0xFF38EF7D),
  ],
  TextCardStyle.darkNight: const [
    Color(0xFF232526),
    Color(0xFF414345),
  ],
};

/// 卡片最大可展示字数（超过后截断 + 省略号）。
///
/// 设计决策 3：≤40 字 24sp / 41~80 字 18sp / >80 字 16sp + 截断。
const int kCardMaxChars = 80;

/// 用户输入框最大字数（避免极端输入导致渲染 / 截图卡顿）。
///
/// 与现有 ComposePost 的 _maxContentLength = 500 保持一致。
const int kInputMaxChars = 500;

/// 字号自适应阈值。
const int kFontSizeLargeThreshold = 40; // ≤ 此值用大字号
const int kFontSizeMediumThreshold = 80; // ≤ 此值用中字号，否则用小字号

/// 字号自适应常量。
const double kFontSizeLarge = 24.0;
const double kFontSizeMedium = 18.0;
const double kFontSizeSmall = 16.0;

/// 行高常量（与字号配套，1.3 / 1.35 / 1.4 保证卡片视觉协调）。
const double kLineHeightLarge = 1.4;
const double kLineHeightMedium = 1.35;
const double kLineHeightSmall = 1.3;

/// 卡片预览默认值（_textCardPreview 在空内容时显示）。
const String kCardEmptyHint = '·';

/// 截断后追加的省略号（中文视觉友好，不用 ...）。
const String kCardTruncatedSuffix = '…';

/// 根据字数选择字号。
double fontSizeFor(int charCount) {
  if (charCount <= kFontSizeLargeThreshold) {
    return kFontSizeLarge;
  }
  if (charCount <= kFontSizeMediumThreshold) {
    return kFontSizeMedium;
  }
  return kFontSizeSmall;
}

/// 根据字数选择行高。
double lineHeightFor(int charCount) {
  if (charCount <= kFontSizeLargeThreshold) {
    return kLineHeightLarge;
  }
  if (charCount <= kFontSizeMediumThreshold) {
    return kLineHeightMedium;
  }
  return kLineHeightSmall;
}

/// 卡片文案：超过 kCardMaxChars 时截断 + 追加省略号。
String truncateForCard(String text) {
  if (text.length <= kCardMaxChars) return text;
  return '${text.substring(0, kCardMaxChars)}$kCardTruncatedSuffix';
}

// ═════════════════════════════════════════════════════════════════════════════
// TextCardPreview
// ═════════════════════════════════════════════════════════════════════════════
//
// 3:4 比例的渐变卡片，居中显示文字。
// 用法：
// ```dart
// TextCardPreview(text: '...', style: TextCardStyle.warmOrange, width: 280)
// ```
// ═════════════════════════════════════════════════════════════════════════════

class TextCardPreview extends StatelessWidget {
  const TextCardPreview({
    Key? key,
    required this.text,
    required this.style,
    required this.width,
  }) : super(key: key);

  /// 用户当前输入的文字内容。
  final String text;

  /// 当前选中的卡片样式（决定渐变色）。
  final TextCardStyle style;

  /// 卡片宽度。高度自动按 3:4 计算。
  final double width;

  double get _height => width * 4 / 3;

  bool get _isEmpty => text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final gradient = kCardGradients[style]!;
    final displayText = _isEmpty
        ? kCardEmptyHint
        : truncateForCard(text);
    final charCount = text.trim().length;
    final fontSize = fontSizeFor(charCount);
    final lineHeight = lineHeightFor(charCount);

    return Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              // 微阴影：保证在 darkNight 渐变上也有足够对比度
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            maxLines: _maxLinesFor(charCount),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 不同字号对应的最大行数（防止溢出卡片垂直空间）。
  int _maxLinesFor(int charCount) {
    if (charCount <= kFontSizeLargeThreshold) return 6;
    if (charCount <= kFontSizeMediumThreshold) return 9;
    return 12;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TextCardStylePicker
// ═════════════════════════════════════════════════════════════════════════════
//
// 横向滚动的样式选择器，4 张缩略图（64×64）。
// 选中态：2px 边框高亮 + 缩放 1.05。
// ═════════════════════════════════════════════════════════════════════════════

class TextCardStylePicker extends StatelessWidget {
  const TextCardStylePicker({
    Key? key,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  final TextCardStyle selected;
  final ValueChanged<TextCardStyle> onSelected;

  static const double _thumbSize = 64;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;

    return SizedBox(
      height: _thumbSize + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: TextCardStyle.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final style = TextCardStyle.values[index];
          final isSelected = style == selected;
          return _StyleThumb(
            style: style,
            isSelected: isSelected,
            borderColor: appColors.textPrimary,
            onTap: () => onSelected(style),
          );
        },
      ),
    );
  }
}

class _StyleThumb extends StatelessWidget {
  const _StyleThumb({
    required this.style,
    required this.isSelected,
    required this.borderColor,
    required this.onTap,
  });

  final TextCardStyle style;
  final bool isSelected;
  final Color borderColor;
  final VoidCallback onTap;

  static const double _size = TextCardStylePicker._thumbSize;

  @override
  Widget build(BuildContext context) {
    final gradient = kCardGradients[style]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: borderColor, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
        ),
      ),
    );
  }
}