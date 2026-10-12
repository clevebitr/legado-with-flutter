import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:html/dom.dart';

/// The page a JS rule is evaluated on: the `baseUrl` / `page` / `source` bindings of
/// `docs/dev/book-source.md` §6.
///
/// The scope carries it because only the caller that fetched the page knows these values,
/// and every `@js:` rule — including one on a per-item field, which runs against an element
/// scope — has to fill [JsJob] from them. Element scopes inherit it from the page scope
/// they were matched in (see `RuleEngine`), so the values survive the descent.
final class JsPageContext {
  /// Creates the context of one fetched page.
  const JsPageContext({
    required this.baseUrl,
    this.page = 1,
    JsSourceInfo? source,
  }) : source = source ?? const JsSourceInfo(name: '', url: '');

  /// The URL the page was fetched from (the `baseUrl` binding).
  final String baseUrl;

  /// The 1-based page number (the `page` binding).
  final int page;

  /// The sandbox view of the book source (the `source` binding).
  final JsSourceInfo source;
}

/// The value a rule is evaluated against (`docs/dev/book-source.md` §3.2).
///
/// A branch reads either the DOM or JSON, and **the rule decides which** (matrix #12
/// / #13), so the scope has to be able to answer with both instead of the caller
/// guessing one for the whole field set:
///
/// * [DomScope] — the default rules and `@css:` (matrix #1..#12);
/// * [JsonScope] — `@json:` and the bare `$.` / `$[` form (matrix #13).
///
/// The engine only ever reads a scope: it holds no state and never mutates the node
/// or the JSON value it is given, so one engine instance can evaluate rules
/// concurrently (C-SRC-9).
sealed class RuleScope {
  /// Const constructor for the sealed hierarchy.
  const RuleScope();

  /// The DOM variant, wrapping [node].
  ///
  /// [body] is the raw response body [node] was parsed from, and it is set only when
  /// the scope is a **whole page**: a `@json:` rule reads it (matrix #13), because a
  /// page whose rules address JSON cannot be read out of the parsed DOM. It stays
  /// `null` for a scope that is only an element — reaching JSON *inside* an element
  /// would need a rule in the extraction segment, which is matrix #30 and
  /// deliberately not implemented.
  factory RuleScope.dom(Node node, {String? body, JsPageContext? jsContext}) =
      DomScope;

  /// The JSON variant, wrapping a decoded JSON [value] (matrix #13).
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

  /// The page a `@js:` rule on this scope runs against (`book-source.md` §6).
  ///
  /// Set by the fetch that built the page scope and copied onto every element scope the
  /// engine derives from it; `null` only for a scope assembled by hand (a unit test).
  final JsPageContext? jsContext;
}

/// The JSON variant of [RuleScope].
final class JsonScope extends RuleScope {
  /// Creates a JSON scope around a decoded [value]: a map, a list, a scalar or
  /// `null`.
  const JsonScope(this.value, {this.jsContext});

  /// The value `@json:` and the bare `$.` / `$[` rules read.
  final Object? value;

  /// The page a `@js:` rule on this scope runs against; see [DomScope.jsContext].
  final JsPageContext? jsContext;
}
