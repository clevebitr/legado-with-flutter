import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_search.freezed.dart';

/// One match of a search across a book (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// [offsetInText] is an offset into the chapter body **as the reader renders it** — paging joined,
/// the source's `replaceRegex` and the user's purge rules already applied — because that is the text
/// the reader scrolls; a hit therefore lands on the sentence it matched instead of on the chapter's
/// first line (the same contract as a bookmark's `charOffset`, ADR-0066 §决策 7).
@freezed
abstract class BookSearchHit with _$BookSearchHit {
  /// Creates one hit.
  const factory BookSearchHit({
    /// Index of the chapter in the book's list.
    required int chapterIndex,

    /// The chapter's title, so the results list is readable without the chapter list.
    required String chapterTitle,

    /// The chapter's address, which is what the reader opens.
    required String chapterUrl,

    /// Where the match starts inside the chapter body.
    required int offsetInText,

    /// The text around the match, for the results list.
    required String excerpt,
  }) = _BookSearchHit;
}

/// Why a search run stopped.
enum BookSearchStop {
  /// Still running.
  running,

  /// Every chapter after the starting point was scanned.
  finished,

  /// The caller cancelled it; requests already in flight were discarded.
  cancelled,

  /// The run's time budget was spent before it reached the end.
  budgetSpent,
}

/// One snapshot of a search run (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// Progress arrives as a stream of these: every snapshot carries **all** hits found so far, so a
/// consumer that skips a frame still ends with the complete list, and the terminal snapshot says why
/// the run stopped — 「搜完了」/「停了」/「预算用完了」are different things to show.
@freezed
abstract class BookSearchProgress with _$BookSearchProgress {
  const BookSearchProgress._();

  /// Creates one snapshot.
  const factory BookSearchProgress({
    /// Every hit found so far, in chapter order.
    required List<BookSearchHit> hits,

    /// How many chapters were read (successfully or not).
    required int scannedChapters,

    /// How many chapters the run intends to read.
    required int totalChapters,

    /// How many chapters could not be read; their absence is not a silent "no match".
    @Default(0) int failedChapters,

    /// Whether the run is over, and why.
    @Default(BookSearchStop.running) BookSearchStop stop,
  }) = _BookSearchProgress;

  /// Whether the run is still going.
  bool get isRunning => stop == BookSearchStop.running;

  /// Whether every chapter up to [totalChapters] was scanned.
  bool get isComplete => stop == BookSearchStop.finished;
}
