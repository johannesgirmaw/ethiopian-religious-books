import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/author_application.dart';
import 'api_client.dart';

/// Endpoints for the author-application feature: a reader's own application and
/// the platform-admin review queue. Mirrors [AuthApi] — a thin service class over
/// [apiDioProvider], surfaced to widgets via Riverpod providers below.
class AuthorApplicationApi {
  AuthorApplicationApi(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(apiDioProvider);

  // --- Applicant ---------------------------------------------------------

  Future<MyAuthorApplication> fetchMine() async {
    final res = await _dio.get<Map<String, dynamic>>('author/application');
    return MyAuthorApplication.fromJson(res.data ?? const {});
  }

  /// Creates (POST) or edits (PATCH) the caller's application and returns it.
  Future<AuthorApplication> submit(
    AuthorApplication application, {
    bool partial = false,
  }) async {
    final payload = application.toPayload();
    final res = partial
        ? await _dio.patch<Map<String, dynamic>>(
            'author/application',
            data: payload,
          )
        : await _dio.post<Map<String, dynamic>>(
            'author/application',
            data: payload,
          );
    return AuthorApplication.fromJson(res.data!);
  }

  /// Uploads [bytes] as the applicant's photo (presign -> direct PUT), attaches
  /// the resulting object key to their application, and returns the key.
  Future<String> uploadPhoto(Uint8List bytes, String mime) async {
    final pres = await _dio.post<Map<String, dynamic>>(
      'author/application/photo/presign',
      data: {'content_type': mime},
    );
    final putUrl = pres.data?['put_url'] as String?;
    final objectKey = pres.data?['object_key'] as String?;
    if (putUrl == null || objectKey == null) {
      throw StateError('Presign response missing put_url/object_key');
    }
    // Raw PUT to object storage with a bare Dio (no auth interceptor), like the
    // book-cover upload.
    final plain = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    await plain.put<dynamic>(
      putUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': mime}),
    );
    await _dio.patch<Map<String, dynamic>>(
      'author/application',
      data: {'photo_object_key': objectKey},
    );
    return objectKey;
  }

  // --- Admin review ------------------------------------------------------

  Future<AuthorApplicationsPage> listApplications() async {
    final res =
        await _dio.get<Map<String, dynamic>>('admin/author-applications');
    return AuthorApplicationsPage.fromJson(res.data ?? const {});
  }

  Future<AuthorApplication> approve(String id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'admin/author-applications/$id/approve',
    );
    return AuthorApplication.fromJson(res.data!);
  }

  Future<AuthorApplication> reject(String id, {String note = ''}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'admin/author-applications/$id/reject',
      data: {'note': note},
    );
    return AuthorApplication.fromJson(res.data!);
  }
}

final authorApplicationApiProvider =
    Provider<AuthorApplicationApi>((ref) => AuthorApplicationApi(ref));

/// The signed-in user's own application (or null) + whether they're an author.
final myAuthorApplicationProvider =
    FutureProvider.autoDispose<MyAuthorApplication>((ref) async {
  return ref.read(authorApplicationApiProvider).fetchMine();
});

/// The platform-admin review queue. Tolerates backend setup errors so the admin
/// UI stays usable (mirrors [adminBooksProvider]).
final adminAuthorApplicationsProvider =
    FutureProvider.autoDispose<AuthorApplicationsPage>((ref) async {
  try {
    return await ref.read(authorApplicationApiProvider).listApplications();
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status == 500 || status == 503) {
      return AuthorApplicationsPage(items: const [], pending: 0);
    }
    rethrow;
  }
});
