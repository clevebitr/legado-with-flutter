import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReaderApp_whenPlatformHasNoDynamicColor_rendersFallbackTheme', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ReaderApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.text('Book sources'),
      findsOneWidget,
      reason: 'The English template locale should be used in tests.',
    );
  });
}
