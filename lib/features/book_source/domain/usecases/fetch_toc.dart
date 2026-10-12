import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Reads the table of contents of one book (`PLAN.md` 2.4, `ruleToc`).
///
/// Paging follows the source's `nextTocUrl` rule (`PLAN.md` 3.5): the requested page
/// and every page the rule names are read, in order, bounded by `book-source.md` §9.
final class FetchToc {
  /// Creates the use case.
  const FetchToc({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and reads the chapter list from it and its `nextTocUrl` pages.
  ///
  /// A chapter without a usable URL is skipped with a warning instead of failing the
  /// whole table of contents (`book-source.md` §9); a `chapterList` rule that matched
  /// nothing on the **first** page is [ParseFailureKind.parseFailed] (§7).
  Future<ParseResult<List<Chapter>>> execute(
    BookSource source,
    String url,
  ) async {
    final ParseResult<PageWalk> walk = await _pages.walk(
      url: url,
      rulePath: 'ruleToc',
      nextRule: source.tocRule.nextTocUrl,
      nextRulePath: 'tocRule.nextTocUrl',
      headers: source.headers,
      sourceId: source.url,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Chapter>>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => _read(source, data),
    };
  }

  /// Reads every walked page into one chapter list.
  ///
  /// A **later** page that cannot be fetched or read does not fail the stage: §9
  /// tolerates a missing table-of-contents page, so the chapters read so far come back
  /// with a warning. The first page keeps the strict rule of §7 — a source whose
  /// `chapterList` does not fit its own entry page has nothing to show.
  ParseResult<List<Chapter>> _read(BookSource source, PageWalk walk) {
    final ParseFailure<Never>? stopped = walk.stoppedBy;
    if (stopped != null) {
      // §9 目录缺页：翻页取不到时保留已读到的章节，只记录 warning。
      _pages.warn(
        'Table of contents stopped before every page was read: '
        'source=${source.url} field=${stopped.rulePath} kind=${stopped.kind.name}',
      );
    }

    final TocRule rules = source.tocRule;
    final List<Chapter> chapters = <Chapter>[];

    for (var index = 0; index < walk.pages.length; index++) {
      final FetchedPage page = walk.pages[index];
      final ParseResult<List<Chapter>> read = _chapters(source, rules, page);

      switch (read) {
        case ParseFailure<List<Chapter>>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          if (index == 0) {
            return failureAt<List<Chapter>>(kind: kind, rulePath: failedAt);
          }
          // 同理：后续页的 chapterList 一个都没匹配到只是「这一页没有目录」。
          _pages.warn(
            'Table of contents page skipped: source=${source.url} '
            'field=$failedAt kind=${kind.name}',
          );

          return ParseSuccess<List<Chapter>>(chapters);
        case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
          chapters.addAll(data);
      }
    }

    return ParseSuccess<List<Chapter>>(chapters);
  }

  /// Reads the chapter list of one walked [page].
  ParseResult<List<Chapter>> _chapters(
    BookSource source,
    TocRule rules,
    FetchedPage page,
  ) {
    final ParseResult<List<RuleScope>> items = _pages.list(
      rules.chapterList,
      page.scope,
      'tocRule.chapterList',
    );

    return switch (items) {
      ParseFailure<List<RuleScope>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Chapter>>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) => _entries(
        source,
        rules,
        page.url,
        data,
      ),
    };
  }

  /// Reads one [Chapter] per item, dropping the entries without a URL.
  ///
  /// A chapter name or `isVip` field whose rule matched nothing or was **rejected**
  /// falls back to empty / non-VIP with a warning (ADR-0026 §决策 2); a rejected
  /// `chapterList` is top-level and still fails the stage, which happens in
  /// [PageFetchService.list].
  ParseResult<List<Chapter>> _entries(
    BookSource source,
    TocRule rules,
    String baseUrl,
    List<RuleScope> items,
  ) {
    final List<Chapter> chapters = <Chapter>[];

    for (final RuleScope item in items) {
      final ParseResult<String?> name = _pages.field(
        rules.chapterName,
        item,
        'tocRule.chapterName',
        sourceId: source.url,
      );
      final ParseResult<String?> url = _pages.field(
        rules.chapterUrl,
        item,
        'tocRule.chapterUrl',
        sourceId: source.url,
      );
      final ParseResult<String?> vip = _pages.field(
        rules.isVip,
        item,
        'tocRule.isVip',
        sourceId: source.url,
      );

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
          isVip: _isVip(vip.dataOrNull),
        ),
      );
    }

    return ParseSuccess<List<Chapter>>(chapters);
  }
}

/// Whether an `isVip` value marks its chapter as VIP (`book-source.md` §4.1).
///
/// The rule's result is a string, and upstream marks the chapter VIP only when the
/// string is **true-ish**: `null`, an empty string, `false` and `0` all stay non-VIP,
/// while `true`, `1` and any other non-empty value (some sources write `是` or `VIP`)
/// mark it. The compare is case-insensitive because the two spellings of `false` both
/// occur in real exports, and §4.1 owns the list rather than this file.
bool _isVip(String? value) {
  if (value == null) {
    return false;
  }

  final String normalized = value.trim().toLowerCase();

  return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
}
