import 'package:ethiopian_reader/models/offline_cached_book.dart';
import 'package:ethiopian_reader/storage/book_content_cache_storage.dart';
import 'package:ethiopian_reader/utils/pdf_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pdf magic accepts a header and rejects short or other bytes', () {
    expect(pdfBytesLookValid([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]), isTrue);
    expect(pdfBytesLookValid([0x25, 0x50, 0x44, 0x46]), isFalse);
    expect(pdfBytesLookValid(const [0, 1, 2, 3, 4]), isFalse);
    expect(pdfBytesLookValid(const []), isFalse);
  });

  test('book cache meta round-trips content format', () {
    final meta = BookCacheMeta(title: 'A book', contentFormat: 'pdf');
    final again = BookCacheMeta.fromJson(meta.toJson());
    expect(again.title, 'A book');
    expect(again.contentFormat, 'pdf');
    expect(again.isPdf, isTrue);

    final chapter = BookCacheMeta.fromJson({'title': 'Chapter book'});
    expect(chapter.contentFormat, isNull);
    expect(chapter.isPdf, isFalse);
  });

  test('a sealed PDF counts as readable offline content', () {
    expect(
      OfflineCachedBook.isReadableOffline(
        chapterCount: 0,
        pageCount: 0,
        hasPdf: true,
      ),
      isTrue,
    );
    expect(
      OfflineCachedBook.isReadableOffline(
        chapterCount: 0,
        pageCount: 0,
        hasPdf: false,
      ),
      isFalse,
    );
    expect(
      OfflineCachedBook.isReadableOffline(
        chapterCount: 2,
        pageCount: 4,
        hasPdf: false,
      ),
      isTrue,
    );
  });
}
