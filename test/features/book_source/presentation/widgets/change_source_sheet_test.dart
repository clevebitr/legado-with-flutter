import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/js/source_login_info.dart';
import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/change_source_controller.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/change_source_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_navigation.dart';
import '../../../../support/fake_book_source_repository.dart';
import '../../../../support/fake_content_cache.dart';
import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_search_scope_store.dart';

/// One source whose search page lists one hit and whose book page carries three chapters.
BookSource _source(String name, String host) => BookSource(
  name: name,
  url: 'https://$host',
  searchUrl: 'https://$host/s?q={{key}}',
  searchRule: const SearchRule(
    bookList: 'class.result',
    name: 'class.title@text',
    author: 'class.author@text',
    bookUrl: 'tag.a.0@href',
  ),
  tocRule: const TocRule(
    chapterList: 'class.chapter',
    chapterName: 'tag.a.0@text',
    chapterUrl: 'tag.a.0@href',
  ),
  contentRule: const ContentRule(content: 'class.body'),
);

/// A search page holding one hit.
String _searchPage(String title, String author) =>
    '<div class="result"><a href="/book/1">'
    '<span class="title">$title</span></a>'
    '<span class="author">$author</span></div>';

/// A book page that is also its table of contents.
String _tocPage(List<String> chapters) => chapters
    .asMap()
    .entries
    .map(
      (MapEntry<int, String> entry) =>
          '<li class="chapter"><a href="/c/${entry.key}">'
          '${entry.value}</a></li>',
    )
    .join();

/// The search URL a source asks for [keyword].
String _searchUrl(String host, String keyword) =>
    'https://$host/s?q=${Uri.encodeComponent(keyword)}';

/// The book the page searches for.
const ChangeSourceTarget _target = (
  sourceUrl: 'https://a.test',
  bookUrl: 'https://a.test/book/0',
  name: '剑来',
  author: '烽火戏诸侯',
  chapterName: '第二章',
  chapterIndex: 1,
);

