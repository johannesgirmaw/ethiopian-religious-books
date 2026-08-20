import 'package:dio/dio.dart';
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

/// Resolves a local file (native) or URI (web) for [access].
Future<PdfViewerSource> resolvePdfViewerSource(
  Dio dio,
  PdfBookAccess access,
) async {
  final uri = Uri.parse(access.url);
  if (kIsWeb) {
    return PdfViewerSource.uri(uri);
  }
  final path = await pdf_cache.cachePdfFile(dio, access);
  return PdfViewerSource.file(path);
}
