import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleStorage {
  AppLocaleStorage._();

  static const _key = 'app_language_code';

  /// Returns `en` or `am` (defaults to `en`).
  static Future<String> readLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key)?.trim().toLowerCase();
    if (raw == 'am') return 'am';
    return 'en';
  }

  static Future<void> writeLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = code.trim().toLowerCase() == 'am' ? 'am' : 'en';
    await prefs.setString(_key, normalized);
  }
}
