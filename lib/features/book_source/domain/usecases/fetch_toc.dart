import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';

/// Reads the table of contents of one book through `ruleToc`.
///
/// Follows `nextTocUrl` pages in order, bounded by the paging limit.
final class FetchToc {
  /// Creates the use case.
  const FetchToc({required this._pages});

  final PageFetchService _pages;

  /// Fetches [url] and reads the chapter list from it and its `nextTocUrl` pages.
  ///
  /// A chapter without a URL is skipped; a `chapterList` matching nothing on the first page fails.
  Future<ParseResult<List<Chapter>>> execute(
    BookSource source,
    String url, {
    String bookName = '',
    String bookUrl = '',
    String author = '',
    String kind = '',
    String intro = '',
  }) async {
    // 书源自己的限速要在第一个请求之前进预算。
    _pages.applySourceRate(source);
    // `header` 写成规则时也要在第一个请求之前求值。
    final Map<String, String>? headers = await _pages.headersOf(source);
    final ParseResult<PageWalk> walk = await _pages.walk(
      rule: url,
      rulePath: 'ruleToc',
      nextRule: source.tocRule.nextTocUrl,
      nextRulePath: 'tocRule.nextTocUrl',
      context: JsPageContext(
        baseUrl: url,
        source: source.jsSourceInfo,
        headers: headers,
        bookName: bookName,
        book: JsBookInfo(
          name: bookName,
          author: author,
          bookUrl: bookUrl,
          tocUrl: url,
          intro: intro,
          kind: kind,
        ),
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<Chapter>>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => await _read(source, data),
    };
  }

  // 后续页取不到只记 warning 并保留已读章节；第一页匹配不到才算失败。
  Future<ParseResult<List<Chapter>>> _read(
    BookSource source,
    PageWalk walk,
  ) async {
    final ParseFailure<Never>? stopped = walk.stoppedBy;
    if (stopped != null) {
      // 目录缺页：保留已读到的章节，只记录 warning。
      _pages.warn(
        'Table of contents stopped before every page was read: '
        'source=${source.url} field=${stopped.rulePath} kind=${stopped.kind.name}',
      );
    }

    final TocRule rules = source.tocRule;
    final List<Chapter> chapters = <Chapter>[];

    for (var index = 0; index < walk.pages.length; index++) {
      final FetchedPage page = walk.pages[index];
      final ParseResult<List<Chapter>> read = await _chapters(
        source,
        rules,
        page,
      );

      switch (read) {
        case ParseFailure<List<Chapter>>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          if (index == 0) {
            return failureAt<List<Chapter>>(kind: kind, rulePath: failedAt);
          }
          // 后续页的 chapterList 没匹配到，只是「这一页没有目录」。
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

  Future<ParseResult<List<Chapter>>> _chapters(
    BookSource source,
    TocRule rules,
    FetchedPage page,
  ) async {
    final ParseResult<List<RuleScope>> items = await _pages.list(
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
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
        await _entries(source, rules, page.url, data),
    };
  }

  // 章节缺 URL 时跳过；名称 / isVip 缺失回落为空 / 非 VIP。
  Future<ParseResult<List<Chapter>>> _entries(
    BookSource source,
    TocRule rules,
    String baseUrl,
    List<RuleScope> items,
  ) async {
    final List<Chapter> chapters = <Chapter>[];

    for (final RuleScope item in items) {
      final ParseResult<String?> name = await _pages.field(
        rules.chapterName,
        item,
        'tocRule.chapterName',
        sourceId: source.url,
      );
      final ParseResult<String?> url = await _pages.field(
        rules.chapterUrl,
        item,
        'tocRule.chapterUrl',
        sourceId: source.url,
      );
      final ParseResult<String?> vip = await _pages.field(
        rules.isVip,
        item,
        'tocRule.isVip',
        sourceId: source.url,
      );
      final ParseResult<String?> updateTime = await _pages.field(
        rules.updateTime,
        item,
        'tocRule.updateTime',
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
          // 选项（`,{webView:…}`）必须留在 URL 之外解析：先绝对化会把 `{` 编码成 `%7B`。
          url: resolveUrlRule(chapterUrl, baseUrl),
          isVip: _isVip(vip.dataOrNull),
          // 展示用字符串：保留规则原文，不做日期解析。
          updateTime: updateTime.dataOrNull,
        ),
      );
    }

    return ParseSuccess<List<Chapter>>(chapters);
  }
}

// 上游 isTrue()：null、空白与字面量 "null" 为 false，其余除否定词外为 true。
bool _isVip(String? value) {
  if (value == null || value.trim().isEmpty || value == 'null') {
    return false;
  }

  return !_falseVipValue.hasMatch(value.trim());
}

// 上游 isTrue() 视为 false 的字面量；`.` 未转义是有意跟随上游。
final RegExp _falseVipValue = RegExp(
  r'^(?:false|no|not|0|0.0)$',
  caseSensitive: false,
);
