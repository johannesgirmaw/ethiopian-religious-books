import 'package:shared_preferences/shared_preferences.dart';

/// Persists the reader's preferred numeral system: Ge'ez (ግዕዝ ቁጥር) vs the
/// default Western/Arabic digits. Applies to chapter/verse numbering.
class NumberSystemStorage {
  NumberSystemStorage._();

  static const _key = 'number_system';

  /// True when Ge'ez numerals are preferred (defaults to false = Arabic).
  static Future<bool> readGeez() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'geez';
  }

  static Future<void> writeGeez(bool geez) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, geez ? 'geez' : 'arabic');
  }
}
