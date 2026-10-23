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

/// The JSON variant of [RuleScope].
final class JsonScope extends RuleScope {
  /// Creates a JSON scope around a decoded [value].
  const JsonScope(this.value, {this.jsContext});

  /// The value `@json:` and the bare `$.` / `$[` rules read.
  final Object? value;

  /// The page a `@js:` rule on this scope runs against; see [DomScope.jsContext].
  final JsPageContext? jsContext;
}
