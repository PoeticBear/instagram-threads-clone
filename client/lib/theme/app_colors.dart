import 'package:flutter/material.dart';

/// Semantic color tokens for the app.
/// Provides [light] and [dark] instances that map to concrete color values.
class AppColors {
  // --- Surfaces ---
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color surfaceTertiary;

  // --- Dividers & Borders ---
  final Color divider;
  final Color dividerSecondary;
  final Color border;

  // --- Text ---
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textHint;

  // --- Semantic ---
  final Color accent;
  final Color like;
  final Color repost;
  final Color destructive;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.divider,
    required this.dividerSecondary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textHint,
    required this.accent,
    required this.like,
    required this.repost,
    required this.destructive,
  });

  // Current dark mode palette (matches the existing hardcoded values)
  static const dark = AppColors(
    background: Colors.black,
    surface: Color(0xff1a1a1a),
    surfaceSecondary: Color(0xff222222),
    surfaceTertiary: Color(0xff292929),
    divider: Color(0xff2e2e2e),
    dividerSecondary: Color(0xff444444),
    border: Color(0xff333333),
    textPrimary: Colors.white,
    textSecondary: Colors.grey,
    textMuted: Color(0xff888888),
    textHint: Color(0xff707070),
    accent: Colors.blue,
    like: Colors.red,
    repost: Colors.green,
    destructive: Colors.red,
  );

  // Light mode palette (inspired by Instagram Threads official light mode)
  static const light = AppColors(
    background: Colors.white,
    surface: Color(0xffefefef),
    surfaceSecondary: Color(0xfff5f5f5),
    surfaceTertiary: Color(0xfff8f8f8),
    divider: Color(0xffefefef),
    dividerSecondary: Color(0xffd8d8d8),
    border: Color(0xffd0d0d0),
    textPrimary: Colors.black,
    textSecondary: Color(0xff666666),
    textMuted: Color(0xff999999),
    textHint: Color(0xffa0a0a0),
    accent: Color(0xff0064e0),
    like: Colors.red,
    repost: Colors.green,
    destructive: Colors.red,
  );
}

/// ThemeExtension wrapper so [AppColors] can be accessed via
/// `Theme.of(context).extension<AppColorsExtension>()!.colors`.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColors colors;
  const AppColorsExtension(this.colors);

  @override
  AppColorsExtension copyWith([AppColors? colors]) =>
      AppColorsExtension(colors ?? this.colors);

  @override
  AppColorsExtension lerp(AppColorsExtension other, double t) =>
      AppColorsExtension(t < 0.5 ? colors : other.colors);
}
