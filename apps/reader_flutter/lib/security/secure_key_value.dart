import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small secure key/value store for cryptographic secrets (the device master key
/// and device id).
///
/// Mirrors [TokenStorage]: on **macOS debug** it falls back to SharedPreferences
/// to avoid the login-keychain password prompt / `-34018` error that otherwise
/// hangs the app when a signed keychain-access-group is absent. Release/profile
/// macOS and every other platform use the hardware-backed keychain/keystore.
/// Force the keychain in debug with `--dart-define=USE_MACOS_KEYCHAIN=true`.
class SecureKeyValue {
  SecureKeyValue._();

  static const _prefPrefix = 'ethiopian_reader.secure.';

  static bool _useMacDebugPrefs() {
    const forceKeychain =
        bool.fromEnvironment('USE_MACOS_KEYCHAIN', defaultValue: false);
    if (forceKeychain) return false;
    return !kIsWeb &&
        kDebugMode &&
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static FlutterSecureStorage _keychain() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return const FlutterSecureStorage(
        mOptions: MacOsOptions(useDataProtectionKeyChain: false),
      );
    }
    return const FlutterSecureStorage();
  }

  static Future<String?> read(String key) async {
    if (_useMacDebugPrefs()) {
      return (await SharedPreferences.getInstance())
          .getString('$_prefPrefix$key');
    }
    return _keychain().read(key: key);
  }

  static Future<void> write(String key, String value) async {
    if (_useMacDebugPrefs()) {
      await (await SharedPreferences.getInstance())
          .setString('$_prefPrefix$key', value);
      return;
    }
    await _keychain().write(key: key, value: value);
  }

  static Future<void> delete(String key) async {
    if (_useMacDebugPrefs()) {
      await (await SharedPreferences.getInstance()).remove('$_prefPrefix$key');
      return;
    }
    await _keychain().delete(key: key);
  }
}
