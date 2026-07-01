import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bible_models.dart';
import 'api_client.dart';

/// Bible books, optionally filtered by testament ("old"/"new"; "" = all).
final bibleBooksProvider = FutureProvider.autoDispose
    .family<List<BibleBook>, String>((ref, testament) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'bible/books',
    queryParameters: testament.isEmpty ? null : {'testament': testament},
  );
  final raw = res.data?['items'] as List<dynamic>? ?? const [];
  return raw
      .map((e) => BibleBook.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// A book's chapter index (chapter numbers + verse/section counts).
final bibleBookIndexProvider = FutureProvider.autoDispose
    .family<BibleBookIndex, String>((ref, bookId) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('bible/books/$bookId/chapters');
  return BibleBookIndex.fromJson(res.data ?? const {});
});

/// Key for a single chapter request.
typedef BibleChapterRef = ({String bookId, int chapter});

/// A full chapter (sections + verses).
final bibleChapterProvider = FutureProvider.autoDispose
    .family<BibleChapter, BibleChapterRef>((ref, key) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'bible/books/${key.bookId}/chapters/${key.chapter}',
  );
  return BibleChapter.fromJson(res.data ?? const {});
});

/// Admin chapter index — works for draft (unpublished) books and returns an
/// empty list for a Bible book that has no content yet.
final adminBibleBookIndexProvider = FutureProvider.autoDispose
    .family<BibleBookIndex, String>((ref, bookId) async {
  final dio = ref.watch(apiDioProvider);
  final res =
      await dio.get<Map<String, dynamic>>('admin/bible/books/$bookId/chapters');
  return BibleBookIndex.fromJson(res.data ?? const {});
});

/// Admin chapter detail (any visibility).
final adminBibleChapterProvider = FutureProvider.autoDispose
    .family<BibleChapter, BibleChapterRef>((ref, key) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'admin/bible/books/${key.bookId}/chapters/${key.chapter}',
  );
  return BibleChapter.fromJson(res.data ?? const {});
});

/// Search key: query + testament scope ("" = all, "old", "new").
typedef BibleSearchKey = ({String query, String scope});

/// Full-text verse search across the Bible, optionally scoped to a testament.
final bibleSearchProvider = FutureProvider.autoDispose
    .family<BibleSearchResult, BibleSearchKey>((ref, key) async {
  final q = key.query.trim();
  if (q.length < 2) {
    return const BibleSearchResult(items: [], total: 0);
  }
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'bible/search',
    queryParameters: {
      'q': q,
      if (key.scope == 'old' || key.scope == 'new') 'testament': key.scope,
    },
  );
  return BibleSearchResult.fromJson(res.data ?? const {});
});

final bibleReferenceProvider = FutureProvider.autoDispose
    .family<BibleReference?, String>((ref, query) async {
  return ref.watch(bibleRepositoryProvider).resolveReference(query);
});

class BibleRepository {
  BibleRepository(this._dio);
  final Dio _dio;

  /// Admin: replace a chapter's sections + verses.
  /// [sections] is `[{title, verses: [{verse, text}]}]`.
  Future<void> saveChapter(
    String bookId,
    int chapter,
    List<Map<String, dynamic>> sections,
  ) async {
    await _dio.put<Map<String, dynamic>>(
      'admin/bible/books/$bookId/chapters/$chapter',
      data: {'sections': sections},
    );
  }

  Future<BibleReference?> resolveReference(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'bible/reference',
        queryParameters: {'q': q},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        return BibleReference.fromJson(res.data!);
      }
    } catch (_) {
      // fall through
    }
    return null;
  }
}

final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(ref.watch(apiDioProvider));
});
