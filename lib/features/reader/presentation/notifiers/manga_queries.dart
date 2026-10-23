import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manga_queries.g.dart';

/// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16/M17).
///
/// It is the async seam `ReaderPage` waits on before building any body: the answer decides whether
/// a text, image or audio request is the right one, so guessing "text" while the port loads would
/// fetch a chapter body nobody shows. The file is named after manga because M16 introduced it; the
/// audio body (M17) dispatches on the same answer instead of asking the source twice.
@riverpod
Future<ParseResult<ReaderSourceKind>> readerSourceKind(
  Ref ref,
  String sourceUrl,
) => ref.watch(readerSourceKindPortProvider).of(sourceUrl);

/// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
///
/// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
/// a detached continuation write into a dead state. The chapter title comes from the already-loaded
/// chapter list, exactly as the text body does, because it feeds `java.get('title')`.
@riverpod
Future<ParseResult<List<ReadingPage>>> mangaPages(
  Ref ref,
  (ReaderBook, String) request,
) {
  final (ReaderBook book, String chapterUrl) = request;
  final ParseResult<List<ReadingChapter>>? chapters = ref
      .watch(readerChaptersProvider(book))
      .value;

  return ref
      .watch(readerMangaPagesProvider)
      .fetch(
        sourceUrl: book.sourceUrl,
        chapterUrl: chapterUrl,
        bookName: book.name,
        chapterTitle: _chapterTitleOf(chapters, chapterUrl),
      );
}

/// The title the chapter list gave [chapterUrl], or empty when the list has not loaded yet.
String _chapterTitleOf(
  ParseResult<List<ReadingChapter>>? chapters,
  String chapterUrl,
) {
  if (chapters is! ParseSuccess<List<ReadingChapter>>) {
    return '';
  }
  for (final ReadingChapter chapter in chapters.data) {
    if (chapter.url == chapterUrl) {
      return chapter.title;
    }
  }

  return '';
}
