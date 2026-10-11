import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'fake_http_client.dart';
import 'fake_log_printer.dart';

/// The offline corpus of `docs/dev/book-source.md` §10, wired for widget tests.
///
/// The pages are driven through the **production chain** (notifier → use case →
/// `renderUrlTemplate` → `HttpClient` → `RuleEngine`) with a fake client, which is
/// what `PLAN.md` §6 trap #1 asks for: a widget test that passes because the page
/// renders must still exercise the real pipeline.
const String corpusSearchUrl =
    'https://example-novel.test/search.php?q=%E5%89%91%E6%9D%A5';

/// The book URL the corpus search page points at.
const String corpusBookUrl = 'https://example-novel.test/book/1/';

/// The chapter URL of the first corpus chapter.
const String corpusChapterUrl = 'https://example-novel.test/book/1/1.html';

/// The keyword the corpus search URL belongs to.
const String corpusKeyword = '剑来';

/// Loads the sanitized real book source of the corpus.
BookSource loadCorpusBookSource() => BookSource.fromLegadoJson(
  jsonDecode(
    File('test/fixtures/book_sources/legado_default_rules_source.json')
        .readAsStringSync(),
  ) as Map<String, Object?>,
);

/// Reads one page of the corpus.
String corpusPage(String name) =>
    File('test/fixtures/html/$name').readAsStringSync();

/// Serves the pages of the four corpus stages on [http].
FakeHttpClient serveCorpusPages(FakeHttpClient http) {
  http.serve(corpusSearchUrl, corpusPage('search_result.html'));
  http.serve(corpusBookUrl, corpusPage('book_page.html'));
  http.serve(corpusChapterUrl, corpusPage('chapter_page.html'));

  return http;
}

/// Pumps the whole app behind [source] and [http].
///
/// This is the shortest path to the production wiring: `ReaderApp` owns the route
/// table, so a test can walk search → detail → reader by tapping.
Future<void> pumpReaderApp(
  WidgetTester tester, {
  required BookSource? source,
  required FakeHttpClient http,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // testing.md §5：固定种子色并禁用动态取色。
        platformDynamicColorProvider.overrideWithValue(null),
        currentBookSourceProvider.overrideWithValue(source),
        httpClientProvider.overrideWithValue(http),
        appLoggerProvider.overrideWithValue(_logger()),
      ],
      child: const ReaderApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single [page] with the same providers, theme and localization.
///
/// Used for the per-page smoke tests of C-TEST-2, i.e. where navigation is not part
/// of what is being asserted.
Future<void> pumpBookSourcePage(
  WidgetTester tester, {
  required Widget page,
  required BookSource? source,
  required FakeHttpClient http,
}) async {
  _fixViewSize(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        currentBookSourceProvider.overrideWithValue(source),
        httpClientProvider.overrideWithValue(http),
        appLoggerProvider.overrideWithValue(_logger()),
      ],
      child: MaterialApp(
        // 固定英文：断言取的是 `AppLocalizations` 的值，而不是写死的字面量。
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The localization the widget behind [finder] sees.
AppLocalizations localizationOf(WidgetTester tester, Finder finder) =>
    AppLocalizations.of(tester.element(finder));

AppLogger _logger() =>
    AppLogger(level: LogLevel.debug, printer: FakeLogPrinter());

void _fixViewSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
