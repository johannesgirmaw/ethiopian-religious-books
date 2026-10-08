import 'package:ethiopian_reader/utils/pdf_book_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a cached PDF is complete only when its length matches', () {
    expect(isCompletePdfCache(1200, 1200), isTrue);
    expect(isCompletePdfCache(100, 1200), isFalse);
    expect(isCompletePdfCache(1200, 0), isFalse);
  });

  test('web PDF proxy path is same-origin and book-scoped', () {
    final uri = webPdfProxyUri('11111111-1111-1111-1111-111111111111');
    expect(uri.path, '/pdf-proxy/11111111-1111-1111-1111-111111111111');
    expect(uri.query, isEmpty);
  });
}
