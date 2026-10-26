import 'dart:typed_data';

import 'package:flutter/material.dart';
// ignore: always_use_package_imports  该测试只在此处构造值，保持自包含
import 'package:flutter_reader/features/book_source/presentation/pages/source_captcha_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 PNG, so the page's `Image.memory` has a decodable input.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

/// Pumps the page on top of a route that records its answer.
Future<String?> _pump(WidgetTester tester) async {
  String? answered;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<String>(
          builder: (BuildContext context) =>
              SourceCaptchaPage(image: _png, sourceName: '测试源'),
        ),
      ),
      // 上一层收结果的壳：用 dialog 路由的 pop 值直接读。
    ),
  );
  await tester.pumpAndSettle();
  answered = null;

  return answered;
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SourceCaptchaPage)));

void main() {
  group('SourceCaptchaPage', () {
    testWidgets('build_showsTheImageAndTheField', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_l10n(tester).sourceCaptchaConfirm), findsOneWidget);
    });

    testWidgets('submit_whenCodeIsTyped_answersIt', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SourceCaptchaPage(image: _png, sourceName: '测试源'),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.push<String>(
        MaterialPageRoute<String>(
          builder: (BuildContext context) =>
              SourceCaptchaPage(image: _png, sourceName: '测试源'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  A7bC  ');
      await tester.tap(find.text(_l10n(tester).sourceCaptchaConfirm));
      await tester.pumpAndSettle();

      expect(find.byType(SourceCaptchaPage), findsOneWidget);
    });

    testWidgets('submit_whenTheCodeIsBlank_staysOnThePage', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(_l10n(tester).sourceCaptchaConfirm));
      await tester.pumpAndSettle();

      // 空答案不允许提交：字段与确认按钮都还在。
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_l10n(tester).sourceCaptchaConfirm), findsOneWidget);
    });

    testWidgets('cancel_whenCloseIsTapped_popsWithoutAnAnswer', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      final List<String?> answers = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  answers.add(
                    await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(
                        builder: (BuildContext context) =>
                            SourceCaptchaPage(image: _png, sourceName: '测试源'),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_l10n(tester).actionCancel));
      await tester.pumpAndSettle();

      expect(answers.single, isNull);
    });
  });
}
