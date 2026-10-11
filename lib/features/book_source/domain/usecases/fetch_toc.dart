import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart';

/// Reads the table of contents of one book (`PLAN.md` 2.4, `ruleToc`).
///
/// Paging (`nextTocUrl`) belongs to `PLAN.md` 3.5, so this stage reads exactly the
/// page it is given.
final class FetchToc {
  /// Creates the use case.
  const FetchToc({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and reads the chapter list from it.
  ///
  /// A chapter without a usable URL is skipped with a warning instead of failing the
  /// whole table of contents (`book-source.md` §9); a `chapterList` rule that matched
  /// nothing is [ParseFailureKind.parseFailed] (§7).
  Future<ParseResult<List<Chapter>>> execute(
    BookSource source,
    String url,
  ) async {
    final ParseResult<Document> page = await _pages.fetch(
      url,
      rulePath: 'ruleToc',
    );

    return switch (page) {
      ParseFailure<Document>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Chapter>>(kind: kind, rulePath: failedAt),
      ParseSuccess<Document>(:final Document data) => _read(source, url, data),
    };
  }

  /// Reads every chapter entry out of [document].
  ParseResult<List<Chapter>> _read(
    BookSource source,
    String baseUrl,
    Document document,
  ) {
    final TocRule rules = source.tocRule;
    final ParseResult<List<Element>> items = _pages.list(
      rules.chapterList,
      document,
      'tocRule.chapterList',
    );

    return switch (items) {
      ParseFailure<List<Element>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Chapter>>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<Element>>(:final List<Element> data) => _chapters(
        source,
        rules,
        baseUrl,
        data,
      ),
    };
  }

  /// Reads one [Chapter] per item, dropping the entries without a URL.
  ///
  /// A chapter name whose rule matched nothing falls back to an empty string; a
  /// **rejected** rule aborts the stage (C-SRC-4).
  ParseResult<List<Chapter>> _chapters(
    BookSource source,
    TocRule rules,
    String baseUrl,
    List<Element> items,
  ) {
    final List<Chapter> chapters = <Chapter>[];

    for (final Element item in items) {
      final ParseResult<String?> name = _pages.field(
        rules.chapterName,
        item,
        'tocRule.chapterName',
      );
      final ParseResult<String?> url = _pages.field(
        rules.chapterUrl,
        item,
        'tocRule.chapterUrl',
      );

      final ParseFailure<List<Chapter>>? failure = firstFailure<List<Chapter>>(
        <ParseResult<Object?>>[name, url],
      );
      if (failure != null) {
        return failure;
      }

      final String? chapterUrl = url.dataOrNull;
      if (chapterUrl == null || chapterUrl.isEmpty) {
        _pages.warn(
          'Chapter without URL skipped: source=${source.url} toc=$baseUrl',
        );
        continue;
      }

      chapters.add(
        Chapter(
          name: name.dataOrNull ?? '',
          url: resolveAbsoluteUrl(chapterUrl, baseUrl),
        ),
      );
    }

    return ParseSuccess<List<Chapter>>(chapters);
  }
}
