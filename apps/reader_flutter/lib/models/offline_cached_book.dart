import 'book_models.dart';

/// Offline row for the downloads screen (catalog + local cache metadata).
class OfflineCachedBook {
  OfflineCachedBook({
    required this.id,
    required this.title,
    this.authorCompiler,
    this.primaryLanguage,
    required this.chapterCount,
    required this.pageCount,
    required this.hasReadableContent,
    required this.isPdf,
    required this.inCatalog,
    this.catalogBook,
    this.savedAtEpochMs,
  });

  final String id;
  final String title;
  final String? authorCompiler;
  final String? primaryLanguage;
  final int chapterCount;
  final int pageCount;
  final bool hasReadableContent;
  final bool isPdf;
  final bool inCatalog;
  final BookSummary? catalogBook;
  final int? savedAtEpochMs;

  /// Saved chapters, or a sealed PDF, can be opened from the downloads list.
  static bool isReadableOffline({
    required int chapterCount,
    required int pageCount,
    required bool hasPdf,
  }) => hasPdf || (chapterCount > 0 && pageCount > 0);

  String get readPath => isPdf ? '/pdf/$id' : '/reader/$id';

  BookSummary get displaySummary =>
      catalogBook ??
      BookSummary(
        id: id,
        title: title,
        authorCompiler: authorCompiler,
        primaryLanguage: primaryLanguage,
        contentFormat: isPdf ? 'pdf' : null,
      );
}
