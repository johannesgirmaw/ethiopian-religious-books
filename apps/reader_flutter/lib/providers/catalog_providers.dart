import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/dev_object_storage_origin.dart';
import '../models/book_models.dart';
import '../models/download_payload.dart';
import '../models/offline_cached_book.dart';
import '../security/device_identity.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/catalog_cache_storage.dart';
import '../storage/reader_prefs_storage.dart';
import '../storage/secure_book_store.dart';
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

/// A dynamic book category from the `/genres` lookup table.
class GenreOption {
  const GenreOption({
    required this.slug,
    required this.label,
    this.labelAm,
    this.icon,
  });

  final String slug;
  final String label;
  final String? labelAm;
  final String? icon;

  factory GenreOption.fromJson(Map<String, dynamic> j) => GenreOption(
        slug: j['slug'] as String? ?? '',
        label: j['label'] as String? ?? '',
        labelAm: j['label_am'] as String?,
        icon: j['icon'] as String?,
      );
}

/// Available book genres/categories (managed server-side).
final genresProvider = FutureProvider.autoDispose<List<GenreOption>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('genres');
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => GenreOption.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// A reusable tag from the `/tags` lookup.
class TagOption {
  const TagOption({required this.slug, required this.label});

  final String slug;
  final String label;

  factory TagOption.fromJson(Map<String, dynamic> j) => TagOption(
        slug: j['slug'] as String? ?? '',
        label: j['label'] as String? ?? '',
      );
}

/// Existing tags, for the admin tag picker.
final tagsProvider = FutureProvider.autoDispose<List<TagOption>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('tags');
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => TagOption.fromJson(e as Map<String, dynamic>))
      .toList();
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
          ...devObjectStorageOriginHeaders(),
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
  final fallback = await dio.get<Map<String, dynamic>>(
    'books',
    options: Options(headers: devObjectStorageOriginHeaders()),
  );
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
          // While online, renew a downloaded book's lease if it's near expiry.
          // A revoked/refunded purchase fails renewal and loses offline access.
          await _maybeRenewOfflineLicense(dio, bookId);
          return remote;
        }
        // API can return empty when content index is off or revision is missing;
        // prefer a non-empty local cache so chapters/pages still render.
        if (cached != null && cached.chapters.isNotEmpty) {
          return cached;
        }
        return remote;
      } catch (_) {
        // Offline: only serve the encrypted cache if a valid, this-device
        // offline license is present. Without one (e.g. never downloaded, or the
        // lease lapsed), reading offline is not permitted.
        if (cached != null && cached.chapters.isNotEmpty) {
          final deviceId = await DeviceIdentity.deviceId();
          final allowed = await SecureBookStore.hasValidOfflineAccess(
            bookId,
            deviceId: deviceId,
          );
          if (allowed) return cached;
        }
        rethrow;
      }
    });

/// Best-effort silent lease renewal. If the user still owns the book the lease is
/// extended; if the purchase was revoked the server returns 403 and we drop the
/// stored license so offline access stops at the current lease's expiry.
Future<void> _maybeRenewOfflineLicense(Dio dio, String bookId) async {
  try {
    final existing = await SecureBookStore.readLicense(bookId);
    if (existing == null || !existing.needsRenewal()) return;
    final deviceId = await DeviceIdentity.deviceId();
    final res = await dio.post<Map<String, dynamic>>(
      'books/$bookId/license',
      data: {'device_id': deviceId},
    );
    final lic = (res.data?['license'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final token = (lic['token'] as String?)?.trim() ?? '';
    if (token.isEmpty) return;
    final expiresIso = lic['expires_at'] as String?;
    final expiresMs = expiresIso != null
        ? (DateTime.tryParse(expiresIso)?.millisecondsSinceEpoch ??
            existing.expiresAtEpochMs)
        : existing.expiresAtEpochMs;
    await SecureBookStore.writeLicense(
      bookId,
      OfflineLicense(
        token: token,
        deviceId: deviceId,
        expiresAtEpochMs: expiresMs,
        revisionId: res.data?['revision_id'] as String? ?? existing.revisionId,
      ),
    );
  } on DioException catch (e) {
    // Entitlement revoked -> stop renewing and revoke local offline access.
    if (e.response?.statusCode == 403) {
      await SecureBookStore.writeLicense(
        bookId,
        OfflineLicense(token: '', deviceId: '', expiresAtEpochMs: 0),
      );
    }
  } catch (_) {
    // Transient/offline — leave the existing license untouched.
  }
}

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
  final res = await dio.get<Map<String, dynamic>>(
    'books/$bookId',
    options: Options(headers: devObjectStorageOriginHeaders()),
  );
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

