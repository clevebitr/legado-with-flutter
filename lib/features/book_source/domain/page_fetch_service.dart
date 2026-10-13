import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/parser.dart' as parser;

/// The paging bound of `docs/dev/book-source.md` §9.
///
/// It is shared by the table of contents and the chapter body: once a walk has read
/// this many pages it stops and logs a warning, so a site whose paging rule keeps
/// naming pages cannot pull an unbounded number of requests.
const int _maxPagingPages = 50;

/// The URL variables a **paging** rule may use as a template (`book-source.md` §4).
///
/// `{{key}}` belongs to `searchUrl` only, and every other name is matrix #18's inner
/// rule / JS, which is M1 — a paging rule carrying one stays with the engine, which
/// rejects it as unsupported rather than rendering it to an empty URL.
const Set<String> _pagingTemplateVariables = <String>{'page', 'baseUrl'};

/// Matches one `{{name}}` placeholder of a paging URL template.
final RegExp _templatePlaceholder = RegExp(r'\{\{([^{}]*)\}\}');

/// Whether [rule] is a **URL template** rather than a selector rule (§4/§4.1).
///
/// A paging field carries a template when the whole text is a URL: it holds at least
/// one `{{...}}` placeholder, every placeholder names an M0 URL variable, and there is
/// no `@` segment (which would make it a selector rule). `toc_{{page}}.html` therefore
/// pages by template, `@css:a#next @href` is evaluated as a rule, and `{{result}}`
/// stays with the engine (matrix #18 is M1).
bool _isPagingTemplate(String rule) {
  if (rule.contains('@')) {
    return false;
  }

  final Iterable<RegExpMatch> matches = _templatePlaceholder.allMatches(rule);

  return matches.isNotEmpty &&
      matches.every(
        (RegExpMatch match) =>
            _pagingTemplateVariables.contains((match.group(1) ?? '').trim()),
      );
}

/// One page of a [PageWalk]: the URL it was fetched from and its parsed scope.
///
/// The URL travels with the scope because a rule on that page may name a **relative**
/// target, and only the page it was read on can resolve it into an absolute URL
/// (`docs/dev/book-source.md` §4).
final class FetchedPage {
  /// Creates a fetched page.
  const FetchedPage({required this.url, required this.scope});

  /// The absolute URL the page was fetched from.
  final String url;

  /// The page, parsed into a scope its rules can read.
  final RuleScope scope;
}

/// The pages one paging walk reached, and why it stopped.
///
/// [stoppedBy] is `null` when the walk ended on its own — the paging rule stopped
/// naming pages, or every further page had already been read. Otherwise a **later**
/// page could not be fetched and [pages] holds the prefix that was read; the two
/// stages of `PLAN.md` 3.5 interpret that differently, because
/// `docs/dev/book-source.md` §9 tolerates a missing table-of-contents page but not a
/// truncated chapter body.
final class PageWalk {
  /// Creates a walk result.
  const PageWalk({required this.pages, this.stoppedBy});

  /// The pages that were read, in reading order: the requested one first.
  final List<FetchedPage> pages;

  /// The failure that ended the walk early, or `null` when it ended on its own.
  final ParseFailure<Never>? stoppedBy;
}

/// Fetches one page of a book source and reads rules from it.
///
/// The four use cases of `PLAN.md` 2.4 share this collaborator so that the failure
/// rules of `docs/dev/book-source.md` §7 live in exactly one place:
///
/// * a failure is always a [ParseResult], never an exception thrown at the UI
///   (C-ERR-1);
/// * a **top-level** list rule (`bookList`, `chapterList`) or the content rule that
///   matched nothing is [ParseFailureKind.parseFailed], because that is what "the
///   rules no longer fit the page" looks like;
/// * an empty value of any other field is a **success** with no value, so an absent
///   cover or intro stays non-fatal;
/// * a rejected rule keeps travelling as [ParseFailureKind.unsupportedRule]
///   (C-SRC-4) instead of being swallowed;
/// * a non-top-level field whose rule was **rejected or malformed** degrades to "no
///   value" plus a warning ([field]), and so do the paging rules ([nextPageUrls]) and
///   the content replacement rule ([replaceContent]) — ADR-0026 §决策 2, applied in
///   this one place.
final class PageFetchService {
  /// Creates the service.
  PageFetchService({
    required this._engine,
    required this._http,
    required this._logger,
  });

  final RuleEngine _engine;
  final HttpClient _http;
  final AppLogger _logger;

