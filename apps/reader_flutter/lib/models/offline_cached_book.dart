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
  final bool inCatalog;
  final BookSummary? catalogBook;
  final int? savedAtEpochMs;

  BookSummary get displaySummary => catalogBook ??
      BookSummary(
        id: id,
        title: title,
        authorCompiler: authorCompiler,
        primaryLanguage: primaryLanguage,
      );
}
