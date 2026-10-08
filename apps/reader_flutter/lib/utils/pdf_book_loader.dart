import 'package:flutter/foundation.dart';

import '../config/dev_object_storage_origin.dart';
import 'pdf_cache_stub.dart'
    if (dart.library.io) 'pdf_cache_io.dart' as pdf_cache;

/// Access payload from ``GET /books/{id}/pdf``.
class PdfBookAccess {
  PdfBookAccess({
    required this.bookId,
    required this.url,
    required this.filename,
    required this.sizeBytes,
    required this.revisionId,
  });

  final String bookId;
  final String url;
  final String filename;
  final int sizeBytes;
  final String revisionId;

  factory PdfBookAccess.fromJson(Map<String, dynamic> j) {
    return PdfBookAccess(
      bookId: j['book_id'] as String? ?? '',
      url: rewriteDevObjectStorageUrl(j['url'] as String? ?? ''),
      filename: j['filename'] as String? ?? 'content.pdf',
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      revisionId: j['revision_id'] as String? ?? '',
    );
  }
}

/// Where the PDF viewer should load from.
class PdfViewerSource {
  PdfViewerSource.file(this.filePath)
      : uri = null,
        headers = null;
  PdfViewerSource.uri(this.uri, {this.headers}) : filePath = null;

  final String? filePath;
  final Uri? uri;
  final Map<String, String>? headers;
}

/// A cached file is usable only when it matches the published byte length.
bool isCompletePdfCache(int length, int expectedBytes) =>
    expectedBytes > 0 && length == expectedBytes;

/// Same-origin path the web app nginx proxies to ``GET /books/{id}/pdf/bytes``.
Uri webPdfProxyUri(String bookId) {
  return Uri.base.replace(
    path: '/pdf-proxy/$bookId',
    query: '',
    fragment: '',
  );
}

/// Resolves a local file when one is already complete, otherwise a URL the
/// viewer can fetch by byte range (page 1 before the rest of the file).
///
/// On web, prefer the same-origin proxy so the WASM engine can issue
/// synchronous Range requests (cross-origin sync XHR is blocked by browsers).
Future<PdfViewerSource> resolvePdfViewerSource(
  PdfBookAccess access, {
  String? accessToken,
}) async {
  if (kIsWeb) {
    final token = (accessToken ?? '').trim();
    if (token.isNotEmpty && access.bookId.isNotEmpty) {
      return PdfViewerSource.uri(
        webPdfProxyUri(access.bookId),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
    return PdfViewerSource.uri(Uri.parse(access.url));
  }

  final cached = await pdf_cache.cachedPdfPath(access);
  if (cached != null) return PdfViewerSource.file(cached);
  return PdfViewerSource.uri(Uri.parse(access.url));
}
