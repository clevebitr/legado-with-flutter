import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/cache_manage_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_content_cache.dart';
import '../../../../support/offline_corpus.dart';

/// A stored source named [name] pointing at [url].
({String name, String url}) _source(String name, String url) =>
    (name: name, url: url);

/// Pumps the page over a repository holding [sources] and a cache with [counts].
Future<FakeContentCache> _pump(
  WidgetTester tester, {
  required List<({String name, String url})> sources,
  Map<String, int> counts = const <String, int>{},
  bool failsToRead = false,
}) async {
  final FakeBookSourceRepository repository = FakeBookSourceRepository();
  for (final ({String name, String url}) source in sources) {
    repository.add(
      source: loadCorpusBookSource().copyWith(
        name: source.name,
        url: source.url,
      ),
    );
  }
  final FakeContentCache cache = FakeContentCache()
    ..sourceCounts.addAll(counts)
    ..totalCount = 0;
  if (failsToRead) {
    cache.sourceCountFailure = Exception('database is gone');
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookSourceRepositoryProvider.overrideWithValue(repository),
        contentCacheProvider.overrideWithValue(cache),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const CacheManagePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return cache;
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CacheManagePage)));

void main() {
  group('CacheManagePage', () {
    testWidgets('build_givenCachedSources_showsTheTotalAndOneRowEach', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        sources: <({String name, String url})>[
          _source('甲源', 'https://a.test'),
          _source('乙源', 'https://b.test'),
        ],
        counts: <String, int>{'https://a.test': 3, 'https://b.test': 0},
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.cacheManageTotal(0)), findsOneWidget);
      expect(find.text('甲源'), findsOneWidget);
      expect(find.text(l10n.cacheManageSourceCount(3)), findsOneWidget);
      // 没有缓存的源不占一行：这一页回答的是「谁占了空间」。
      expect(find.text('乙源'), findsNothing);
    });

    testWidgets('build_givenNothingCached_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        sources: <({String name, String url})>[_source('甲源', 'https://a.test')],
      );

      expect(find.text(_l10n(tester).cacheManageEmpty), findsOneWidget);
    });

    testWidgets('build_givenAnUnreadableCache_showsTheFailureState', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        sources: <({String name, String url})>[_source('甲源', 'https://a.test')],
        failsToRead: true,
      );

      expect(find.text(_l10n(tester).cacheManageLoadFailed), findsOneWidget);
    });

    testWidgets('clearSource_whenPressed_clearsOnlyThatSource', (
      WidgetTester tester,
    ) async {
      final FakeContentCache cache = await _pump(
        tester,
        sources: <({String name, String url})>[
          _source('甲源', 'https://a.test'),
          _source('乙源', 'https://b.test'),
        ],
        counts: <String, int>{'https://a.test': 3, 'https://b.test': 5},
      );

      await tester.tap(
        find.byTooltip(_l10n(tester).cacheManageClearSource).first,
      );
      await tester.pumpAndSettle();

      expect(cache.scopeCalls, contains('sourceClear|https://a.test'));
    });

    testWidgets('menu_whenExpiredIsChosen_clearsExpiredEntries', (
      WidgetTester tester,
    ) async {
      final FakeContentCache cache = await _pump(
        tester,
        sources: <({String name, String url})>[_source('甲源', 'https://a.test')],
        counts: <String, int>{'https://a.test': 3},
      );

      await tester.tap(find.byTooltip(_l10n(tester).cacheManageMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).cacheManageClearExpired));
      await tester.pumpAndSettle();

      expect(cache.scopeCalls, contains('clearExpired'));
    });

    testWidgets('menu_whenClearAllIsConfirmed_emptiesTheCache', (
      WidgetTester tester,
    ) async {
      final FakeContentCache cache = await _pump(
        tester,
        sources: <({String name, String url})>[_source('甲源', 'https://a.test')],
        counts: <String, int>{'https://a.test': 3},
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.cacheManageMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cacheManageClearAll));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(cache.scopeCalls, contains('clearAll'));
    });
  });
}
