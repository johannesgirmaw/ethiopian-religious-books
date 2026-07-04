import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_book.dart';
import 'api_client.dart';

final adminBooksProvider = FutureProvider.autoDispose<AdminBooksPage>((ref) async {
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('admin/books');
    return AdminBooksPage.fromJson(res.data!);
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    // Keep admin UI usable while backend migrations/setup are in progress.
    if (status == 500 || status == 503) {
      return AdminBooksPage(items: const [], total: 0);
    }
    rethrow;
  }
});

Future<AdminBook?> fetchAdminBookByDio(Dio dio, String id) async {
  try {
    final res = await dio.get<Map<String, dynamic>>('admin/books/$id');
    final data = res.data;
    if (data == null) return null;
    return AdminBook.fromJson(data);
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status == 404 || status == 500 || status == 503) return null;
    rethrow;
  }
}

Future<AdminBook?> fetchAdminBookById(Ref ref, String id) =>
    fetchAdminBookByDio(ref.read(apiDioProvider), id);

/// Summary of one detection mode from the import preview (dry-run).
class ImportModeSummary {
  ImportModeSummary({
    required this.mode,
    required this.strategyUsed,
    required this.chapters,
    required this.pages,
    required this.titles,
  });

  final String mode;
  final String strategyUsed;
  final int chapters;
  final int pages;
  final List<String> titles;

  factory ImportModeSummary.fromJson(Map<String, dynamic> j) {
    final rawTitles = j['titles'];
    return ImportModeSummary(
      mode: j['mode'] as String? ?? '',
      strategyUsed: j['strategy_used'] as String? ?? '',
      chapters: (j['chapters'] as num?)?.toInt() ?? 0,
      pages: (j['pages'] as num?)?.toInt() ?? 0,
      titles: rawTitles is List
          ? rawTitles.map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

/// Detected structure across all modes, returned by the import preview.
class ImportPreview {
  ImportPreview({required this.recommended, required this.modes});

  final String recommended;
  final List<ImportModeSummary> modes;

  ImportModeSummary? forMode(String mode) {
    for (final m in modes) {
      if (m.mode == mode) return m;
    }
    return null;
  }

  factory ImportPreview.fromJson(Map<String, dynamic> j) {
    final rawModes = j['modes'];
    final modes = rawModes is List
        ? rawModes
            .whereType<Map>()
            .map((e) => ImportModeSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ImportModeSummary>[];
    return ImportPreview(
      recommended: j['recommended'] as String? ?? 'auto',
      modes: modes,
    );
  }
}

FormData _docxForm(
  List<int> bytes,
  String filename, {
  String? mode,
  String? pattern,
  String? marker,
  String? title,
  String? language,
  String? genre,
}) {
  return FormData.fromMap({
    'file': MultipartFile.fromBytes(bytes, filename: filename),
    if (mode != null && mode.isNotEmpty) 'mode': mode,
    if (pattern != null && pattern.trim().isNotEmpty) 'pattern': pattern.trim(),
    if (marker != null && marker.trim().isNotEmpty) 'marker': marker.trim(),
    if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    if (language != null && language.trim().isNotEmpty)
      'primary_language': language.trim(),
    if (genre != null && genre.trim().isNotEmpty) 'genre': genre.trim(),
  });
}

/// Dry-run: parses a Word (.docx) file and returns the structure detected for
/// every mode, without creating a book. Lets the user compare strategies first.
Future<ImportPreview> previewBookImportDocx(
  Dio dio, {
  required List<int> bytes,
  required String filename,
  String? pattern,
  String? marker,
}) async {
  final res = await dio.post<Map<String, dynamic>>(
    'admin/books/import-docx/preview',
    data: _docxForm(bytes, filename, pattern: pattern, marker: marker),
    options: Options(contentType: 'multipart/form-data'),
  );
  return ImportPreview.fromJson(res.data!);
}

/// Uploads a Word (.docx) file and returns the created draft [AdminBook].
///
/// The backend parses the document into chapters/pages using [mode] (optionally
/// a custom [pattern] or [marker]) and creates a hidden (draft) book; the caller
/// then opens the editor to review and publish.
Future<AdminBook> importBookFromDocx(
  Dio dio, {
  required List<int> bytes,
  required String filename,
  String? mode,
  String? pattern,
  String? marker,
  String? title,
  String? language,
  String? genre,
}) async {
  final res = await dio.post<Map<String, dynamic>>(
    'admin/books/import-docx',
    data: _docxForm(
      bytes,
      filename,
      mode: mode,
      pattern: pattern,
      marker: marker,
      title: title,
      language: language,
      genre: genre,
    ),
    options: Options(contentType: 'multipart/form-data'),
  );
  return AdminBook.fromJson(res.data!);
}

String? publishErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    final err = data['error'] as Map;
    return err['message'] as String? ?? err['code'] as String?;
  }
  return null;
}
