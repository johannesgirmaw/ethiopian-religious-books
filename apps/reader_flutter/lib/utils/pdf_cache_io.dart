import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pdf_book_loader.dart';

File _cacheFileFor(Directory dir, PdfBookAccess access) {
  final safeName = access.filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  return File(
    '${dir.path}/pdf_${access.bookId}_${access.revisionId}_$safeName',
  );
}

/// Returns a finished local copy of [access], or null.
///
/// Plaintext temp-dir caching is disabled for security (ciphertext belongs in
/// [SecureBookStore] only). This still recognizes leftover files so
/// [clearNativePdfTempCache] can remove them.
Future<String?> cachedPdfPath(PdfBookAccess access) async {
  final dir = await getTemporaryDirectory();
  final file = _cacheFileFor(dir, access);
  if (!await file.exists()) return null;
  return file.path;
}

/// Formerly downloaded [uri] into the OS temp directory as plaintext.
///
/// That path defeated encryption-at-rest. Online opens now stream from the
/// network URI (or the sealed vault when offline). This no-op remains so
/// callers compile; it never writes disk.
Future<void> cachePdfFromNetwork(
  PdfBookAccess access,
  Uri uri, {
  Map<String, String>? headers,
}) async {}

/// Delete plaintext PDF leftovers under the OS temp directory.
///
/// When [bookId] is set, only that book's `pdf_{bookId}_*` files are removed.
/// Otherwise every `pdf_*` cache file from this app is wiped (logout).
Future<void> clearNativePdfTempCache({String? bookId}) async {
  try {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) return;
    final prefix = bookId == null || bookId.isEmpty
        ? 'pdf_'
        : 'pdf_${bookId}_';
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      if (!name.startsWith(prefix)) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  } catch (_) {
    // Best-effort: never block sign-out or entitlement revoke on cleanup.
  }
}
