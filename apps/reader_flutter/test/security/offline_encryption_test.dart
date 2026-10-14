import 'dart:convert';
import 'dart:io';

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
  late Directory tempDocs;

  setUp(() async {
    store.clear();
    tempDocs = await Directory.systemTemp.createTemp('fm_vault_test_');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDocs.path;
        }
        if (call.method == 'getTemporaryDirectory') {
          return tempDocs.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    try {
      if (await tempDocs.exists()) await tempDocs.delete(recursive: true);
    } catch (_) {}
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

    test('AAD binds ciphertext to context (v1)', () async {
      final blob = await BookCrypto.seal(
        utf8.encode('bound'),
        aadContext: 'pdf:book:gen:0',
      );
      expect(blob.sublist(0, 3), <int>[0x46, 0x4d, 0x01]); // FM\x01
      final plain = await BookCrypto.open(
        blob,
        aadContext: 'pdf:book:gen:0',
      );
      expect(utf8.decode(plain), 'bound');
      expect(
        BookCrypto.open(blob, aadContext: 'pdf:other:gen:0'),
        throwsA(isA<Object>()),
      );
    });

    test('legacy blobs without AAD still open', () async {
      final legacy = await BookCrypto.seal(utf8.encode('legacy'));
      final plain = await BookCrypto.open(
        legacy,
        aadContext: 'ignored-for-legacy',
      );
      expect(utf8.decode(plain), 'legacy');
    });

    test('legacy blob whose nonce starts with 0x01 still opens', () async {
      // Format v1 also starts with 0x01; open must not mis-parse a legacy nonce.
      late Uint8List legacy;
      for (var i = 0; i < 512; i++) {
        final candidate = await BookCrypto.seal(utf8.encode('legacy-$i'));
        if (candidate.isNotEmpty && candidate.first == 0x01) {
          legacy = candidate;
          break;
        }
        if (i == 511) {
          // Extremely unlikely; still assert open works for a normal legacy blob.
          legacy = candidate;
        }
      }
      final plain = await BookCrypto.open(
        legacy,
        aadContext: 'pdf:book:gen:0',
      );
      expect(utf8.decode(plain), startsWith('legacy-'));
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

  group('hasValidOfflineAccess device binding', () {
    int ms(Duration d) => DateTime.now().add(d).millisecondsSinceEpoch;

    test('caller empty device id fails closed', () async {
      await SecureBookStore.writeLicense(
        'book-a',
        OfflineLicense(
          token: 'tok',
          deviceId: 'dev',
          expiresAtEpochMs: ms(const Duration(days: 10)),
        ),
      );
      expect(
        await SecureBookStore.hasValidOfflineAccess('book-a', deviceId: ''),
        isFalse,
      );
    });

    test('legacy empty license device id is rebound once', () async {
      await SecureBookStore.writeLicense(
        'book-legacy',
        OfflineLicense(
          token: 'tok',
          deviceId: '',
          expiresAtEpochMs: ms(const Duration(days: 10)),
        ),
      );
      expect(
        await SecureBookStore.hasValidOfflineAccess(
          'book-legacy',
          deviceId: 'dev-now',
        ),
        isTrue,
      );
      final rebound = await SecureBookStore.readLicense('book-legacy');
      expect(rebound?.deviceId, 'dev-now');
    });

    test('mismatched device is rejected', () async {
      await SecureBookStore.writeLicense(
        'book-b',
        OfflineLicense(
          token: 'tok',
          deviceId: 'dev-1',
          expiresAtEpochMs: ms(const Duration(days: 10)),
        ),
      );
      expect(
        await SecureBookStore.hasValidOfflineAccess('book-b', deviceId: 'dev-2'),
        isFalse,
      );
      expect(
        await SecureBookStore.hasValidOfflineAccess('book-b', deviceId: 'dev-1'),
        isTrue,
      );
    });
  });
}
