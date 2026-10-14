// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Sealed PDF chunks for Flutter web. Each chunk is its own IndexedDB record
/// so a page can be opened without loading the rest of the book into memory.
///
/// IndexedDB types live in `dart:indexed_db`, which this analyzer target does
/// not load, so calls go through `dynamic`. The transaction's completion
/// listener is attached before any request so a finished write cannot be missed.
const _dbName = 'fm-pdf-vault-v1';
const _storeName = 'sealed';

String _chunkKey(String bookId, String generation, int index) =>
    '$bookId/$generation/$index';

Future<dynamic> _open() {
  final factory = html.window.indexedDB;
  if (factory == null) {
    throw StateError('IndexedDB is not available');
  }
  return factory.open(
    _dbName,
    version: 1,
    onUpgradeNeeded: (event) {
      final db = (event.target as dynamic).result;
      if (db == null) return;
      try {
        if (!_storeExists(db)) db.createObjectStore(_storeName);
      } catch (_) {
        // The store already exists, or this browser reports names in a shape
        // we cannot iterate. Creating it again throws; that is fine.
        try {
          db.createObjectStore(_storeName);
        } catch (_) {}
      }
    },
  );
}

bool _storeExists(dynamic db) {
  final names = db.objectStoreNames;
  if (names == null) return false;
  try {
    for (final name in names as Iterable) {
      if (name == _storeName) return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

Future<T> _run<T>(
  Future<T> Function(dynamic store) action, {
  required bool write,
}) async {
  final db = await _open();
  try {
    final txn = db.transaction(_storeName, write ? 'readwrite' : 'readonly');
    final done = txn.completed;
    final result = await action(txn.objectStore(_storeName));
    await done;
    return result;
  } finally {
    db.close();
  }
}

Uint8List? _asBytes(Object? value) {
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is ByteBuffer) return Uint8List.view(value);
  if (value is html.Blob) return null;
  if (value is List) {
    try {
      return Uint8List.fromList(value.cast<int>());
    } catch (_) {
      return null;
    }
  }
  return null;
}

Future<Uint8List> _readBlob(html.Blob blob) async {
  final reader = html.FileReader();
  final loaded = reader.onLoadEnd.first;
  reader.readAsArrayBuffer(blob);
  await loaded;
  final result = reader.result;
  if (result is ByteBuffer) return Uint8List.view(result);
  if (result is Uint8List) return result;
  throw const FormatException('pdf vault chunk unreadable');
}

Future<Uint8List?> _decode(Object? value) async {
  if (value is html.Blob) return _readBlob(value);
  return _asBytes(value);
}

Future<void> writeSealedChunk(
  String bookId,
  String generation,
  int index,
  Uint8List sealed,
) {
  final key = _chunkKey(bookId, generation, index);
  return _run((store) async {
    await store.put(sealed, key);
  }, write: true);
}

Future<Uint8List?> readSealedChunk(
  String bookId,
  String generation,
  int index,
) {
  final key = _chunkKey(bookId, generation, index);
  return _run((store) async {
    final value = await store.getObject(key);
    return _decode(value);
  }, write: false);
}

Future<bool> hasSealedChunk(String bookId, String generation, int index) async {
  try {
    final bytes = await readSealedChunk(bookId, generation, index);
    return bytes != null && bytes.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> deleteSealedGeneration(
  String bookId,
  String generation,
  int chunkCount,
) async {
  for (var index = 0; index < chunkCount; index++) {
    final key = _chunkKey(bookId, generation, index);
    try {
      await _run((store) async {
        await store.delete(key);
      }, write: true);
    } catch (_) {
      // Keep deleting the rest of this generation.
    }
  }
}

Future<void> clearPdfBlobs() async {
  try {
    await _run((store) async {
      await store.clear();
    }, write: true);
  } catch (_) {
    // Best-effort: sign-out must still wipe the rest of the vault.
  }
}
