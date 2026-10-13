import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Reads the detail page of one book (`PLAN.md` 2.4, `ruleBookInfo`).
final class FetchBookInfo {
  /// Creates the use case.
  const FetchBookInfo({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and reads the book detail from it.
  ///
  /// A field whose rule is absent, matched nothing or was **rejected** stays `null`
  /// (ADR-0026 §决策 2), so an absent cover or intro is not fatal and an unsupported
  /// optional field no longer costs the whole detail page; the degradation is logged
  /// with its `rulePath` and the book source id (C-SRC-8, C-ERR-8). A *malformed*
  /// rule still travels as a failure (C-SRC-4).
  Future<ParseResult<BookInfo>> execute(BookSource source, String url) async {
    final ParseResult<RuleScope> page = await _pages.fetch(
      url,
      rulePath: 'ruleBookInfo',
      headers: source.headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (page) {
      ParseFailure<RuleScope>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<BookInfo>(kind: kind, rulePath: failedAt),
      ParseSuccess<RuleScope>(:final RuleScope data) => await _read(
        source,
        url,
        data,
      ),
    };
  }

  /// Reads every `ruleBookInfo` field out of [scope].
  Future<ParseResult<BookInfo>> _read(
    BookSource source,
    String url,
    RuleScope scope,
  ) async {
    final BookInfoRule? rules = source.bookInfoRule;
    final ParseResult<String?> name = await _pages.field(
      rules?.name,
      scope,
      'bookInfoRule.name',
      sourceId: source.url,
    );
    final ParseResult<String?> author = await _pages.field(
      rules?.author,
      scope,
      'bookInfoRule.author',
      sourceId: source.url,
    );
    final ParseResult<String?> kind = await _pages.field(
      rules?.kind,
      scope,
      'bookInfoRule.kind',
      sourceId: source.url,
    );
    final ParseResult<String?> coverUrl = await _pages.field(
      rules?.coverUrl,
      scope,
      'bookInfoRule.coverUrl',
      sourceId: source.url,
    );
    final ParseResult<String?> intro = await _pages.field(
      rules?.intro,
      scope,
      'bookInfoRule.intro',
      sourceId: source.url,
    );
    final ParseResult<String?> lastChapter = await _pages.field(
      rules?.lastChapter,
      scope,
      'bookInfoRule.lastChapter',
      sourceId: source.url,
    );
    final ParseResult<String?> wordCount = await _pages.field(
      rules?.wordCount,
      scope,
      'bookInfoRule.wordCount',
      sourceId: source.url,
    );
    final ParseResult<String?> updateTime = await _pages.field(
      rules?.updateTime,
      scope,
      'bookInfoRule.updateTime',
      sourceId: source.url,
    );
    final ParseResult<String?> tocUrl = await _pages.field(
      rules?.tocUrl,
      scope,
      'bookInfoRule.tocUrl',
      sourceId: source.url,
    );

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
        // 展示用字符串：规则结果原文，不做日期解析（book-source.md §2）。
        updateTime: updateTime.dataOrNull,
      ),
    );
  }
}
