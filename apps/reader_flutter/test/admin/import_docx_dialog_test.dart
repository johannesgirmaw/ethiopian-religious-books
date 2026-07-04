import 'package:dio/dio.dart';
import 'package:ethiopian_reader/design/app_theme.dart';
import 'package:ethiopian_reader/l10n/app_localizations.dart';
import 'package:ethiopian_reader/providers/admin_providers.dart';
import 'package:ethiopian_reader/screens/admin/admin_book_import.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the reported crash: after selecting one mode, tapping another
/// (e.g. Chapter text -> Bold/centered) threw "Cannot hit test a render box
/// that has never been laid out" and froze the whole modal. The crash only
/// appears when the dialog content is height-constrained enough to scroll
/// (a real window), so this drives it through showDialog on a small surface.

ImportModeSummary _m(String mode, int ch, List<String> titles) => ImportModeSummary(
      mode: mode,
      strategyUsed: mode,
      chapters: ch,
      pages: ch,
      titles: titles,
    );

bool _isSelected(WidgetTester tester, String mode) {
  final tile = tester.widget<RadioListTile<String>>(
    find.descendant(
      of: find.byKey(Key('import-mode-$mode')),
      matching: find.byType(RadioListTile<String>),
    ),
  );
  return tile.selected;
}

ImportPreview _preview() => ImportPreview(recommended: 'patterns', modes: [
      _m('auto', 3, ['A', 'B', 'C']),
      _m('heading', 3, ['A', 'B', 'C']),
      _m('patterns', 4, ['P1', 'P2', 'P3', 'P4']),
      _m('format', 15, List.generate(15, (i) => 'F${i + 1}')),
      _m('pagebreak', 8, ['G1', 'G2']),
      _m('marker', 1, ['M1']),
      _m('size', 1, ['S1']),
    ]);

void main() {
  testWidgets('mode switch + hover does not crash on a constrained window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Use the REAL app theme — its full-width button style
    // (minimumSize: Size.fromHeight(50)) is what made the custom-field button
    // demand infinite width under AlertDialog's IntrinsicWidth and crash.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ImportDocxDialog(
                  dio: Dio(),
                  bytes: const [1, 2, 3],
                  filename: 'book.docx',
                  initial: _preview(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'dialog opened');

    await tester.tap(find.byKey(const Key('import-mode-patterns')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'select patterns');

    await tester.tap(find.byKey(const Key('import-mode-format')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'select format');
    expect(_isSelected(tester, 'format'), isTrue);

    // Simulate the mouse hovering across the rows — on desktop this re-hit-tests
    // every frame, which is what surfaced "Cannot hit test a render box that has
    // never been laid out" once a layout exception had left a box un-laid-out.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    for (final mode in ['auto', 'heading', 'patterns', 'format', 'marker']) {
      await gesture.moveTo(tester.getCenter(find.byKey(Key('import-mode-$mode'))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'hover over $mode');
    }
  });
}
