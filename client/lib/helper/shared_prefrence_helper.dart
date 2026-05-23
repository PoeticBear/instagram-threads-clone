import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user.module.dart';

class SharedPreferenceHelper {
  SharedPreferenceHelper._internal(this._prefs);
  static final SharedPreferenceHelper _singleton =
      SharedPreferenceHelper._internal(null);

  final SharedPreferences? _prefs;
  SharedPreferences get prefs {
    if (_prefs != null) return _prefs!;
    throw Exception('SharedPreferences not initialized');
  }

  factory SharedPreferenceHelper.create(SharedPreferences? prefs) {
    return SharedPreferenceHelper._internal(prefs);
  }

  factory SharedPreferenceHelper() {
    return _singleton;
  }

  static Future<SharedPreferenceHelper> getInstance() async {
    if (_singleton._prefs == null) {
      final prefs = await SharedPreferences.getInstance();
      return SharedPreferenceHelper._internal(prefs);
    }
    return _singleton;
  }

  Future<void> clearPreferenceValues() async {
    await _prefs!.clear();
  }

  Future<bool> saveUserProfile(UserModel user) async {
    return _prefs!.setString(
        UserPreferenceKey.UserProfile.toString(), json.encode(user.toJson()));
  }

  UserModel? getUserProfile() {
    final jsonStr = _prefs?.getString(UserPreferenceKey.UserProfile.toString());
    if (jsonStr == null) return null;
    try {
      return UserModel.fromJson(json.decode(jsonStr));
    } catch (_) {
      return null;
    }
  }
}

enum UserPreferenceKey { UserProfile }
