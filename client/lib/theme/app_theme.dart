import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(AppColors.light, Brightness.light);
  static ThemeData get darkTheme => _buildTheme(AppColors.dark, Brightness.dark);

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      dividerColor: colors.divider,
      tabBarTheme: TabBarThemeData(
        labelColor: colors.textPrimary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.textPrimary,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColorsExtension(colors),
      ],
    );
  }
}
