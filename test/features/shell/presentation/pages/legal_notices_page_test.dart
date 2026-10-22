import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/shell/presentation/pages/legal_notices_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the page.
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildReaderTheme(fallbackLightColorScheme()),
      home: const LegalNoticesPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LegalNoticesPage', () {
    testWidgets('build_showsTheSixCui9Statements', (WidgetTester tester) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(LegalNoticesPage)),
      );

      // C-UI-9 的六条：页面标题、版权、无担保、禁止侵权用途、查看许可、源码地址。
      expect(find.text(l10n.legalNoticesTitle), findsOneWidget);
      expect(find.text(l10n.legalNoticesCopyright), findsOneWidget);
      expect(find.text(l10n.legalNoticesNoWarranty), findsOneWidget);
      expect(find.text(l10n.legalNoticesProhibitedUse), findsOneWidget);
      expect(find.text(l10n.legalNoticesCorrespondingSource), findsOneWidget);
      expect(find.text(l10n.legalNoticesViewLicense), findsOneWidget);
    });

    testWidgets('license_whenOpened_showsTheBundledGplText', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(LegalNoticesPage)),
      );

      await tester.tap(find.text(l10n.legalNoticesViewLicense));
      await tester.pumpAndSettle();

      // 打包的 GPL-3.0 全文：标题 + 正文（asset 在 flutter test 里同样可读）。
      expect(find.text(l10n.legalNoticesLicenseTitle), findsOneWidget);
      expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsOneWidget);
    });
  });
}
