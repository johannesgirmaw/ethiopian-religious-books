import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ethiopian_reader/storage/form_draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('form draft stores, restores, and deletes payload', () async {
    const key = 'form/admin_book/new';
    await FormDraftStorage.write(
      scopedKey: key,
      data: {'title': 'My book', 'chaptersDraft': []},
    );

    expect(await FormDraftStorage.exists(key), isTrue);
    final envelope = await FormDraftStorage.read(key);
    expect(envelope, isNotNull);
    expect(envelope!.data['title'], 'My book');

    await FormDraftStorage.delete(key);
    expect(await FormDraftStorage.exists(key), isFalse);
    expect(await FormDraftStorage.read(key), isNull);
  });

  test('empty drafts are not indexed after delete', () async {
    const key = 'form/book_review/book-1';
    await FormDraftStorage.write(
      scopedKey: key,
      data: {'body': 'Great read'},
    );
    final listed = await FormDraftStorage.listAll();
    expect(listed.any((e) => e.key == key), isTrue);

    await FormDraftStorage.delete(key);
    expect(await FormDraftStorage.listAll(), isEmpty);
  });
}
