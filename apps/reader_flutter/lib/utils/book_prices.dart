import 'money_format.dart';

/// One currency a reader can pay for a book.
class BookPriceQuote {
  const BookPriceQuote({
    required this.currency,
    required this.amount,
    this.compareAt,
  });

  final String currency;

  /// What the reader pays.
  final double amount;

  /// Original list price, set when [amount] is a discount.
  final double? compareAt;
}

/// ETB then USD amounts a reader sees.
///
/// [priceEtb] and [priceUsd] are the stored list prices. [salePrice] discounts
/// only the book's primary [currency]. A legacy book that only has [price]
/// still produces a quote in that currency.
List<BookPriceQuote> bookPriceQuotes({
  required String currency,
  required double price,
  double? salePrice,
  required double finalPrice,
  required double priceEtb,
  required double priceUsd,
}) {
  final code = currency.toUpperCase();
  final onSale = salePrice != null && price > 0 && salePrice < price;

  var etb = priceEtb;
  double? etbCompare;
  var usd = priceUsd;
  double? usdCompare;

  if (code == 'ETB') {
    if (onSale) {
      etb = finalPrice;
      etbCompare = price;
    } else if (etb <= 0) {
      etb = finalPrice;
    }
  } else if (code == 'USD') {
    if (onSale) {
      usd = finalPrice;
      usdCompare = price;
    } else if (usd <= 0) {
      usd = finalPrice;
    }
  }

  final quotes = <BookPriceQuote>[];
  if (etb > 0) {
    quotes.add(
      BookPriceQuote(currency: 'ETB', amount: etb, compareAt: etbCompare),
    );
  }
  if (usd > 0) {
    quotes.add(
      BookPriceQuote(currency: 'USD', amount: usd, compareAt: usdCompare),
    );
  }
  if (quotes.isEmpty && finalPrice > 0) {
    quotes.add(
      BookPriceQuote(
        currency: code.isEmpty ? 'USD' : code,
        amount: finalPrice,
        compareAt: onSale ? price : null,
      ),
    );
  }
  return quotes;
}

/// `Br 550.00 · $10.00` — list and detail surfaces that cannot strike through.
String formatBookPriceQuotes(List<BookPriceQuote> quotes) {
  if (quotes.isEmpty) return '';
  return quotes.map((q) => formatMoney(q.amount, q.currency)).join(' · ');
}
