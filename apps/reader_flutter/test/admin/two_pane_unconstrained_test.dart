import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The admin book editor's two-pane crash had two independent causes:
///  1. The shell can hand the screen a fully unconstrained size (infinity via
///     BOTH constraints and MediaQuery) — Row/Expanded/ListView need a finite
///     size. Fixed by clamping the two-pane SizedBox to a finite value.
///  2. The app's FilledButton theme is full-width (`Size.fromHeight` == infinite
///     minimum width). Flex measures a *non-flex* child (a button next to an
///     Expanded) with UNBOUNDED main-axis width, so the button demands infinity
///     and crashes — even when the row itself is bounded. Fixed by overriding
///     that in-row button's minimumSize to Size.zero.

Widget _twoPane({required bool fixButton}) {
  return MaterialApp(
    theme: ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: Size.infinite),
        child: Scaffold(
          body: UnconstrainedBox(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final screen = MediaQuery.sizeOf(ctx);
                var w = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : screen.width;
                var h = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : screen.height;
                if (!w.isFinite || w <= 0) w = 1400; // clamp (fix #1)
                if (!h.isFinite || h <= 0) h = 900;
                return SizedBox(
                  width: w,
                  height: h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: ListView(children: const [Text('details')]),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Expanded(child: Text('Chapters')),
                                  FilledButton.tonalIcon(
                                    // fix #2
                                    style: fixButton
                                        ? FilledButton.styleFrom(
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          )
                                        : null,
                                    onPressed: () {},
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add'),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView(children: const [Text('content')]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('reproduces the crash without the button fix', (tester) async {
    await tester.pumpWidget(_twoPane(fixButton: false));
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('clamp + button fix: no exception, lays out', (tester) async {
    // Large surface so the 1400px clamp fits (no benign overflow artifact).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_twoPane(fixButton: true));
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('content'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
