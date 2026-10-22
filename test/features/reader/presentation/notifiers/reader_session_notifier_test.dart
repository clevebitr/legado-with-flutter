import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
  ReadingChapter(title: '第3章', url: 'https://source.test/3.html'),
];

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeChapterListProvider chapters,
  FakeChapterContentProvider content,
  FakeReadingProgressStore progress,
  FakeLogPrinter printer,
});

/// Builds a container around the three reader ports.
_Fixture _fixture({
  FakeChapterListProvider? chapters,
  FakeReadingProgressStore? progress,
}) {
  final FakeChapterListProvider list = chapters ?? FakeChapterListProvider();
  if (chapters == null) {
    list.chapters = _chapters;
  }
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = '第一章正文'
    ..bodies['https://source.test/2.html'] = '第二章正文'
    ..bodies['https://source.test/3.html'] = '第三章正文';
  final FakeReadingProgressStore store = progress ?? FakeReadingProgressStore();
  final FakeLogPrinter printer = FakeLogPrinter();

  return (
    container: ProviderContainer.test(
      overrides: <Override>[
        readerChapterListProvider.overrideWithValue(list),
        readerChapterContentProvider.overrideWithValue(content),
        readerProgressStoreProvider.overrideWithValue(store),
        appLoggerProvider.overrideWithValue(
          AppLogger(level: LogLevel.debug, printer: printer),
        ),
      ],
    ),
    chapters: list,
    content: content,
    progress: store,
    printer: printer,
  );
}

