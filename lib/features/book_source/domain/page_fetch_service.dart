import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart';
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

  /// Fetches [url] and parses the body into a document.
  ///
  /// [rulePath] names the book source field the request belongs to, so a failure
  /// stays locatable (C-SRC-8); [keyword] is passed through so the HTTP client can
  /// keep a search keyword out of its failure logs (ADR-0006 §5).
  Future<ParseResult<Document>> fetch(
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
        failureAt<Document>(kind: kind, rulePath: failedAt),
      ParseSuccess<HttpResponse>(:final HttpResponse data) => ParseSuccess(
        parser.parse(data.body),
      ),
    };
  }

  /// Returns the first value of [rule] in [scope], or the failure that stopped it.
  ///
  /// A `null` value means the rule matched nothing, which is **not** a failure: the
  /// caller decides whether that field is required. A rejected or malformed rule
  /// comes back as `failure`, so the caller can propagate it without inspecting
  /// kinds itself.
  ({String? value, ParseFailure<Never>? failure}) field(
    String? rule,
    Node scope,
    String rulePath,
  ) {
    final ParseResult<String?> result = _engine.extractFirst(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (result) {
      ParseFailure<String?>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        (
          value: null,
          failure: failureAt<Never>(kind: kind, rulePath: failedAt),
        ),
      ParseSuccess<String?>(:final String? data) => (
        value: data,
        failure: null,
      ),
    };
  }

  /// Returns every element matched by a **top-level list** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  ParseResult<List<Element>> list(String? rule, Node scope, String rulePath) {
    final ParseResult<List<Element>> result = _engine.selectAll(
      rule ?? '',
      scope,
      rulePath: rulePath,
    );

    return switch (result) {
      ParseSuccess<List<Element>>(:final List<Element> data) =>
        data.isEmpty ? _noMatch(rulePath) : ParseSuccess<List<Element>>(data),
      ParseFailure<List<Element>>() => result,
    };
  }

  /// Returns the single value of the **top-level content** rule.
  ///
  /// Matching nothing is [ParseFailureKind.parseFailed] (`book-source.md` §7).
  ParseResult<String> content(String? rule, Node scope, String rulePath) {
    final ({String? value, ParseFailure<Never>? failure}) field = this.field(
      rule,
      scope,
      rulePath,
    );
    final ParseFailure<Never>? failure = field.failure;
    if (failure != null) {
      return failure;
    }
    final String? value = field.value;

    return value == null || value.isEmpty
        ? _noMatch(rulePath)
        : ParseSuccess(value);
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