  /// Fetches [url] and parses the body into a page scope.
  ///
  /// The scope carries both the parsed DOM and the raw body, because the **rule**
  /// decides which of the two it reads (matrix #12 / #13), and one fetched page is
  /// read by a whole field set whose rules need not agree: a `bookList` of `$.data…`
  /// and a `content` of `class.content@text` may come from the same response.
  ///
  /// [rulePath] names the book source field the request belongs to, so a failure
  /// stays locatable (C-SRC-8); [keyword] is passed through so the HTTP client can
  /// keep a search keyword out of its failure logs (ADR-0006 §5).
  ///
  /// [headers] are the book source's own `header` field (`book-source.md` §2, an M0
  /// field). They are request overrides for the policy defaults — a source that needs
  /// a browser `User-Agent`, or a `Referer` without which its pages 404, declares it
  /// there (C-NET-4). Cookies are still added by the `CookieManager` and a source must
  /// never spell them out (C-NET-5).
  ///
  /// [sourceId] is the book source URL. It travels only for the logs the HTTP layer
  /// owns — the tolerant-decode warning of ADR-0031 §决策 2 names the source, which is
  /// what C-ERR-8 asks for (C-SEC-4 still forbids the body).
  ///
  /// [page] and [source] fill the `page` / `source` bindings a `@js:` rule sees
  /// (`book-source.md` §6); they default to the first page and an empty source so a caller
  /// that has no book source context still gets a valid context.
  Future<ParseResult<RuleScope>> fetch(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int page = 1,
    JsSourceInfo? source,
  }) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: rulePath,
      headers: headers,
      keyword: keyword,
      sourceId: sourceId,
    );

    return switch (response) {
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<RuleScope>(kind: kind, rulePath: failedAt),
      ParseSuccess<HttpResponse>(:final HttpResponse data) => ParseSuccess(
        RuleScope.dom(
          parser.parse(data.body),
          body: data.body,
          // §6 的 baseUrl / page / source 绑定就来自这里；逐项字段的 `@js:` 靠它继承。
          // 书源自带的 `header` 同时带上：规则里的 `http.*` 也要用它（C-NET-4）。
          jsContext: JsPageContext(
            baseUrl: url,
            page: page,
            source: source,
            headers: headers,
          ),
        ),
      ),
    };
  }

  /// Applies [source]'s own `concurrentRate` to the request budget (`book-source.md` §8).
  ///
  /// The use cases call this when an operation starts, because they are the layer that holds
  /// the model: the request layer knows only the source id it is given, and the rate gate has to
  /// be keyed by it so a `@js:` rule's `http.*` calls (which see only that id, §6) pass the same
  /// gate (ADR-0036 §决策 5).
  void applySourceRate(BookSource source) =>
      _http.applySourceRate(source.url, source.concurrentRate);

  /// Returns the first value of [rule] in [scope], or the failure that stopped it.
  ///
  /// A `null` value means the rule matched nothing, which is a **success** here: the
  /// caller decides whether that field is required, because only the caller knows
  /// whether the rule is top-level (`book-source.md` §7).
  ///
  /// A non-top-level field whose rule was **rejected** or is **malformed** degrades to
  /// `null` plus a warning carrying `rulePath` and the book source id (ADR-0026
  /// §决策 2/4): one bad optional field must not cost the whole stage, and for the
  /// caller “unsupported syntax” and “broken rule” have the same consequence — losing
  /// that one field. Escalating a malformed rule instead would be worse than useless:
  /// the callers read `dataOrNull`, so it would turn into a silent `null` with no
  /// record at all. C-SRC-4 is satisfied by the explicit degradation plus its warning.
  ///
  /// Asynchronous because the engine is: the rule may hold a `@js:` segment
  /// (ADR-0029 §决策 1). Every caller awaits it in turn, so the use cases stay
  /// `Future`-returning without a second evaluation path.
  Future<ParseResult<String?>> field(
    String? rule,
    RuleScope scope,
    String rulePath, {
    required String sourceId,
  }) async {
    final ParseResult<String?> parsed = await _engine.extractFirst(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseFailure<String?>(:final ParseFailureKind kind)
          when kind == ParseFailureKind.unsupportedRule ||
              kind == ParseFailureKind.parseFailed =>
        _degrade(sourceId, rulePath, kind),
      _ => parsed,
    };
  }

  /// Logs a degraded optional field and turns it into “no value” (ADR-0026).
  ///
  /// The message carries the field, the failure kind and the source, never a page body
  /// or a keyword (C-ERR-8, C-SEC-4).
  ParseResult<String?> _degrade(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'empty');

    return const ParseSuccess<String?>(null);
  }

  /// Logs an optional rule whose failure was degraded to its empty consequence.
  ///
  /// [consequence] spells out what “empty” means for the field that degraded — no
  /// value, no next page, no replacement — so the log keeps one shape per outcome
  /// while each call site keeps its own fallback. It must never name a page body or a
  /// keyword (C-ERR-8, C-SEC-4).
  void _warnDegraded(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
    String consequence,
  ) {
    _logger.warning(
      'Field rule degraded to $consequence: source=$sourceId field=$rulePath '
      'kind=${kind.name}',
    );
  }

  /// Returns every match of a **top-level list** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  Future<ParseResult<List<RuleScope>>> list(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<List<RuleScope>> result = await _engine.selectAll(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (result) {
      ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
        data.isEmpty ? _noMatch(rulePath) : ParseSuccess<List<RuleScope>>(data),
      ParseFailure<List<RuleScope>>() => result,
    };
  }

  /// Returns the single value of the **top-level content** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  ///
  /// A rejected `content` rule stays a failure: it is top-level, so ADR-0026 §决策 1
  /// applies and the degradation of [field] deliberately does not. The engine is
  /// therefore called directly here.
  ///
  /// Asynchronous for the same reason as [field]: the engine's value API is.
  Future<ParseResult<String>> content(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) async {
    final ParseResult<String?> parsed = await _engine.extractFirst(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseFailure<String?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<String?>(:final String? data) =>
        data == null || data.isEmpty ? _noMatch(rulePath) : ParseSuccess(data),
    };
  }

  /// Fetches [url] and walks every page [nextRule] names (`book-source.md` §4.1).
  ///
  /// A **first** page that cannot be fetched is the stage's failure, exactly as before;
  /// a **later** one stops the walk and is reported through [PageWalk.stoppedBy], so
  /// each stage can decide what a partial walk means.
  ///
  /// The walk is a queue, not a fixed chain: a paging rule may name one page or several
  /// (`nextTocUrl` is a list upstream), so every fetched page contributes its own next
  /// URLs. Four bounds keep it finite without trusting the site — a page is never read
  /// twice, a paging rule cannot name the page it was read on ([nextPageUrls]), the
  /// walk stops at the §9 page bound and logs a warning, and the paging rule itself
  /// degrades to “no next page” when it is rejected.
  ///
  /// [rulePath] is the stage's field (`ruleToc`, `ruleContent`) and travels into every
  /// request, so a failure stays locatable (C-SRC-8); [nextRulePath] is the paging
  /// field (`tocRule.nextTocUrl`, `contentRule.nextContentUrl`). [headers], [sourceId] and
  /// [source] are the book source's own request overrides, id and sandbox view
  /// (C-NET-4, C-ERR-8, §6), passed the same way [fetch] takes them.
  Future<ParseResult<PageWalk>> walk({
    required String url,
    required String rulePath,
    required String? nextRule,
    required String nextRulePath,
    Map<String, String>? headers,
    required String sourceId,
    JsSourceInfo? source,
  }) async {
    final List<FetchedPage> pages = <FetchedPage>[];
    final Set<String> visited = <String>{};
    final List<String> pending = <String>[url];

    while (pending.isNotEmpty) {
      if (pages.length >= _maxPagingPages) {
        _logger.warning(
          'Paging stopped at $_maxPagingPages pages: source=$sourceId '
          'field=$rulePath',
        );
        break;
      }

      final String pageUrl = pending.removeAt(0);
      if (!visited.add(pageUrl)) {
        // 翻页规则指回了已经读过的页（本站的页码列表常同时列出上一页）：跳过而不是重读。
        continue;
      }

      final ParseResult<RuleScope> page = await fetch(
        pageUrl,
        rulePath: rulePath,
        headers: headers,
        sourceId: sourceId,
        // 正在取的这一页就是 `pages.length + 1`（1-based），与翻页规则里的 `{{page}}` 同口径。
        page: pages.length + 1,
        source: source,
      );

      switch (page) {
        case ParseFailure<RuleScope>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          if (pages.isEmpty) {
            return failureAt<PageWalk>(kind: kind, rulePath: failedAt);
          }

          return ParseSuccess<PageWalk>(
            PageWalk(
              pages: pages,
              stoppedBy: failureAt<Never>(kind: kind, rulePath: failedAt),
            ),
          );
        case ParseSuccess<RuleScope>(:final RuleScope data):
          pages.add(FetchedPage(url: pageUrl, scope: data));
          pending.addAll(
            await nextPageUrls(
              nextRule,
              data,
              nextRulePath,
              currentUrl: pageUrl,
              // 刚读到的这一页是 `pages.length`（1-based），它指向的下一页就是下一号。
              page: pages.length + 1,
              sourceId: sourceId,
            ),
          );
      }
    }

    return ParseSuccess<PageWalk>(PageWalk(pages: pages));
  }

  /// Returns the absolute URLs a **paging** rule points at (`book-source.md` §4.1).
  ///
  /// [rule] is read as a **list** because `nextTocUrl` / `nextContentUrl` may name one
  /// page or a whole array of them (upstream `getStringList`,
  /// `BookChapterList.kt:210-218`); taking only the first value would silently drop
  /// pages. Every value is resolved against the page it was read on (C-SRC-5), and the
  /// current page plus any repeat are dropped — upstream filters `redirectUrl`
  /// (`BookChapterList.kt:212`) and stops its chapter loop on a URL it already has.
  ///
  /// The field is also a place where `book-source.md` §4 allows the URL variables
  /// `{{page}}` and `{{baseUrl}}` ([page] is the 1-based number the value becomes,
  /// `{{baseUrl}}` is [currentUrl]), so every value is rendered before it is requested,
  /// and a rule that **is** a template is rendered as a whole — the engine has no node
  /// to extract from it. Section 4 forbids letting a literal `{{...}}` reach the
  /// request, so a value that renders to nothing is dropped.
  ///
  /// A rejected or malformed rule degrades to **no next page** plus a warning
  /// (ADR-0026 §决策 2): the field is not top-level, so it must not cost the stage —
  /// paging simply stops where it is. Asynchronous because the rule may hold a `@js:`
  /// segment (ADR-0029 §决策 1).
  Future<List<String>> nextPageUrls(
    String? rule,
    RuleScope scope,
    String rulePath, {
    required String currentUrl,
    required int page,
    required String sourceId,
  }) async {
    if (rule == null || rule.trim().isEmpty) {
      return const <String>[];
    }

    final String text = rule.trim();
    final JsPageContext context = _pagingContext(
      scope,
      currentUrl: currentUrl,
      page: page,
    );
    if (_isPagingTemplate(text)) {
      return _pagingUrls(
        <String>[text],
        currentUrl,
        page,
        rulePath: rulePath,
        context: context,
        sourceId: sourceId,
      );
    }

    final ParseResult<List<String>> parsed = await _engine.extractAll(
      text,
      scope,
      rulePath: rulePath,
    );

    return switch (parsed) {
      ParseSuccess<List<String>>(:final List<String> data) => _pagingUrls(
        data,
        currentUrl,
        page,
        rulePath: rulePath,
        context: context,
        sourceId: sourceId,
      ),
      // 降级 warning 用**字段路径**而不是引擎报的 `unsupported:<语法>`：与 [field] 同
      // 一口径，书源里要改的是哪个字段（C-SRC-8、ADR-0026 §决策 2）。
      ParseFailure<List<String>>(:final ParseFailureKind kind) => _noNextPage(
        sourceId,
        rulePath,
        kind,
      ),
    };
  }

  /// Renders, resolves, filters and de-duplicates paging values, keeping rule order.
  ///
  /// [page] is the 1-based number the value becomes and `{{baseUrl}}` is [currentUrl],
  /// which is what §4.1 fixes for these two fields under queue paging. Rendering goes
  /// through [renderUrl], so a paging value may also carry matrix #18's `{{…}}` JavaScript;
  /// when that fails the field degrades to “no next page” plus a warning (ADR-0026 §决策 2),
  /// exactly like a rejected paging rule.
  Future<List<String>> _pagingUrls(
    List<String> values,
    String currentUrl,
    int page, {
    required String rulePath,
    required JsPageContext context,
    required String sourceId,
  }) async {
    final List<String> urls = <String>[];
    final Map<String, String> params = <String, String>{
      'page': '$page',
      'baseUrl': currentUrl,
    };

    for (final String value in values) {
      if (value.trim().isEmpty) {
        continue;
      }

      final ParseResult<String> rendered = await renderUrl(
        value,
        params,
        rulePath: rulePath,
        context: context,
      );
      if (rendered case ParseFailure<String>(:final ParseFailureKind kind)) {
        // 降级 warning 用**字段路径**而不是引擎报的 `unsupported:<语法>`：与 [field] 同
        // 一口径，书源里要改的是哪个字段（C-SRC-8、ADR-0026 §决策 2）。
        return _noNextPage(sourceId, rulePath, kind);
      }
      final String url0 = (rendered as ParseSuccess<String>).data.trim();
      if (url0.isEmpty) {
        continue;
      }

      final String url = resolveAbsoluteUrl(url0, currentUrl);
      if (url == currentUrl || urls.contains(url)) {
        continue;
      }

      urls.add(url);
    }

    return urls;
  }

  /// Builds the page context a **paging** rule's `{{…}}` JavaScript runs against.
  ///
  /// `{{baseUrl}}` / the `baseUrl` binding is the page the rule was read on and `page` is
  /// the number the value becomes (§4.1); the source and its headers travel from the page's
  /// own context, so `http.*` of a paging script keeps using them (C-NET-4).
  JsPageContext _pagingContext(
    RuleScope scope, {
    required String currentUrl,
    required int page,
  }) {
    final JsPageContext? context = switch (scope) {
      DomScope(:final JsPageContext? jsContext) => jsContext,
      JsonScope(:final JsPageContext? jsContext) => jsContext,
    };

    return JsPageContext(
      baseUrl: currentUrl,
      page: page,
      source: context?.source,
      headers: context?.headers,
    );
  }

  /// Logs a degraded paging rule and turns it into “no next page” (ADR-0026).
  List<String> _noNextPage(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'no next page');

    return const <String>[];
  }

  /// Applies the `ruleContent.replaceRegex` purification to [content].
  ///
  /// The rule is a **standalone** `##regex##replacement` rule run on the joined
  /// chapter text (matrix #9, `book-source.md` §4.1), so it goes through
  /// [RuleEngine.applyReplaceRule] rather than [field]: there is no page left to read.
  /// Upstream's surrounding per-line trim and re-indent (`BookContent.kt:191-194`) is
  /// reader-side formatting and is deliberately not applied here.
  ///
  /// A rejected or malformed rule degrades to **no replacement** plus a warning
  /// (ADR-0026 §决策 2), which for a transform means “keep the text as it was
  /// extracted” instead of losing the whole chapter. Asynchronous because the engine's
  /// evaluation API is (ADR-0029 §决策 1).
  ///
  /// [jsContext] is the page a `@js:` purification rule runs against — the caller has it (it
  /// fetched the chapter), and without it a rule reading `baseUrl` would silently get an
  /// empty string.
  Future<String> replaceContent(
    String? rule,
    String content,
    String rulePath, {
    required String sourceId,
    required JsPageContext jsContext,
  }) async {
    if (rule == null || rule.trim().isEmpty) {
      return content;
    }

    final ParseResult<String> replaced = await _engine.applyReplaceRule(
      rule,
      content,
      rulePath: rulePath,
      jsContext: jsContext,
    );

    return switch (replaced) {
      ParseSuccess<String>(:final String data) => data,
      // 同 [nextPageUrls]：降级 warning 指向字段而不是 `unsupported:<语法>`。
      ParseFailure<String>(:final ParseFailureKind kind) => _noReplacement(
        sourceId,
        rulePath,
        kind,
        content,
      ),
    };
  }

  /// Logs a degraded replacement rule and hands back [content] untouched (ADR-0026).
  String _noReplacement(
    String sourceId,
    String rulePath,
    ParseFailureKind kind,
    String content,
  ) {
    _warnDegraded(sourceId, rulePath, kind, 'no replacement');

    return content;
  }

  /// Renders a URL template with the well-known variables of `book-source.md` §4 and the
  /// `{{…}}` JavaScript / nested rules of matrix #18.
  ///
  /// Kept here so the logger stays encapsulated: the renderer warns about undefined
  /// variables without any use case having to hold a logger of its own. Asynchronous
  /// because a `{{…}}` that names neither `key` / `page` / `baseUrl` nor an entry of
  /// [params] is evaluated by the sandbox (ADR-0029 §决策 1).
  Future<ParseResult<String>> renderUrl(
    String template,
    Map<String, String> params, {
    required String rulePath,
    required JsPageContext context,
  }) => _engine.renderUrl(
    template,
    rulePath: rulePath,
    params: params,
    context: context,
  );

  /// Logs a page-level warning.
  ///
  /// Exposed so a use case can report a partially usable page without taking a
  /// logger of its own; the message must never carry a page body or a keyword
  /// (C-ERR-8, C-SEC-4).
  void warn(String message) => _logger.warning(message);

  /// Builds the failure for a top-level rule that matched nothing.
  ParseFailure<T> _noMatch<T>(String rulePath) =>
      failureAt<T>(kind: ParseFailureKind.parseFailed, rulePath: rulePath);
}
