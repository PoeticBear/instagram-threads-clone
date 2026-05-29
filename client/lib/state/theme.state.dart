import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = GetIt.I<SharedPreferences>();
    final saved = prefs.getString(_themeKey);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.dark,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = GetIt.I<SharedPreferences>();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  void switchToDark() => setThemeMode(ThemeMode.dark);
  void switchToLight() => setThemeMode(ThemeMode.light);
  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
