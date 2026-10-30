import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';
import 'package:flutter_reader/features/reader/domain/usecases/search_in_book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_clock.dart';
import '../../../../support/fake_reader_ports.dart';

const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// Builds [count] chapters addressed `…/1.html`, `…/2.html`, …
List<ReadingChapter> _chapters(int count) => <ReadingChapter>[
  for (int index = 1; index <= count; index++)
    ReadingChapter(
      title: '第$index章',
      url: 'https://source.test/book/1/$index.html',
    ),
];

/// A content provider whose answers can be held open, so a run's window can be observed.
final class _GatedContent implements ChapterContentProvider {
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  /// Bodies per chapter URL.
  final Map<String, String> bodies = <String, String>{};

  /// Chapter URLs requested, in order.
  final List<String> requests = <String>[];

  /// How many requests are in flight right now.
  int inFlight = 0;

  /// The highest [inFlight] ever reached.
  int maxInFlight = 0;

  @override
  Future<ParseResult<String>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
    String bookUrl = '',
    String tocUrl = '',
    String nextChapterUrl = '',
    bool isVip = false,
    bool isPay = false,
    bool isVolume = false,
    String? updateTime,
  }) async {
    requests.add(chapterUrl);
    inFlight++;
    if (inFlight > maxInFlight) {
      maxInFlight = inFlight;
    }
    final Completer<void>? gate = gates[chapterUrl];
    if (gate != null) {
      await gate.future;
    }
    inFlight--;

    return ParseSuccess<String>(bodies[chapterUrl] ?? '');
  }
}

/// Every snapshot a session emitted, in order.
Future<List<BookSearchProgress>> _drain(BookSearchSession session) async {
  final List<BookSearchProgress> snapshots = <BookSearchProgress>[];
  await for (final BookSearchProgress progress in session.progress) {
    snapshots.add(progress);
  }

  return snapshots;
}

