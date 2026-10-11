import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart';

/// Reads the detail page of one book (`PLAN.md` 2.4, `ruleBookInfo`).
final class FetchBookInfo {
  /// Creates the use case.
  const FetchBookInfo({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and reads the book detail from it.
  ///
  /// A field whose rule is absent or matched nothing stays `null`, so an absent
  /// cover or intro is not fatal; a **rejected** rule aborts the stage and travels
  /// as [ParseFailureKind.unsupportedRule], so a source that needs a later phase is
  /// reported instead of yielding a half-filled book (C-SRC-4).
  Future<ParseResult<BookInfo>> execute(BookSource source, String url) async {
    final ParseResult<Document> page = await _pages.fetch(
      url,
      rulePath: 'ruleBookInfo',
    );

    return switch (page) {
      ParseFailure<Document>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<BookInfo>(kind: kind, rulePath: failedAt),
      ParseSuccess<Document>(:final Document data) => _read(source, url, data),
    };
  }

  /// Reads every `ruleBookInfo` field out of [document].
  ParseResult<BookInfo> _read(
    BookSource source,
    String url,
    Document document,
  ) {
    final BookInfoRule? rules = source.bookInfoRule;
    final ParseResult<String?> name = _pages.field(
      rules?.name,
      document,
      'bookInfoRule.name',
    );
    final ParseResult<String?> author = _pages.field(
      rules?.author,
      document,
      'bookInfoRule.author',
    );
    final ParseResult<String?> kind = _pages.field(
      rules?.kind,
      document,
      'bookInfoRule.kind',
    );
    final ParseResult<String?> coverUrl = _pages.field(
      rules?.coverUrl,
      document,
      'bookInfoRule.coverUrl',
    );
    final ParseResult<String?> intro = _pages.field(
      rules?.intro,
      document,
      'bookInfoRule.intro',
    );
    final ParseResult<String?> lastChapter = _pages.field(
      rules?.lastChapter,
      document,
      'bookInfoRule.lastChapter',
    );
    final ParseResult<String?> wordCount = _pages.field(
      rules?.wordCount,
      document,
      'bookInfoRule.wordCount',
    );
    final ParseResult<String?> tocUrl = _pages.field(
      rules?.tocUrl,
      document,
      'bookInfoRule.tocUrl',
    );

    final ParseFailure<BookInfo>? failure = firstFailure<BookInfo>(
      <ParseResult<Object?>>[
        name,
        author,
        kind,
        coverUrl,
        intro,
        lastChapter,
        wordCount,
        tocUrl,
      ],
    );
    if (failure != null) {
      return failure;
    }

    final String? toc = tocUrl.dataOrNull;

    return ParseSuccess<BookInfo>(
      BookInfo(
        name: name.dataOrNull ?? '',
        url: url,
        // 上游：`tocUrl` 规则缺失时目录就在书籍页本身，因此回落到书籍 URL。
        tocUrl: resolveAbsoluteUrl(toc == null || toc.isEmpty ? url : toc, url),
        author: author.dataOrNull,
        kind: kind.dataOrNull,
        coverUrl: resolveAbsoluteUrlOrNull(coverUrl.dataOrNull, url),
        intro: intro.dataOrNull,
        lastChapter: lastChapter.dataOrNull,
        wordCount: wordCount.dataOrNull,
      ),
    );
  }
}
