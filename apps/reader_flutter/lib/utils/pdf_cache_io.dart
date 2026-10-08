import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pdf_book_loader.dart';

/// Returns a finished local copy of [access], or null when the reader should
/// stream the PDF by byte range instead of waiting for the whole file.
Future<String?> cachedPdfPath(PdfBookAccess access) async {
  final dir = await getTemporaryDirectory();
  final safeName = access.filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final file = File(
    '${dir.path}/pdf_${access.bookId}_${access.revisionId}_$safeName',
  );
  if (!await file.exists()) return null;
  final length = await file.length();
  if (!isCompletePdfCache(length, access.sizeBytes)) {
    try {
      await file.delete();
    } catch (_) {}
    return null;
  }
  return file.path;
}
