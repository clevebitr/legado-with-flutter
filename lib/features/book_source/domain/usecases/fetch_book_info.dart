import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Reads the detail page of one book (`docs/dev/roadmap.md` 2.4, `ruleBookInfo`).
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
    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);
    // `header` 写成规则时要在**第一个请求之前**求值（book-source.md §2、M12-A2）。
    final Map<String, String>? headers = await _pages.headersOf(source);
    // 详情页地址也是 **URL 规则**（可以带 `,{…}` 后缀，`book-source.md` §4.3）。
    final ParseResult<FetchedPage> fetched = await _pages.fetchRule(
      url,
      rulePath: 'ruleBookInfo',
      params: const <String, String>{},
      context: JsPageContext(
        baseUrl: url,
        source: source.jsSourceInfo,
        headers: headers,
        // 详情阶段还不知道书名 / 作者（它们和 tocUrl 在同一次读取里），先把两个 URL 给规则：
        // `book.tocUrl` / `book.bookUrl` 在这一阶段指向书籍页本身（上游的回落口径）。
        book: JsBookInfo(bookUrl: url, tocUrl: url),
        // `fromBookInfo`（M25/S3b）：规则可以据此区分「在详情页跑」与「在列表页跑」。
        fromBookInfo: true,
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
      login: source.loginGuard,
    );

    return switch (fetched) {
      ParseFailure<FetchedPage>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<BookInfo>(kind: kind, rulePath: failedAt),
      ParseSuccess<FetchedPage>(data: final FetchedPage page) =>
        switch (await _initScope(source, page.scope)) {
          ParseFailure<RuleScope>(
            :final ParseFailureKind kind,
            rulePath: final String failedAt,
          ) =>
            failureAt<BookInfo>(kind: kind, rulePath: failedAt),
          ParseSuccess<RuleScope>(data: final RuleScope scope) => await _read(
            source,
            page.url,
            scope,
          ),
        },
    };
  }

  /// [value] with a `,{…}` URL-option suffix removed, or `null` when it is absent.
  ///
  /// Same rule as the search list's cover (`BookListFields`): the corpus writes cover addresses as
  /// URL rules, and the cover loader cannot carry their headers yet (ADR-0069 G4).
  String? _coverOf(String? value, PageFetchService pages, String baseUrl) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final String clean = stripUrlOptions(value);
    if (clean != value) {
      pages.warn(
        'Cover URL options dropped (covers carry no request headers): '
        'base=$baseUrl',
      );
    }

    return clean;
  }

  /// Reads one book out of a page that was **already fetched** (`bookUrlPattern`, ADR-0078 S2).
  ///
  /// Upstream's search stage calls `getInfoItem` on the same response when the search URL is a
  /// detail page, or when `bookList` matched nothing (`BookList.kt:62-84`, `:100-110`). Keeping the
  /// reader here means both stages run the same field rules against the same scope, instead of the
  /// search stage growing a second, subtly different copy.
  Future<ParseResult<BookInfo>> readFromPage(
    BookSource source,
    FetchedPage page,
  ) async => switch (await _initScope(source, page.scope)) {
    ParseFailure<RuleScope>(
      :final ParseFailureKind kind,
      rulePath: final String failedAt,
    ) =>
      failureAt<BookInfo>(kind: kind, rulePath: failedAt),
    ParseSuccess<RuleScope>(data: final RuleScope scope) => await _read(
      source,
      page.url,
      scope,
    ),
  };

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
        // 目录地址也可能带 `,{…}`：先切选项再绝对化（与章节地址同一口径）。
        tocUrl: resolveUrlRule(toc == null || toc.isEmpty ? url : toc, url),
        author: author.dataOrNull,
        kind: kind.dataOrNull,
        coverUrl: resolveAbsoluteUrlOrNull(
          _coverOf(coverUrl.dataOrNull, _pages, url),
          url,
        ),
        intro: intro.dataOrNull,
        lastChapter: lastChapter.dataOrNull,
        wordCount: wordCount.dataOrNull,
        // 展示用字符串：规则结果原文，不做日期解析（book-source.md §2）。
        updateTime: updateTime.dataOrNull,
        canReName: declaresCanReName(rules),
      ),
    );
  }

  /// Returns the scope every `ruleBookInfo` field is read from.
  ///
  /// `init` is upstream's “read this first” field (`BookInfo.kt:58-64`): a non-blank value is
  /// evaluated and its result becomes the content of every later field, so the fields of a
  /// source that declares `init: "$.data.bookInfo"` are the **sub**-object's fields. A blank or
  /// absent `init` keeps the page itself, which is the behaviour from before. A rule that cannot
  /// build a scope is the stage's failure — no ADR-0026 degradation, because losing the scope
  /// would silently empty every field at once — with the failure pointing at `ruleBookInfo.init`
  /// when nothing matched, or at §7's `unsupported:<flag>` marker when the rule was rejected
  /// (`book-source.md` §2).
  Future<ParseResult<RuleScope>> _initScope(
    BookSource source,
    RuleScope page,
  ) async {
    final String init = (source.bookInfoRule?.init ?? '').trim();

    return init.isEmpty
        ? ParseSuccess<RuleScope>(page)
        : _pages.selectScope(init, page, 'ruleBookInfo.init');
  }
}

/// Whether [rules] declares a `canReName` rule at all (`book-source.md` §2).
///
/// This is upstream's check, **not** an evaluation of the rule: `BookInfo.kt:65` only asks
/// whether the field is non-blank, and the caller decides what to do with that
/// (`WebBook.kt:235-238`). Evaluating the rule would be a difference that has to be registered
/// before it is made.
bool declaresCanReName(BookInfoRule? rules) =>
    (rules?.canReName ?? '').trim().isNotEmpty;
