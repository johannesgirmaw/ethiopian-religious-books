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

String? publishErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    final err = data['error'] as Map;
    return err['message'] as String? ?? err['code'] as String?;
  }
  return null;
}
