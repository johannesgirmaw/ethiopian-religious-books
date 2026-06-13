import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/dev_object_storage_origin.dart';
import '../models/book_models.dart';
import '../models/download_payload.dart';
import '../models/offline_cached_book.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/catalog_cache_storage.dart';
import '../storage/reader_prefs_storage.dart';
import 'api_client.dart';

class CatalogBookMeta {
  const CatalogBookMeta({
    this.chapterCount,
    this.progress = 0,
    this.offlineCached = false,
  });

  final int? chapterCount;
  final double progress;
  final bool offlineCached;
}

final catalogBookMetaProvider =
    FutureProvider.autoDispose.family<CatalogBookMeta, String>((ref, bookId) async {
  int? chapterCount;
  final cached = await BookContentCacheStorage.readBookContent(bookId);
  if (cached != null && cached.chapters.isNotEmpty) {
    chapterCount = cached.chapters.length;
  } else {
    try {
      final chapters = await ref.watch(bookChaptersProvider(bookId).future);
      if (chapters.isNotEmpty) chapterCount = chapters.length;
    } catch (_) {}
  }

  final progress = await ReaderPrefsStorage.readProgress(bookId);
  final offline = await ref.watch(offlineBookCachedProvider(bookId).future);

  return CatalogBookMeta(
    chapterCount: chapterCount,
    progress: progress,
    offlineCached: offline,
  );
});

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
          BookCacheMeta? meta;
          try {
            final catalog = await ref.read(catalogProvider.future);
            for (final b in catalog.items) {
              if (b.id == bookId) {
                meta = BookCacheMeta(
                  title: b.title,
                  authorCompiler: b.authorCompiler,
                  primaryLanguage: b.primaryLanguage,
                );
                break;
              }
            }
          } catch (_) {}
          await BookContentCacheStorage.writeBookContent(
            bookId,
            payload,
            meta: meta,
          );
          return remote;
        }
        // API can return empty when content index is off or revision is missing;
        // prefer a non-empty local cache so chapters/pages still render.
        if (cached != null && cached.chapters.isNotEmpty) {
          return cached;
        }
        return remote;
      } catch (_) {
        if (cached != null && cached.chapters.isNotEmpty) return cached;
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
  final res = await dio.get<Map<String, dynamic>>(
    'books/$id/download',
    options: Options(headers: devObjectStorageOriginHeaders()),
  );
  return DownloadPayload.fromJson(res.data!);
});

final catalogCachedAtProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  return CatalogCacheStorage.readSavedAt();
});

/// Resolves book metadata: catalog → local meta → cached content → API.
Future<BookSummary> resolveBookSummary(
  Ref ref,
  String bookId,
) async {
  try {
    final catalog = await ref.read(catalogProvider.future);
    final match = catalog.items.where((b) => b.id == bookId).toList();
    if (match.isNotEmpty) return match.first;
  } catch (_) {}

  final meta = await BookContentCacheStorage.readBookMeta(bookId);
  final cached = await BookContentCacheStorage.readBookContent(bookId);
  if (meta != null && meta.title.isNotEmpty) {
    return BookSummary(
      id: bookId,
      title: meta.title,
      authorCompiler: meta.authorCompiler,
      primaryLanguage: meta.primaryLanguage,
    );
  }
  if (cached != null && cached.chapters.isNotEmpty) {
    final inferred = BookContentCacheStorage.titleFromContentTree(cached);
    return BookSummary(
      id: bookId,
      title: inferred ?? bookId,
      primaryLanguage: null,
    );
  }

  final dio = ref.read(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('books/$bookId');
  final book = BookSummary.fromJson(res.data!);
  await BookContentCacheStorage.writeBookMeta(
    bookId,
    BookCacheMeta(
      title: book.title,
      authorCompiler: book.authorCompiler,
      primaryLanguage: book.primaryLanguage,
      savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  return book;
}

final bookDetailProvider =
    FutureProvider.autoDispose.family<BookSummary, String>((ref, id) async {
  return resolveBookSummary(ref, id);
});

final offlineDownloadsListProvider =
    FutureProvider.autoDispose<List<OfflineCachedBook>>((ref) async {
  final ids = await BookContentCacheStorage.listCachedBookIds();
  if (ids.isEmpty) return const [];

  var catalogById = <String, BookSummary>{};
  try {
    final catalog = await ref.watch(catalogProvider.future);
    catalogById = {for (final b in catalog.items) b.id: b};
  } catch (_) {}

  final rows = <OfflineCachedBook>[];
  for (final id in ids) {
    final tree = await BookContentCacheStorage.readBookContent(id);
    final meta = await BookContentCacheStorage.readBookMeta(id);
    final catalogBook = catalogById[id];
    final chapterCount = tree?.chapters.length ?? 0;
    final pageCount = tree?.chapters.fold<int>(
          0,
          (sum, c) => sum + c.pages.length,
        ) ??
        0;
    final hasReadable = chapterCount > 0 && pageCount > 0;

    String title;
    String? author;
    String? language;
    if (catalogBook != null) {
      title = catalogBook.title;
      author = catalogBook.authorCompiler;
      language = catalogBook.primaryLanguage;
    } else if (meta != null && meta.title.isNotEmpty) {
      title = meta.title;
      author = meta.authorCompiler;
      language = meta.primaryLanguage;
    } else {
      title = BookContentCacheStorage.titleFromContentTree(tree) ?? id;
    }

    if (catalogBook != null &&
        (meta == null || meta.title.isEmpty || meta.title == id)) {
      await BookContentCacheStorage.writeBookMeta(
        id,
        BookCacheMeta(
          title: catalogBook.title,
          authorCompiler: catalogBook.authorCompiler,
          primaryLanguage: catalogBook.primaryLanguage,
          savedAtEpochMs: meta?.savedAtEpochMs,
        ),
      );
    }

    rows.add(
      OfflineCachedBook(
        id: id,
        title: title,
        authorCompiler: author,
        primaryLanguage: language,
        chapterCount: chapterCount,
        pageCount: pageCount,
        hasReadableContent: hasReadable,
        inCatalog: catalogBook != null,
        catalogBook: catalogBook,
        savedAtEpochMs: meta?.savedAtEpochMs,
      ),
    );
  }
  rows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return rows;
});

