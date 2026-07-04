import 'package:ethiopian_reader/design/app_theme.dart';
import 'package:ethiopian_reader/web/widgets/common/web_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the web "Manage books" header crash: WebPageHeader measures its
/// actions Row with UNBOUNDED width (it's the non-flex sibling of the Expanded
/// title), and the app's full-width button theme (minimumSize: Size.fromHeight)
/// then "forces an infinite width" and fails to lay out — blanking the header.
/// Action buttons must override minimumSize to Size.zero (as the admin books web
/// body does for the Import/Create buttons).

Widget _headerWith(List<Widget> actions) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          children: [
            WebPageHeader(title: 'Manage books', actions: actions),
          ],
        ),
      ),
    );

void main() {
  testWidgets('bounded (Size.zero) action buttons lay out without crashing',
      (tester) async {
    await tester.pumpWidget(_headerWith([
      OutlinedButton.icon(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Import Word (.docx)'),
      ),
      FilledButton.icon(
        onPressed: () {},
        style: FilledButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Create'),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Import Word (.docx)'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('reproduction: unstyled full-width buttons force infinite width',
      (tester) async {
    // Documents WHY the override is required: without it, the app theme's
    // full-width buttons crash the header. If a future Flutter changes this,
    // update/remove this reproduction test.
    await tester.pumpWidget(_headerWith([
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Import Word (.docx)'),
      ),
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Create'),
      ),
    ]));
    expect(tester.takeException(), isNotNull);
  });
}
