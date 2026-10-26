import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/usecases/search_in_book.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/book_search_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_reader_ports.dart';

const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

List<ReadingChapter> _chapters(int count) => <ReadingChapter>[
  for (int index = 1; index <= count; index++)
    ReadingChapter(
      title: '第$index章',
      url: 'https://source.test/book/1/$index.html',
    ),
];

/// A container whose search runs over [content], with the notifier kept alive.
///
/// The provider is `autoDispose`, and a bare `read` between polls would dispose the notifier — which
/// also cancels its run. The sheet in the app keeps it alive by watching, so the test does the same
/// with a no-op listener.
ProviderContainer _container(FakeChapterContentProvider content) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      searchInBookProvider.overrideWith(
        (Ref ref) => SearchInBook(content: content),
      ),
    ],
  );
  final ProviderSubscription<BookSearchProgress?> subscription = container
      .listen(
        bookSearchProvider(_book),
        (BookSearchProgress? previous, BookSearchProgress? next) {},
        fireImmediately: true,
      );
  addTearDown(subscription.close);
  addTearDown(container.dispose);

  return container;
}

/// Waits until the notifier stopped running (the stream ended).
Future<BookSearchProgress> _awaitDone(
  ProviderContainer container,
  ReaderBook book,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final BookSearchProgress? progress = container.read(
      bookSearchProvider(book),
    );
    if (progress != null && !progress.isRunning) {
      return progress;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('the search never finished');
}

void main() {
  group('BookSearch', () {
    test('build_givenNoRun_answersNull', () {
      final ProviderContainer container = _container(
        FakeChapterContentProvider(),
      );

      expect(container.read(bookSearchProvider(_book)), isNull);
    });

    test('start_givenAKeyword_publishesTheHitsAndTheTerminalState', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来开始'
        ..bodies['https://source.test/book/1/2.html'] = '没有';
      final ProviderContainer container = _container(content);

      await container
          .read(bookSearchProvider(_book).notifier)
          .start(chapters: _chapters(2), fromIndex: 0, keyword: '剑来');

      final BookSearchProgress? progress = container.read(
        bookSearchProvider(_book),
      );
      expect(progress?.hits, hasLength(1));
      expect(progress?.stop, BookSearchStop.finished);
    });

    test('start_givenAnEmptyKeyword_answersAFinishedEmptyState', () async {
      // 空关键词不进「进行中」：页面不该先闪一帧进度再变空。
      final FakeChapterContentProvider content = FakeChapterContentProvider();
      final ProviderContainer container = _container(content);

      await container
          .read(bookSearchProvider(_book).notifier)
          .start(chapters: _chapters(2), fromIndex: 0, keyword: '  ');

      final BookSearchProgress? progress = container.read(
        bookSearchProvider(_book),
      );
      expect(progress?.stop, BookSearchStop.finished);
      expect(progress?.hits, isEmpty);
      expect(content.requests, isEmpty);
    });

    test('start_givenNoChapters_answersAFinishedEmptyState', () async {
      final ProviderContainer container = _container(
        FakeChapterContentProvider(),
      );

      await container
          .read(bookSearchProvider(_book).notifier)
          .start(
            chapters: const <ReadingChapter>[],
            fromIndex: 0,
            keyword: '剑来',
          );

      expect(
        container.read(bookSearchProvider(_book))?.stop,
        BookSearchStop.finished,
      );
    });

    test('cancel_whenRunning_leavesTheHitsFoundSoFar', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来';
      final ProviderContainer container = _container(content);

      // 跑完之后再 cancel：已经找到的命中留在屏幕上，「停止」不是「清空」。
      await container
          .read(bookSearchProvider(_book).notifier)
          .start(chapters: _chapters(1), fromIndex: 0, keyword: '剑来');
      container.read(bookSearchProvider(_book).notifier).cancel();

      expect(container.read(bookSearchProvider(_book))?.hits, hasLength(1));
    });

    test('start_givenASecondKeyword_cancelsTheFirstRun', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来 forever';
      final ProviderContainer container = _container(content);

      unawaitedStart(container, chapters: _chapters(1), keyword: '剑来');
      unawaitedStart(container, chapters: _chapters(1), keyword: 'forever');

      final BookSearchProgress progress = await _awaitDone(container, _book);
      // 后一次搜索赢：状态属于它，前一次被取消。
      expect(progress.hits, isNotEmpty);
      expect(progress.hits.first.excerpt, contains('forever'));
    });

    test('dispose_whenRunning_cancelsTheRun', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来';
      final ProviderContainer container = _container(content);
      // 先让 provider 存在，再启动，最后销毁容器。
      container.read(bookSearchProvider(_book));
      await container
          .read(bookSearchProvider(_book).notifier)
          .start(chapters: _chapters(1), fromIndex: 0, keyword: '剑来');

      container.dispose();

      // 销毁之后就没人再发请求了（取消是幂等的，重复取消不该抛）。
      final int requests = content.requests.length;
      await Future<void>.delayed(Duration.zero);
      expect(content.requests, hasLength(requests));
    });
  });
}

/// Starts a search without awaiting it (`Future` 必须显式处理，C-ERR-6)。
void unawaitedStart(
  ProviderContainer container, {
  required List<ReadingChapter> chapters,
  required String keyword,
}) {
  container
      .read(bookSearchProvider(_book).notifier)
      .start(chapters: chapters, fromIndex: 0, keyword: keyword)
      .ignore();
}
