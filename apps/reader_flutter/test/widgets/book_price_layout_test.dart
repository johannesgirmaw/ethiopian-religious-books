import 'package:ethiopian_reader/desktop/widgets/catalog/desktop_book_card.dart';
import 'package:ethiopian_reader/l10n/app_localizations.dart';
import 'package:ethiopian_reader/mobile/widgets/catalog/mobile_book_card.dart';
import 'package:ethiopian_reader/models/book_models.dart';
import 'package:ethiopian_reader/providers/catalog_providers.dart';
import 'package:ethiopian_reader/providers/engagement_providers.dart';
import 'package:ethiopian_reader/web/widgets/catalog/web_book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BookSummary _pricedBook() {
  return BookSummary(
    id: 'b1',
    title: 'A long title that wraps onto two lines in the catalog',
    authorCompiler: 'Test Author',
    isPremium: true,
    currency: 'USD',
    price: 10,
    priceEtb: 5500,
    priceUsd: 10,
    finalPrice: 10,
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget card, Size size) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        favouriteIdsProvider.overrideWith((ref) async => <String>{}),
        catalogBookMetaProvider.overrideWith(
          (ref, id) async => const CatalogBookMeta(chapterCount: 12),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: card,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('mobile catalog cell shows both prices without overflowing', (
    tester,
  ) async {
    const width = 150.0;
    await _pumpCard(
      tester,
      MobileBookCard(book: _pricedBook(), index: 0),
      const Size(width, width / 0.52),
    );
    expect(find.textContaining('Br '), findsWidgets);
    expect(find.textContaining(r'$10.00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web catalog cell shows both prices without overflowing', (
    tester,
  ) async {
    const width = 180.0;
    await _pumpCard(
      tester,
      WebBookCard(book: _pricedBook(), index: 0),
      const Size(width, width / 0.50),
    );
    expect(find.textContaining('Br '), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop catalog cell shows both prices without overflowing', (
    tester,
  ) async {
    const width = 160.0;
    await _pumpCard(
      tester,
      DesktopBookCard(book: _pricedBook(), index: 0),
      const Size(width, width / 0.48),
    );
    expect(find.textContaining('Br '), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
