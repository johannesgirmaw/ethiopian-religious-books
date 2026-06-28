import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book_models.dart';
import 'api_client.dart';
import 'catalog_providers.dart';

// ─── Recommendations (client-side from the catalog) ──────────────────────────

/// Books recommended on the home screen, scored by popularity + rating.
/// There is no server recommender yet; this derives a sensible ranking from
/// readers count and the rating signal.
final recommendedBooksProvider =
    FutureProvider.autoDispose<List<BookSummary>>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  final books = [...catalog.items];
  double score(BookSummary b) =>
      b.readersCount + b.ratingAverage * b.ratingCount * 2;
  books.sort((a, b) => score(b).compareTo(score(a)));
  return books.take(10).toList();
});

/// Books flagged `is_featured` for the home "Popular" carousel. Falls back to
/// the first few catalog books when nothing is flagged yet.
final featuredBooksProvider =
    FutureProvider.autoDispose<List<BookSummary>>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  final featured = catalog.items.where((b) => b.isFeatured).toList();
  if (featured.isNotEmpty) return featured;
  return catalog.items.take(5).toList();
});

/// Catalog books sharing an author (for author pages), case-insensitive.
final booksByAuthorProvider = FutureProvider.autoDispose
    .family<List<BookSummary>, String>((ref, author) async {
  final catalog = await ref.watch(catalogProvider.future);
  final needle = author.trim().toLowerCase();
  return catalog.items
      .where((b) => (b.authorCompiler ?? '').trim().toLowerCase() == needle)
      .toList();
});

// ─── Favourites ──────────────────────────────────────────────────────────────

/// Set of book ids the current user has favourited.
final favouriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('study/favourites');
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return {
    for (final e in items) (e as Map<String, dynamic>)['book'] as String,
  };
});

/// Adds or removes a favourite, then refreshes [favouriteIdsProvider].
Future<void> setFavourite(WidgetRef ref, String bookId, {required bool add}) async {
  final dio = ref.read(apiDioProvider);
  if (add) {
    await dio.post<Map<String, dynamic>>(
      'study/favourites',
      data: {'book': bookId},
    );
  } else {
    await dio.delete<void>('study/favourites/$bookId');
  }
  ref.invalidate(favouriteIdsProvider);
}

// ─── Reviews ─────────────────────────────────────────────────────────────────

class BookReview {
  const BookReview({
    required this.id,
    required this.rating,
    required this.body,
    required this.userName,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String body;
  final String userName;
  final DateTime? createdAt;

  factory BookReview.fromJson(Map<String, dynamic> j) => BookReview(
        id: j['id'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        body: j['body'] as String? ?? '',
        userName: j['user_name'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

final bookReviewsProvider = FutureProvider.autoDispose
    .family<List<BookReview>, String>((ref, bookId) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'study/reviews',
    queryParameters: {'book': bookId},
  );
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => BookReview.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Upserts the current user's review for a book.
Future<void> submitReview(
  WidgetRef ref,
  String bookId, {
  required int rating,
  String body = '',
}) async {
  final dio = ref.read(apiDioProvider);
  await dio.post<Map<String, dynamic>>(
    'study/reviews',
    data: {'book': bookId, 'rating': rating, 'body': body},
  );
  ref.invalidate(bookReviewsProvider(bookId));
}

// ─── Notifications ───────────────────────────────────────────────────────────

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.bookId,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? bookId;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? 'info',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        bookId: j['book'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

class NotificationsResult {
  const NotificationsResult({required this.items, required this.unread});

  final List<AppNotification> items;
  final int unread;
}

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsResult>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('study/notifications');
  final items = (res.data?['items'] as List<dynamic>? ?? const [])
      .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
      .toList();
  final unread = (res.data?['unread'] as num?)?.toInt() ?? 0;
  return NotificationsResult(items: items, unread: unread);
});

/// Lightweight unread-count provider for the bell badge.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(notificationsProvider.future);
  return result.unread;
});

Future<void> markAllNotificationsRead(WidgetRef ref) async {
  final dio = ref.read(apiDioProvider);
  await dio.post<void>('study/notifications');
  ref.invalidate(notificationsProvider);
}

Future<void> markNotificationRead(WidgetRef ref, String id) async {
  final dio = ref.read(apiDioProvider);
  await dio.patch<void>('study/notifications/$id');
  ref.invalidate(notificationsProvider);
}
