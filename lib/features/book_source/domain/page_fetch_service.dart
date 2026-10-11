import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/parser.dart' as parser;

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
///   (C-SRC-4) instead of being swallowed.
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
  Future<ParseResult<RuleScope>> fetch(
    String url, {
    required String rulePath,
    String? keyword,
  }) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: rulePath,
      keyword: keyword,
    );

    return switch (response) {
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<RuleScope>(kind: kind, rulePath: failedAt),
      ParseSuccess<HttpResponse>(:final HttpResponse data) => ParseSuccess(
        RuleScope.dom(parser.parse(data.body), body: data.body),
      ),
    };
  }

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
  ParseResult<String?> field(
    String? rule,
    RuleScope scope,
    String rulePath, {
    required String sourceId,
  }) {
    final ParseResult<String?> parsed = _engine.extractFirst(
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
    _logger.warning(
      'Field rule degraded to empty: source=$sourceId field=$rulePath '
      'kind=${kind.name}',
    );

    return const ParseSuccess<String?>(null);
  }

  /// Returns every match of a **top-level list** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  ParseResult<List<RuleScope>> list(
    String? rule,
    RuleScope scope,
    String rulePath,
  ) {
    final ParseResult<List<RuleScope>> result = _engine.selectAll(
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
  ParseResult<String> content(String? rule, RuleScope scope, String rulePath) {
    final ParseResult<String?> parsed = _engine.extractFirst(
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

  /// Renders a URL template with the well-known variables of `book-source.md` §4.
  ///
  /// Kept here so the logger stays encapsulated: the renderer warns about undefined
  /// variables without any use case having to hold a logger of its own.
  String renderUrl(String template, Map<String, String> params) =>
      renderUrlTemplate(template, params, logger: _logger);

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
