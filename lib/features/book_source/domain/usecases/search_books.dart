import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart';

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
    final ParseResult<Document> response = await _pages.fetch(
      url,
      rulePath: 'searchUrl',
      keyword: keyword,
    );

    return switch (response) {
      ParseFailure<Document>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<Document>(:final Document data) => _read(source, url, data),
    };
  }

  /// Reads every search hit out of [document].
  ParseResult<List<Book>> _read(
    BookSource source,
    String baseUrl,
    Document document,
  ) {
    final ParseResult<List<Element>> items = _pages.list(
      source.searchRule.bookList,
      document,
      'searchRule.bookList',
    );

    return switch (items) {
      ParseFailure<List<Element>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Book>>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<Element>>(:final List<Element> data) => _books(
        source,
        baseUrl,
        data,
      ),
    };
  }

  /// Reads one [Book] per item, dropping the items without a usable URL.
  ///
  /// A field whose rule matched nothing falls back to `null` (and to an empty name),
  /// because only the URL is required to open a hit; a **rejected** rule aborts the
  /// stage instead of producing a half-filled book (C-SRC-4).
  ParseResult<List<Book>> _books(
    BookSource source,
    String baseUrl,
    List<Element> items,
  ) {
    final SearchRule rules = source.searchRule;
    final List<Book> books = <Book>[];

    for (final Element item in items) {
      final ParseResult<String?> name = _pages.field(
        rules.name,
        item,
        'searchRule.name',
      );
      final ParseResult<String?> bookUrl = _pages.field(
        rules.bookUrl,
        item,
        'searchRule.bookUrl',
      );
      final ParseResult<String?> author = _pages.field(
        rules.author,
        item,
        'searchRule.author',
      );
      final ParseResult<String?> kind = _pages.field(
        rules.kind,
        item,
        'searchRule.kind',
      );
      final ParseResult<String?> coverUrl = _pages.field(
        rules.coverUrl,
        item,
        'searchRule.coverUrl',
      );
      final ParseResult<String?> intro = _pages.field(
        rules.intro,
        item,
        'searchRule.intro',
      );
      final ParseResult<String?> lastChapter = _pages.field(
        rules.lastChapter,
        item,
        'searchRule.lastChapter',
      );
      final ParseResult<String?> wordCount = _pages.field(
        rules.wordCount,
        item,
        'searchRule.wordCount',
      );

      final ParseFailure<List<Book>>? failure = firstFailure<List<Book>>(
        <ParseResult<Object?>>[
          name,
          bookUrl,
          author,
          kind,
          coverUrl,
          intro,
          lastChapter,
          wordCount,
        ],
      );
      if (failure != null) {
        return failure;
      }

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
