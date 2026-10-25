import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_chapter_source.dart';

/// How long one in-book search may take in total.
///
/// The number is the same order as the other single-source budgets (60 s for an aggregate search,
/// 180 s for a check run, ADR-0049 §决策 3): long enough for a few hundred uncached chapters at two
/// at a time, short enough that a dead source cannot hold the page forever.
const Duration defaultBookSearchBudget = Duration(minutes: 2);

/// Searches one book's chapters for a keyword (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The run is **sequential with a window of [concurrency] chapters**: it starts at the chapter the
/// reader is on and walks forward, at most two chapter requests in flight. A book-wide fan-out would
/// fire one request per chapter of a 2000-chapter source, which is what the per-source rate gate and
/// `HttpPolicy` exist to prevent (`book-source.md` §8, C-NET-2); the politeness itself stays inside
/// `book_source`'s `FetchContent`, because that is where the requests are made.
///
/// The budget is measured here, with the injected [Clock], instead of borrowing
/// `book_source`'s `SourceBudget`: a feature may not import another feature's domain (C-ARCH-2), and
/// the only thing this run needs from it is「一共最多跑多久」. Running out is reported as
/// [BookSearchStop.budgetSpent] rather than as a failure — the hits found so far are still true.
final class SearchInBook {
  /// Creates the use case.
  const SearchInBook({
    required this._content,
    this._clock = const SystemClock(),
    this.budget = defaultBookSearchBudget,
    this.concurrency = 2,
    this.maxHitsPerChapter = 20,
    this.excerptRadius = 40,
  });

  final ChapterContentProvider _content;
  final Clock _clock;

  /// How long the whole run may take.
  final Duration budget;

  /// How many chapter requests may be in flight at once.
  final int concurrency;

  /// How many hits one chapter contributes at most.
  ///
  /// A chapter that repeats the keyword a hundred times is not a hundred destinations; capping keeps
  /// the results list readable and the snapshot small.
  final int maxHitsPerChapter;

  /// How much text around a match the excerpt keeps, per side.
  final int excerptRadius;

  /// Starts a run and answers its session.
  ///
  /// The stream emits one snapshot when the run starts, one after every window, and one terminal
  /// snapshot whose [BookSearchProgress.stop] says why it ended. [keyword] is matched
  /// **case-insensitively** and literally (a regular expression is not a search term here).
  BookSearchSession execute({
    required ReaderBook book,
    required List<ReadingChapter> chapters,
    required String keyword,
    int fromIndex = 0,
  }) {
    final StreamController<BookSearchProgress> controller =
        StreamController<BookSearchProgress>();
    final List<BookSearchHit> hits = <BookSearchHit>[];
    final String pattern = keyword.trim();
    final DateTime deadline = _clock.now().add(budget);
    final int from = fromIndex < 0 ? 0 : fromIndex;
    int scannedChapters = 0;
    int failedChapters = 0;
    bool isCancelled = false;

    void emit(BookSearchStop stop) {
      if (controller.isClosed) {
        return;
      }
      controller.add(
        BookSearchProgress(
          hits: List<BookSearchHit>.unmodifiable(hits),
          scannedChapters: scannedChapters,
          totalChapters: chapters.length,
          failedChapters: failedChapters,
          stop: stop,
        ),
      );
    }

    Future<void> run() async {
      if (pattern.isEmpty) {
        // 空关键词匹配一切：与其返回整本书，不如当成「什么都没搜」直接收工；
        // 也不进入「进行中」，否则页面会闪一下进度再变空。
        emit(BookSearchStop.finished);
        unawaited(controller.close());

        return;
      }

      BookSearchStop stop = BookSearchStop.finished;
      emit(BookSearchStop.running);

      for (int start = from; start < chapters.length; start += _windowSize) {
        if (isCancelled) {
          stop = BookSearchStop.cancelled;
          break;
        }
        if (!_clock.now().isBefore(deadline)) {
          stop = BookSearchStop.budgetSpent;
          break;
        }

        final int end = math.min(start + _windowSize, chapters.length);
        final List<ParseResult<String>> bodies = await Future.wait(
          <Future<ParseResult<String>>>[
            for (int index = start; index < end; index++)
              _read(book: book, chapter: chapters[index]),
          ],
        );

        // 取消发生在这次窗口的请求还在飞的时候：结果直接丢掉，不再往列表里加
        // （ADR-0070 §决策 2「在途请求的结果直接丢弃」）。
        if (isCancelled) {
          stop = BookSearchStop.cancelled;
          break;
        }

        for (int offset = 0; offset < bodies.length; offset++) {
          scannedChapters++;
          switch (bodies[offset]) {
            case ParseSuccess<String>(:final String data):
              hits.addAll(
                _hitsOf(
                  chapterIndex: start + offset,
                  chapter: chapters[start + offset],
                  text: data,
                  pattern: pattern,
                ),
              );
            case ParseFailure<String>():
              // 一章读不出来不等于「这本没搜到」：记下来，跑完时如实报数。
              failedChapters++;
          }
        }

        emit(BookSearchStop.running);
      }

      emit(stop);
      // 不 await `close()`：没有监听者时它要等到有人订阅才完成，那会让 `done` 永远挂着。
      // 事件已经按顺序排进去了，`close()` 只是排在它们后面。
      unawaited(controller.close());
    }

    // 开跑放在下一个微任务：`execute` 之后立刻 `cancel()` 就一个请求都不会发出去
    // （ADR-0070 §决策 2「cancel() 之后不再发起新请求」）。
    final Future<void> done = Future<void>.microtask(run);

    return BookSearchSession._(
      progress: controller.stream,
      done: done,
      cancel: () => isCancelled = true,
    );
  }

