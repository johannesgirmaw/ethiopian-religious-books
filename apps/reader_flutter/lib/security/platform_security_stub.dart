/// Web and other platforms without native capture APIs.
PlatformSecurityImpl platformSecurity = _NoOpPlatformSecurity();

abstract class PlatformSecurityImpl {
  Future<void> setSecureMode(bool enabled);
}

class _NoOpPlatformSecurity implements PlatformSecurityImpl {
  @override
  Future<void> setSecureMode(bool enabled) async {}
}
