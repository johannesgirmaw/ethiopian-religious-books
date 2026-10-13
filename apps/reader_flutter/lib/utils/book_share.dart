import '../models/book_models.dart';

/// Public Flutter web origin (hash-routed). Shared links always point here so
/// recipients can open the book detail page in the browser.
const String kReaderWebAppOrigin = 'https://app.felegemetsahft.com';

/// Canonical share URL for a book's detail page on the web app.
String bookDetailShareUrl(String bookId) {
  final id = bookId.trim();
  return '$kReaderWebAppOrigin/#/book/$id';
}

/// Share payload: title (and author when present) plus the web detail link.
String bookShareText(BookSummary book) {
  final url = bookDetailShareUrl(book.id);
  final author = book.authorCompiler?.trim();
  if (author != null && author.isNotEmpty) {
    return '${book.title} — $author\n$url';
  }
  return '${book.title}\n$url';
}
