// Device-level encryption verification.
//
// Unlike test/security/offline_encryption_test.dart (which mocks the keychain),
// this runs on a REAL device against the REAL flutter_secure_storage backend
// (iOS Keychain / Android Keystore / Linux libsecret / Windows DPAPI / macOS
// keychain) and the REAL on-disk vault. It is the only thing that proves the
// per-platform key storage actually works.
//
// Run on each target:
//   flutter test integration_test/encryption_device_test.dart -d <device>
// e.g. -d android | -d ios | -d linux | -d macos | -d windows | -d chrome

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ethiopian_reader/security/book_crypto.dart';
import 'package:ethiopian_reader/storage/secure_book_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bookId = '__enc_selftest__';

  tearDown(() async {
    await SecureBookStore.removeBookContent(bookId).catchError((_) {});
  });

  group('on-device AES-256-GCM via real secure storage', () {
    testWidgets('master key persists in the platform keychain', (_) async {
      // Two seals in a row must use the SAME device key: if the keychain write
      // on seal #1 silently failed, seal #2 would generate a fresh key and the
      // first blob would no longer open.
      final blob1 = await BookCrypto.seal(utf8.encode('first'));
      final blob2 = await BookCrypto.seal(utf8.encode('second'));
      expect(utf8.decode(await BookCrypto.open(blob1)), 'first');
      expect(utf8.decode(await BookCrypto.open(blob2)), 'second');
    });

    testWidgets('full vault round-trip through SecureBookStore', (_) async {
      final lic = OfflineLicense(
        token: 'jwt.test.token',
        deviceId: 'device-xyz',
        expiresAtEpochMs:
            DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      );
      await SecureBookStore.writeLicense(bookId, lic);

      final back = await SecureBookStore.readLicense(bookId);
      expect(back, isNotNull);
      expect(back!.token, lic.token);
      expect(back.deviceId, lic.deviceId);
      expect(
        await SecureBookStore.hasValidOfflineAccess(bookId,
            deviceId: 'device-xyz'),
        isTrue,
      );
    });

    testWidgets('ciphertext on disk is not plaintext', (_) async {
      final blob = await BookCrypto.seal(utf8.encode('confidential-marker'));
      expect(
        utf8.decode(blob, allowMalformed: true),
        isNot(contains('confidential')),
      );
    });

    testWidgets('GCM auth tag rejects tampering', (_) async {
      final blob = await BookCrypto.seal(utf8.encode('payload'));
      final tampered = Uint8List.fromList(blob);
      tampered[tampered.length - 1] ^= 0xFF;
      expect(BookCrypto.open(tampered), throwsA(isA<Object>()));
    });

    testWidgets('wrong-device key cannot open a foreign blob', (_) async {
      final blob = await BookCrypto.seal(utf8.encode('secret'));
      await BookCrypto.wipeMasterKey(); // simulate a different install
      expect(BookCrypto.open(blob), throwsA(isA<Object>()));
    });
  });
}
