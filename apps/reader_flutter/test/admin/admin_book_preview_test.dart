import 'package:ethiopian_reader/models/admin_book.dart';
import 'package:ethiopian_reader/router/app_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

AdminBook _book({
  String visibility = 'hidden',
  List<AdminDraftChapter> chapters = const [],
  AdminPdfDraft? pdfDraft,
}) {
  return AdminBook(
    id: 'book-1',
    title: 'Title',
    primaryLanguage: 'am',
    scriptTags: const [],
    chaptersDraft: chapters,
    catalogVisibility: visibility,
    pdfDraft: pdfDraft,
  );
}

void main() {
  test('in-review drafts with chapters can be opened in the reader', () {
    final book = _book(
      chapters: [
        AdminDraftChapter(chapterKey: 'ch1', title: 'One', pages: const []),
      ],
    );
    expect(book.hasReaderPreview, isTrue);
  });

  test('empty unpublished drafts cannot be opened in the reader', () {
    expect(_book().hasReaderPreview, isFalse);
  });

  test('published books can be opened in the reader', () {
    expect(_book(visibility: 'published').hasReaderPreview, isTrue);
  });

  test('reading paths send reviewers to the reader, not catalog detail', () {
    expect(
      readingPathForBook('abc', isPdf: false, query: 'pickChapter=1'),
      '/reader/abc?pickChapter=1',
    );
    expect(readingPathForBook('abc', isPdf: true), '/pdf/abc');
    expect(bookDetailPathForBook('abc', isBible: false), '/book/abc');
  });
}
