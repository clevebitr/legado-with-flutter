import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/presentation/pages/manga_reader_page.dart';
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

/// Two chapters, so chapter navigation is meaningful.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章 开端', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章 继续', url: 'https://source.test/2.html'),
];

/// The pages of chapter 1.
const List<ReadingPage> _pages = <ReadingPage>[
  ReadingPage(url: 'https://img.test/1.jpg'),
  ReadingPage(url: 'https://img.test/2.jpg'),
];

/// A 1x1 transparent PNG, so a page image decodes without any network or cache manager.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The test image loader: every page is the same pixel, so nothing touches HTTP.
ImageProvider _testImage(ReadingPage page) => MemoryImage(_pixel);

/// A provider whose bytes are not an image, so the page's error tile can be exercised.
ImageProvider _brokenImage(ReadingPage page) =>
    MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeMangaPageProvider manga,
  FakeReadingProgressStore progress,
  FakeReaderSourceKindProvider kind,
});

/// Builds a container around the manga ports.
_Fixture _fixture({ReaderSettings? settings, FakeMangaPageProvider? manga}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeMangaPageProvider pages =
      manga ??
      (FakeMangaPageProvider()
        ..pages['https://source.test/1.html'] = _pages
        ..pages['https://source.test/2.html'] = _pages);
  final FakeReadingProgressStore progress = FakeReadingProgressStore();
  final FakeReaderSourceKindProvider kind = FakeReaderSourceKindProvider()
    ..kind = ReaderSourceKind.image;
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerMangaPagesProvider.overrideWithValue(pages),
      readerProgressStoreProvider.overrideWithValue(progress),
      readerSourceKindPortProvider.overrideWithValue(kind),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async => FakeReaderSettingsRepository(initial: settings),
      ),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (container: container, manga: pages, progress: progress, kind: kind);
}

/// Pumps [page] on top of [fixture], sized like a phone.
Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture, {
  Widget? page,
  String? chapterUrl,
  ImageProvider Function(ReadingPage page)? imageProvider,
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
        home:
            page ??
            MangaReaderPage(
              book: _book,
              chapterUrl: chapterUrl,
              imageProvider: imageProvider ?? _testImage,
            ),
      ),
    ),
  );
  // 图片解码是异步的，但测试不该等一个可能永远不结束的动画：固定 pump 几帧即可。
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The strings the page renders, taken from the page's own localization.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(MangaReaderPage));

void main() {
  group('MangaReaderPage', () {
    testWidgets('build_givenAPagedChapter_showsOneTileAndTheCounter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(pageMode: ReaderPageMode.paged),
      );

      await _pump(tester, fixture);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.mangaPageIndicator(1, 2)), findsOneWidget);
      expect(fixture.manga.requests, <String>['https://source.test/1.html']);
    });

    testWidgets('paged_whenThePageIsSwiped_savesThePageIndex', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(pageMode: ReaderPageMode.paged),
      );

      await _pump(tester, fixture);
      final AppLocalizations l10n = _l10n(tester);

      await tester.fling(find.byType(PageView), const Offset(-900, 0), 1200);
      // PageView 的落位动画 + 预取：pump 固定帧，不用会等动画停的 pumpAndSettle。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(l10n.mangaPageIndicator(2, 2)), findsOneWidget);
      // 漫画的进度是**页号**，不是正文字符比例（ADR-0053 §决策 3）。
      expect(fixture.progress.writes.last.charOffset, 1);
      expect(
        fixture.progress.writes.last.chapterUrl,
        'https://source.test/1.html',
      );
    });

    testWidgets('scroll_whenTheChapterIsLong_showsTheStripAndTheCounter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text(l10n.mangaPageIndicator(1, 2)), findsOneWidget);
    });

    testWidgets('chapter_whenNextIsChosen_loadsTheNextChaptersPages', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        settings: ReaderSettings(pageMode: ReaderPageMode.paged),
      );
      await _pump(tester, fixture);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.readerNextChapter));
      await tester.pumpAndSettle();

      expect(fixture.manga.requests.last, 'https://source.test/2.html');
      expect(
        fixture.progress.writes.last.chapterUrl,
        'https://source.test/2.html',
      );
    });

    testWidgets('build_givenTheRouteNamesAChapter_opensThatOne', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture, chapterUrl: 'https://source.test/2.html');

      expect(fixture.manga.requests, contains('https://source.test/2.html'));
    });

    testWidgets('build_givenAFailingChapter_offersRetry', (
      WidgetTester tester,
    ) async {
      final FakeMangaPageProvider manga = FakeMangaPageProvider()
        ..failures['https://source.test/1.html'] =
            ParseFailureKind.networkFailed;
      final _Fixture fixture = _fixture(manga: manga);

      await _pump(tester, fixture);
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text(l10n.actionRetry), findsOneWidget);
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();

      expect(manga.requests, hasLength(2));
    });

    testWidgets('image_whenItCannotBeDecoded_offersItsOwnRetry', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture, imageProvider: _brokenImage);
      final AppLocalizations l10n = _l10n(tester);

      // 一张坏图只让这一页显示失败与重试，整章不受影响（ADR-0053 §决策 3）。
      // PageView 会预建相邻页，所以失败页可能不止一个。
      expect(find.text(l10n.mangaImageFailed), findsWidgets);
      expect(find.text(l10n.actionRetry), findsWidgets);
    });
  });

  group('ReaderPage dispatch', () {
    testWidgets('reader_givenAnImageSource_buildsTheMangaReader', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        manga: FakeMangaPageProvider()
          ..pages['https://source.test/1.html'] = const <ReadingPage>[],
      );

      await _pump(tester, fixture, page: const ReaderPage(book: _book));

      expect(find.byType(MangaReaderPage), findsOneWidget);
    });
  });
}
