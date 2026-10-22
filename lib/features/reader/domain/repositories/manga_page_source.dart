import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';

/// Reads one manga chapter's image list for the reader (`docs/dev/roadmap.md` §3.10 M16).
///
/// The reader declares this port and the composition root binds it to `book_source`'s
/// `FetchMangaPages`, so the reader never imports that feature (C-ARCH-2, ADR-0041 §决策 2).
/// `bookName` / `chapterTitle` answer `java.get('bookName')` / `java.get('title')` for the source's
/// `@js:` rules (`docs/dev/book-source.md` §6, ADR-0049).
abstract interface class MangaPageProvider {
  /// Reads the images of the chapter at [chapterUrl] of [sourceUrl].
  Future<ParseResult<List<ReadingPage>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  });
}

/// The answer when nothing bound [MangaPageProvider]: an observable failure, never a throw.
final class UnboundMangaPageProvider implements MangaPageProvider {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundMangaPageProvider({required this._logger});

  final AppLogger _logger;

  @override
  Future<ParseResult<List<ReadingPage>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  }) async {
    _logger.warning(
      'No MangaPageProvider is bound: the reader cannot read a manga chapter.',
    );

    return const ParseFailure<List<ReadingPage>>(
      kind: ParseFailureKind.unsupportedRule,
      rulePath: 'reader.mangaPages',
    );
  }
}
