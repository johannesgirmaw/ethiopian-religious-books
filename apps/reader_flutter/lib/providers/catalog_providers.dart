import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book_models.dart';
import '../models/download_payload.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/catalog_cache_storage.dart';
import 'api_client.dart';

final catalogProvider = FutureProvider.autoDispose<CatalogPage>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final cached = await CatalogCacheStorage.readCatalog();
  final etag = await CatalogCacheStorage.readEtag();
  try {
    final res = await dio.get<Map<String, dynamic>>(
      'sync/catalog',
      options: Options(
        headers: {
          if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (res.statusCode == 304 && cached != null) {
      return cached;
    }
    if (res.data != null && res.statusCode == 200) {
      await CatalogCacheStorage.writeCatalog(
        raw: res.data!,
        etag: res.headers.value('etag'),
      );
      return CatalogPage.fromJson(res.data!);
    }
  } catch (_) {
    if (cached != null) return cached;
    rethrow;
  }
  if (cached != null) return cached;
  final fallback = await dio.get<Map<String, dynamic>>('books');
  await CatalogCacheStorage.writeCatalog(
    raw: fallback.data!,
    etag: fallback.headers.value('etag'),
  );
  return CatalogPage.fromJson(fallback.data!);
});

final bookDetailProvider =
    FutureProvider.autoDispose.family<BookSummary, String>((ref, id) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('books/$id');
  return BookSummary.fromJson(res.data!);
});

class CatalogSearchFilters {
  const CatalogSearchFilters({
    this.query = '',
    this.chapter,
    this.page,
  });

  final String query;
  final String? chapter;
  final int? page;
}

final catalogSearchProvider = FutureProvider.autoDispose
    .family<CatalogPage, CatalogSearchFilters>((ref, filters) async {
      final dio = ref.watch(apiDioProvider);
      final params = <String, dynamic>{};
      if (filters.query.trim().isNotEmpty) params['q'] = filters.query.trim();
      if ((filters.chapter ?? '').trim().isNotEmpty) {
        params['chapter'] = filters.chapter!.trim();
      }
      if (filters.page != null && filters.page! > 0) params['page'] = filters.page;
      final res = await dio.get<Map<String, dynamic>>('books', queryParameters: params);
      return CatalogPage.fromJson(res.data!);
    });

final bookChaptersProvider = FutureProvider.autoDispose
    .family<List<BookChapter>, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>('books/$bookId/chapters');
      final raw = res.data?['items'] as List<dynamic>? ?? const [];
      return raw.map((e) => BookChapter.fromJson(e as Map<String, dynamic>)).toList();
    });

class BookSearchFilters {
  const BookSearchFilters({
    required this.bookId,
    required this.query,
    this.chapter,
    this.page,
  });

  final String bookId;
  final String query;
  final String? chapter;
  final int? page;
}

final bookSearchProvider = FutureProvider.autoDispose
    .family<List<BookSearchHit>, BookSearchFilters>((ref, filters) async {
      final dio = ref.watch(apiDioProvider);
      final params = <String, dynamic>{};
      if (filters.query.trim().isNotEmpty) params['q'] = filters.query.trim();
      if ((filters.chapter ?? '').trim().isNotEmpty) {
        params['chapter'] = filters.chapter!.trim();
      }
      if (filters.page != null && filters.page! > 0) params['page'] = filters.page;
      final res = await dio.get<Map<String, dynamic>>(
        'books/${filters.bookId}/search',
        queryParameters: params,
      );
      final raw = res.data?['items'] as List<dynamic>? ?? const [];
      return raw
          .map((e) => BookSearchHit.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final bookContentProvider = FutureProvider.autoDispose
    .family<BookContentTree, String>((ref, bookId) async {
      final dio = ref.watch(apiDioProvider);
      final cached = await BookContentCacheStorage.readBookContent(bookId);
      try {
        final res = await dio.get<Map<String, dynamic>>('books/$bookId/content');
        final payload = res.data ?? const <String, dynamic>{};
        final remote = BookContentTree.fromJson(payload);
        if (remote.chapters.isNotEmpty) {
          await BookContentCacheStorage.writeBookContent(bookId, payload);
          return remote;
        }
        // API can return empty when content index is off or revision is missing;
        // prefer a non-empty local cache so chapters/pages still render.
        if (cached != null && cached.chapters.isNotEmpty) {
          return cached;
        }
        return remote;
      } catch (_) {
        if (cached != null) return cached;
        rethrow;
      }
    });

final offlineBookCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return BookContentCacheStorage.cachedBookCount();
});

final offlineBookCachedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, bookId) async {
      return BookContentCacheStorage.hasBookContent(bookId);
    });

final downloadInfoProvider =
    FutureProvider.autoDispose.family<DownloadPayload, String>((ref, id) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('books/$id/download');
  return DownloadPayload.fromJson(res.data!);
});

final catalogCachedAtProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  return CatalogCacheStorage.readSavedAt();
});
