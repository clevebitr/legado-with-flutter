import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/shell/presentation/pages/my_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_navigation.dart';

/// Scrolls the list until [finder] is on screen (the entries grew past one viewport in M20).
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.pumpAndSettle();
}

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
      await _scrollTo(tester, find.text(l10n.settingsTitle));
      expect(find.text(l10n.settingsTitle), findsOneWidget);
      await _scrollTo(tester, find.text(l10n.aboutTitle));
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

    testWidgets('build_givenTheRuleEntries_showsAllFourKinds', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      expect(find.text(l10n.mySectionRules), findsOneWidget);
      expect(find.text(l10n.rulesReplaceTitle), findsOneWidget);
      expect(find.text(l10n.rulesTocTitle), findsOneWidget);
      expect(find.text(l10n.rulesDictTitle), findsOneWidget);
      expect(find.text(l10n.rulesHighlightTitle), findsOneWidget);
    });

    testWidgets('tap_whenEachRuleEntryIsChosen_asksTheMatchingPort', (
      WidgetTester tester,
    ) async {
      // 四类规则各有一个入口：点错行就管错了表（ADR-0070 §决策 1 的 kind 隔离）。
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await tester.tap(find.text(l10n.rulesReplaceTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rulesTocTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rulesDictTitle));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text(l10n.rulesHighlightTitle));
      await tester.tap(find.text(l10n.rulesHighlightTitle));
      await tester.pumpAndSettle();

      expect(navigation.ruleCalls, <String, int>{
        'replace': 1,
        'toc': 1,
        'dict': 1,
        'highlight': 1,
      });
    });

    testWidgets('tap_whenAboutIsChosen_asksTheNavigationPort', (
      WidgetTester tester,
    ) async {
      final FakeAppNavigation navigation = await _pump(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(MyPage)),
      );

      await _scrollTo(tester, find.text(l10n.aboutTitle));
      await tester.tap(find.text(l10n.aboutTitle));
      await tester.pumpAndSettle();

      expect(navigation.aboutCalls, 1);
    });
  });
}
