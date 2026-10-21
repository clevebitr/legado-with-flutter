import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';
import '../../../../support/offline_corpus.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// One chapter, long enough that a paged layout needs several pages.
final String _longBody = <String>[
  for (var index = 0; index < 80; index++) '第${index + 1}行：正文内容。',
].join('\n');

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
];

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeChapterListProvider chapters,
  FakeChapterContentProvider content,
  FakeReadingProgressStore progress,
  FakeReaderSettingsRepository settings,
  FakeLogPrinter printer,
});

/// Builds a container around the three reader ports and the settings store.
_Fixture _fixture({
  FakeChapterListProvider? chapters,
  FakeReadingProgressStore? progress,
  ReaderSettings? settings,
}) {
  final FakeChapterListProvider list = chapters ?? FakeChapterListProvider();
  if (chapters == null) {
    list.chapters = _chapters;
  }
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = _longBody
    ..bodies['https://source.test/2.html'] = '第二章正文';
  final FakeReadingProgressStore store = progress ?? FakeReadingProgressStore();
  final FakeReaderSettingsRepository readerSettings =
      FakeReaderSettingsRepository(initial: settings);
  final FakeLogPrinter printer = FakeLogPrinter();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(list),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(store),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async => readerSettings,
      ),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: printer),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (
    container: container,
    chapters: list,
    content: content,
    progress: store,
    settings: readerSettings,
    printer: printer,
  );
}

/// Pumps the reader page on top of [fixture].
Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture, {
  String? chapterUrl,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: ReaderPage(book: _book, chapterUrl: chapterUrl),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(ReaderPage));

/// The body text widget of the reader.
Finder _bodyFinder() => find.textContaining('第1行');

/// Opens the settings sheet.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_l10n(tester).readerSettingsAction));
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderPage', () {
    testWidgets('build_givenAChapterList_showsTheFirstChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      expect(find.text('第1章 开端'), findsWidgets);
      expect(_bodyFinder(), findsOneWidget);
      expect(fixture.chapters.requests.single.$2, _book.tocUrl);
    });

    testWidgets('build_givenAStoredPosition_opensThatChapter', (
      WidgetTester tester,
    ) async {
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(
              chapterUrl: 'https://source.test/2.html',
              chapterName: '第2章',
            );
      final _Fixture fixture = _fixture(progress: store);

      await _pump(tester, fixture);

      // 恢复到存下来的那一章，而不是永远从第一章开始。
      expect(find.text('第2章 继续'), findsWidgets);
      expect(find.text('第二章正文'), findsOneWidget);
    });

    testWidgets('build_givenAChapterUrl_opensTheRequestedChapter', (
      WidgetTester tester,
    ) async {
      // 详情页点某一章时，显式给的章节要压过「上次读到哪」。
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(chapterUrl: 'https://source.test/1.html');
      final _Fixture fixture = _fixture(progress: store);

      await _pump(tester, fixture, chapterUrl: 'https://source.test/2.html');

      expect(find.text('第二章正文'), findsOneWidget);
    });

    testWidgets('build_givenAFailingChapterList_showsTheFailure', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        chapters: FakeChapterListProvider()
          ..failure = const ParseFailure<List<ReadingChapter>>(
            kind: ParseFailureKind.networkFailed,
            rulePath: 'reader.chapterList',
          ),
      );

      await _pump(tester, fixture);

      expect(find.text(_l10n(tester).failureNetworkFailed), findsOneWidget);
    });

    testWidgets('nextChapter_whenTapped_showsTheNextChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      await tester.tap(find.byTooltip(_l10n(tester).readerNextChapter));
      await tester.pumpAndSettle();

      expect(find.text('第二章正文'), findsOneWidget);
      expect(fixture.progress.writes, isNotEmpty);
    });

    testWidgets('toc_whenAChapterIsTapped_opensIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      await tester.tap(find.byTooltip(_l10n(tester).readerTocAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第2章 继续').last);
      await tester.pumpAndSettle();

      expect(find.text('第二章正文'), findsOneWidget);
    });

    testWidgets('settings_whenTheFontSizeIsRaised_appliesItToTheBody', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      final double before = tester.widget<Text>(_bodyFinder()).style!.fontSize!;

      await _openSettings(tester);
      // 字号滑块是设置面板里的第一根；往右拖一档。
      await tester.drag(find.byType(Slider).first, const Offset(200, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(_bodyFinder()).style!.fontSize,
        greaterThan(before),
      );
      expect(fixture.settings.stored.fontScale, greaterThan(1));
    });

    testWidgets('settings_whenTheDarkBackgroundIsChosen_paintsIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      final Color before = tester
          .widget<Scaffold>(find.byType(Scaffold))
          .backgroundColor!;

      await _openSettings(tester);
      await tester.tap(find.text(_l10n(tester).readerBackgroundDark));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isNot(before),
      );
      expect(fixture.settings.stored.background, ReaderBackground.dark);
    });

    testWidgets('settings_whenPagedIsChosen_showsPages', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      expect(find.byType(PageView), findsNothing);

      await _openSettings(tester);
      await tester.tap(find.text(_l10n(tester).readerPageModePaged));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(fixture.settings.stored.pageMode, ReaderPageMode.paged);
    });

    testWidgets('pagedMode_whenThePageIsTurned_remembersTheNewOffset', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(pageMode: ReaderPageMode.paged),
      );

      await _pump(tester, fixture);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      // 翻页把「读到第几页」换算成字符偏移并交给会话（ADR-0044 §决策 4）。
      expect(
        fixture.container.read(readerSessionProvider(_book)).value?.charOffset,
        greaterThan(0),
      );
    });

    testWidgets('dispose_whenLeaving_writesThePosition', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);
      // 换掉整棵子树 → 阅读器 dispose → 落盘（ADR-0044 §决策 2）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(fixture.progress.writes, isNotEmpty);
      expect(
        fixture.progress.writes.last.chapterUrl,
        'https://source.test/1.html',
      );
    });
  });
}
