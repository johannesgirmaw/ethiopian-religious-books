import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAccess = 'access_token';
const _kRefresh = 'refresh_token';
const _kUserJson = 'user_json';

/// UserDefaults keys when avoiding Keychain on macOS debug (no login-keychain prompt).
const _prefPrefix = 'ethiopian_reader.token.';

/// On macOS, `flutter_secure_storage` uses the login keychain; debug/ad-hoc builds
/// often trigger "enter keychain password" dialogs. In **debug** we store tokens in
/// SharedPreferences instead (still private app container, not encrypted like Keychain).
///
/// Release/profile macOS builds still use Keychain. To force Keychain in debug:
/// `--dart-define=USE_MACOS_KEYCHAIN=true`
bool _useMacOsDebugPlainPrefs() {
  const forceKeychain = bool.fromEnvironment(
    'USE_MACOS_KEYCHAIN',
    defaultValue: false,
  );
  if (forceKeychain) return false;
  return !kIsWeb &&
      kDebugMode &&
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// macOS: default data-protection keychain path triggers -34018 without extra entitlements;
/// disabling matches local debug without a signed keychain-access-group.
FlutterSecureStorage _platformSecureStorage() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return const FlutterSecureStorage(
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    );
  }
  return const FlutterSecureStorage();
}

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _usePlainMacDebug = storage == null && _useMacOsDebugPlainPrefs(),
        _secure = (storage == null && _useMacOsDebugPlainPrefs())
            ? null
            : (storage ?? _platformSecureStorage());

  final bool _usePlainMacDebug;
  final FlutterSecureStorage? _secure;
  SharedPreferences? _prefs;

  FlutterSecureStorage get _keychain {
    final s = _secure;
    if (s == null) {
      throw StateError('TokenStorage: expected Keychain backend');
    }
    return s;
  }

  Future<SharedPreferences> _prefsInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? userJson,
  }) async {
    if (_usePlainMacDebug) {
      final p = await _prefsInstance();
      await p.setString('$_prefPrefix$_kAccess', accessToken);
      await p.setString('$_prefPrefix$_kRefresh', refreshToken);
      if (userJson != null) {
        await p.setString('$_prefPrefix$_kUserJson', userJson);
      }
      return;
    }
    await _keychain.write(key: _kAccess, value: accessToken);
    await _keychain.write(key: _kRefresh, value: refreshToken);
    if (userJson != null) {
      await _keychain.write(key: _kUserJson, value: userJson);
    }
  }

  Future<String?> readAccess() async {
    if (_usePlainMacDebug) {
      return (await _prefsInstance()).getString('$_prefPrefix$_kAccess');
    }
    return _keychain.read(key: _kAccess);
  }

  Future<String?> readRefresh() async {
    if (_usePlainMacDebug) {
      return (await _prefsInstance()).getString('$_prefPrefix$_kRefresh');
    }
    return _keychain.read(key: _kRefresh);
  }

  Future<String?> readUserJson() async {
    if (_usePlainMacDebug) {
      return (await _prefsInstance()).getString('$_prefPrefix$_kUserJson');
    }
    return _keychain.read(key: _kUserJson);
  }

  Future<void> updateAccess(String access, {String? refresh}) async {
    if (_usePlainMacDebug) {
      final p = await _prefsInstance();
      await p.setString('$_prefPrefix$_kAccess', access);
      if (refresh != null) {
        await p.setString('$_prefPrefix$_kRefresh', refresh);
      }
      return;
    }
    await _keychain.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _keychain.write(key: _kRefresh, value: refresh);
    }
  }

  Future<void> clear() async {
    if (_usePlainMacDebug) {
      final p = await _prefsInstance();
      await p.remove('$_prefPrefix$_kAccess');
      await p.remove('$_prefPrefix$_kRefresh');
      await p.remove('$_prefPrefix$_kUserJson');
      return;
    }
    await _keychain.delete(key: _kAccess);
    await _keychain.delete(key: _kRefresh);
    await _keychain.delete(key: _kUserJson);
  }
}
