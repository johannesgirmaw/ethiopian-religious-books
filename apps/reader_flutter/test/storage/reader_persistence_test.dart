import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ethiopian_reader/storage/catalog_cache_storage.dart';
import 'package:ethiopian_reader/storage/reader_prefs_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalog cache stores and restores payload', () async {
    await CatalogCacheStorage.writeCatalog(
      raw: {
        'items': [
          {
            'id': '1',
            'title': 'Sample',
            'primary_language': 'am',
          }
        ],
        'catalog_etag': 'abc',
      },
      etag: 'abc',
    );

    final page = await CatalogCacheStorage.readCatalog();
    final etag = await CatalogCacheStorage.readEtag();

    expect(page, isNotNull);
    expect(page!.items, hasLength(1));
    expect(page.items.first.title, 'Sample');
    expect(etag, 'abc');
  });

  test('reader prefs persist progress and font size', () async {
    await ReaderPrefsStorage.writeProgress('book-1', 0.4);
    await ReaderPrefsStorage.writeFontSize('book-1', 22);

    final progress = await ReaderPrefsStorage.readProgress('book-1');
    final fontSize = await ReaderPrefsStorage.readFontSize('book-1');

    expect(progress, closeTo(0.4, 0.0001));
    expect(fontSize, 22);
  });

  test('last opened book persists title and id', () async {
    await ReaderPrefsStorage.writeLastOpenedBook(
      LastOpenedBook(
        bookId: 'book-42',
        title: 'Test Book',
        updatedAtEpochMs: 1700000000000,
      ),
    );

    final last = await ReaderPrefsStorage.readLastOpenedBook();

    expect(last, isNotNull);
    expect(last!.bookId, 'book-42');
    expect(last.title, 'Test Book');
    expect(last.updatedAtEpochMs, 1700000000000);
  });
}
