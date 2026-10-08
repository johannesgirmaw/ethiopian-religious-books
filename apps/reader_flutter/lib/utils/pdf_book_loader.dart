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
///
/// [revisionId] is only for Cache API keying (stale-revision avoidance); the
/// API ignores it. Auth stays in the ``Authorization`` header, never the URL.
Uri webPdfProxyUri(String bookId, {String revisionId = ''}) {
  final rev = revisionId.trim();
  return Uri.base.replace(
    path: '/pdf-proxy/$bookId',
    queryParameters: rev.isEmpty ? const <String, String>{} : {'r': rev},
    fragment: '',
  );
}

/// Resolves a local file when one is already complete, otherwise a URL the
/// viewer can fetch.
///
/// Web always uses the authenticated same-origin proxy (never a MinIO URL).
/// Native prefers a complete local cache, else a short-lived presigned URL.
Future<PdfViewerSource> resolvePdfViewerSource(
  PdfBookAccess access, {
  String? accessToken,
}) async {
  if (kIsWeb) {
    final token = (accessToken ?? '').trim();
    if (token.isEmpty || access.bookId.isEmpty) {
      throw StateError('PDF open requires a signed-in session on web.');
    }
    return PdfViewerSource.uri(
      webPdfProxyUri(access.bookId, revisionId: access.revisionId),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  final cached = await pdf_cache.cachedPdfPath(access);
  if (cached != null) return PdfViewerSource.file(cached);
  final url = access.url.trim();
  if (url.isEmpty) {
    throw StateError('PDF open requires a download URL on this platform.');
  }
  return PdfViewerSource.uri(Uri.parse(url));
}
