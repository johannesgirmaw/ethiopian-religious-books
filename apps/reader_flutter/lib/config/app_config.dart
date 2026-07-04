import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;

import 'resolve_api_host_stub.dart'
    if (dart.library.io) 'resolve_api_host_io.dart';

/// API base including `/v1` prefix (must end with `/` for correct path joining in Dio).
///
/// **Release / profile builds** (`!kDebugMode`): default is production at
/// `https://api.felegemetsahft.com/v1/` unless `--dart-define=API_BASE_URL=...` is set.
///
/// **Debug builds:** defaults by platform (Docker maps API to host **8000** — see `infra/docker-compose.yml`):
/// - **Android (emulator):** `http://10.0.2.2:8000/v1/` — use `--dart-define=API_BASE_URL=...` on a **physical** Android device.
/// - **iOS simulator:** `http://127.0.0.1:8000/v1/`
/// - **macOS desktop:** after [ensureInitialized], prefers this machine’s primary **LAN IPv4**
///   when `127.0.0.1` is unusable (common with some VPN / Docker Desktop + broken loopback).
/// - **Web:** `http://localhost:8000/v1/`
/// - **Linux / Windows:** `http://127.0.0.1:8000/v1/` unless macOS-style init set a host.
///
/// Without a trailing slash, `http://host:8000/v1` plus path `auth/login` becomes
/// `http://host:8000/auth/login` (wrong). [apiBaseUrl] normalizes overrides to end with `/`.
///
/// Override anytime (slash optional):
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/v1`
class AppConfig {
  AppConfig._();

  static const String _productionApiBaseUrl =
      'https://api.felegemetsahft.com/v1/';

  /// Dart's [Uri.resolve] drops `/v1` if the base has no trailing `/`.
  static String _withTrailingSlash(String base) {
    final t = base.trim();
    if (t.isEmpty) return t;
    return t.endsWith('/') ? t : '$t/';
  }

  static const String _fromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _desktopLanHost;

  /// Call from `main()` before `runApp` (desktop macOS: discovers LAN IP for Docker).
  static Future<void> ensureInitialized() async {
    if (_fromEnvironment.isNotEmpty) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    _desktopLanHost = await resolveApiHostForDesktop();
  }

  static String get apiBaseUrl {
    if (_fromEnvironment.isNotEmpty) {
      return _withTrailingSlash(_fromEnvironment);
    }
    if (!kDebugMode) {
      return _productionApiBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000/v1/';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/v1/';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000/v1/';
    }
    final lan = _desktopLanHost;
    if (lan != null && lan.isNotEmpty) {
      return 'http://$lan:8000/v1/';
    }
    return 'http://127.0.0.1:8000/v1/';
  }
}
