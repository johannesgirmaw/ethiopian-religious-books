import '../models/book_models.dart';
import '../security/book_crypto.dart';
import 'book_content_cache_storage.dart' show BookCacheMeta;
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

/// Encrypted-at-rest replacement for the old plaintext SharedPreferences cache.
///
/// Content, metadata and the offline license are each AES-256-GCM sealed by
/// [BookCrypto] before being written to the vault (files on mobile/desktop,
/// SharedPreferences on web). Plaintext is never persisted. Offline reading is
/// gated on holding a sealed, unexpired, this-device [OfflineLicense].
class SecureBookStore {
  SecureBookStore._();

  static const _contentName = 'content.enc';
  static const _metaName = 'meta.enc';
  static const _licenseName = 'license.enc';

  static Future<BookContentTree?> readBookContent(String bookId) async {
    final blob = await vaultRead(bookId, _contentName);
    if (blob == null) return null;
    try {
      final map = await BookCrypto.openJson(blob);
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
    await vaultWrite(bookId, _contentName, await BookCrypto.sealJson(raw));
    if (meta != null && meta.title.trim().isNotEmpty) {
      await vaultWrite(bookId, _metaName, await BookCrypto.sealJson(meta.toJson()));
    }
  }

  static Future<BookCacheMeta?> readBookMeta(String bookId) async {
    final blob = await vaultRead(bookId, _metaName);
    if (blob == null) return null;
    try {
      final meta = BookCacheMeta.fromJson(await BookCrypto.openJson(blob));
      return meta.title.isEmpty ? null : meta;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeBookMeta(String bookId, BookCacheMeta meta) async {
    if (meta.title.trim().isEmpty) return;
    await vaultWrite(bookId, _metaName, await BookCrypto.sealJson(meta.toJson()));
  }

  static Future<bool> hasBookContent(String bookId) =>
      vaultExists(bookId, _contentName);

  static Future<List<String>> listCachedBookIds() => vaultListBookIds();

  static Future<int> cachedBookCount() async =>
      (await vaultListBookIds()).length;

  static Future<void> removeBookContent(String bookId) =>
      vaultDeleteBook(bookId);

  static Future<void> clearAll() => vaultClear();

  // --- Offline license (lease) -------------------------------------------

  static Future<void> writeLicense(String bookId, OfflineLicense lic) async {
    await vaultWrite(bookId, _licenseName, await BookCrypto.sealJson(lic.toJson()));
  }

  static Future<OfflineLicense?> readLicense(String bookId) async {
    final blob = await vaultRead(bookId, _licenseName);
    if (blob == null) return null;
    try {
      return OfflineLicense.fromJson(await BookCrypto.openJson(blob));
    } catch (_) {
      return null;
    }
  }

  /// Whether the book may be opened offline: a sealed, unexpired license issued
  /// to this device must be present.
  static Future<bool> hasValidOfflineAccess(
    String bookId, {
    required String deviceId,
  }) async {
    final lic = await readLicense(bookId);
    if (lic == null || lic.token.isEmpty) return false;
    if (lic.deviceId.isNotEmpty &&
        deviceId.isNotEmpty &&
        lic.deviceId != deviceId) {
      return false;
    }
    return !lic.isExpired;
  }
}