  /// At least one: a window of zero would spin the loop forever.
  int get _windowSize => concurrency < 1 ? 1 : concurrency;

  /// Reads one chapter body; a failure is part of the run, not the end of it.
  Future<ParseResult<String>> _read({
    required ReaderBook book,
    required ReadingChapter chapter,
  }) => _content.fetch(
    sourceUrl: book.sourceUrl,
    chapterUrl: chapter.url,
    bookName: book.name,
    chapterTitle: chapter.title,
    bookUrl: book.bookUrl,
    tocUrl: book.tocUrl,
  );

  /// Every match of [pattern] in [text], as hits of one chapter.
  ///
  /// The keyword is escaped and matched case-insensitively through [RegExp] rather than by lowering
  /// both strings: `toLowerCase` can change a string's length, which would shift every offset after
  /// the first such character (`İ` → `i̇`) and land hits in the wrong place.
  List<BookSearchHit> _hitsOf({
    required int chapterIndex,
    required ReadingChapter chapter,
    required String text,
    required String pattern,
  }) {
    final RegExp regex = RegExp(RegExp.escape(pattern), caseSensitive: false);
    final List<BookSearchHit> found = <BookSearchHit>[];

    for (final RegExpMatch match in regex.allMatches(text)) {
      found.add(
        BookSearchHit(
          chapterIndex: chapterIndex,
          chapterTitle: chapter.title,
          chapterUrl: chapter.url,
          offsetInText: match.start,
          excerpt: _excerpt(text, match.start, match.end),
        ),
      );
      if (found.length >= maxHitsPerChapter) {
        break;
      }
    }

    return found;
  }

  /// The text around one match, with line breaks flattened so a row stays one row.
  String _excerpt(String text, int start, int end) {
    final int from = math.max(0, start - excerptRadius);
    final int to = math.min(text.length, end + excerptRadius);

    return <String>[
      if (from > 0) '…',
      text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim(),
      if (to < text.length) '…',
    ].join();
  }
}

/// One running search: its progress stream and the way to stop it
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// [cancel] stops **new** requests; the ones already in flight are awaited and their results are
/// discarded. The chapter bodies they fetched stay in the content cache, which is not a side effect —
/// a normal read would have put them there too.
final class BookSearchSession {
  BookSearchSession._({
    required this.progress,
    required this.done,
    required this._cancel,
  });

  /// Snapshots of the run, ending with the terminal one.
  final Stream<BookSearchProgress> progress;

  /// Completes when the run stopped, cancelled or not.
  final Future<void> done;

  final void Function() _cancel;

  /// Stops the run after the requests already in flight.
  void cancel() => _cancel();
}
