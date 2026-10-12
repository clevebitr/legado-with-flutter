import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Searches one book source for a keyword (`PLAN.md` 2.4, `searchUrl`).
final class SearchBooks {
  /// Creates the use case.
  const SearchBooks({required this._pages});

  final PageFetchService _pages;

  /// Searches [source] for [keyword] and returns the matching books.
  ///
  /// The keyword is rendered into `searchUrl` by `renderUrlTemplate`, which
  /// form-encodes it exactly once (C-SRC-5, `book-source.md` §4).
  ///
  /// Failures come back as a [ParseResult] instead of reaching the UI as an
  /// exception (C-ERR-1). An empty result list is a **success** — the source
  /// answered and found nothing — while a `bookList` rule that matched nothing is
  /// [ParseFailureKind.parseFailed] (`book-source.md` §7).
  Future<ParseResult<List<Book>>> execute(
    BookSource source,
    String keyword, {
    int page = 1,
  }) async {
    final String? searchUrl = source.searchUrl;
    if (searchUrl == null || searchUrl.trim().isEmpty) {
      _pages.warn('Book source cannot search: source=${source.url}');

      return failureAt<List<Book>>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'searchUrl',
      );
    }

    final String url = _pages.renderUrl(searchUrl, <String, String>{
      'key': keyword,
      'page': '$page',
    });
    final ParseResult<RuleScope> response = await _pages.fetch(
      url,
      rulePath: 'searchUrl',
      headers: source.headers,
      keyword: keyword,
      sourceId: source.url,
    );

    return switch (response) {
      ParseFailure<RuleScope>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<RuleScope>(:final RuleScope data) => _read(
        source,
        url,
        data,
      ),
    };
  }

  /// Reads every search hit out of [scope].
  ParseResult<List<Book>> _read(
    BookSource source,
    String baseUrl,
    RuleScope scope,
  ) {
    final ParseResult<List<RuleScope>> items = _pages.list(
      source.searchRule.bookList,
      scope,
      'searchRule.bookList',
    );

    return switch (items) {
      ParseFailure<List<RuleScope>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) => _books(
        source,
        baseUrl,
        data,
      ),
    };
  }

  /// Reads one [Book] per item, dropping the items without a usable URL.
  ///
  /// A field whose rule matched nothing falls back to `null` (and to an empty name),
  /// because only the URL is required to open a hit. A **rejected** optional field
  /// degrades the same way with a warning (ADR-0026 §决策 2): one unsupported field
  /// must not cost the whole search. A rejected `bookList` is top-level and still
  /// fails the stage, which happens in [PageFetchService.list].
  ParseResult<List<Book>> _books(
    BookSource source,
    String baseUrl,
    List<RuleScope> items,
  ) {
    final SearchRule rules = source.searchRule;
    final List<Book> books = <Book>[];

    for (final RuleScope item in items) {
      final ParseResult<String?> name = _pages.field(
        rules.name,
        item,
        'searchRule.name',
        sourceId: source.url,
      );
      final ParseResult<String?> bookUrl = _pages.field(
        rules.bookUrl,
        item,
        'searchRule.bookUrl',
        sourceId: source.url,
      );
      final ParseResult<String?> author = _pages.field(
        rules.author,
        item,
        'searchRule.author',
        sourceId: source.url,
      );
      final ParseResult<String?> kind = _pages.field(
        rules.kind,
        item,
        'searchRule.kind',
        sourceId: source.url,
      );
      final ParseResult<String?> coverUrl = _pages.field(
        rules.coverUrl,
        item,
        'searchRule.coverUrl',
        sourceId: source.url,
      );
      final ParseResult<String?> intro = _pages.field(
        rules.intro,
        item,
        'searchRule.intro',
        sourceId: source.url,
      );
      final ParseResult<String?> lastChapter = _pages.field(
        rules.lastChapter,
        item,
        'searchRule.lastChapter',
        sourceId: source.url,
      );
      final ParseResult<String?> wordCount = _pages.field(
        rules.wordCount,
        item,
        'searchRule.wordCount',
        sourceId: source.url,
      );

      final String? url = bookUrl.dataOrNull;
      if (url == null || url.isEmpty) {
        // §9：单条失败不中断整页结果，只跳过它并记录。
        _pages.warn('Search hit without URL skipped: source=${source.url}');
        continue;
      }

      books.add(
        Book(
          name: name.dataOrNull ?? '',
          url: resolveAbsoluteUrl(url, baseUrl),
          author: author.dataOrNull,
          kind: kind.dataOrNull,
          coverUrl: resolveAbsoluteUrlOrNull(coverUrl.dataOrNull, baseUrl),
          intro: intro.dataOrNull,
          lastChapter: lastChapter.dataOrNull,
          wordCount: wordCount.dataOrNull,
        ),
      );
    }

    return ParseSuccess<List<Book>>(books);
  }
}
