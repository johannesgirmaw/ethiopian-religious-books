import 'package:flutter/foundation.dart';

import '../config/dev_object_storage_origin.dart';
import 'pdf_cache_stub.dart'
    if (dart.library.io) 'pdf_cache_io.dart'
    as pdf_cache;

/// Access payload from ``GET /books/{id}/pdf``.
class PdfBookAccess {
  PdfBookAccess({
    required this.bookId,
    required this.url,
    required this.filename,
    required this.sizeBytes,
    required this.revisionId,
    this.linearized = false,
  });

  final String bookId;
  final String url;
  final String filename;
  final int sizeBytes;
  final String revisionId;

  /// True when the stored PDF is Fast Web View (linearized). Web uses this to
  /// enable HTTP Range first-page paint; non-linearized web falls back to a
  /// full download to avoid blank page 1 on scanned books.
  final bool linearized;

  factory PdfBookAccess.fromJson(Map<String, dynamic> j) {
    return PdfBookAccess(
      bookId: j['book_id'] as String? ?? '',
      url: rewriteDevObjectStorageUrl(j['url'] as String? ?? ''),
      filename: j['filename'] as String? ?? 'content.pdf',
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      revisionId: j['revision_id'] as String? ?? '',
      linearized: j['linearized'] == true,
    );
  }
}

/// Copies plaintext into [buffer] starting at [position]. Returns the number
/// of bytes written.
typedef PdfByteReader =
    Future<int> Function(Uint8List buffer, int position, int size);

/// Where the PDF viewer should load from.
class PdfViewerSource {
  PdfViewerSource.file(this.filePath)
    : uri = null,
      bytes = null,
      fileSize = null,
      read = null,
      sourceName = null,
      headers = null,
      preferRangeAccess = true;
  PdfViewerSource.uri(this.uri, {this.headers, this.preferRangeAccess = true})
    : filePath = null,
      bytes = null,
      fileSize = null,
      read = null,
      sourceName = null;
  PdfViewerSource.data(this.bytes, {required this.sourceName})
    : filePath = null,
      uri = null,
      fileSize = null,
      read = null,
      headers = null,
      preferRangeAccess = true;

  /// Offline vault. [read] decrypts only the requested range.
  PdfViewerSource.range({
    required this.fileSize,
    required this.read,
    required this.sourceName,
  }) : filePath = null,
       uri = null,
       bytes = null,
       headers = null,
       preferRangeAccess = true;

  final String? filePath;
  final Uri? uri;

  /// Decrypted PDF bytes already in memory. Offline books use [read] instead.
  final Uint8List? bytes;

  /// Plaintext length for [read].
  final int? fileSize;
  final PdfByteReader? read;

  /// Stable id for [PdfViewer.data] and [PdfViewer.custom].
  final String? sourceName;
  final Map<String, String>? headers;

  /// When false on web, the worker does a full download (safer for scanned,
  /// non-linearized PDFs that blank page 1 under live Range/GetBlock).
  final bool preferRangeAccess;
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
    // Range/first-page only when the blob is linearized. Otherwise full GET.
    return PdfViewerSource.uri(
      webPdfProxyUri(access.bookId, revisionId: access.revisionId),
      headers: {'Authorization': 'Bearer $token'},
      preferRangeAccess: access.linearized,
    );
  }

  final cached = await pdf_cache.cachedPdfPath(access);
  if (cached != null) return PdfViewerSource.file(cached);
  final url = access.url.trim();
  if (url.isEmpty) {
    throw StateError('PDF open requires a download URL on this platform.');
  }
  return PdfViewerSource.uri(Uri.parse(url), preferRangeAccess: true);
}
