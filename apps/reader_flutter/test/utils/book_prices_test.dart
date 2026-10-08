import 'package:ethiopian_reader/utils/book_prices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows ETB and USD when both list prices are set', () {
    final quotes = bookPriceQuotes(
      currency: 'USD',
      price: 10,
      finalPrice: 10,
      priceEtb: 550,
      priceUsd: 10,
    );
    expect(quotes.map((q) => q.currency).toList(), ['ETB', 'USD']);
    expect(quotes.map((q) => q.amount).toList(), [550, 10]);
    expect(formatBookPriceQuotes(quotes), 'Br 550.00 · \$10.00');
  });

  test('legacy USD price still shows when the dual fields are empty', () {
    final quotes = bookPriceQuotes(
      currency: 'USD',
      price: 12,
      finalPrice: 12,
      priceEtb: 0,
      priceUsd: 0,
    );
    expect(quotes, hasLength(1));
    expect(quotes.single.currency, 'USD');
    expect(quotes.single.amount, 12);
  });

  test('sale price discounts only the primary currency', () {
    final quotes = bookPriceQuotes(
      currency: 'USD',
      price: 20,
      salePrice: 15,
      finalPrice: 15,
      priceEtb: 800,
      priceUsd: 20,
    );
    expect(quotes[0].currency, 'ETB');
    expect(quotes[0].amount, 800);
    expect(quotes[0].compareAt, isNull);
    expect(quotes[1].currency, 'USD');
    expect(quotes[1].amount, 15);
    expect(quotes[1].compareAt, 20);
  });
}