void main() {
  group('SearchInBook', () {
    test(
      'execute_givenMatches_answersOneHitPerOccurrenceInChapterOrder',
      () async {
        final FakeChapterContentProvider content = FakeChapterContentProvider()
          ..bodies['https://source.test/book/1/1.html'] = '开头 剑来 中间 剑来'
          ..bodies['https://source.test/book/1/2.html'] = '没有'
          ..bodies['https://source.test/book/1/3.html'] = '剑来在这';

        final BookSearchSession session = SearchInBook(content: content)
            .execute(book: _book, chapters: _chapters(3), keyword: '剑来');
        final List<BookSearchProgress> snapshots = await _drain(session);

        final BookSearchProgress last = snapshots.last;
        expect(last.stop, BookSearchStop.finished);
        expect(last.isComplete, isTrue);
        expect(last.isRunning, isFalse);
        expect(last.scannedChapters, 3);
        expect(
          last.hits.map(
            (BookSearchHit hit) => (hit.chapterIndex, hit.offsetInText),
          ),
          <(int, int)>[(0, 3), (0, 9), (2, 0)],
        );
        // 命中带着章节地址与标题：结果列表不必再回目录里查。
        expect(last.hits.first.chapterUrl, 'https://source.test/book/1/1.html');
        expect(last.hits.first.chapterTitle, '第1章');
        expect(last.hits.first.excerpt, contains('剑来'));
      },
    );

    test('execute_givenDifferentCase_matchesCaseInsensitively', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = 'The Wheel of TIME';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content).execute(
          book: _book,
          chapters: _chapters(1),
          keyword: 'wheel of time',
        ),
      );

      // 大小写不敏感靠 `RegExp(caseSensitive: false)`，偏移仍是原串里的下标。
      expect(snapshots.last.hits.single.offsetInText, 4);
      expect(snapshots.last.hits.single.excerpt, contains('Wheel of TIME'));
    });

    test('execute_givenNoMatch_finishesWithNoHits', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '别的内容';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content)
            .execute(book: _book, chapters: _chapters(1), keyword: '剑来'),
      );

      expect(snapshots.last.hits, isEmpty);
      expect(snapshots.last.stop, BookSearchStop.finished);
    });

    test('execute_givenAnEmptyKeyword_finishesWithoutReading', () async {
      // 空关键词匹配一切：返回整本书不是用户想要的「什么都没搜」。
      final FakeChapterContentProvider content = FakeChapterContentProvider();
      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content)
            .execute(book: _book, chapters: _chapters(3), keyword: '   '),
      );

      expect(snapshots.first.stop, BookSearchStop.finished);
      expect(snapshots.last.hits, isEmpty);
      expect(content.requests, isEmpty);
    });

    test('execute_givenEmptyChapters_finishesWithoutReading', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider();

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content).execute(
          book: _book,
          chapters: const <ReadingChapter>[],
          keyword: 'a',
        ),
      );

      expect(snapshots.last.stop, BookSearchStop.finished);
      expect(snapshots.last.totalChapters, 0);
    });

    test('execute_givenAFailingChapter_countsItAndKeepsReading', () async {
      // 一章读不出来不等于「这本没搜到」：跑完时如实报数，其余章节照常搜。
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..failures['https://source.test/book/1/2.html'] =
            ParseFailureKind.networkTimeout
        ..bodies['https://source.test/book/1/3.html'] = '剑来';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content)
            .execute(book: _book, chapters: _chapters(3), keyword: '剑来'),
      );

      expect(snapshots.last.failedChapters, 1);
      expect(snapshots.last.scannedChapters, 3);
      expect(snapshots.last.hits.single.chapterIndex, 2);
    });

    test(
      'execute_givenFromIndex_startsThereAndSkipsTheEarlierChapters',
      () async {
        final FakeChapterContentProvider content = FakeChapterContentProvider()
          ..bodies['https://source.test/book/1/1.html'] = '剑来'
          ..bodies['https://source.test/book/1/2.html'] = '剑来'
          ..bodies['https://source.test/book/1/3.html'] = '剑来';

        final List<BookSearchProgress> snapshots = await _drain(
          SearchInBook(content: content).execute(
            book: _book,
            chapters: _chapters(3),
            keyword: '剑来',
            fromIndex: 1,
          ),
        );

        // 从当前章往后搜（ADR-0070 §决策 2）：前面的章节既不发请求也不出现。
        expect(content.requests, <String>[
          'https://source.test/book/1/2.html',
          'https://source.test/book/1/3.html',
        ]);
        expect(
          snapshots.last.hits.map((BookSearchHit hit) => hit.chapterIndex),
          <int>[1, 2],
        );
        expect(snapshots.last.totalChapters, 3);
        expect(snapshots.last.scannedChapters, 2);
      },
    );

    test('execute_givenANegativeFromIndex_startsAtTheFirstChapter', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(content: content).execute(
          book: _book,
          chapters: _chapters(1),
          keyword: '剑来',
          fromIndex: -5,
        ),
      );

      expect(snapshots.last.hits, hasLength(1));
    });

    test('execute_givenAWindow_keepsAtMostTwoRequestsInFlight', () async {
      // 并发上限 2（ADR-0070 §决策 2）：2000 章的源不能一次发出上千个请求。
      final _GatedContent content = _GatedContent();
      for (final ReadingChapter chapter in _chapters(4)) {
        content.gates[chapter.url] = Completer<void>();
      }

      final BookSearchSession session = SearchInBook(content: content)
          .execute(book: _book, chapters: _chapters(4), keyword: '剑来');
      // 让第一窗的请求发出去（它们卡在 gate 上）。
      await Future<void>.delayed(Duration.zero);

      expect(content.requests, hasLength(2));
      expect(content.maxInFlight, 2);

      for (final Completer<void> gate in content.gates.values) {
        gate.complete();
      }
      await session.done;

      expect(content.requests, hasLength(4));
      // 每一窗最多同时 2 个，绝不出现 3 个。
      expect(content.maxInFlight, 2);
    });

    test('execute_givenCancelWhileInFlight_discardsThemAndStops', () async {
      final _GatedContent content = _GatedContent();
      content.bodies['https://source.test/book/1/1.html'] = '剑来';
      content.bodies['https://source.test/book/1/2.html'] = '剑来';
      content.gates['https://source.test/book/1/1.html'] = Completer<void>();
      content.gates['https://source.test/book/1/2.html'] = Completer<void>();

      final BookSearchSession session = SearchInBook(content: content)
          .execute(book: _book, chapters: _chapters(4), keyword: '剑来');
      await Future<void>.delayed(Duration.zero);

      session.cancel();
      for (final Completer<void> gate in content.gates.values) {
        gate.complete();
      }
      final List<BookSearchProgress> snapshots = await _drain(session);

      expect(snapshots.last.stop, BookSearchStop.cancelled);
      // 在途请求的结果直接丢掉：取消了就不该再往列表里加命中。
      expect(snapshots.last.hits, isEmpty);
      expect(content.requests, hasLength(2));
    });

    test(
      'execute_givenACancelBeforeTheFirstWindow_stopsWithoutRequesting',
      () async {
        final FakeChapterContentProvider content = FakeChapterContentProvider();

        final BookSearchSession session = SearchInBook(content: content)
            .execute(book: _book, chapters: _chapters(2), keyword: '剑来');
        session.cancel();
        final List<BookSearchProgress> snapshots = await _drain(session);

        expect(snapshots.last.stop, BookSearchStop.cancelled);
        expect(content.requests, isEmpty);
      },
    );

    test('execute_givenAnExhaustedBudget_stopsWithBudgetSpent', () async {
      // 预算按注入时钟量（ADR-0070 §决策 2）：用完就停，已找到的命中仍然是真的。
      final FakeClock clock = FakeClock();
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(
          content: content,
          clock: clock,
          budget: Duration.zero,
        ).execute(book: _book, chapters: _chapters(1), keyword: '剑来'),
      );

      expect(snapshots.last.stop, BookSearchStop.budgetSpent);
      expect(content.requests, isEmpty);
    });

    test('execute_givenManyMatchesInOneChapter_capsThemPerChapter', () async {
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来 ' * 30;

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(
          content: content,
          maxHitsPerChapter: 3,
        ).execute(book: _book, chapters: _chapters(1), keyword: '剑来'),
      );

      expect(snapshots.last.hits, hasLength(3));
    });

    test('execute_givenAWindowOfZero_stillReadsOneChapterAtATime', () async {
      // 0 或者负数会让窗口循环原地打转；夹到 1 才停得下来。
      final FakeChapterContentProvider content = FakeChapterContentProvider()
        ..bodies['https://source.test/book/1/1.html'] = '剑来'
        ..bodies['https://source.test/book/1/2.html'] = '剑来';

      final List<BookSearchProgress> snapshots = await _drain(
        SearchInBook(
          content: content,
          concurrency: 0,
        ).execute(book: _book, chapters: _chapters(2), keyword: '剑来'),
      );

      expect(snapshots.last.hits, hasLength(2));
    });

    test(
      'execute_givenAMatchInTheMiddle_excerptsBothSidesAndFlattensBreaks',
      () async {
        final String text = '${'前' * 60}\n剑来\n${'后' * 60}';
        final FakeChapterContentProvider content = FakeChapterContentProvider()
          ..bodies['https://source.test/book/1/1.html'] = text;

        final List<BookSearchProgress> snapshots = await _drain(
          SearchInBook(
            content: content,
            excerptRadius: 5,
          ).execute(book: _book, chapters: _chapters(1), keyword: '剑来'),
        );

        // 两侧各留 5 个字符，被截断的一侧加省略号，换行压成空格（一行结果就是一行）。
        expect(snapshots.last.hits.single.excerpt, '…前前前前 剑来 后后后后…');
      },
    );

    test(
      'execute_givenAMatchAtTheStart_excerptsWithoutAPrefixEllipsis',
      () async {
        final FakeChapterContentProvider content = FakeChapterContentProvider()
          ..bodies['https://source.test/book/1/1.html'] = '剑来开头';

        final List<BookSearchProgress> snapshots = await _drain(
          SearchInBook(
            content: content,
            excerptRadius: 2,
          ).execute(book: _book, chapters: _chapters(1), keyword: '剑来'),
        );

        expect(snapshots.last.hits.single.excerpt, '剑来开头');
      },
    );
  });
}
