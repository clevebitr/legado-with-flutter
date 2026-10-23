import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/shell/presentation/app_info.dart';
import 'package:flutter_reader/features/shell/presentation/pages/about_page.dart';
import 'package:flutter_reader/features/shell/presentation/pages/legal_notices_page.dart';
import 'package:flutter_reader/features/shell/presentation/shell_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the page with the shell's own route table.
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildReaderTheme(fallbackLightColorScheme()),
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            shellPageFor(settings.arguments! as ShellRoute),
      ),
      home: const AboutPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AboutPage', () {
    testWidgets('build_showsTheVersionAndTheSourceAddress', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AboutPage)),
      );

      expect(find.text(l10n.aboutVersion(appVersion)), findsOneWidget);
      expect(find.text(appRepositoryUrl), findsOneWidget);
    });

    testWidgets('tap_whenLicensesIsChosen_opensTheLegalNotices', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AboutPage)),
      );

      await tester.tap(find.text(l10n.aboutLicenses));
      await tester.pumpAndSettle();

      expect(find.byType(LegalNoticesPage), findsOneWidget);
    });
  });
}
