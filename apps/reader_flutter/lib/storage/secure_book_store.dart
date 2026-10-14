import 'dart:typed_data';

import '../models/book_models.dart';
import '../security/book_crypto.dart';
import '../utils/pdf_bytes.dart';
import 'book_content_cache_storage.dart' show BookCacheMeta;
import 'pdf_blob_store_stub.dart'
    if (dart.library.io) 'pdf_blob_store_io.dart'
    as pdf_blob;
import 'pdf_vault_reader.dart';
import 'vault/vault_fs_stub.dart' if (dart.library.io) 'vault/vault_fs_io.dart';

/// An offline-reading lease for one book on this device. The opaque [token] is a
/// server-signed JWT; we only ever check [expiresAtEpochMs] (the lease window)
/// and [deviceId] locally. The signature is re-verified server-side on renewal,
/// which is where a refunded/revoked purchase is actually caught.
class OfflineLicense {
  OfflineLicense({
    required this.token,
    required this.deviceId,
    required this.expiresAtEpochMs,
    this.revisionId,
  });

  final String token;
  final String deviceId;
  final int expiresAtEpochMs;
  final String? revisionId;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtEpochMs;

  /// Within [days] of expiry (or already expired) — time to renew while online.
  bool needsRenewal({int days = 5}) {
    final soon = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    return soon >= expiresAtEpochMs;
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'device_id': deviceId,
    'expires_at_ms': expiresAtEpochMs,
    if (revisionId != null) 'revision_id': revisionId,
  };

  factory OfflineLicense.fromJson(Map<String, dynamic> j) => OfflineLicense(
    token: j['token'] as String? ?? '',
    deviceId: j['device_id'] as String? ?? '',
    expiresAtEpochMs: (j['expires_at_ms'] as num?)?.toInt() ?? 0,
    revisionId: j['revision_id'] as String?,
  );
}

/// Manifest for one sealed offline PDF. The file itself is stored as chunks,
/// not as this object.
class PdfVaultManifest {
  PdfVaultManifest({
    required this.revisionId,
    required this.filename,
    required this.sizeBytes,
    required this.chunkSize,
    required this.generation,
  });

  final String revisionId;
  final String filename;
  final int sizeBytes;
  final int chunkSize;
  final String generation;

  int get chunkCount => pdfVaultChunkCount(sizeBytes, chunkSize: chunkSize);

  bool get isUsable =>
      generation.isNotEmpty && chunkSize > 0 && sizeBytes > 0 && chunkCount > 0;

  Map<String, dynamic> toJson() => {
    'revision_id': revisionId,
    'filename': filename,
    'size_bytes': sizeBytes,
    'chunk_size': chunkSize,
    'generation': generation,
    'content_format': 'pdf',
  };

  factory PdfVaultManifest.fromJson(Map<String, dynamic> j) => PdfVaultManifest(
    revisionId: j['revision_id'] as String? ?? '',
    filename: j['filename'] as String? ?? 'content.pdf',
    sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
    chunkSize: (j['chunk_size'] as num?)?.toInt() ?? 0,
    generation: j['generation'] as String? ?? '',
  );
}

/// Encrypted-at-rest replacement for the old plaintext SharedPreferences cache.
///
/// Content, metadata and the offline license are each AES-256-GCM sealed by
/// [BookCrypto] before being written to the vault (files on mobile/desktop,
/// SharedPreferences on web). A PDF is sealed in small chunks: files on
/// mobile/desktop, IndexedDB records on web. Plaintext is never persisted.
/// Offline reading is gated on holding a sealed, unexpired, this-device
/// [OfflineLicense].
class SecureBookStore {
  SecureBookStore._();

  static const _contentName = 'content.enc';
  static const _metaName = 'meta.enc';
  static const _licenseName = 'license.enc';
  static const _pdfMetaName = 'pdf_meta.enc';
  static const _pdfPartialName = 'pdf_partial.enc';

