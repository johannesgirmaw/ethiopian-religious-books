import 'dart:typed_data';

import 'package:ethiopian_reader/security/book_crypto.dart';
import 'package:ethiopian_reader/storage/pdf_vault_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

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
            default:
              return null;
          }
        });
  });

  test('a leftover marker does not describe the published generation', () {
    expect(pdfVaultPartialIsStale('new', 'published'), isTrue);
    expect(pdfVaultPartialIsStale('published', 'published'), isFalse);
    expect(pdfVaultPartialIsStale('', 'published'), isFalse);
    expect(pdfVaultPartialIsStale('only', null), isTrue);
  });

  test('chunk counts cover a short tail', () {
    expect(pdfVaultChunkCount(0), 0);
    expect(pdfVaultChunkCount(1, chunkSize: 8), 1);
    expect(pdfVaultChunkCount(8, chunkSize: 8), 1);
    expect(pdfVaultChunkCount(9, chunkSize: 8), 2);
    expect(pdfVaultPlainChunkLength(9, 0, chunkSize: 8), 8);
    expect(pdfVaultPlainChunkLength(9, 1, chunkSize: 8), 1);
  });

  test('range reads span sealed chunks and stop at the end', () async {
    const chunkSize = 8;
    final plain = Uint8List.fromList(List<int>.generate(20, (i) => i + 1));
    final sealed = await _sealChunks(plain, chunkSize);
    final reader = _reader(plain.length, chunkSize, sealed);

    final across = Uint8List(10);
    expect(await reader.read(across, 6, 10), 10);
    expect(across, plain.sublist(6, 16));

    final tail = Uint8List(8);
    expect(await reader.read(tail, 16, 8), 4);
    expect(tail.sublist(0, 4), plain.sublist(16));

    expect(await reader.read(Uint8List(4), plain.length, 4), 0);

    final copy = ChunkedPdfReader(
      plainSize: plain.length,
      revisionId: 'rev',
      chunkSize: chunkSize,
      readSealed: (index) async => sealed[index],
    );
    expect(await copy.readAll(), plain);
  });

  test('a tampered chunk is rejected', () async {
    const chunkSize = 8;
    final plain = Uint8List.fromList(List<int>.generate(20, (i) => i + 1));
    final sealed = await _sealChunks(plain, chunkSize);
    sealed[1][sealed[1].length - 1] ^= 0xff;
    final reader = _reader(plain.length, chunkSize, sealed);

    expect(reader.read(Uint8List(4), 8, 4), throwsA(isA<Object>()));
  });
}

ChunkedPdfReader _reader(int size, int chunkSize, List<Uint8List> sealed) {
  return ChunkedPdfReader(
    plainSize: size,
    revisionId: 'rev',
    chunkSize: chunkSize,
    readSealed: (index) async => sealed[index],
  );
}

Future<List<Uint8List>> _sealChunks(Uint8List plain, int chunkSize) async {
  final count = pdfVaultChunkCount(plain.length, chunkSize: chunkSize);
  final sealed = <Uint8List>[];
  for (var index = 0; index < count; index++) {
    final start = index * chunkSize;
    final end =
        start +
        pdfVaultPlainChunkLength(plain.length, index, chunkSize: chunkSize);
    sealed.add(await BookCrypto.seal(plain.sublist(start, end)));
  }
  return sealed;
}
