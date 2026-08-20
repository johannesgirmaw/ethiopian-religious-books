import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'pdf_book_loader.dart';

Future<String> cachePdfFile(Dio dio, PdfBookAccess access) async {
  final dir = await getTemporaryDirectory();
  final safeName = access.filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final path =
      '${dir.path}/pdf_${access.bookId}_${access.revisionId}_$safeName';
  final file = File(path);
  if (await file.exists() && access.sizeBytes > 0) {
    final len = await file.length();
    if (len == access.sizeBytes) {
      return path;
    }
  }

  final plain = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 5),
      responseType: ResponseType.bytes,
    ),
  );
  final res = await plain.get<List<int>>(access.url);
  final bytes = res.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Empty PDF download');
  }
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
