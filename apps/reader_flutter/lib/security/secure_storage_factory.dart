import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared [FlutterSecureStorage] options for tokens and vault secrets.
///
/// - Android: EncryptedSharedPreferences (AES) instead of plain prefs fallback
/// - iOS: first-unlock, this-device-only (not iCloud-synced; available after first unlock)
/// - macOS: legacy login keychain (data-protection keychain needs entitlements)
/// - Windows / Linux: plugin defaults (DPAPI / libsecret)
FlutterSecureStorage createAppSecureStorage() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return const FlutterSecureStorage(
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    );
  }
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Prefer keeping secrets over wiping the vault on a transient Keystore error.
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
}
