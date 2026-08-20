import 'package:dio/dio.dart';

import 'pdf_book_loader.dart';

Future<String> cachePdfFile(Dio dio, PdfBookAccess access) async {
  throw UnsupportedError('Local PDF cache is not available on this platform');
}
