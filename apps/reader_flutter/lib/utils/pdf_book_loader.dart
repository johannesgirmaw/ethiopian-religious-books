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
  PdfViewerSource.file(this.filePath) : uri = null;
  PdfViewerSource.uri(this.uri) : filePath = null;

  final String? filePath;
  final Uri? uri;
}

/// A cached file is usable only when it matches the published byte length.
bool isCompletePdfCache(int length, int expectedBytes) =>
    expectedBytes > 0 && length == expectedBytes;

/// Resolves a local file when one is already complete, otherwise the presigned
/// URL so the viewer can fetch page 1 by byte range.
Future<PdfViewerSource> resolvePdfViewerSource(PdfBookAccess access) async {
  final uri = Uri.parse(access.url);
  if (!kIsWeb) {
    final cached = await pdf_cache.cachedPdfPath(access);
    if (cached != null) return PdfViewerSource.file(cached);
  }
  return PdfViewerSource.uri(uri);
}