/// Pumps a host page whose button opens the change-source sheet.
///
/// The sheet is what the reader and the detail page both open (ADR-0091 §决策 1b), so the tests
/// drive the same entry point instead of mounting the content directly.
Future<Future<ChangeSourceSelection?> Function()> _pumpSheet(
  WidgetTester tester, {
  required FakeHttpClient http,
  required FakeBookSourceRepository repository,
  FakeSearchScopeStore? scopeStore,
  ChangeSourceTarget target = _target,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      bookSourceRepositoryProvider.overrideWithValue(repository),
      httpClientProvider.overrideWithValue(http),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
      // 请求层默认接真实 Drift（登录头 / 正文缓存）：宿主 VM 里没有执行器，用内存替身。
      sourceLoginHeaderStoreProvider.overrideWithValue(
        SourceLoginHeaderStore(),
      ),
      sourceLoginInfoWriterProvider.overrideWithValue(
        InMemorySourceLoginInfoWriter(),
      ),
      contentCacheProvider.overrideWithValue(FakeContentCache()),
      // 每源变量默认写穿 Drift：页面测试用内存实现（testing.md §4）。
      sourceVariableStoreProvider.overrideWithValue(SourceVariableStore()),
      changeSourceScopeStoreProvider.overrideWith(
        (Ref ref) async => scopeStore ?? FakeSearchScopeStore(),
      ),
      // 页面自己不去别处；端口留着是因为外壳可能在测试里被构建。
      appNavigationProvider.overrideWithValue(FakeAppNavigation()),
    ],
  );
  addTearDown(container.dispose);

  ChangeSourceSelection? answer;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => ElevatedButton(
                onPressed: () async {
                  answer = await showChangeSourceSheet(context, target: target);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return () async => answer;
}

void main() {
  testWidgets('page_whenOpened_sendsNothingAndShowsTheStartButton', (
    WidgetTester tester,
  ) async {
    // 只有点「开始搜索」才发请求（DECISIONS #74）：首帧不许有 spinner。
    final FakeHttpClient http = FakeHttpClient();
    final FakeBookSourceRepository repository = FakeBookSourceRepository()
      ..add(source: _source('甲源', 'a.test'))
      ..add(source: _source('乙源', 'b.test'));

    await _pumpSheet(tester, http: http, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ChangeSourceSheet)),
    );

    expect(find.text(l10n.changeSourceSearchPrompt), findsOneWidget);
    expect(find.text(l10n.changeSourceStart), findsOneWidget);
    expect(http.requestedUrls, isEmpty);
  });

  testWidgets('start_whenTapped_showsProgressThenCandidates', (
    WidgetTester tester,
  ) async {
    final FakeHttpClient http = FakeHttpClient()
      ..serve(_searchUrl('b.test', '剑来'), _searchPage('剑来', '烽火戏诸侯'))
      ..serve(_searchUrl('c.test', '剑来'), _searchPage('剑来（精校版）', '烽火戏诸侯'));
    final FakeBookSourceRepository repository = FakeBookSourceRepository()
      ..add(source: _source('甲源', 'a.test'))
      ..add(source: _source('乙源', 'b.test'))
      ..add(source: _source('丙源', 'c.test'));

    await _pumpSheet(tester, http: http, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ChangeSourceSheet)),
    );

    await tester.tap(find.text(l10n.changeSourceStart));
    await tester.pumpAndSettle();

    // 进度行说出「处理到第几个源」与「找到几条」，结果再按源列出。
    expect(find.textContaining(l10n.searchProgress(2, 2)), findsOneWidget);
    expect(find.textContaining(l10n.changeSourceFound(2)), findsOneWidget);
    expect(find.text('乙源'), findsOneWidget);
    expect(find.text('丙源'), findsOneWidget);
    // 当前源不参与候选（ADR-0051 §决策 3）。
    expect(find.text('甲源'), findsNothing);
  });

  testWidgets('candidate_whenTapped_showsItsChaptersAndAnswersThePick', (
    WidgetTester tester,
  ) async {
    final FakeHttpClient http = FakeHttpClient()
      ..serve(_searchUrl('b.test', '剑来'), _searchPage('剑来', '烽火戏诸侯'))
      ..serve('https://b.test/book/1', _tocPage(<String>['第一章', '第二章', '第三章']));
    final FakeBookSourceRepository repository = FakeBookSourceRepository()
      ..add(source: _source('甲源', 'a.test'))
      ..add(source: _source('乙源', 'b.test'));

    final Future<ChangeSourceSelection?> Function() answer = await _pumpSheet(
      tester,
      http: http,
      repository: repository,
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ChangeSourceSheet)),
    );

    await tester.tap(find.text(l10n.changeSourceStart));
    await tester.pumpAndSettle();
    await tester.tap(find.text('乙源'));
    await tester.pumpAndSettle();

    // 点源之后才出现章节列表，并且自动对齐到同名章节（ADR-0091 §决策 1）。
    expect(find.text(l10n.changeSourceChapterTitle), findsOneWidget);
    expect(find.text('第三章'), findsOneWidget);
    expect(
      find.textContaining(l10n.changeSourceAlignHint('第二章')),
      findsOneWidget,
    );

    await tester.tap(find.text('第三章'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.changeSourceConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeSourceSheet), findsNothing);
    final ChangeSourceSelection? picked = await answer();
    expect(picked, isNotNull);
    expect(picked!.candidate.sourceName, '乙源');
    expect(picked.chapterIndex, 2);
    expect(picked.chapters[2].name, '第三章');
  });

  testWidgets('page_whenNoSourceInScope_explainsItWithoutSearching', (
    WidgetTester tester,
  ) async {
    // 范围里只剩当前源：不是「没这本书」，而是「没得搜」。
    final FakeHttpClient http = FakeHttpClient();
    final FakeBookSourceRepository repository = FakeBookSourceRepository()
      ..add(source: _source('甲源', 'a.test'));

    await _pumpSheet(
      tester,
      http: http,
      repository: repository,
      scopeStore: FakeSearchScopeStore(
        initial: const BookSearchScope.groups(<String>{'不存在'}),
      ),
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(ChangeSourceSheet)),
    );

    await tester.tap(find.text(l10n.changeSourceStart));
    await tester.pumpAndSettle();

    expect(find.text(l10n.changeSourceNoSources), findsOneWidget);
    expect(http.requestedUrls, isEmpty);
  });

  testWidgets(
    'sheet_whenClosedWhileSearching_doesNotTouchTheDisposedController',
    (WidgetTester tester) async {
      // 真机日志（app-2026-10-30）里两次 `UnmountedRefException` + ERROR CRASH：用户在搜索
      // 还没跑完时关掉换源，await 回来继续对已销毁的 provider 写状态。这里把请求按在闸门上，
      // 关掉 sheet 再放行，必须安静结束（ADR-0091 §决策 1b 的回归点）。
      final Completer<void> gate = Completer<void>();
      final FakeHttpClient http = FakeHttpClient()
        ..onRequest = () => gate.future;
      http.serve(_searchUrl('b.test', '剑来'), _searchPage('剑来', '烽火戏诸侯'));
      final FakeBookSourceRepository repository = FakeBookSourceRepository()
        ..add(source: _source('甲源', 'a.test'))
        ..add(source: _source('乙源', 'b.test'));

      await _pumpSheet(tester, http: http, repository: repository);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(ChangeSourceSheet)),
      );

      await tester.tap(find.text(l10n.changeSourceStart));
      await tester.pump();
      // 搜索还挂在网络上时把 sheet 关掉：provider 随即销毁。
      Navigator.of(tester.element(find.byType(ChangeSourceSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ChangeSourceSheet), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
