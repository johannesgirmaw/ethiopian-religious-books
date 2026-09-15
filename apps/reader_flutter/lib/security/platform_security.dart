import 'platform_security_stub.dart'
    if (dart.library.io) 'platform_security_io.dart';

/// Enables or disables platform content-protection (screenshot / screen capture).
///
/// Call with [enabled] true while a reader surface is visible; false when leaving.
abstract class PlatformSecurity {
  static Future<void> setSecureMode(bool enabled) =>
      platformSecurity.setSecureMode(enabled);
}