  static String _aad(String bookId, String kind) => 'book:$bookId:$kind';

  static Future<BookContentTree?> readBookContent(String bookId) async {
    final blob = await vaultRead(bookId, _contentName);
    if (blob == null) return null;
    try {
      final map = await BookCrypto.openJson(
        blob,
        aadContext: _aad(bookId, 'content'),
      );
      return BookContentTree.fromJson(map);
    } catch (_) {
      return null; // tampered, wrong key, or corrupt — treat as absent
    }
  }

  static Future<void> writeBookContent(
    String bookId,
    Map<String, dynamic> raw, {
    BookCacheMeta? meta,
  }) async {
    await vaultWrite(
      bookId,
      _contentName,
      await BookCrypto.sealJson(raw, aadContext: _aad(bookId, 'content')),
    );
    if (meta != null && meta.title.trim().isNotEmpty) {
      await vaultWrite(
        bookId,
        _metaName,
        await BookCrypto.sealJson(
          meta.toJson(),
          aadContext: _aad(bookId, 'meta'),
        ),
      );
    }
  }

  static Future<BookCacheMeta?> readBookMeta(String bookId) async {
    final blob = await vaultRead(bookId, _metaName);
    if (blob == null) return null;
    try {
      final meta = BookCacheMeta.fromJson(
        await BookCrypto.openJson(blob, aadContext: _aad(bookId, 'meta')),
      );
      return meta.title.isEmpty ? null : meta;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeBookMeta(String bookId, BookCacheMeta meta) async {
    if (meta.title.trim().isEmpty) return;
    await vaultWrite(
      bookId,
      _metaName,
      await BookCrypto.sealJson(
        meta.toJson(),
        aadContext: _aad(bookId, 'meta'),
      ),
    );
  }

  static Future<bool> hasBookContent(String bookId) =>
      vaultExists(bookId, _contentName);

  static Future<List<String>> listCachedBookIds() => vaultListBookIds();

  static Future<int> cachedBookCount() async =>
      (await vaultListBookIds()).length;

  static Future<void> removeBookContent(String bookId) async {
    final manifest = await _readPdfManifest(bookId);
    final partial = await _readPdfPartial(bookId);
    if (manifest != null) {
      await pdf_blob.deleteSealedGeneration(
        bookId,
        manifest.generation,
        manifest.chunkCount,
      );
    }
    if (partial != null && partial.generation != manifest?.generation) {
      await pdf_blob.deleteSealedGeneration(
        bookId,
        partial.generation,
        partial.count,
      );
    }
    await vaultDeleteBook(bookId);
  }

  static Future<void> clearAll() async {
    await pdf_blob.clearPdfBlobs();
    await vaultClear();
  }

  // --- Offline PDF (sealed chunks, not one giant blob) ------------------

  static final Map<String, Future<void>> _pdfWriteTail = {};

  /// Runs [body] only after any in-flight save of [bookId] has finished.
  static Future<T> exclusivePdfSave<T>(
    String bookId,
    Future<T> Function() body,
  ) {
    final gate = _pdfWriteTail[bookId] ?? Future<void>.value();
    final result = gate.then((_) => body());
    _pdfWriteTail[bookId] = result.then(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  /// Seals [bytes] in [kPdfVaultChunkSize] pieces. The previous generation is
  /// left in place until the new manifest is written, so a failed refresh
  /// does not destroy a book that already saved.
  static Future<void> writePdfFromStream(
    String bookId,
    Stream<List<int>> bytes, {
    required int expectedBytes,
    required String revisionId,
    required String filename,
    BookCacheMeta? meta,
  }) async {
    final previous = await _readPdfManifest(bookId);
    final stale = await _readPdfPartial(bookId);
    if (stale != null &&
        pdfVaultPartialIsStale(stale.generation, previous?.generation)) {
      // +1 covers a chunk written just before the marker update was lost.
      await pdf_blob.deleteSealedGeneration(
        bookId,
        stale.generation,
        stale.count + 1,
      );
      await _clearPdfPartial(bookId);
    } else if (stale != null) {
      await _clearPdfPartial(bookId);
    }

    final generation = DateTime.now().microsecondsSinceEpoch.toString();
    final queue = _ByteQueue();
    var total = 0;
    var index = 0;
    var checkedMagic = false;

    Future<void> sealChunk(Uint8List plain) async {
      if (!checkedMagic) {
        if (!pdfBytesLookValid(plain)) {
          throw PdfVaultWriteException('invalid');
        }
        checkedMagic = true;
      }
      await pdf_blob.writeSealedChunk(
        bookId,
        generation,
        index,
        await BookCrypto.seal(
          plain,
          aadContext: 'pdf:$bookId:$generation:$index',
        ),
      );
      index++;
      await _writePdfPartial(bookId, generation, index);
    }

    var published = false;
    try {
      await for (final piece in bytes) {
        queue.add(piece);
        while (queue.length >= kPdfVaultChunkSize) {
          final plain = queue.take(kPdfVaultChunkSize);
          total += plain.length;
          await sealChunk(plain);
        }
      }
      if (queue.length > 0) {
        final plain = queue.take(queue.length);
        total += plain.length;
        await sealChunk(plain);
      }
      if (!checkedMagic || total <= 0) {
        throw PdfVaultWriteException('invalid');
      }
      if (expectedBytes > 0 && total != expectedBytes) {
        throw PdfVaultWriteException('incomplete');
      }
      await _writePdfManifest(
        bookId,
        PdfVaultManifest(
          revisionId: revisionId,
          filename: filename,
          sizeBytes: total,
          chunkSize: kPdfVaultChunkSize,
          generation: generation,
        ),
      );
      published = true;
      try {
        await _clearPdfPartial(bookId);
      } catch (_) {}
      if (previous != null && previous.generation != generation) {
        try {
          await pdf_blob.deleteSealedGeneration(
            bookId,
            previous.generation,
            previous.chunkCount,
          );
        } catch (_) {}
      }
      if (meta != null && meta.title.trim().isNotEmpty) {
        try {
          await writeBookMeta(bookId, meta);
        } catch (_) {}
      }
    } catch (_) {
      if (!published) {
        try {
          await pdf_blob.deleteSealedGeneration(bookId, generation, index);
          await _clearPdfPartial(bookId);
        } catch (_) {
          // Keep the original failure. A cleanup error must not hide it.
        }
      }
      rethrow;
    }
  }

  static Future<PdfVaultManifest?> readPdfManifest(String bookId) =>
      _readPdfManifest(bookId);

  static Future<ChunkedPdfReader?> openPdfReader(String bookId) async {
    final manifest = await _readPdfManifest(bookId);
    if (manifest == null || !manifest.isUsable) return null;
    if (!await pdf_blob.hasSealedChunk(bookId, manifest.generation, 0)) {
      return null;
    }
    return ChunkedPdfReader(
      plainSize: manifest.sizeBytes,
      revisionId: manifest.revisionId,
      chunkSize: manifest.chunkSize,
      readSealed: (index) =>
          pdf_blob.readSealedChunk(bookId, manifest.generation, index),
      aadContextForIndex: (index) =>
          'pdf:$bookId:${manifest.generation}:$index',
    );
  }

  static Future<bool> hasPdf(String bookId) async {
    final manifest = await _readPdfManifest(bookId);
    if (manifest == null || !manifest.isUsable) return false;
    return pdf_blob.hasSealedChunk(bookId, manifest.generation, 0);
  }

  static Future<void> revokeOfflineLicense(String bookId) {
    return writeLicense(
      bookId,
      OfflineLicense(token: '', deviceId: '', expiresAtEpochMs: 0),
    );
  }

  static Future<PdfVaultManifest?> _readPdfManifest(String bookId) async {
    final blob = await vaultRead(bookId, _pdfMetaName);
    if (blob == null) return null;
    try {
      return PdfVaultManifest.fromJson(
        await BookCrypto.openJson(
          blob,
          aadContext: _aad(bookId, 'pdf_meta'),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writePdfManifest(
    String bookId,
    PdfVaultManifest manifest,
  ) async {
    await vaultWrite(
      bookId,
      _pdfMetaName,
      await BookCrypto.sealJson(
        manifest.toJson(),
        aadContext: _aad(bookId, 'pdf_meta'),
      ),
    );
  }

  static Future<_PdfPartial?> _readPdfPartial(String bookId) async {
    final blob = await vaultRead(bookId, _pdfPartialName);
    if (blob == null) return null;
    try {
      final json = await BookCrypto.openJson(
        blob,
        aadContext: _aad(bookId, 'pdf_partial'),
      );
      final generation = json['generation'] as String? ?? '';
      if (generation.isEmpty) return null;
      return _PdfPartial(generation, (json['count'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writePdfPartial(
    String bookId,
    String generation,
    int count,
  ) async {
    await vaultWrite(
      bookId,
      _pdfPartialName,
      await BookCrypto.sealJson(
        {'generation': generation, 'count': count},
        aadContext: _aad(bookId, 'pdf_partial'),
      ),
    );
  }

  static Future<void> _clearPdfPartial(String bookId) =>
      vaultDelete(bookId, _pdfPartialName);

  // --- Offline license (lease) -------------------------------------------

  static Future<void> writeLicense(String bookId, OfflineLicense lic) async {
    await vaultWrite(
      bookId,
      _licenseName,
      await BookCrypto.sealJson(
        lic.toJson(),
        aadContext: _aad(bookId, 'license'),
      ),
    );
  }

  static Future<OfflineLicense?> readLicense(String bookId) async {
    final blob = await vaultRead(bookId, _licenseName);
    if (blob == null) return null;
    try {
      return OfflineLicense.fromJson(
        await BookCrypto.openJson(blob, aadContext: _aad(bookId, 'license')),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the book may be opened offline: a sealed, unexpired license issued
  /// to this device must be present. Empty caller [deviceId] fails closed.
  ///
  /// Licenses written before device-binding (empty ``device_id``) are rebound
  /// once to this install — the vault master key already ties ciphertext to
  /// the device, so this only repairs the lease metadata.
  static Future<bool> hasValidOfflineAccess(
    String bookId, {
    required String deviceId,
  }) async {
    final lic = await readLicense(bookId);
    if (lic == null || lic.token.isEmpty) return false;
    if (deviceId.isEmpty) return false;
    if (lic.isExpired) return false;
    if (lic.deviceId.isEmpty) {
      await writeLicense(
        bookId,
        OfflineLicense(
          token: lic.token,
          deviceId: deviceId,
          expiresAtEpochMs: lic.expiresAtEpochMs,
          revisionId: lic.revisionId,
        ),
      );
      return true;
    }
    return lic.deviceId == deviceId;
  }
}

class _PdfPartial {
  _PdfPartial(this.generation, this.count);
  final String generation;
  final int count;
}

/// Bytes from a download stream, taken out in fixed-size pieces.
class _ByteQueue {
  final List<Uint8List> _parts = [];
  int _head = 0;
  int length = 0;

  void add(List<int> data) {
    if (data.isEmpty) return;
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    _parts.add(bytes);
    length += bytes.length;
  }

  Uint8List take(int count) {
    if (count > length) {
      throw StateError('pdf download buffer underflow');
    }
    final out = Uint8List(count);
    var filled = 0;
    while (filled < count) {
      final part = _parts.first;
      final available = part.length - _head;
      final n = available < count - filled ? available : count - filled;
      out.setRange(filled, filled + n, part, _head);
      filled += n;
      _head += n;
      length -= n;
      if (_head == part.length) {
        _parts.removeAt(0);
        _head = 0;
      }
    }
    return out;
  }
}
