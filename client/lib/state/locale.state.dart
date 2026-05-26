import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _locale = const Locale('zh');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = GetIt.I<SharedPreferences>();
    final code = prefs.getString(_localeKey);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = GetIt.I<SharedPreferences>();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  void switchToEnglish() => setLocale(const Locale('en'));
  void switchToChinese() => setLocale(const Locale('zh'));
}