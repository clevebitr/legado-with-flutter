import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/source_check_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/book_source_check_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/offline_corpus.dart';

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(BookSourceCheckPage));

/// One stored corpus source.
StoredBookSource _stored(FakeBookSourceRepository repository, {String? name}) =>
    repository.add(
      source: loadCorpusBookSource().copyWith(name: name ?? '示例书源'),
    );

/// Types [keyword] into the field and submits it, which is how the page hands it to the notifier.
Future<void> _useKeyword(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('BookSourceCheckPage', () {
    testWidgets('build_givenNoStoredSource_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: FakeBookSourceRepository(),
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.bookSourceCheckEmpty), findsOneWidget);
      // 没有可校验的源时不给运行按钮。
      expect(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
        findsNothing,
      );
    });

    testWidgets('build_givenStoredSources_listsThemWithTheDebugEntry', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      _stored(repository, name: 'first');
      _stored(repository, name: 'second');

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(find.text(l10n.bookSourceCheckStatusPending), findsNothing);
      // 每行都有「调试该书源」入口（C-UI-7：图标按钮必须有 tooltip）。
      expect(
        find.byTooltip(l10n.bookSourceCheckOpenDebug),
        findsNWidgets(3),
        reason: '1 个 AppBar 入口 + 2 行',
      );
    });

    testWidgets('start_givenAHealthyChain_showsPassedAndWritesTheVerdict', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = _stored(repository);
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      // 语料的 searchUrl 用 `{{key}}`，所以先把关键词设成语料里那个（渲染成已登记的地址）。
      await _useKeyword(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(l10n.bookSourceCheckStatusSucceeded),
        findsOneWidget,
      );
      // ADR-0043 §决策 1：结论写回书源的投影列（分组 / 注释 / 耗时）。
      expect(repository.respondTimeOf(stored.id), isNotNull);
      expect(repository.groupsOf(stored.id), isEmpty);
      expect(repository.commentOf(stored.id), isNull);
    });

    testWidgets('start_givenAnEmptySearchPage_showsTheFailedVerdict', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = _stored(repository);
      final FakeHttpClient http = FakeHttpClient()
        ..serve(corpusSearchUrl, '<div id="nothing"></div>');

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _useKeyword(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(l10n.bookSourceCheckStatusFailed),
        findsOneWidget,
      );
      // 同一行还给出失败规则的位置，用户才知道去修哪一条。
      expect(
        find.textContaining(
          l10n.bookSourceCheckFailedAt('searchRule.bookList'),
        ),
        findsOneWidget,
      );
      expect(repository.groupsOf(stored.id), <String>[searchInvalidGroup]);
    });

    testWidgets('start_givenARequestInFlight_showsTheRunningState', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      _stored(repository);
      final Completer<void> gate = Completer<void>();
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..onRequest = () => gate.future;

      final ProviderContainer container = await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _useKeyword(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(l10n.bookSourceCheckStatusRunning), findsWidgets);
      // 运行期间给的是「取消」而不是「开始」。
      expect(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStop),
        findsOneWidget,
      );

      // 放行并收尾，否则会留下挂起的请求。
      container.read(sourceCheckProvider.notifier).cancel();
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('stop_givenARunInFlight_marksTheSourceCancelled', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      final StoredBookSource stored = _stored(repository);
      final Completer<void> gate = Completer<void>();
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient())
        ..onRequest = () => gate.future;

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _useKeyword(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStop),
      );
      gate.complete();
      await tester.pumpAndSettle();

      // 取消是 Cancelled 而不是 Failed（上游 Incomplete 口径的反面，ADR-0043 §后果）。
      expect(
        find.textContaining(l10n.bookSourceCheckStatusCancelled),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.bookSourceCheckStatusFailed),
        findsNothing,
      );
      // 取消不算结论：不写回。
      expect(repository.respondTimeOf(stored.id), isNull);
      expect(repository.groupsOf(stored.id), isEmpty);
    });

    testWidgets('start_givenNothingSelected_showsTheSelectionHint', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      _stored(repository);

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: FakeHttpClient(),
      );
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(
        find.widgetWithText(TextButton, l10n.bookSourceCheckSelectNone),
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pump();

      expect(find.text(l10n.bookSourceCheckSelectionEmpty), findsOneWidget);
    });

    testWidgets('start_givenASwitchedOffStage_doesNotRunIt', (
      WidgetTester tester,
    ) async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      _stored(repository);
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _useKeyword(tester, corpusKeyword);

      await tester.tap(
        find.widgetWithText(FilterChip, l10n.bookSourceCheckStageContent),
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pumpAndSettle();

      // 正文阶段关掉后就不再请求章节页（ADR-0043 §决策 2 的阶段开关）。
      expect(http.requestedUrls, isNot(contains(corpusChapterUrl)));
      expect(
        find.textContaining(l10n.bookSourceCheckStatusSucceeded),
        findsOneWidget,
      );
    });

    testWidgets('rows_givenAVerdict_showTheStageOutcomeOnce', (
      WidgetTester tester,
    ) async {
      // 「运行中 → 通过」之后每行只有一条结论，不会因为阶段数而出现重复行。
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      _stored(repository);
      final FakeHttpClient http = serveCorpusPages(FakeHttpClient());

      await pumpSourceConsolePage(
        tester,
        page: const BookSourceCheckPage(),
        repository: repository,
        http: http,
      );
      final AppLocalizations l10n = _l10n(tester);
      await _useKeyword(tester, corpusKeyword);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.bookSourceCheckStart),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookSourceCheckStatusSucceeded), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });
}