void main() {
  group('ReaderSession', () {
    test('build_givenNoStoredPosition_opensTheFirstChapter', () async {
      final _Fixture fixture = _fixture();

      final ReaderSessionState state = await fixture.container.read(
        readerSessionProvider(_book).future,
      );

      expect(state.chapterIndex, 0);
      expect(state.charOffset, 0);
      expect(fixture.chapters.requests.single, (_book.sourceUrl, _book.tocUrl));
    });

    test(
      'readerContent_givenABookAndChapter_passesTheirNamesToTheSource',
      () async {
        // M12-A5 / ADR-0049：阅读器是**唯一**同时知道书名与章节名的调用方，所以它必须把
        // 这两个值交给书源（`java.get('bookName')` / `java.get('title')`）。
        final _Fixture fixture = _fixture();
        // 先让目录加载完，章节名才对得上。
        await fixture.container.read(readerChaptersProvider(_book).future);

        await fixture.container.read(
          readerContentProvider((_book, 'https://source.test/1.html')).future,
        );

        expect(fixture.chapters.bookNames.single, '剑来');
        expect(fixture.content.contexts.single, ('剑来', '第1章'));
      },
    );

    test('build_givenAStoredPosition_restoresChapterAndOffset', () async {
      // 进度写入 → 恢复的往返：写进 store 的那一份必须原样回来（验收要求的往返测试）。
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(
              chapterUrl: 'https://source.test/2.html',
              chapterName: '第2章',
              charOffset: 42,
            );
      final _Fixture fixture = _fixture(progress: store);

      final ReaderSessionState state = await fixture.container.read(
        readerSessionProvider(_book).future,
      );

      expect(state.chapterIndex, 1);
      expect(state.charOffset, 42);
    });

    test('build_givenAStoredChapterThatIsGone_opensTheFirstChapter', () async {
      // 源重排了章节：不要把读者挡在门外，从第一章开始。
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..positions['${_book.sourceUrl}|${_book.bookUrl}'] =
            const ReadingPosition(
              chapterUrl: 'https://source.test/removed.html',
            );
      final _Fixture fixture = _fixture(progress: store);

      final ReaderSessionState state = await fixture.container.read(
        readerSessionProvider(_book).future,
      );

      expect(state.chapterIndex, 0);
      expect(state.charOffset, 0);
    });

    test('build_givenAFailingChapterList_keepsTheFirstChapter', () async {
      final FakeChapterListProvider list = FakeChapterListProvider()
        ..failure = const ParseFailure<List<ReadingChapter>>(
          kind: ParseFailureKind.networkFailed,
          rulePath: 'reader.chapterList',
        );
      final _Fixture fixture = _fixture(chapters: list);

      final ReaderSessionState state = await fixture.container.read(
        readerSessionProvider(_book).future,
      );

      expect(state.chapterIndex, 0);
    });

    test('selectChapter_whenCalled_writesTheNewPosition', () async {
      final _Fixture fixture = _fixture();
      final ReaderSession session = fixture.container.read(
        readerSessionProvider(_book).notifier,
      );
      await fixture.container.read(readerSessionProvider(_book).future);

      await session.selectChapter(1);

      expect(session.state.value?.chapterIndex, 1);
      expect(
        fixture.progress.writes.single.chapterUrl,
        'https://source.test/2.html',
      );
      expect(fixture.progress.writes.single.chapterName, '第2章');
    });

    test('selectChapter_givenAnIndexOutOfRange_doesNothing', () async {
      final _Fixture fixture = _fixture();
      final ReaderSession session = fixture.container.read(
        readerSessionProvider(_book).notifier,
      );
      await fixture.container.read(readerSessionProvider(_book).future);
      await session.selectChapter(1);

      await session.selectChapter(7);
      await session.selectChapter(-1);

      expect(session.state.value?.chapterIndex, 1);
    });

    test('nextChapterAndPreviousChapter_whenAtTheBounds_stayPut', () async {
      final _Fixture fixture = _fixture();
      final ReaderSession session = fixture.container.read(
        readerSessionProvider(_book).notifier,
      );
      await fixture.container.read(readerSessionProvider(_book).future);

      // 第一章再往前 / 最后一章再往后：不越界、不写进度。
      await session.previousChapter();
      expect(session.state.value?.chapterIndex, 0);
      await session.selectChapter(2);
      await session.nextChapter();
      expect(session.state.value?.chapterIndex, 2);
    });

    test('updateOffset_givenANegativeOffset_clampsToZero', () async {
      final _Fixture fixture = _fixture();
      final ReaderSession session = fixture.container.read(
        readerSessionProvider(_book).notifier,
      );
      await fixture.container.read(readerSessionProvider(_book).future);

      session.updateOffset(-10);
      expect(session.state.value?.charOffset, 0);
      session.updateOffset(30);
      expect(session.state.value?.charOffset, 30);
    });

    test('saveProgress_thenRebuild_restoresTheSamePosition', () async {
      // 同一个 store 换一个容器：这正是「退出再进来」的数据路径。
      final _Fixture first = _fixture();
      final ReaderSession session = first.container.read(
        readerSessionProvider(_book).notifier,
      );
      await first.container.read(readerSessionProvider(_book).future);
      await session.selectChapter(2);
      session.updateOffset(88);
      await session.saveProgress();
      final _Fixture second = _fixture(progress: first.progress);

      final ReaderSessionState restored = await second.container.read(
        readerSessionProvider(_book).future,
      );

      expect(restored.chapterIndex, 2);
      expect(restored.charOffset, 88);
    });

    test('saveProgress_givenAFailingStore_keepsTheSessionAndWarns', () async {
      final FakeReadingProgressStore store = FakeReadingProgressStore()
        ..failWrites = true;
      final _Fixture fixture = _fixture(progress: store);
      final ReaderSession session = fixture.container.read(
        readerSessionProvider(_book).notifier,
      );
      await fixture.container.read(readerSessionProvider(_book).future);

      await session.selectChapter(1);

      // 丢一个书签不能连章节一起丢（C-ERR-2 的边界）：状态照旧，日志有一条。
      expect(session.state.value?.chapterIndex, 1);
      expect(
        fixture.printer.events.last.message.toString(),
        contains('Saving the reading position failed'),
      );
    });
  });
}
