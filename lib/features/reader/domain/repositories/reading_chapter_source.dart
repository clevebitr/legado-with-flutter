import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';

/// Reads one book's table of contents for the reader (`docs/dev/roadmap.md` 5.3).
///
/// The reader declares this port and the composition root binds it to `book_source`'s
/// `FetchToc`, so the reader never imports that feature (C-ARCH-2, ADR-0041 §决策 2). The source
/// URL travels with the request because the adapter has to resolve the book source from it — a
/// shelf row may name a source that is not the currently selected one.
abstract interface class ChapterListProvider {
  /// Reads the chapters of [sourceUrl] that live at [tocUrl].
  Future<ParseResult<List<ReadingChapter>>> fetch({
    required String sourceUrl,
    required String tocUrl,
  });
}

/// Reads one chapter body for the reader (`docs/dev/roadmap.md` 5.3).
///
/// Bound to `book_source`'s `FetchContent`, which is what makes the reader share the chapter body
/// cache of 5.2 (a second visit costs no request).
abstract interface class ChapterContentProvider {
  /// Reads the body at [chapterUrl] of [sourceUrl].
  Future<ParseResult<String>> fetch({
    required String sourceUrl,
    required String chapterUrl,
  });
}

/// The answer when nothing bound [ChapterListProvider]: an observable failure, never a throw.
///
/// It is the default of the provider, so a forgotten binding shows up as a failure message plus
/// one warning instead of a crash (ADR-0041 §决策 2). The `rulePath` is pinned by a test, which is
/// what keeps the failure locatable (C-SRC-8).
final class UnboundChapterListProvider implements ChapterListProvider {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundChapterListProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<List<ReadingChapter>>> fetch({
    required String sourceUrl,
    required String tocUrl,
  }) async {
    _logger.warning(
      'No ChapterListProvider is bound: the reader cannot read a table of contents.',
    );

    return const ParseFailure<List<ReadingChapter>>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'reader.chapterList',
    );
  }
}

/// The answer when nothing bound [ChapterContentProvider]: an observable failure, never a throw.
final class UnboundChapterContentProvider implements ChapterContentProvider {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundChapterContentProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<String>> fetch({
    required String sourceUrl,
    required String chapterUrl,
  }) async {
    _logger.warning(
      'No ChapterContentProvider is bound: the reader cannot read a chapter body.',
    );

    return const ParseFailure<String>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'reader.chapterContent',
    );
  }
}
