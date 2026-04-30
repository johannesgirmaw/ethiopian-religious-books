import 'package:ethiopian_reader/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash shows loading', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EthiopianReaderApp()),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
