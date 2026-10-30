import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:html/dom.dart';

/// The page a JS rule is evaluated on: the `baseUrl` / `page` / `source` bindings.
///
/// Element scopes inherit it from the page scope they were matched in.
final class JsPageContext {
  /// Creates the context of one fetched page.
  const JsPageContext({
    required this.baseUrl,
    this.page = 1,
    JsSourceInfo? source,
    this.headers,
    this.bookName,
    this.chapterTitle,
    this.book,
    this.src,
    this.chapter,
    this.nextChapterUrl,
    this.fromBookInfo = false,
  }) : source = source ?? const JsSourceInfo(name: '', url: '');

  /// The URL the page was fetched from.
  final String baseUrl;

  /// The 1-based page number.
  final int page;

  /// The sandbox view of the book source.
  final JsSourceInfo source;

  /// The book being read, when the stage knows it.
  final String? bookName;

  /// The chapter being read, when the stage knows it.
  final String? chapterTitle;

  /// The book being read, when the stage knows it.
  final JsBookInfo? book;

  /// The book source's own `header` field, used as the default for `http.*` calls.
  final Map<String, String>? headers;

  /// The body of the page this context belongs to (the `src` binding, M25/S3b).
  ///
  /// Set by the page fetcher right after the body is decoded, so every rule on the page — and on
  /// an element of it — sees the same text. `null` for a context that has no page (a URL rule, a
  /// `header` rule).
  final String? src;

  /// The chapter this stage is reading (the `chapter` binding), when it has one.
  final JsChapterInfo? chapter;

  /// The next chapter's URL (the `nextChapterUrl` binding), when the reader knows it.
  final String? nextChapterUrl;

  /// Whether these rules were reached from the book info stage (the `fromBookInfo` binding).
  final bool fromBookInfo;

  /// The same stage context on **one page** of it: the URL, page number, request headers and body
  /// change, everything the stage declared (book, chapter, `nextChapterUrl`, `fromBookInfo`) stays.
  ///
  /// A paging walk goes through this, which is what makes `chapter` / `nextChapterUrl` visible on
  /// page 2 exactly as on page 1.
  JsPageContext forPage({
    required String baseUrl,
    required int page,
    Map<String, String>? headers,
    String? src,
  }) => JsPageContext(
    baseUrl: baseUrl,
    page: page,
    source: source,
    headers: headers,
    bookName: bookName,
    chapterTitle: chapterTitle,
    book: book,
    src: src,
    chapter: chapter,
    nextChapterUrl: nextChapterUrl,
    fromBookInfo: fromBookInfo,
  );
}

/// The value a rule is evaluated against: either the DOM or a decoded JSON value.
///
/// The rule decides which one it reads; the engine only ever reads a scope.
sealed class RuleScope {
  /// Const constructor for the sealed hierarchy.
  const RuleScope();

  /// The DOM variant.
  ///
  /// [body] is set only for a whole page, which is what a `@json:` rule reads.
  factory RuleScope.dom(Node node, {String? body, JsPageContext? jsContext}) =
      DomScope;

  /// The JSON variant around a decoded [value].
  factory RuleScope.json(Object? value, {JsPageContext? jsContext}) = JsonScope;
}

/// The DOM variant of [RuleScope].
final class DomScope extends RuleScope {
  /// Creates a DOM scope; see [RuleScope.dom] for [node] and [body].
  const DomScope(this.node, {this.body, this.jsContext});

  /// The node the default rules and `@css:` read.
  final Node node;

  /// The raw body of the page [node] was parsed from, or `null` for an element.
  final String? body;

  /// The page a `@js:` rule on this scope runs against.
  final JsPageContext? jsContext;
}

/// The variant one **regex match** produces (`book-source.md` §3 matrix #20).
///
/// Upstream's `AnalyzeByRegex` answers one list per match: `[整段, 组1, 组2, …]`. The per-item
/// field rules then refer to those groups as `$1` / `$2` templates — `chapterName: $2$3`,
/// `chapterUrl: https://a.test/c/$1` — which is the only shape the corpus uses.
final class RegexScope extends RuleScope {
  /// Creates a scope from one match's groups; `groups[0]` is the whole match.
  const RegexScope(this.groups, {this.jsContext});

  /// The match's groups, `groups[0]` being the whole match (Java's `groupValues`).
  final List<String> groups;

  /// The page a `@js:` rule on this scope runs against; see [DomScope.jsContext].
  final JsPageContext? jsContext;
}

/// The JSON variant of [RuleScope].
final class JsonScope extends RuleScope {
  /// Creates a JSON scope around a decoded [value].
  const JsonScope(this.value, {this.jsContext});

  /// The value `@json:` and the bare `$.` / `$[` rules read.
  final Object? value;

  /// The page a `@js:` rule on this scope runs against; see [DomScope.jsContext].
  final JsPageContext? jsContext;
}
