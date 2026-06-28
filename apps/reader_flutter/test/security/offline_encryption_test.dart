import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ethiopian_reader/security/book_crypto.dart';
import 'package:ethiopian_reader/storage/secure_book_store.dart';

/// In-memory stand-in for the platform keychain so BookCrypto's device master key
/// can be generated/read during unit tests.
const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};

  setUp(() async {
    store.clear();
    await BookCrypto.wipeMasterKey().catchError((_) {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          store[key!] = args['value'] as String;
          return null;
        case 'read':
          return store[key];
        case 'delete':
          store.remove(key);
          return null;
        case 'containsKey':
          return store.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(store);
        case 'deleteAll':
          store.clear();
          return null;
      }
      return null;
    });
  });

  group('BookCrypto AES-256-GCM', () {
    test('seals and opens JSON round-trip', () async {
      final blob = await BookCrypto.sealJson({'a': 1, 'b': 'x'});
      final out = await BookCrypto.openJson(blob);
      expect(out['a'], 1);
      expect(out['b'], 'x');
    });

    test('ciphertext is not plaintext', () async {
      final blob = await BookCrypto.seal(utf8.encode('top secret body'));
      expect(utf8.decode(blob, allowMalformed: true), isNot(contains('secret')));
    });

    test('tampering is detected (GCM auth tag)', () async {
      final blob = await BookCrypto.seal(utf8.encode('hello'));
      final tampered = Uint8List.fromList(blob);
      tampered[tampered.length - 1] ^= 0xFF;
      expect(BookCrypto.open(tampered), throwsA(isA<Object>()));
    });

    test('a different device key cannot open the blob', () async {
      final blob = await BookCrypto.seal(utf8.encode('secret'));
      // Simulate a different device: drop the key so a fresh one is generated.
      store.clear();
      await BookCrypto.wipeMasterKey();
      expect(BookCrypto.open(blob), throwsA(isA<Object>()));
    });
  });

  group('OfflineLicense lease window', () {
    int ms(Duration d) => DateTime.now().add(d).millisecondsSinceEpoch;

    test('fresh license is valid and does not need renewal', () {
      final lic = OfflineLicense(
        token: 't',
        deviceId: 'd',
        expiresAtEpochMs: ms(const Duration(days: 30)),
      );
      expect(lic.isExpired, isFalse);
      expect(lic.needsRenewal(days: 5), isFalse);
    });

    test('expired license is flagged', () {
      final lic = OfflineLicense(
        token: 't',
        deviceId: 'd',
        expiresAtEpochMs: ms(const Duration(days: -1)),
      );
      expect(lic.isExpired, isTrue);
      expect(lic.needsRenewal(), isTrue);
    });

    test('near-expiry license requests renewal', () {
      final lic = OfflineLicense(
        token: 't',
        deviceId: 'd',
        expiresAtEpochMs: ms(const Duration(days: 2)),
      );
      expect(lic.isExpired, isFalse);
      expect(lic.needsRenewal(days: 5), isTrue);
    });
  });
}
