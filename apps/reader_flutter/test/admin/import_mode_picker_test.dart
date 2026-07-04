import 'package:ethiopian_reader/l10n/app_localizations.dart';
import 'package:ethiopian_reader/providers/admin_providers.dart';
import 'package:ethiopian_reader/screens/admin/import_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the reported ".docx import: can't select the mode options / stuck"
/// bug: tapping a strategy row must move the selection, and the detected-chapter
/// preview must never render blank.

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

ImportModeSummary _mode(String m, int chapters, {List<String> titles = const []}) =>
    ImportModeSummary(
      mode: m,
      strategyUsed: m,
      chapters: chapters,
      pages: chapters,
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

void main() {
  testWidgets('tapping a mode row moves the selection', (tester) async {
    var selected = 'auto';
    final modes = [_mode('auto', 2), _mode('heading', 1), _mode('marker', 3)];

    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) => ImportModePicker(
            modes: modes,
            selectedMode: selected,
            onSelect: (m) => setState(() => selected = m),
          ),
        ),
      ),
    );

    // Starts on 'auto'.
    expect(_isSelected(tester, 'auto'), isTrue);
    expect(_isSelected(tester, 'marker'), isFalse);

    // Tap 'marker' -> selection moves.
    await tester.tap(find.byKey(const Key('import-mode-marker')));
    await tester.pumpAndSettle();
    expect(selected, 'marker');
    expect(_isSelected(tester, 'marker'), isTrue);
    expect(_isSelected(tester, 'auto'), isFalse);

    // Tap 'heading' -> moves again (proves every row is selectable).
    await tester.tap(find.byKey(const Key('import-mode-heading')));
    await tester.pumpAndSettle();
    expect(selected, 'heading');
    expect(_isSelected(tester, 'heading'), isTrue);
  });

  testWidgets('detected-chapters list renders titles', (tester) async {
    await tester.pumpWidget(
      _harness(const DetectedChaptersList(titles: ['ምዕራፍ ፩', 'ምዕራፍ ፪', 'ምዕራፍ ፫'])),
    );
    expect(find.text('1. ምዕራፍ ፩'), findsOneWidget);
    expect(find.text('3. ምዕራፍ ፫'), findsOneWidget);
  });

  testWidgets('detected-chapters list never blank when empty', (tester) async {
    await tester.pumpWidget(_harness(const DetectedChaptersList(titles: [])));
    expect(find.text('No chapters detected for this option.'), findsOneWidget);
  });

  testWidgets('detected-chapters list caps titles with +N more', (tester) async {
    final many = List.generate(12, (i) => 'C${i + 1}');
    await tester.pumpWidget(
      _harness(DetectedChaptersList(titles: many, maxShown: 8)),
    );
    expect(find.text('1. C1'), findsOneWidget);
    expect(find.text('8. C8'), findsOneWidget);
    expect(find.text('9. C9'), findsNothing);
    expect(find.text('+4 more'), findsOneWidget);
  });
}
