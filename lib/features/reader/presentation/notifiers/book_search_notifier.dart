import 'dart:async';

import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/usecases/search_in_book.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_search_notifier.g.dart';

/// Runs one in-book search and publishes its progress
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
/// against one source would double every request), and disposing it — which is what closing the
/// search sheet does — cancels too, so a closed page stops asking the source for chapters.
@riverpod
class BookSearch extends _$BookSearch {
  BookSearchSession? _session;

  @override
  BookSearchProgress? build(ReaderBook book) {
    ref.onDispose(_stop);

    return null;
  }

  /// Starts searching [chapters] from [fromIndex] for [keyword], replacing any running search.
  Future<void> start({
    required List<ReadingChapter> chapters,
    required int fromIndex,
    required String keyword,
  }) async {
    _stop();
    if (keyword.trim().isEmpty || chapters.isEmpty) {
      // 空关键词 / 空目录：直接给一个「跑完了、0 命中」的终态，不进入进行中。
      state = BookSearchProgress(
        hits: const <BookSearchHit>[],
        scannedChapters: 0,
        totalChapters: chapters.length,
        stop: BookSearchStop.finished,
      );

      return;
    }

    final BookSearchSession session = ref
        .read(searchInBookProvider)
        .execute(
          book: book,
          chapters: chapters,
          keyword: keyword,
          fromIndex: fromIndex,
        );
    _session = session;

    await for (final BookSearchProgress progress in session.progress) {
      // 新一轮已经接手（或者页面已经关了）：这一份进度作废，别覆盖更新的状态。
      if (!identical(_session, session)) {
        return;
      }
      state = progress;
    }
  }

  /// Stops the running search; the hits found so far stay on screen.
  void cancel() => _session?.cancel();

  void _stop() {
    final BookSearchSession? session = _session;
    _session = null;
    session?.cancel();
  }
}
