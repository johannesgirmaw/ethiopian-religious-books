import 'package:ethiopian_reader/models/book_models.dart';
import 'package:ethiopian_reader/utils/book_share.dart';
import 'package:ethiopian_reader/utils/offline_book_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('book detail share URL points at the public web hash route', () {
    expect(
      bookDetailShareUrl('abc-123'),
      'https://app.felegemetsahft.com/#/book/abc-123',
    );
  });

  test('book share text includes title and link', () {
    final book = BookSummary(
      id: 'abc-123',
      title: 'Test Book',
      authorCompiler: 'Author',
    );
    final text = bookShareText(book);
    expect(text, contains('Test Book'));
    expect(text, contains('Author'));
    expect(text, contains('https://app.felegemetsahft.com/#/book/abc-123'));
  });

  test('purchase-required download errors are detected in en and am', () {
    expect(
      isPurchaseRequiredDownloadError(
        'You need to purchase this book before you can download it.',
      ),
      isTrue,
    );
    expect(
      isPurchaseRequiredDownloadError(
        'ከማውረድዎ በፊት ይህን መጽሐፍ መግዛት አለብዎት።',
      ),
      isTrue,
    );
    expect(isPurchaseRequiredDownloadError('Connection failed'), isFalse);
  });
}
