import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'secure_key_value.dart';

/// Stable, private per-install device identity used to bind offline licenses to
/// one device. The id is a random 128-bit value kept in the platform secure
/// store — it is not derived from hardware serials, so it leaks nothing about
/// the user while still letting the backend pin a lease to this install.
class DeviceIdentity {
  DeviceIdentity._();

  static const _deviceIdKey = 'device_id_v1';
  static String? _cached;
  static bool _registered = false;

  static String _randomId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<String> deviceId() async {
    if (_cached != null) return _cached!;
    final existing = await SecureKeyValue.read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final id = _randomId();
    await SecureKeyValue.write(_deviceIdKey, id);
    _cached = id;
    return id;
  }

  static String platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  /// Best-effort registration with the backend (idempotent server-side). Safe to
  /// call repeatedly; silently no-ops when offline and retries on the next call.
  static Future<void> ensureRegistered(Dio dio) async {
    if (_registered) return;
    try {
      final id = await deviceId();
      await dio.post<Map<String, dynamic>>(
        'devices/register',
        data: {'device_id': id, 'platform': platformLabel()},
      );
      _registered = true;
    } catch (_) {
      // Offline or transient; registration is retried on the next attempt.
    }
  }
}
