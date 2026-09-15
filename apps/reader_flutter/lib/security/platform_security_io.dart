import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_security_stub.dart';

PlatformSecurityImpl platformSecurity = _MethodChannelPlatformSecurity();

class _MethodChannelPlatformSecurity implements PlatformSecurityImpl {
  static const _channel = MethodChannel(
    'com.ethiopianreligious.reader/content_protection',
  );

  @override
  Future<void> setSecureMode(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecureMode', {'enabled': enabled});
    } on MissingPluginException {
      // Desktop/Linux runners without native handler — copy blocking still applies.
    } on PlatformException {
      // Best-effort; do not block the reader if the OS rejects the call.
    }
  }
}
