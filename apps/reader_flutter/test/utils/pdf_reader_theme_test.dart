import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethiopian_reader/design/pdf_reader_theme.dart';
import 'package:ethiopian_reader/storage/reader_prefs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sepia paper is warm parchment, not brand cyan', () {
    final sepia = PdfReaderTheme.forMode('sepia');
    expect(sepia.canvas, isNot(const Color(0xFF29B6E0)));
    expect(sepia.isSepia, isTrue);
    expect(PdfReaderTheme.forMode('dark').isDark, isTrue);
  });

  test('pdf page bookmarks round-trip in prefs', () async {
    SharedPreferences.setMockInitialValues({});
    const bookId = 'book-pdf-1';
    final marks = [
      PdfPageBookmark(pageNumber: 3, label: 'Page 3', savedAtEpochMs: 100),
      PdfPageBookmark(
        pageNumber: 12,
        label: 'Page 12',
        snippet: 'prayer',
        savedAtEpochMs: 200,
      ),
    ];
    await ReaderPrefsStorage.writePdfBookmarks(bookId, marks);
    await ReaderPrefsStorage.writePdfTheme(bookId, 'sepia');
    await ReaderPrefsStorage.writePdfPageMode(bookId, 'single');
    await ReaderPrefsStorage.writeProgress(bookId, 0.42);

    final loaded = await ReaderPrefsStorage.readPdfBookmarks(bookId);
    expect(loaded, hasLength(2));
    expect(loaded.first.pageNumber, 3);
    expect(await ReaderPrefsStorage.readPdfTheme(bookId), 'sepia');
    expect(await ReaderPrefsStorage.readPdfPageMode(bookId), 'single');
    expect(await ReaderPrefsStorage.readProgress(bookId), closeTo(0.42, 0.001));
  });
}
