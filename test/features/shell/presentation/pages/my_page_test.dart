import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/shell/presentation/pages/my_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_navigation.dart';

/// Pumps the page with a recording navigation port.
Future<FakeAppNavigation> _pump(WidgetTester tester) async {
  final FakeAppNavigation navigation = FakeAppNavigation();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appNavigationProvider.overrideWithValue(navigation),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const MyPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return navigation;
}

void main() {
  group('MyPage', () {
    testWidgets('build_givenTheEntries_showsBookSourcesSettingsAndAbout', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      expect(find.text(l10n.myBookSources), findsOneWidget);
      expect(find.text(l10n.myBookSourcesBody), findsOneWidget);
      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(find.text(l10n.aboutTitle), findsOneWidget);
    });

    testWidgets('tap_whenBookSourcesIsChosen_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await tester.tap(find.text(l10n.myBookSources));
      await tester.pumpAndSettle();

      expect(navigation.bookSourcesCalls, 1);
      expect(navigation.settingsCalls, 0);
    });

    testWidgets('build_givenTheContentEntries_showsBookmarksAndRecords', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      expect(find.text(l10n.myBookmarks), findsOneWidget);
      expect(find.text(l10n.myReadingRecords), findsOneWidget);
    });

    testWidgets('tap_whenBookmarksIsChosen_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await tester.tap(find.text(l10n.myBookmarks));
      await tester.pumpAndSettle();

      expect(navigation.bookmarksCalls, 1);
      expect(navigation.readingRecordsCalls, 0);
    });

    testWidgets('tap_whenReadingRecordsAreChosen_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await tester.tap(find.text(l10n.myReadingRecords));
      await tester.pumpAndSettle();

      expect(navigation.readingRecordsCalls, 1);
      expect(navigation.bookmarksCalls, 0);
    });

    testWidgets('tap_whenAboutIsChosen_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await tester.tap(find.text(l10n.aboutTitle));
      await tester.pumpAndSettle();

      expect(navigation.aboutCalls, 1);
    });
  });
}
