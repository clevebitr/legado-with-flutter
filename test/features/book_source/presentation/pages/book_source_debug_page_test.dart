import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/source_debug_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_debug_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceDebugPage));

/// A repository holding one stored corpus source.
FakeBookSourceRepository _repository() =>
    FakeBookSourceRepository()..add(source: loadCorpusBookSource());

/// Types [query] into the console's field.
Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

void main() {
  group('BookSourceDebugPage', () {
    testWidgets('build_givenNoStoredSource_showsTheMissingSourceState', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: FakeBookSourceRepository(),
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.bookSourceDebugMissingSource), findsOneWidget);
    });

    testWidgets('build_whenOpened_showsTheIdleStateAndTheKeywordExample', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.bookSourceDebugStatusIdle), findsOneWidget);
      expect(find.text(l10n.bookSourceDebugEmpty), findsOneWidget);
      // 搜索目标的示例就是校验会用的那个关键词（书源没声明 checkKeyWord 时取默认值）。
      expect(find.text(defaultCheckKeyword), findsOneWidget);
    });

    testWidgets('run_givenTheSearchTarget_streamsTheThreeEventKinds', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        http: serveCorpusPages(FakeHttpClient()),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, corpusKeyword);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStart),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceDebugStatusSucceeded), findsOneWidget);
      // 消息 / 来源 两类事件都在；「来源」直接给出抓取的地址，方便去浏览器里核对。
      expect(find.text(l10n.bookSourceDebugEventMessage), findsWidgets);
      expect(find.text(l10n.bookSourceDebugEventSource), findsWidgets);
      expect(find.textContaining('search: books='), findsOneWidget);
      expect(find.text(corpusSearchUrl), findsWidgets);
    });

    testWidgets('run_givenAFailingTarget_showsTheFailedStatusAndAnErrorLine', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        // 没有登记任何页面 ⇒ 请求一律 404。
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, corpusKeyword);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStart),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceDebugStatusFailed), findsOneWidget);
      expect(find.text(l10n.bookSourceDebugEventError), findsOneWidget);
      expect(find.text('searchUrl'), findsOneWidget);
    });

    testWidgets('run_givenAnEmptyQuery_doesNothing', (
      WidgetTester tester,
    ) async {
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStart),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceDebugStatusIdle), findsOneWidget);
      expect(http.requestedUrls, isEmpty);
    });

    testWidgets('run_givenARequestInFlight_showsRunningThenCancelled', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..onRequest = () => gate.future;

      final ProviderContainer container = await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _type(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStart),
      );
      await tester.pump();

      expect(find.text(l10n.bookSourceDebugStatusRunning), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStop),
        findsOneWidget,
      );

      container.read(sourceDebugProvider.notifier).stop();
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceDebugStatusCancelled), findsOneWidget);
      expect(find.text('cancelled'), findsOneWidget);
    });

    testWidgets('clear_givenSomeEvents_emptiesTheStream', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceDebugPage(),
        repository: _repository(),
        http: serveCorpusPages(FakeHttpClient()),
      );
      final AppLocalizations l10n = _l10n(tester);

      await _type(tester, corpusKeyword);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceDebugStart),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('search: books='), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.bookSourceDebugClear));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceDebugEmpty), findsOneWidget);
      expect(find.textContaining('search: books='), findsNothing);
    });
  });
}
