import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';

/// One other source that has the book being read (`docs/dev/roadmap.md` §3.9-R3).
///
/// Primitives only: the reader must not see `book_source`'s entities (C-ARCH-2), and a source is
/// just a name, a URL and the book's address inside it.
final class ReaderSourceCandidate {
  /// Creates a candidate.
  const ReaderSourceCandidate({
    required this.sourceUrl,
    required this.sourceName,
    required this.bookUrl,
    this.author,
    this.lastChapter,
  });

  /// The candidate source's URL.
  final String sourceUrl;

  /// The candidate source's display name.
  final String sourceName;

  /// The book's detail URL inside that source.
  final String bookUrl;

  /// The author as that source spelled it.
  final String? author;

  /// The latest chapter as that source spelled it.
  final String? lastChapter;
}

/// Where the reader continues after a source switch (ADR-0051 §决策 3).
final class ReaderSourceSwitch {
  /// Creates the result.
  const ReaderSourceSwitch({
    required this.book,
    required this.chapterUrl,
    required this.chapterName,
    required this.chapterIndex,
  });

  /// The same book, now identified by the new source.
  final ReaderBook book;

  /// The chapter aligned to the one the reader was on.
  final String chapterUrl;

  /// That chapter's title in the new source.
  final String chapterName;

  /// That chapter's index in the new source.
  final int chapterIndex;
}

/// Finds other sources for a book and switches the reader onto one of them
/// (`docs/dev/roadmap.md` §3.9-R3).
///
/// The reader declares the port and the composition root binds it to `book_source`'s
/// `SwitchBookSource` plus the shelf's identity migration, so the reader never imports either
/// feature (C-ARCH-2, ADR-0051 §决策 3). Both methods answer a [ParseResult]: a switch can fail
/// (the new source's rules do not fit, its site is down), and the reader shows that failure like any
/// other.
abstract interface class BookSourceSwitcher {
  /// The other sources that have [book], best match first.
  Future<ParseResult<List<ReaderSourceCandidate>>> candidates(ReaderBook book);

  /// Switches [book] onto [candidate], aligned to [currentChapterName].
  ///
  /// The implementation also **migrates the shelf identity** when the book is on the shelf: a
  /// switch changes `(sourceUrl, bookUrl)`, and leaving the old row behind would make the book
  /// appear twice with the old progress (ADR-0051 §决策 3).
  Future<ParseResult<ReaderSourceSwitch>> switchTo({
    required ReaderBook book,
    required ReaderSourceCandidate candidate,
    required String currentChapterName,
    required int currentChapterIndex,
  });
}

/// The answer when nothing bound [BookSourceSwitcher]: a readable failure, never a throw.
final class UnboundBookSourceSwitcher implements BookSourceSwitcher {
  /// Creates the unbound port.
  const UnboundBookSourceSwitcher();

  @override
  Future<ParseResult<List<ReaderSourceCandidate>>> candidates(
    ReaderBook book,
  ) async => failureAt<List<ReaderSourceCandidate>>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'reader.changeSource',
  );

  @override
  Future<ParseResult<ReaderSourceSwitch>> switchTo({
    required ReaderBook book,
    required ReaderSourceCandidate candidate,
    required String currentChapterName,
    required int currentChapterIndex,
  }) async => failureAt<ReaderSourceSwitch>(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'reader.changeSource',
  );
}
