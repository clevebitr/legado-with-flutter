import 'dart:convert';

import 'package:cascadia/cascadia.dart' as cascadia;
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:html/dom.dart';
import 'package:json_path/json_path.dart';

/// Prefixes of the rule flags that a later phase of the matrix owns.
///
/// `docs/dev/book-source.md` §3 declares the prefix casing insensitive
/// (`@css:` and `@CSS:` are the same flag), so these are matched lower-cased.
/// The order matters: `{{` has to be tested before `{`.
///
/// `<js>` is not a flag of the matrix at all: it is a newer upstream wrapper whose
/// semantics (a whole rule body written as JavaScript) this repository does not
/// implement, so it is rejected by name instead of being handed to cascadia as an
/// unknown type (ADR-0032 §决策 3).
const List<String> _deferredFlags = <String>[
  '{{',
  '//',
  '{',
  ':',
  '@@',
  '@xpath:',
  '@put:',
  '@get:',
  '@webjs',
  '<js>',
];

/// The `@js:` flag of matrix #14, lower-cased for a case-insensitive compare.
///
/// It is **terminal**: upstream's `AppPattern.JS_PATTERN` is `@js:([\w\W]*)`, i.e. greedy
/// to the end of the rule, so everything after the flag is the script and a `&&` or `||`
/// inside the script stays part of it instead of being read as a connector.
const String _jsFlag = '@js:';

/// The `@css:` flag of matrix #12, lower-cased for a case-insensitive compare.
const String _cssFlag = '@css:';

/// The `@json:` flag of matrix #13, lower-cased for a case-insensitive compare.
const String _jsonFlag = '@json:';

/// jsoup's index pseudo-classes and the cascadia form each maps onto (matrix #29).
///
/// cascadia does not implement `:eq` / `:gt` / `:lt`, and rewriting them keeps the
/// matching itself inside cascadia (C-SRC-6). The replacement receives the argument
/// jsoup was given and returns the `:nth-child` form with the same **sibling-index**
/// meaning. Requiring an integer in parentheses keeps standard pseudos such as
/// `:first-child` out of the rewrite. Immutable on purpose: the engine holds no
/// shared mutable state (C-SRC-9).
final Map<String, String Function(int)> _indexPseudoRewrites =
    Map<String, String Function(int)>.unmodifiable(
      <String, String Function(int)>{
        'eq': (int index) => ':nth-child(${index + 1})',
        'gt': (int index) => ':nth-child(n+${index + 2})',
        'lt': (int index) => ':nth-child(-n+$index)',
      },
    );

/// Selector types this phase implements: matrix #2 (`class` / `id` / `tag`),
/// #3 (`text`) and #4 (`children`).
const Set<String> _implementedTypes = <String>{
  'class',
  'id',
  'tag',
  'text',
  'children',
};

/// Matches a segment that carries a rule flag, e.g. the `css:` of `class.a@css:.b`.
///
/// `@@` is deliberately absent: it is a rule-body prefix, and the `@`-split would
/// leave it as an empty segment that is rejected as malformed anyway.
final RegExp _flagSegment = RegExp(
  r'^(?:css|json|js|xpath|put|get|webjs):',
  caseSensitive: false,
);

/// Runs of whitespace, collapsed the way upstream (jsoup) normalises text.
final RegExp _whitespace = RegExp(r'\s+');

/// Evaluates Legado's **default** rule syntax against an HTML scope
/// (`docs/dev/book-source.md` §3.3; C-SRC-1, C-SRC-6, C-SRC-9).
///
/// Implemented so far:
///
/// | Matrix | Syntax |
/// |---|---|
/// | #1 / #2 | selector segments `类型.名称.位置` with the types `class`, `id`, `tag` |
/// | #3 | the type `text`, matching an element by its own text |
/// | #4 | the type `children`, taking every direct child element |
/// | #5 / #6 | the position, including negative positions and the `!` exclusion list |
/// | #7 | a leading `-`, reversing the result list |
/// | #8 | extraction `text`, `textNodes`, `ownText`, `html`, `all`, or an attribute name |
/// | #9 | `##regex##replacement`, with `$1` / `${name}` group references |
/// | #10 | `||`, taking the first candidate that produced a value |
/// | #11 | `&&`, merging the branches of one candidate (union, not chaining) |
/// | #27 | `%%`, interleaving the branches of one candidate |
/// | #12 | the `@css:` flag, handing the rest of the segment to cascadia |
/// | #13 | the `@json:` flag and the bare `$.` / `$[` form, read as JSONPath |
/// | #14 | the terminal `@js:` flag, evaluated by the sandbox ([JsBridge]) |
/// | #26 | the `[...]` index list, with ranges, steps and `[!...]` exclusion |
/// | #28 | an index as the first rule of a segment (`.1` / `[1]` / `children[1]`) |
/// | #29 | the jsoup index pseudo-classes `:eq` / `:gt` / `:lt`, rewritten onto `:nth-child` |
///
/// A branch reads its scope ([RuleScope]) as DOM or as JSON, and the rule decides
/// which: the default rules and `@css:` need a [DomScope], `@json:` and the bare
/// `$.` / `$[` form need JSON. A whole page answers both, because [RuleScope.dom]
/// carries the raw body it was parsed from.
///
/// The two directions do **not** fail alike, and the difference decides what a book
/// source sees when it no longer matches the site:
///
/// * a **JSON** branch against a DOM scope with no body — an element, or one of its
///   matches — is [ParseFailureKind.parseFailed] with the field path, and so is one
///   whose page body is not JSON at all: there is nothing to read;
/// * a **DOM** branch against a page whose body is JSON is **not** a failure: the page
///   is a parsed document like any other, so a selector that matches nothing is the
///   ordinary “success with no match” of matrix #8. Only a match that *is* a JSON
///   value has no DOM at all, and that is [ParseFailureKind.parseFailed] as well.
///
/// Reporting those mismatches loudly is what keeps them from becoming a silent empty
/// result (C-SRC-4): otherwise “the rule is wrong” and “the site changed” look the
/// same in the UI.
///
/// A **selector segment whose type is none of the implemented ones** is not unsupported:
/// upstream degrades it to a raw CSS selector, and real book sources depend on that
/// (`li`, `dd`, `.searchresult`, `#txt`, `tr!0`), so the segment is handed to cascadia as
/// it is (ADR-0032). Only a `//`-prefixed segment stays [ParseFailureKind.unsupportedRule]
/// — that is matrix #21's XPath.
///
/// Everything else in the matrix is reported as
/// [ParseFailureKind.unsupportedRule] — never silently mis-parsed (C-SRC-4) — with
/// `rulePath` naming the syntax, e.g. `unsupported:nested-rule` (matrix #30). A rule
/// that is structurally broken (a missing name, a non-numeric position) is reported as
/// [ParseFailureKind.parseFailed] with the field path as `rulePath`.
///
/// The engine is stateless, so one instance can evaluate rules concurrently
/// (C-SRC-9), and it never mutates the scope it is given or its elements.
final class RuleEngine {
  /// Creates an engine that reports rejected rules through `logger` and runs `@js:` rules
  /// on `jsBridge`.
  ///
  /// The bridge is the only door to JavaScript (C-SRC-2), which is why the engine takes it
  /// as a collaborator instead of the engine library: a unit test passes a fake
  /// (`docs/dev/testing.md` §4) and `domain/` never imports `flutter_qjs_next`.
  RuleEngine({required this._logger, required this._jsBridge});

  final AppLogger _logger;
  final JsBridge _jsBridge;

  /// Returns every element matched by the **list** rule [rule] inside [scope].
  ///
  /// Every `@`-separated segment is a selector here, because `bookList` and
  /// `chapterList` carry no extraction segment (upstream `getElements`).
  ///
  /// [rulePath] names the book source field, e.g. `searchRule.bookList`; it is
  /// carried into [ParseFailure.rulePath] so a failure stays locatable (C-SRC-8).
  ///
  /// An empty result is a **success**: whether "nothing matched" is a failure is
  /// the caller's decision, because only the caller knows whether [rule] is a
  /// top-level rule (`docs/dev/book-source.md` §7). A blank [rule] is also a
  /// success with no elements, since real exports use `""` for absent fields.
  ///
  /// Asynchronous because the same rule text may hold a `@js:` segment, and a JS rule
  /// has to cross into the worker isolate (ADR-0029 §决策 1).
  Future<ParseResult<List<RuleScope>>> selectAll(
    String rule,
    RuleScope scope, {
    required String rulePath,
  }) async {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<RuleScope>>(<RuleScope>[]);
    }

    final _ParsedRule parsed = _parse(rule);
    final _Parsed<List<_CheckedCandidate>> check = _check(
      parsed,
      field: rulePath,
      hasExtraction: false,
    );

    return switch (check) {
      _ParsedFailure<List<_CheckedCandidate>>(
        :final _RuleRejection rejection,
      ) =>
        _fail<List<RuleScope>>(rejection, field: rulePath),
      _ParsedValue<List<_CheckedCandidate>>(
        :final List<_CheckedCandidate> value,
      ) =>
        switch (_selectAll(value, scope, field: rulePath)) {
          _ParsedFailure<List<RuleScope>>(:final _RuleRejection rejection) =>
            _fail<List<RuleScope>>(rejection, field: rulePath),
          _ParsedValue<List<RuleScope>>(:final List<RuleScope> value) =>
            ParseSuccess<List<RuleScope>>(
              parsed.reverse ? value.reversed.toList(growable: false) : value,
            ),
        },
    };
  }

  /// Runs the candidates of a list rule and returns the first non-empty one
  /// (matrix #10's `||`).
  ///
  /// A candidate that **fails** ends the rule: later candidates are not tried, because a
  /// failure says the rule and the page disagree, not that this candidate happened to
  /// match nothing (C-SRC-4). Only “succeeded but matched nothing” moves on to the next
  /// candidate — that is what makes `$.a||$.b` a fallback.
  ///
  /// Reversing the result (matrix #7) applies to the winning candidate, not to each
  /// candidate on its own, so `-a||b` reverses whichever one produced matches.
  _Parsed<List<RuleScope>> _selectAll(
    List<_CheckedCandidate> candidates,
    RuleScope scope, {
    required String field,
  }) {
    for (final _CheckedCandidate candidate in candidates) {
      final _Parsed<List<RuleScope>> matched = _matchCandidate(
        candidate,
        scope,
        field: field,
      );
      switch (matched) {
        case _ParsedFailure<List<RuleScope>>():
          return matched;
        case _ParsedValue<List<RuleScope>>(:final List<RuleScope> value):
          if (value.isNotEmpty) {
            return matched;
          }
      }
    }

    return const _ParsedValue<List<RuleScope>>(<RuleScope>[]);
  }

  /// Runs every branch of one candidate from [scope] and merges the matches.
  _Parsed<List<RuleScope>> _matchCandidate(
    _CheckedCandidate candidate,
    RuleScope scope, {
    required String field,
  }) {
    final List<List<RuleScope>> results = <List<RuleScope>>[];
    for (final _RuleBranch branch in candidate.branches) {
      final _Parsed<List<RuleScope>> matched = _matches(
        branch,
        scope,
        field: field,
      );
      switch (matched) {
        case _ParsedFailure<List<RuleScope>>():
          return matched;
        case _ParsedValue<List<RuleScope>>(:final List<RuleScope> value):
          results.add(value);
      }
    }

    return _ParsedValue<List<RuleScope>>(
      _merge<RuleScope>(results, candidate.connector),
    );
  }

  /// Runs one list-rule branch from [scope] and returns its matches as scopes.
  ///
  /// Each match is a scope of its own — a [DomScope] for an element, a [JsonScope]
  /// for a JSON value — so the next level of rules reads it the way this one read the
  /// page (`book-source.md` §3.2).
  _Parsed<List<RuleScope>> _matches(
    _RuleBranch branch,
    RuleScope scope, {
    required String field,
  }) => switch (branch) {
    final _DomBranch dom => switch (_matchElements(dom, scope, field: field)) {
      _ParsedFailure<List<Element>>(:final _RuleRejection rejection) =>
        _ParsedFailure<List<RuleScope>>(rejection),
      _ParsedValue<List<Element>>(:final List<Element> value) =>
        _ParsedValue<List<RuleScope>>(<RuleScope>[
          // 逐条结果继承页面的 JS 上下文，否则 `searchRule.name` 这种逐项字段上的
          // `@js:` 拿不到 baseUrl / page / source（book-source.md §6）。
          for (final Element element in value)
            RuleScope.dom(element, jsContext: _jsContextOf(scope)),
        ]),
    },
    final _JsonBranch json => switch (_jsonScopeOf(scope, field: field)) {
      _ParsedFailure<Object?>(:final _RuleRejection rejection) =>
        _ParsedFailure<List<RuleScope>>(rejection),
      _ParsedValue<Object?>(:final Object? value) =>
        _ParsedValue<List<RuleScope>>(<RuleScope>[
          for (final JsonPathMatch match in json.path.read(value))
            RuleScope.json(match.value, jsContext: _jsContextOf(scope)),
        ]),
    },
  };

  /// Returns the elements one DOM branch matches inside [scope].
  ///
  /// A [JsonScope] — a match that is a JSON value — has no DOM at all, so a default or
  /// `@css:` rule against it is [ParseFailureKind.parseFailed] rather than a silent
  /// empty result (C-SRC-4). This is **not** the JSON *page* case: a page is a
  /// [DomScope] whose body was parsed into a document, so the same selector there simply
  /// matches nothing and stays an ordinary empty result.
  _Parsed<List<Element>> _matchElements(
    _DomBranch branch,
    RuleScope scope, {
    required String field,
  }) => switch (scope) {
    DomScope(:final Node node) => _ParsedValue<List<Element>>(
      _run(branch.selectors, node),
    ),
    JsonScope() => _ParsedFailure<List<Element>>(_malformed(field)),
  };

  /// The JSON value [scope] offers a `@json:` branch (matrix #13).
  ///
  /// A whole page makes its raw body available ([RuleScope.dom]); any other DOM scope
  /// has none, because reaching JSON inside an element would need a rule in the
  /// extraction segment (matrix #30, not implemented). A body that is not JSON is
  /// [ParseFailureKind.parseFailed] with the field path, never a thrown
  /// `FormatException` (C-ERR-1).
  ///
  /// Both of those are the **JSON** side only. A DOM branch read against the very same
  /// page is unaffected: it reads the parsed document, so it cannot fail because of the
  /// body's format (see [_matchElements]).
  _Parsed<Object?> _jsonScopeOf(RuleScope scope, {required String field}) =>
      switch (scope) {
        JsonScope(:final Object? value) => _ParsedValue<Object?>(value),
        DomScope(:final String? body) => switch (body) {
          null => _ParsedFailure<Object?>(_malformed(field)),
          final String text => _decodeJson(text, field: field),
        },
      };

  /// Decodes a page body, or reports that it is not JSON.
  _Parsed<Object?> _decodeJson(String body, {required String field}) {
    try {
      return _ParsedValue<Object?>(jsonDecode(body));
    } on FormatException {
      return _ParsedFailure<Object?>(_malformed(field));
    }
  }

  /// Merges the per-branch results of one candidate (matrix #11 / #27).
  ///
  /// `&&` concatenates in rule order; `%%` takes one value from each branch in turn,
  /// which is upstream's “交叉取数”; a single branch is returned as it is.
  List<T> _merge<T>(List<List<T>> results, _RuleConnector connector) {
    switch (connector) {
      case _RuleConnector.single:
        return results.first;
      case _RuleConnector.union:
        return <T>[for (final List<T> result in results) ...result];
      case _RuleConnector.interleave:
        final int longest = results.fold(
          0,
          (int length, List<T> result) =>
              result.length > length ? result.length : length,
        );
        final List<T> merged = <T>[];
        for (int index = 0; index < longest; index++) {
          for (final List<T> result in results) {
            if (index < result.length) {
              merged.add(result[index]);
            }
          }
        }

        return merged;
    }
  }

  /// Returns every value extracted by the **value** rule [rule] from [scope].
  ///
  /// The last `@`-separated segment is the extraction and every preceding one is a
  /// selector (upstream `getStringList`). Values that extract to an empty string
  /// are dropped, duplicates of an attribute value are dropped, and an empty
  /// result is a success.
  ///
  /// Asynchronous because the rule may hold a `@js:` segment (ADR-0029 §决策 1).
  Future<ParseResult<List<String>>> extractAll(
    String rule,
    RuleScope scope, {
    required String rulePath,
  }) => _evaluate(rule, scope, rulePath: rulePath, single: false);

  /// Returns the first value of [rule], or `null` when nothing matched.
  ///
  /// Upstream `getString`. A `null` data is not a failure: it keeps an optional
  /// book source field (an absent cover, an absent intro) non-fatal, while a
  /// rejected rule still comes back as a [ParseFailure].
  ///
  /// Asynchronous because the rule may hold a `@js:` segment (ADR-0029 §决策 1).
  Future<ParseResult<String?>> extractFirst(
    String rule,
    RuleScope scope, {
    required String rulePath,
  }) async {
    final ParseResult<List<String>> values = await _evaluate(
      rule,
      scope,
      rulePath: rulePath,
      single: true,
    );

    return switch (values) {
      ParseFailure<List<String>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String?>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<String?>(data.isEmpty ? null : data.first),
    };
  }

  /// Runs the shared pipeline of a **value** rule: candidates, branches, the optional
  /// terminal `@js:`, then the `-` reverse and the `##` replacements.
  ///
  /// [single] says which shape the sandbox receives as `result`: upstream reads a single
  /// value for `getString` and the whole list for `getStringList`, and real rules depend on
  /// the difference — `result.replace(...)` needs a String, while `nextTocUrl`'s array needs
  /// a List (`book-source.md` §4.1).
  Future<ParseResult<List<String>>> _evaluate(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required bool single,
  }) async {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<String>>(<String>[]);
    }

    final _ParsedRule parsed = _parse(rule);
    final List<String> merged;
    if (parsed.isBareJs) {
      // `@js:` 独立成规则：没有选择器要跑，`result` 就是整页内容（§6 的 result 绑定）。
      merged = <String>[_contentOf(scope)];
    } else {
      final _Parsed<List<_CheckedCandidate>> check = _check(
        parsed,
        field: rulePath,
        hasExtraction: true,
      );
      final List<_CheckedCandidate> candidates;
      switch (check) {
        case _ParsedFailure<List<_CheckedCandidate>>(
          :final _RuleRejection rejection,
        ):
          return _fail<List<String>>(rejection, field: rulePath);
        case _ParsedValue<List<_CheckedCandidate>>(
          :final List<_CheckedCandidate> value,
        ):
          candidates = value;
      }

      switch (_extractAll(candidates, scope, field: rulePath)) {
        case _ParsedFailure<List<String>>(:final _RuleRejection rejection):
          return _fail<List<String>>(rejection, field: rulePath);
        case _ParsedValue<List<String>>(:final List<String> value):
          merged = value;
      }
    }

    final String? script = parsed.jsScript;
    if (script == null) {
      return ParseSuccess<List<String>>(_finish(merged, parsed));
    }

    final ParseResult<List<String>> evaluated = await _runJs(
      script,
      merged,
      scope,
      field: rulePath,
      single: single,
    );

    return switch (evaluated) {
      ParseFailure<List<String>>() => evaluated,
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<List<String>>(_finish(data, parsed)),
    };
  }

  /// Runs one terminal `@js:` script on the values the selectors produced (matrix #14).
  ///
  /// The sandbox receives them as `result`, plus the page context the scope carries
  /// ([JsPageContext]). What it returns becomes the rule's value: a String is one value, a
  /// List is many — which is how `nextTocUrl` gets an array, and `null` yields no value
  /// (matrix #8's “no value” for an empty extract).
  ///
  /// A timeout or a JS exception comes back as [ParseFailureKind.parseFailed] with the
  /// bridge's `rulePath` marker (§6); nothing is swallowed (C-SRC-4).
  Future<ParseResult<List<String>>> _runJs(
    String script,
    List<String> values,
    RuleScope scope, {
    required String field,
    required bool single,
  }) async {
    final JsPageContext context = _jsContextOf(scope);
    final ParseResult<Object?> evaluated = await _jsBridge.evaluate(
      JsJob(
        script: script,
        rulePath: field,
        baseUrl: context.baseUrl,
        page: context.page,
        source: context.source,
        result: single ? (values.isEmpty ? null : values.first) : values,
      ),
    );

    return switch (evaluated) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<String>>(kind: kind, rulePath: rulePath),
      ParseSuccess<Object?>(:final Object? data) => ParseSuccess<List<String>>(
        _jsValues(data),
      ),
    };
  }

  /// The values one `@js:` result contributes: a List is kept element by element, anything
  /// else is one value, and `null` (or a null element) contributes nothing.
  List<String> _jsValues(Object? value) => switch (value) {
    null => const <String>[],
    final List<Object?> list => <String>[
      for (final Object? item in list)
        if (item != null) item.toString(),
    ],
    _ => <String>[value.toString()],
  };

  /// Applies the `-` reverse and every `##` replacement of [parsed] to [values].
  ///
  /// Upstream applies a `SourceRule`'s `replaceRegex` **after** its JS evaluation
  /// (`AnalyzeRule.kt:250-258`), so the replacement runs on the sandbox's output here too.
  List<String> _finish(List<String> values, _ParsedRule parsed) =>
      _applyReplacement(
        parsed.reverse ? values.reversed.toList(growable: false) : values,
        parsed.replacementParts,
      );

  /// The page context of [scope], or an empty one for a scope built without a fetch.
  JsPageContext _jsContextOf(RuleScope scope) => switch (scope) {
    DomScope(:final JsPageContext? jsContext) =>
      jsContext ?? const JsPageContext(baseUrl: ''),
    JsonScope() => const JsPageContext(baseUrl: ''),
  };

  /// The page content a bare `@js:` rule receives as `result` (`book-source.md` §6).
  String _contentOf(RuleScope scope) => switch (scope) {
    DomScope(:final String? body) => body ?? '',
    JsonScope(:final Object? value) => value == null ? '' : jsonEncode(value),
  };

  /// Applies a **standalone** `##regex##replacement` rule to [text] (matrix #9).
  ///
  /// `ruleContent.replaceRegex` is not evaluated against a page: upstream applies it
  /// to the chapter text it has already assembled (`BookContent.kt:190-193`,
  /// `analyzeRule.getString(replaceRegex, contentStr)`), so there is no DOM for a
  /// selector to read. Real sources therefore spell the rule as the replacement
  /// segments alone — `##本章未完，点击下一页继续阅读。` — which upstream defines as the
  /// `all##…` form ("used on its own it equals `all##…`"); `all` is accepted as well
  /// for the explicit spelling. The four-part `##match##replace###` form of matrix #25
  /// goes through the same replacement engine.
  ///
  /// A body that names a selector has nothing to select in a plain string, and a flag
  /// such as `@js:` belongs to a later phase: the flag is reported as
  /// [ParseFailureKind.unsupportedRule] with the syntax in `rulePath` (C-SRC-4), any
  /// other body as [ParseFailureKind.parseFailed] with [rulePath]. Neither is silently
  /// dropped; the caller degrades the field (ADR-0026 §决策 2).
  ///
  /// Asynchronous like the rest of the evaluation API: from 3.4 on, a `@js:` body is
  /// evaluated by the sandbox (upstream applies `replaceRegex` through
  /// `analyzeRule.getString`, `BookContent.kt:190-193`), and one shared shape keeps a
  /// caller from branching on which engine entry point it holds.
  Future<ParseResult<String>> applyReplaceRule(
    String rule,
    String text, {
    required String rulePath,
  }) async {
    final List<String> parts = rule.split('##');
    final String body = parts.first.trim();
    if (body.toLowerCase().startsWith(_jsFlag)) {
      // 上游把 `replaceRegex` 交给同一套规则求值（`analyzeRule.getString(replaceRegex,
      // contentStr)`），所以 `@js:` 净化规则在沙箱里跑，`result` 是拼接后的整章正文。
      const JsPageContext context = JsPageContext(baseUrl: '');
      final ParseResult<Object?> evaluated = await _jsBridge.evaluate(
        JsJob(
          script: body.substring(_jsFlag.length),
          rulePath: rulePath,
          baseUrl: context.baseUrl,
          page: context.page,
          source: context.source,
          result: text,
        ),
      );

      return switch (evaluated) {
        ParseFailure<Object?>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ) =>
          failureAt<String>(kind: kind, rulePath: rulePath),
        ParseSuccess<Object?>(:final Object? data) => ParseSuccess<String>(
          data?.toString() ?? '',
        ),
      };
    }

    if (body.isNotEmpty && body.toLowerCase() != 'all') {
      for (final String flag in _deferredFlags) {
        if (body.toLowerCase().startsWith(flag)) {
          // 用原文截取，保留作者写的 `@JS:` 这类大小写（§3 前缀大小写不敏感）。
          return _fail<String>(
            _unsupported(body.substring(0, flag.length)),
            field: rulePath,
          );
        }
      }

      return _fail<String>(_malformed(rulePath), field: rulePath);
    }

    return ParseSuccess<String>(_applyReplacement(<String>[text], parts).first);
  }

  /// Extracts every value of a rule whose branches already parsed into [candidates].
  ///
  /// A candidate that **fails** ends the rule: later candidates are not tried, because a
  /// failure says the rule and the page disagree (C-SRC-4). Only a candidate that
  /// succeeded with no value moves on to the next one, which is what makes `||` a
  /// fallback rather than an error recovery.
  _Parsed<List<String>> _extractAll(
    List<_CheckedCandidate> candidates,
    RuleScope scope, {
    required String field,
  }) {
    for (final _CheckedCandidate candidate in candidates) {
      final List<List<String>> results = <List<String>>[];
      for (final _RuleBranch branch in candidate.branches) {
        final _Parsed<List<String>> values = _values(
          branch,
          scope,
          field: field,
        );
        switch (values) {
          case _ParsedFailure<List<String>>():
            return values;
          case _ParsedValue<List<String>>(:final List<String> value):
            results.add(value);
        }
      }
      final List<String> values = _merge<String>(results, candidate.connector);
      if (values.isNotEmpty) {
        // 倒置与 `##` 替换不在这里做：`@js:` 之后才轮到它们（[_finish]）。
        return _ParsedValue<List<String>>(values);
      }
    }

    return const _ParsedValue<List<String>>(<String>[]);
  }

  /// Extracts the values of one value-rule branch from [scope].
  _Parsed<List<String>> _values(
    _RuleBranch branch,
    RuleScope scope, {
    required String field,
  }) => switch (branch) {
    final _DomBranch dom => switch (_matchElements(dom, scope, field: field)) {
      _ParsedFailure<List<Element>>(:final _RuleRejection rejection) =>
        _ParsedFailure<List<String>>(rejection),
      _ParsedValue<List<Element>>(:final List<Element> value) =>
        _ParsedValue<List<String>>(_extract(dom.extraction, value)),
    },
    final _JsonBranch json => switch (_jsonScopeOf(scope, field: field)) {
      _ParsedFailure<Object?>(:final _RuleRejection rejection) =>
        _ParsedFailure<List<String>>(rejection),
      _ParsedValue<Object?>(:final Object? value) => _ParsedValue<List<String>>(
        <String>[
          for (final JsonPathMatch match in json.path.read(value))
            ..._jsonValues(match.value),
        ],
      ),
    },
  };

  /// The values one JSON match contributes to a value rule (matrix #13).
  ///
  /// A JSON string is its own value, a number or a boolean is written the way JSON
  /// writes it, and `null` — like an empty string — yields no value at all, which is
  /// the same “no value” an unmatched selector gives (matrix #8). A map or a list is
  /// handed back as JSON text: upstream's Java `toString` of a map (`{a=1}`) is not
  /// reproducible and no rule can rely on it, so the lossless form is used until a
  /// real book source says otherwise (`docs/dev/book-source.md` §10 decides that).
  Iterable<String> _jsonValues(Object? value) => switch (value) {
    null => const <String>[],
    final String text => text.isEmpty ? const <String>[] : <String>[text],
    final Map<Object?, Object?> map => <String>[jsonEncode(map)],
    final List<Object?> list => <String>[jsonEncode(list)],
    _ => <String>[value.toString()],
  };

  /// Runs [steps] from [scope] and returns the elements they matched.
  ///
  /// With no step the scope itself is the single match, which is what makes an
  /// extraction-only rule such as `href` work (upstream applies the extraction to
  /// the current element).
  List<Element> _run(List<_SelectorStep> steps, Node scope) {
    List<Node> current = <Node>[scope];

    for (final _SelectorStep step in steps) {
      final List<Element> next = <Element>[];
      for (final Node node in current) {
        next.addAll(_match(step, node));
      }
      current = next;
    }

    return current.whereType<Element>().toList();
  }

  /// Returns the elements [step] matches inside [scope], with its positions
  /// applied.
  List<Element> _match(_SelectorStep step, Node scope) {
    final List<Element> matched = switch (step.type) {
      // 矩阵 #4：`children` 取直接子标签（原版 html.children()），第二、三段忽略。
      'children' => List<Element>.of(scope.children),
      // 矩阵 #3：`text` 按元素自身的文本匹配，见 [_elementsContainingOwnText]。
      'text' => _elementsContainingOwnText(scope, step.name),
      _ => _matchByCss(step, scope),
    };

    return _applySelection(matched, step.selection);
  }

  /// Returns the elements matched by [step]'s CSS selector inside [scope].
  ///
  /// Upstream (jsoup) matches the scope element itself as well as its
  /// descendants, while `cascadia.queryAll` deliberately excludes the root, so the
  /// scope is tested separately.
  List<Element> _matchByCss(_SelectorStep step, Node scope) {
    final String selector = _selectorFor(step);

    return <Element>[
      if (scope is Element && cascadia.matches(scope, selector)) scope,
      ...cascadia.queryAll(scope, selector),
    ];
  }

  /// Returns the elements whose **own** text contains [text] (matrix #3).
  ///
  /// Upstream calls jsoup's `getElementsContainingOwnText`: the comparison is
  /// case-insensitive, it covers the scope element itself plus its descendants, and
  /// it only looks at an element's direct text. A wrapper is therefore not a match
  /// for text that lives in its child, which is the same `text` / `ownText`
  /// distinction matrix #8 extracts.
  List<Element> _elementsContainingOwnText(Node scope, String text) {
    final String needle = text.toLowerCase();

    return <Element>[
      for (final Element element in <Element>[
        if (scope is Element) scope,
        ...cascadia.queryAll(scope, '*'),
      ])
        if (_ownTextOf(element).toLowerCase().contains(needle)) element,
    ];
  }

  /// Keeps the positions [selection] names, in the order the author wrote them.
  ///
  /// A `null` selection keeps every match (matrix #5's “不加位置表示取全部”). An
  /// out-of-range position is dropped: upstream degrades a missing position to
  /// “nothing matched” instead of failing the rule, so `tag.li.9` is an empty
  /// result rather than a failure.
  List<Element> _applySelection(
    List<Element> matched,
    _IndexSelection? selection,
  ) {
    if (selection == null) {
      return matched;
    }

    final List<int> resolved = _resolveIndices(selection, matched.length);

    if (!selection.isExclude) {
      return <Element>[for (final int index in resolved) matched[index]];
    }

    final Set<int> excluded = resolved.toSet();

    return <Element>[
      for (int index = 0; index < matched.length; index++)
        if (!excluded.contains(index)) matched[index],
    ];
  }

  /// Resolves every part of [selection] against a list of [length] matches.
  List<int> _resolveIndices(_IndexSelection selection, int length) {
    final List<int> indices = <int>[];

    for (final _IndexPart part in selection.parts) {
      final int? end = part.end;
      if (end == null) {
        final int index = _resolveIndex(part.start, length);
        if (index >= 0 && index < length) {
          indices.add(index);
        }
        continue;
      }
      indices.addAll(_resolveRange(part.start, end, part.step, length));
    }

    return indices;
  }

  /// Expands the `start:end[:step]` range `start`..`end` into concrete indices.
  ///
  /// Both endpoints are clamped to at most one step outside the list so a rule such
  /// as `[0:1000000000]` cannot spin: out-of-range indices are dropped anyway, and a
  /// book source is untrusted input that must not be able to hang the parse
  /// (C-SRC-9).
  List<int> _resolveRange(int start, int end, int? step, int length) {
    final int resolvedStart = _resolveIndex(start, length);
    final int resolvedEnd = _resolveIndex(end, length);
    // 未写 step 时方向由两端决定，矩阵 #26 的 `[-1:0]` 因此天然成为倒序。
    final int resolvedStep = step ?? (resolvedStart <= resolvedEnd ? 1 : -1);
    final int from = _clampIndex(resolvedStart, length);
    final int to = _clampIndex(resolvedEnd, length);
    final List<int> indices = <int>[];

    for (
      int index = from;
      resolvedStep > 0 ? index <= to : index >= to;
      index += resolvedStep
    ) {
      if (index >= 0 && index < length) {
        indices.add(index);
      }
    }

    return indices;
  }

  /// Maps a negative [index] onto the list by counting from its end.
  int _resolveIndex(int index, int length) =>
      index < 0 ? length + index : index;

  /// Clamps [index] to at most one step outside `[0, length)`.
  int _clampIndex(int index, int length) {
    if (index < 0) {
      return -1;
    }

    return index > length ? length : index;
  }

  /// Extracts one value per element, following upstream `getResultLast` (#8).
  List<String> _extract(String extraction, List<Element> elements) {
    final List<String> values = <String>[];

    for (final Element element in elements) {
      switch (extraction) {
        case 'text':
          _addValue(values, _collapseWhitespace(element.text));
        case 'textNodes':
          _addValue(
            values,
            _ownTextNodes(element)
                .map((String text) => text.trim())
                .where((String text) => text.isNotEmpty)
                .join('\n'),
          );
        case 'ownText':
          _addValue(values, _ownTextOf(element));
        case 'html':
          _addValue(values, _withoutScripts(element).outerHtml);
        case 'all':
          _addValue(values, element.outerHtml);
        default:
          // 其他取值一律按 HTML 属性名处理（矩阵 #8 的「及其他 HTML 属性名」）。
          _addAttribute(values, element.attributes[extraction]);
      }
    }

    return values;
  }

  /// Builds the CSS selector of [step]; `class` / `id` / `tag` map onto CSS so the
  /// matching itself goes through cascadia (C-SRC-6).
  String _selectorFor(_SelectorStep step) => switch (step.type) {
    // 矩阵 #12：`@css:` 的选择器原样交给 cascadia，不做任何改写。
    'css' => step.name,
    'class' => '.${cascadia.escapeCssIdent(step.name)}',
    'id' => '#${cascadia.escapeCssIdent(step.name)}',
    _ => cascadia.escapeCssIdent(step.name),
  };

  /// Splits [rule] into its `##` parts, its leading `-` and its `@`-separated
  /// segments.
  ///
  /// Total on purpose: a rejected rule still needs its segments to name the
  /// offending syntax.
  _ParsedRule _parse(String rule) {
    final List<String> replacementParts = rule.split('##');
    final String rawBody = replacementParts.first.trim();
    // 矩阵 #7：`-` 是整条规则的前缀（`-class.odd@tag.a@href`）。必须在按 `@`
    // 切段之前摘掉，否则它会变成一个空段，后面的标志头也会被切错。
    final bool reverse = rawBody.startsWith('-');
    final String body = (reverse ? rawBody.substring(1) : rawBody).trim();
    // 矩阵 #14：`@js:` 贪婪吞掉本条规则剩余部分（上游 `AppPattern.JS_PATTERN` 的
    // `@js:([\w\W]*)`），所以必须在切候选 / 分支 / 段之前先切它——否则 JS 里的
    // `&&` / `||` 会被当成连接符，而那正是真实规则大量使用的写法。
    final int jsAt = body.toLowerCase().indexOf(_jsFlag);
    final String selectorBody = jsAt < 0
        ? body
        : body.substring(0, jsAt).trim();
    final String? jsScript = jsAt < 0
        ? null
        : body.substring(jsAt + _jsFlag.length).trim();

    return _ParsedRule(
      body: selectorBody,
      jsScript: jsScript,
      replacementParts: replacementParts,
      reverse: reverse,
      candidates: _candidatesOf(selectorBody),
    );
  }

  /// Splits the rule body into candidates (matrix #10's `||`) and, inside each, into
  /// branches (matrix #11's `&&` / #27's `%%`).
  ///
  /// `||` binds loosest, so it is split first: `a&&b||c` is `(a&&b) || c`
  /// (`book-source.md` §3.2, architect ruling 1). Inside a candidate `%%` and `&&` are
  /// the same level, so the first one to occur decides.
  List<_RuleCandidate> _candidatesOf(String body) => <_RuleCandidate>[
    for (final String candidate in _splitRule(body, <String>['||']).parts)
      _candidateOf(candidate),
  ];

  /// Splits one candidate into its branches.
  ///
  /// A branch is kept as the author wrote it: `@json:` has to be recognised **before**
  /// the `@`-split, because a JSONPath may carry an `@` of its own — the filter form
  /// `$[?(@.a)]` of matrix #13.
  _RuleCandidate _candidateOf(String text) {
    final ({List<String> parts, String? separator}) split = _splitRule(
      text,
      <String>['%%', '&&'],
    );
    final _RuleConnector connector = switch (split.separator) {
      '%%' => _RuleConnector.interleave,
      '&&' => _RuleConnector.union,
      _ => _RuleConnector.single,
    };

    return _RuleCandidate(
      branches: <String>[
        for (final String branch in split.parts) branch.trim(),
      ],
      connector: connector,
    );
  }

  /// Splits one branch into its `@`-separated segments.
  ///
  /// A branch that starts with a flag (`@js:…`) would otherwise leave an empty first
  /// segment and be read as malformed — the same trap a rule body has, and now handled
  /// in one place because a body is just the first branch. The `@` is only dropped when
  /// a flag really follows, so `@foo` stays a broken rule.
  List<String> _segmentsOf(String branch) {
    final String trimmed = branch.trim();
    final String text =
        trimmed.startsWith('@') && _flagSegment.hasMatch(trimmed.substring(1))
        ? trimmed.substring(1)
        : trimmed;

    return text.split('@').map((String segment) => segment.trim()).toList();
  }

  /// Reads [parsed] into the selector steps it runs, or reports the rejection.
  ///
  /// Validation and evaluation share this one parse, so the two can never disagree
  /// about what a rule means. [hasExtraction] says whether the last segment is the
  /// extraction (value rules) or one more selector (list rules).
  _Parsed<List<_CheckedCandidate>> _check(
    _ParsedRule parsed, {
    required String field,
    required bool hasExtraction,
  }) {
    final String body = parsed.body;

    if (!hasExtraction && parsed.jsScript != null) {
      // 矩阵 #14 目前只实现**值规则**上的 `@js:`（终段）。列表规则上的 JS 要的是「JS
      // 返回一列元素」的契约（上游 `getElements` 的 `Mode.Js` 分支，AnalyzeRule.kt:439），
      // 该契约尚未成型，所以显式拒绝——顶层列表规则被拒仍整次失败（C-SRC-4）。
      return _ParsedFailure<List<_CheckedCandidate>>(_unsupported('@js:list'));
    }

    for (final String flag in _deferredFlags) {
      if (body.toLowerCase().startsWith(flag)) {
        // 用原文截取，保留作者写的 `@webJs` 这类大小写（book-source.md §3 前缀大小写不敏感）。
        return _ParsedFailure<List<_CheckedCandidate>>(
          _unsupported(body.substring(0, flag.length)),
        );
      }
    }
    if (body.contains('@@')) {
      // 矩阵 #15：`@@` 默认规则标志。`@` 切分后中段的 `@@` 会留下一个空段，
      // 因此必须在切段之前判掉，否则会被误报成畸形规则。
      return _ParsedFailure<List<_CheckedCandidate>>(_unsupported('@@'));
    }

    final List<_CheckedCandidate> candidates = <_CheckedCandidate>[];
    for (final _RuleCandidate candidate in parsed.candidates) {
      final List<_RuleBranch> branches = <_RuleBranch>[];
      for (final String branchText in candidate.branches) {
        final _Parsed<_RuleBranch> branch = _readBranch(
          branchText,
          field: field,
          hasExtraction: hasExtraction,
        );
        switch (branch) {
          case _ParsedFailure<_RuleBranch>(:final _RuleRejection rejection):
            return _ParsedFailure<List<_CheckedCandidate>>(rejection);
          case _ParsedValue<_RuleBranch>(:final _RuleBranch value):
            branches.add(value);
        }
      }
      if (_mergesTwoScopes(branches)) {
        // `book-source.md` §3 的 `&&` 注记：连接符只合并同种规则。JSON 分支与默认 /
        // `@css:` 分支合并会拼出异构结果，语义未定义，所以显式报畸形而不是猜一种。
        return _ParsedFailure<List<_CheckedCandidate>>(_malformed(field));
      }
      candidates.add(
        _CheckedCandidate(branches: branches, connector: candidate.connector),
      );
    }

    return _ParsedValue<List<_CheckedCandidate>>(candidates);
  }

  /// Reads one branch: its selector steps plus, for a value rule, its extraction.
  ///
  /// A branch that is a JSON rule is recognised first and read on its own (matrix
  /// #13): its whole text is one JSONPath, not a run of `@`-separated segments.
  _Parsed<_RuleBranch> _readBranch(
    String branch, {
    required String field,
    required bool hasExtraction,
  }) {
    final String? jsonPath = _jsonPathOf(branch);
    if (jsonPath != null) {
      return _readJsonBranch(jsonPath, field: field);
    }

    final List<String> segments = _segmentsOf(branch);
    final List<String> selectorTexts = hasExtraction
        ? segments.sublist(0, segments.length - 1)
        : segments;
    final List<_SelectorStep> steps = <_SelectorStep>[];
    for (final String segment in selectorTexts) {
      final _Parsed<_SelectorStep> read = _readSelector(segment, field: field);
      switch (read) {
        case _ParsedFailure<_SelectorStep>(:final _RuleRejection rejection):
          return _ParsedFailure<_RuleBranch>(rejection);
        case _ParsedValue<_SelectorStep>(:final _SelectorStep value):
          steps.add(value);
      }
    }

    if (!hasExtraction) {
      return _ParsedValue<_RuleBranch>(
        _DomBranch(selectors: steps, extraction: ''),
      );
    }
    final String extraction = segments.last;
    if (extraction.isEmpty) {
      return _ParsedFailure<_RuleBranch>(_malformed(field));
    }
    final String? flag = _flagOf(extraction);
    if (flag != null) {
      // 末段是提取段，而上游在那里允许**嵌套规则**（矩阵 #30，M2/暂不实现）。
      // 名字必须与中段的 `@css:` 区分开：中段已支持（矩阵 #12），末段仍未支持。
      return _ParsedFailure<_RuleBranch>(_unsupported('nested-rule'));
    }

    return _ParsedValue<_RuleBranch>(
      _DomBranch(selectors: steps, extraction: extraction),
    );
  }

  /// Reads one selector [segment] into the step it stands for (matrix #1..#7,
  /// #26, #28), or reports why it cannot be evaluated.
  _Parsed<_SelectorStep> _readSelector(
    String segment, {
    required String field,
  }) {
    if (segment.isEmpty) {
      return _ParsedFailure<_SelectorStep>(_malformed(field));
    }
    final String? flag = _flagOf(segment);
    if (flag != null) {
      if (flag.toLowerCase() == _cssFlag) {
        // 矩阵 #12：`@css:` 的其余部分是交给 cascadia 的 CSS 选择器（C-SRC-6）。
        // `_flagOf` 返回的 flag 把被 `@` 切分吃掉的 `@` 补了回来，所以这里要少取一位。
        return _readCss(segment.substring(flag.length - 1), field: field);
      }
      // 整条分支的 `@json:` 在 `_readBranch` 已读走（矩阵 #13），能到这里的 `@json:`
      // 只可能是中段 / 末段，即矩阵 #30 的嵌套规则；`@js:` / `@xpath:` … 仍属后续
      // 阶段（矩阵 #14 / #21）。
      return _ParsedFailure<_SelectorStep>(_unsupported(flag));
    }

    final List<String> parts = segment.split('.');
    final String type = parts[0];
    final String? indexExpression = _childrenIndexExpression(segment, parts);
    if (indexExpression != null) {
      // 矩阵 #28：索引作为该段首规则，等价于 `children` + 该索引。
      return _readChildren(indexExpression, field: field);
    }
    if (type.isEmpty) {
      // ADR-0032：空类型不是结构性错误，而是一段原始 CSS（`.searchresult`）。
      // 真正畸形的写法（`.`、`.1.2`）会在 cascadia 解析或索引解析处失败。
      return _readDegraded(segment, field: field);
    }
    if (!_implementedTypes.contains(type)) {
      // ADR-0032：类型未知时原版把**整段**当成原始 CSS 选择器（`li`、`dd`、`tr!0`、
      // `#txt`、`div.item`）。语料中 58.1% 的 M0 源依赖这个退化，因此不能再按
      // 「未知类型 = 不支持」拒绝。
      return _readDegraded(segment, field: field);
    }
    if (type == 'children') {
      // 矩阵 #4：`children` 取全部子标签，忽略第二、三段。
      return const _ParsedValue<_SelectorStep>(
        _SelectorStep(type: 'children', name: ''),
      );
    }
    if (parts.length < 2 || parts.length > 3) {
      return _ParsedFailure<_SelectorStep>(_malformed(field));
    }

    final _Parsed<_NamedSelector> named = _readName(parts[1], field: field);
    switch (named) {
      case _ParsedFailure<_NamedSelector>(:final _RuleRejection rejection):
        return _ParsedFailure<_SelectorStep>(rejection);
      case _ParsedValue<_NamedSelector>(:final _NamedSelector value):
        return _withPosition(
          type: type,
          named: value,
          position: parts.length == 3 ? parts[2] : null,
          field: field,
        );
    }
  }

  /// Adds the position segment of matrix #1 to an already read name.
  ///
  /// The two position forms — `tag.li.0` and `tag.li[0]` — are alternatives:
  /// upstream would read `[-1]` of `tag.div[-1].0` as part of the name and match
  /// nothing, so writing both is rejected instead of silently returning empty.
  _Parsed<_SelectorStep> _withPosition({
    required String type,
    required _NamedSelector named,
    required String? position,
    required String field,
  }) {
    if (position == null) {
      return _ParsedValue<_SelectorStep>(
        _SelectorStep(type: type, name: named.name, selection: named.selection),
      );
    }

    final _Parsed<List<_IndexPart>> positions = _readIndices(
      position,
      field: field,
    );
    switch (positions) {
      case _ParsedFailure<List<_IndexPart>>(:final _RuleRejection rejection):
        return _ParsedFailure<_SelectorStep>(rejection);
      case _ParsedValue<List<_IndexPart>>(:final List<_IndexPart> value):
        if (named.selection != null) {
          return _ParsedFailure<_SelectorStep>(_malformed(field));
        }

        return _ParsedValue<_SelectorStep>(
          _SelectorStep(
            type: type,
            name: named.name,
            selection: _IndexSelection(parts: value, isExclude: false),
          ),
        );
    }
  }

  /// Splits the name part of a selector into the name itself and the positions
  /// attached to it (matrix #6's `!` list and #26's `[...]` list).
  _Parsed<_NamedSelector> _readName(String text, {required String field}) {
    final int bracket = text.indexOf('[');
    if (bracket >= 0) {
      return _withIndexSelection(
        name: text.substring(0, bracket),
        indexExpression: text.substring(bracket),
        field: field,
      );
    }

    final int excluded = text.indexOf('!');
    if (excluded < 0) {
      // `div]`：括起来却没有 `[`，不是任何已实现的写法。
      return text.contains(']')
          ? _ParsedFailure<_NamedSelector>(_malformed(field))
          : _namedWith(text, null, field: field);
    }

    return _withIndexSelection(
      name: text.substring(0, excluded),
      indexExpression: text.substring(excluded),
      field: field,
    );
  }

  /// Pairs [name] with the positions named by [indexExpression].
  _Parsed<_NamedSelector> _withIndexSelection({
    required String name,
    required String indexExpression,
    required String field,
  }) {
    return switch (_readIndexOnly(indexExpression, field: field)) {
      _ParsedFailure<_IndexSelection>(:final _RuleRejection rejection) =>
        _ParsedFailure<_NamedSelector>(rejection),
      _ParsedValue<_IndexSelection>(:final _IndexSelection value) => _namedWith(
        name,
        value,
        field: field,
      ),
    };
  }

  /// Checks the name itself and pairs it with its positions.
  ///
  /// A `:` inside the name is not part of any implemented syntax (matrix #6 uses
  /// `:` only inside the `!` list and inside the position segment), so it is
  /// reported as unsupported instead of being matched as a class or tag name.
  _Parsed<_NamedSelector> _namedWith(
    String name,
    _IndexSelection? selection, {
    required String field,
  }) {
    if (name.isEmpty) {
      return _ParsedFailure<_NamedSelector>(_malformed(field));
    }
    if (name.contains(':')) {
      return _ParsedFailure<_NamedSelector>(_unsupported(':'));
    }

    return _ParsedValue<_NamedSelector>((name: name, selection: selection));
  }

  /// Reads a segment whose type is not one of the implemented ones as a **raw CSS
  /// selector** (ADR-0032).
  ///
  /// Upstream hands such a segment to jsoup unchanged (`doc.select(rule)`), and real book
  /// sources rely on it: `li` / `dd` / `p` (a bare tag name), `.searchresult`, `#txt`,
  /// `div.item`. The position suffix is split off first, because `tr!0` is not valid CSS:
  /// it means “every `tr`, minus index 0”, i.e. matrix #6's position applied to the CSS
  /// matches.
  ///
  /// A `//`-prefixed segment stays [ParseFailureKind.unsupportedRule]: that is matrix
  /// #21's XPath, and treating it as CSS would produce a syntactically fine selector that
  /// never matches (C-SRC-4).
  _Parsed<_SelectorStep> _readDegraded(
    String segment, {
    required String field,
  }) {
    if (segment.startsWith('//')) {
      return _ParsedFailure<_SelectorStep>(_unsupported('//'));
    }

    final _Parsed<_NamedSelector> split = _splitDegradedSuffix(
      segment,
      field: field,
    );
    switch (split) {
      case _ParsedFailure<_NamedSelector>(:final _RuleRejection rejection):
        return _ParsedFailure<_SelectorStep>(rejection);
      case _ParsedValue<_NamedSelector>(:final _NamedSelector value):
        // 空选择器不需要在这里判：[_readCss] 对空串本就返回字段级 `parseFailed`，
        // 重复判一次只会多出一行永不执行的代码（C-BAN-1）。
        return switch (_readCss(value.name, field: field)) {
          _ParsedFailure<_SelectorStep>(:final _RuleRejection rejection) =>
            _ParsedFailure<_SelectorStep>(rejection),
          _ParsedValue<_SelectorStep>(:final _SelectorStep value) =>
            _ParsedValue<_SelectorStep>(
              _SelectorStep(
                type: value.type,
                name: value.name,
                selection: split.value.selection,
              ),
            ),
        };
    }
  }

  /// Splits the position suffix (`!0`, `[1]`, `[0:2]`) off a degraded segment.
  ///
  /// The same split as [_readName], minus its name validation: a raw CSS selector may
  /// contain `:` (`.result-item:lt(3)`, `p:nth-of-type(3)`), which [_namedWith] rejects
  /// because inside an **implemented** type a `:` is not part of any syntax.
  _Parsed<_NamedSelector> _splitDegradedSuffix(
    String segment, {
    required String field,
  }) {
    final int bracket = segment.indexOf('[');
    if (bracket >= 0) {
      return _indexSuffix(
        segment.substring(0, bracket),
        segment.substring(bracket),
        field: field,
      );
    }

    final int excluded = segment.indexOf('!');
    if (excluded < 0) {
      // `div]`：括起来却没有 `[`，不是任何已实现的写法（与 [_readName] 同口径）。
      return segment.contains(']')
          ? _ParsedFailure<_NamedSelector>(_malformed(field))
          : _ParsedValue<_NamedSelector>((name: segment, selection: null));
    }

    return _indexSuffix(
      segment.substring(0, excluded),
      segment.substring(excluded),
      field: field,
    );
  }

  /// Pairs a degraded segment's head with the positions named by [indexExpression].
  _Parsed<_NamedSelector> _indexSuffix(
    String head,
    String indexExpression, {
    required String field,
  }) => switch (_readIndexOnly(indexExpression, field: field)) {
    _ParsedFailure<_IndexSelection>(:final _RuleRejection rejection) =>
      _ParsedFailure<_NamedSelector>(rejection),
    _ParsedValue<_IndexSelection>(:final _IndexSelection value) =>
      _ParsedValue<_NamedSelector>((name: head, selection: value)),
  };

  /// Reads the `:`-separated index list of matrix #6 (`!0:1`, and the position
  /// segment's `-1:2`).
  ///
  /// Upstream parses this list with `findIndexSet`, which throws on an empty or
  /// non-numeric entry (upstream issue #1796); here it is a `parseFailed` rejection
  /// so the book source field stays locatable (C-SRC-8).
  _Parsed<List<_IndexPart>> _readIndices(String text, {required String field}) {
    final List<_IndexPart> parts = <_IndexPart>[];

    for (final String token in text.split(':')) {
      final int? index = int.tryParse(token.trim());
      if (index == null) {
        return _ParsedFailure<List<_IndexPart>>(_malformed(field));
      }
      parts.add(_IndexPart(start: index));
    }

    return _ParsedValue<List<_IndexPart>>(parts);
  }

  /// Reads the comma-separated list inside `[...]` (matrix #26).
  ///
  /// Each entry is an index (`-1`) or a range (`start:end[:step]`). The upstream
  /// rule documentation allows an omitted `start` (meaning 0) and an omitted `end`
  /// (meaning -1); negatives count from the end in every position.
  _Parsed<List<_IndexPart>> _readRanges(String text, {required String field}) {
    if (text.trim().isEmpty) {
      return _ParsedFailure<List<_IndexPart>>(_malformed(field));
    }
    final List<_IndexPart> parts = <_IndexPart>[];

    for (final String token in text.split(',')) {
      final List<String> pieces = token.trim().split(':');
      if (pieces.length > 3) {
        return _ParsedFailure<List<_IndexPart>>(_malformed(field));
      }

      final String startText = pieces[0].trim();
      final int? start = startText.isEmpty ? 0 : int.tryParse(startText);
      final bool hasEnd = pieces.length > 1;
      final String endText = hasEnd ? pieces[1].trim() : '';
      final int? end = hasEnd
          ? (endText.isEmpty ? -1 : int.tryParse(endText))
          : null;
      final bool hasStep = pieces.length > 2;
      final String stepText = hasStep ? pieces[2].trim() : '';
      final int? step = hasStep && stepText.isNotEmpty
          ? int.tryParse(stepText)
          : null;

      if (start == null ||
          (hasEnd && end == null) ||
          (hasStep && stepText.isNotEmpty && step == null) ||
          step == 0) {
        return _ParsedFailure<List<_IndexPart>>(_malformed(field));
      }
      parts.add(_IndexPart(start: start, end: end, step: step));
    }

    return _ParsedValue<List<_IndexPart>>(parts);
  }

  /// The JSONPath of a branch that is a JSON rule, or `null` when it is not one
  /// (matrix #13).
  ///
  /// The flag is case-insensitive like every other flag (`@Json:` works), and it may be
  /// omitted when the path starts with `$.` or `$[` — the two spellings upstream's rule
  /// documentation lists. A bare `$` is not one of them, so it stays an unknown rule
  /// type instead of being guessed.
  String? _jsonPathOf(String branch) {
    final String trimmed = branch.trim();
    if (trimmed.toLowerCase().startsWith(_jsonFlag)) {
      return trimmed.substring(_jsonFlag.length);
    }
    if (trimmed.startsWith(r'$.') || trimmed.startsWith(r'$[')) {
      return trimmed;
    }

    return null;
  }

  /// Reads a `@json:` branch (matrix #13) into the JSONPath it evaluates.
  ///
  /// The path is parsed while the rule is read, for the same reason `@css:` parses its
  /// selector here: a malformed path has to become a locatable
  /// [ParseFailureKind.parseFailed] carrying the field path, instead of an unlocatable
  /// throw out of the matcher (C-SRC-8).
  _Parsed<_RuleBranch> _readJsonBranch(
    String expression, {
    required String field,
  }) {
    final String trimmed = expression.trim();
    if (trimmed.isEmpty) {
      return _ParsedFailure<_RuleBranch>(_malformed(field));
    }

    try {
      return _ParsedValue<_RuleBranch>(_JsonBranch(JsonPath(trimmed)));
    } on FormatException {
      return _ParsedFailure<_RuleBranch>(_malformed(field));
    }
  }

  /// Whether [branches] read two different scopes, i.e. a JSON branch merged with a
  /// DOM one.
  ///
  /// `&&` and `%%` only merge rules of the same kind (`book-source.md` §3, the `&&`
  /// note), so mixing them has no defined result and is reported instead of being
  /// guessed. Note that this is a narrower question than “is this branch a value
  /// rule”: a value rule written inside a **list** rule is still rejected by
  /// [_readSelector], which reports its segment as unsupported or malformed.
  bool _mergesTwoScopes(List<_RuleBranch> branches) =>
      branches.any((_RuleBranch branch) => branch is _JsonBranch) &&
      branches.any((_RuleBranch branch) => branch is _DomBranch);

  /// Reads the `@css:` form of matrix #12: the rest of the segment is a CSS
  /// selector that goes to cascadia unchanged (C-SRC-6).
  ///
  /// The selector is parsed once here instead of being handed to cascadia during
  /// evaluation, because only this layer can turn a bad selector into the right
  /// [ParseResult]: malformed CSS is [ParseFailureKind.parseFailed], while jsoup's
  /// index pseudo-classes — not standard CSS, not in cascadia, not in the matrix —
  /// are named as [ParseFailureKind.unsupportedRule] so the missing capability
  /// stays visible (C-SRC-4) instead of surfacing as an unlocatable throw.
  _Parsed<_SelectorStep> _readCss(String selector, {required String field}) {
    final String trimmed = selector.trim();
    if (trimmed.isEmpty) {
      return _ParsedFailure<_SelectorStep>(_malformed(field));
    }

    return switch (_rewriteIndexPseudos(trimmed, field: field)) {
      _ParsedFailure<String>(:final _RuleRejection rejection) =>
        _ParsedFailure<_SelectorStep>(rejection),
      _ParsedValue<String>(:final String value) => _compileCss(
        value,
        field: field,
      ),
    };
  }

  /// Parses the rewritten [selector] with cascadia, or reports why it cannot be
  /// evaluated.
  ///
  /// Parsing here — while the rule is read — is what turns a bad selector into the
  /// right [ParseResult]: malformed CSS becomes [ParseFailureKind.parseFailed] with
  /// the field path, instead of an unlocatable throw from the matcher (C-SRC-8).
  /// cascadia parses again when matching; that parse is served from its own cache.
  _Parsed<_SelectorStep> _compileCss(String selector, {required String field}) {
    try {
      cascadia.parse(selector);
    } on FormatException {
      return _ParsedFailure<_SelectorStep>(_malformed(field));
    }

    return _ParsedValue<_SelectorStep>(
      _SelectorStep(type: 'css', name: selector),
    );
  }

  /// Rewrites the jsoup index pseudo-classes of matrix #29 into their cascadia
  /// equivalent, or reports the one form that cannot be rewritten.
  ///
  /// jsoup defines them on the **sibling index** (`elementSiblingIndex()`, 0-based),
  /// so `:eq(n)` is an equality and becomes `:nth-child({n+1})`: the plain `B` form is
  /// the only one that means “equals”, while `:nth-child(n+…)` would match every
  /// later sibling. `:gt(n)` and `:lt(n)` become `:nth-child(n+{n+2})` and
  /// `:nth-child(-n+{n})`. Rewriting keeps the matching inside cascadia (C-SRC-6).
  ///
  /// A negative argument is rejected by name: jsoup's documentation defines the
  /// indexed pseudo-selectors as 0-based and says nothing about negatives, so the
  /// behaviour is not guessed here (`book-source.md` §3 row #29).
  ///
  /// The scan is textual, so an `:eq(…)` inside a quoted attribute value would be
  /// rewritten as well. That is the deliberate tolerance boundary of matrix #29: a
  /// quote-aware scanner buys nothing for real book sources, and the result still
  /// fails loudly whenever cascadia cannot parse it.
  _Parsed<String> _rewriteIndexPseudos(
    String selector, {
    required String field,
  }) {
    String rewritten = selector;

    for (final MapEntry<String, String Function(int)> entry
        in _indexPseudoRewrites.entries) {
      final RegExp pattern = RegExp(':${entry.key}\\(\\s*(-?\\d+)\\s*\\)');
      while (true) {
        final RegExpMatch? match = pattern.firstMatch(rewritten);
        if (match == null) {
          break;
        }
        final String argument = match.group(1) ?? '';
        final int? index = int.tryParse(argument);
        if (index == null) {
          return _ParsedFailure<String>(_malformed(field));
        }
        if (index < 0) {
          return _ParsedFailure<String>(
            _unsupported(':${entry.key}($argument)'),
          );
        }
        rewritten = rewritten.replaceRange(
          match.start,
          match.end,
          entry.value(index),
        );
      }
    }

    return _ParsedValue<String>(rewritten);
  }

  /// Returns the index expression of a segment that stands for `children` plus a
  /// position, or `null` when the segment is a normal selector (matrix #28).
  ///
  /// Upstream allows an index as the **first rule** of a segment, and three
  /// spellings mean the same thing: `.1`, `[1]` and `children[1]`. A letter after
  /// the dot is *not* one of them — `children.li.0` stays matrix #4's “ignore the
  /// second and third segment” behaviour.
  String? _childrenIndexExpression(String segment, List<String> parts) {
    final String type = parts[0];

    if (type.isEmpty) {
      final String rest = parts.sublist(1).join('.');

      return _looksLikeIndexExpression(rest) ? rest : null;
    }
    if (segment.startsWith('children')) {
      final String rest = segment.substring('children'.length);
      final String expression = rest.startsWith('.') ? rest.substring(1) : rest;

      // 裸 `children`（矩阵 #4）与 `children.li.0`（忽略第二、三段）都不是索引写法。
      return _looksLikeIndexExpression(expression) ? expression : null;
    }
    if (type.startsWith('[') || type.startsWith('!')) {
      return segment;
    }

    return null;
  }

  /// Whether [text] starts like an index expression (an index, a range or a list).
  bool _looksLikeIndexExpression(String text) {
    if (text.isEmpty) {
      return false;
    }
    if (text.startsWith('[') || text.startsWith('!')) {
      return true;
    }

    final int first = text.codeUnitAt(0);

    // `-1`（负索引）与 `0` / `0:2` 这类序号列表。
    return first == 0x2D || _isDigit(first);
  }

  /// Reads an index-only segment into a `children` step (matrix #28).
  _Parsed<_SelectorStep> _readChildren(
    String indexExpression, {
    required String field,
  }) {
    return switch (_readIndexOnly(indexExpression, field: field)) {
      _ParsedFailure<_IndexSelection>(:final _RuleRejection rejection) =>
        _ParsedFailure<_SelectorStep>(rejection),
      _ParsedValue<_IndexSelection>(:final _IndexSelection value) =>
        _ParsedValue<_SelectorStep>(
          _SelectorStep(type: 'children', name: '', selection: value),
        ),
    };
  }

  /// Reads an index expression on its own: `[1]`, `[!0]`, `[0:2]`, `!0`, `-1`.
  ///
  /// Matrix #26 owns the bracketed form, matrix #6 the `!` list, and the bare list
  /// is what an index-only segment carries (`children.1`, matrix #28). All three go
  /// through one parser, so `[1]` and `children.1` cannot drift apart.
  _Parsed<_IndexSelection> _readIndexOnly(
    String text, {
    required String field,
  }) {
    if (text.startsWith('[')) {
      if (!text.endsWith(']')) {
        return _ParsedFailure<_IndexSelection>(_malformed(field));
      }
      final String listed = text.substring(1, text.length - 1);
      final bool isExclude = listed.startsWith('!');

      return switch (_readRanges(
        isExclude ? listed.substring(1) : listed,
        field: field,
      )) {
        _ParsedFailure<List<_IndexPart>>(:final _RuleRejection rejection) =>
          _ParsedFailure<_IndexSelection>(rejection),
        _ParsedValue<List<_IndexPart>>(:final List<_IndexPart> value) =>
          _ParsedValue<_IndexSelection>(
            _IndexSelection(parts: value, isExclude: isExclude),
          ),
      };
    }

    final bool isExclude = text.startsWith('!');

    return switch (_readIndices(
      isExclude ? text.substring(1) : text,
      field: field,
    )) {
      _ParsedFailure<List<_IndexPart>>(:final _RuleRejection rejection) =>
        _ParsedFailure<_IndexSelection>(rejection),
      _ParsedValue<List<_IndexPart>>(:final List<_IndexPart> value) =>
        _ParsedValue<_IndexSelection>(
          _IndexSelection(parts: value, isExclude: isExclude),
        ),
    };
  }

  /// Returns the rule flag [segment] starts with, or `null` when it starts with
  /// none.
  ///
  /// The flag is returned as the author wrote it, so `rulePath` keeps the original
  /// casing (`unsupported:@webJs`), and the `@` that the `@`-split removed is put
  /// back.
  String? _flagOf(String segment) {
    final String? token = _flagSegment.firstMatch(segment)?.group(0);

    return token == null ? null : '@$token';
  }

  /// Builds the failure for a syntax a later phase owns.
  ///
  /// `rulePath` follows `book-source.md` §7: `unsupported:<语法名>`.
  _RuleRejection _unsupported(String syntax) => _RuleRejection(
    kind: ParseFailureKind.unsupportedRule,
    rulePath: 'unsupported:$syntax',
  );

  /// Builds the failure for a rule that is structurally broken.
  ///
  /// The field path is kept as `rulePath`, because the caller has to be able to
  /// point at the book source field that carries the broken rule (C-SRC-8).
  _RuleRejection _malformed(String field) =>
      _RuleRejection(kind: ParseFailureKind.parseFailed, rulePath: field);

  /// Logs [rejection] and turns it into the caller's result type (C-SRC-4).
  ParseResult<T> _fail<T>(_RuleRejection rejection, {required String field}) {
    _logger.warning(
      'Rejected rule: field=$field reason=${rejection.rulePath} '
      'kind=${rejection.kind.name}',
    );

    return failureAt<T>(kind: rejection.kind, rulePath: rejection.rulePath);
  }

  /// Adds [value] unless it is empty, matching upstream `getResultLast`.
  void _addValue(List<String> values, String value) {
    if (value.isNotEmpty) {
      values.add(value);
    }
  }

  /// Adds an attribute value, skipping blanks and duplicates (upstream behaviour).
  void _addAttribute(List<String> values, String? value) {
    if (value == null || value.trim().isEmpty || values.contains(value)) {
      return;
    }

    values.add(value);
  }
}

/// One parsed rule: its body, its script, its leading `-` and its `@`-separated segments.
final class _ParsedRule {
  const _ParsedRule({
    required this.body,
    required this.jsScript,
    required this.replacementParts,
    required this.reverse,
    required this.candidates,
  });

  /// The rule itself: everything before the first `##` and before an `@js:` flag, without
  /// the leading `-`. Empty when the rule is nothing but `@js:`.
  final String body;

  /// The script of a terminal `@js:` flag (matrix #14), or `null` when the rule has none.
  final String? jsScript;

  /// Whether the rule is a bare `@js:`: no selector to run, so `result` is the page itself.
  bool get isBareJs => jsScript != null && body.isEmpty;

  /// The `##`-separated parts: `[rule]`, `[regex]`, `[replacement]`.
  final List<String> replacementParts;

  /// Whether the rule starts with `-`, i.e. its result list is reversed (matrix #7).
  final bool reverse;

  /// The candidates of the body: `||` alternatives, each with its own branches.
  final List<_RuleCandidate> candidates;
}

/// A selector name together with the positions written on it (matrix #6 / #26).
typedef _NamedSelector = ({String name, _IndexSelection? selection});

/// One selector segment: `类型.名称.位置` (matrix #1).
final class _SelectorStep {
  const _SelectorStep({required this.type, required this.name, this.selection});

  /// `class`, `id`, `tag`, `text` or `children` — validated before this step is built.
  final String type;

  /// The class name, id, tag name, or the text `text` looks for (empty for `children`).
  final String name;

  /// The positions this step keeps, or `null` for every match (`类型.名称`).
  final _IndexSelection? selection;
}

/// One entry of a position selection: a single index or a `start:end[:step]` range
/// (matrix #6 / #26).
final class _IndexPart {
  const _IndexPart({required this.start, this.end, this.step});

  /// The start index; a negative value counts from the end of the matches.
  final int start;

  /// The end index of a range, or `null` for a single index.
  final int? end;

  /// The range step, or `null` to take the direction from the two endpoints.
  final int? step;
}

/// The positions a selector keeps, in the order the author wrote them.
final class _IndexSelection {
  const _IndexSelection({required this.parts, required this.isExclude});

  /// The indices and ranges of the selection.
  final List<_IndexPart> parts;

  /// Whether the listed positions are removed instead of kept (`!`).
  final bool isExclude;
}

/// How the branches of one candidate combine (`book-source.md` §3.2).
enum _RuleConnector {
  /// One branch only.
  single,

  /// Matrix #11: `&&` merges the branches (union), in rule order.
  union,

  /// Matrix #27: `%%` takes one value from each branch in turn.
  interleave,
}

/// One `||` candidate: its branches and how they combine.
final class _RuleCandidate {
  const _RuleCandidate({required this.branches, required this.connector});

  /// The branches as written, before the `@`-split.
  final List<String> branches;

  /// How [branches] combine.
  final _RuleConnector connector;
}

/// One candidate whose branches parsed into steps.
final class _CheckedCandidate {
  const _CheckedCandidate({required this.branches, required this.connector});

  /// The parsed branches.
  final List<_RuleBranch> branches;

  /// How [branches] combine.
  final _RuleConnector connector;
}

/// One parsed branch: either DOM selectors plus an extraction, or a JSONPath.
sealed class _RuleBranch {
  const _RuleBranch();
}

/// A branch that reads the DOM: the default rules and `@css:` (matrix #1..#12).
final class _DomBranch extends _RuleBranch {
  const _DomBranch({required this.selectors, required this.extraction});

  /// The selector steps. Every branch of a candidate runs from the same scope.
  final List<_SelectorStep> selectors;

  /// The extraction segment of a value rule, or `''` for a list rule.
  final String extraction;
}

/// A branch that reads JSON: `@json:` and the bare `$.` / `$[` form (matrix #13).
final class _JsonBranch extends _RuleBranch {
  const _JsonBranch(this.path);

  /// The parsed JSONPath this branch applies to the scope.
  final JsonPath path;
}

/// A parse outcome: the value the parser produced, or why it was rejected.
sealed class _Parsed<T> {
  const _Parsed();
}

/// The parser accepted its input.
final class _ParsedValue<T> extends _Parsed<T> {
  const _ParsedValue(this.value);

  /// The parsed value.
  final T value;
}

/// The parser rejected its input.
///
/// A malformed rule is an expected outcome of untrusted book source input, so the
/// rejection is a value instead of a thrown error (C-ERR-1 / C-ERR-2).
final class _ParsedFailure<T> extends _Parsed<T> {
  const _ParsedFailure(this.rejection);

  /// Why the input cannot be evaluated.
  final _RuleRejection rejection;
}

/// Why a rule cannot be evaluated, in the shape [ParseFailure] needs.
final class _RuleRejection {
  const _RuleRejection({required this.kind, required this.rulePath});

  /// The failure kind `book-source.md` §7 assigns to this problem.
  final ParseFailureKind kind;

  /// The `rulePath` of the failure: a field path, or `unsupported:<syntax>`.
  final String rulePath;
}

/// Splits [text] at the top-level occurrences of the first separator of [separators]
/// that occurs, ignoring separators inside `[...]`, `(...)` or quotes.
///
/// Returns the parts and the separator that was used (`null` when none occurred, which
/// means a single part). Only that one separator is used for the rest of the text, the
/// way upstream's `splitRule` behaves (`book-source.md` §3.2).
({List<String> parts, String? separator}) _splitRule(
  String text,
  List<String> separators,
) {
  final String? separator = _firstSeparator(text, separators);
  if (separator == null) {
    return (parts: <String>[text], separator: null);
  }

  final List<String> parts = <String>[];
  final StringBuffer current = StringBuffer();
  var depth = 0;
  String? quote;
  var index = 0;

  while (index < text.length) {
    final String character = text[index];
    if (quote != null) {
      current.write(character);
      if (character == quote) {
        quote = null;
      }
      index++;
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
    } else if (character == '[' || character == '(') {
      depth++;
    } else if (character == ']' || character == ')') {
      depth--;
    } else if (depth == 0 && text.startsWith(separator, index)) {
      parts.add(current.toString());
      current.clear();
      index += separator.length;
      continue;
    }
    current.write(character);
    index++;
  }
  parts.add(current.toString());

  return (parts: parts, separator: separator);
}

/// Returns the first separator of [separators] that occurs outside brackets, parens and
/// quotes, or `null` when none does.
String? _firstSeparator(String text, List<String> separators) {
  var depth = 0;
  String? quote;

  for (var index = 0; index < text.length; index++) {
    final String character = text[index];
    if (quote != null) {
      if (character == quote) {
        quote = null;
      }
      continue;
    }
    switch (character) {
      case '"' || "'":
        quote = character;
      case '[' || '(':
        depth++;
      case ']' || ')':
        depth--;
      default:
        if (depth == 0) {
          for (final String separator in separators) {
            if (text.startsWith(separator, index)) {
              return separator;
            }
          }
        }
    }
  }

  return null;
}

/// The direct text-node data of [element] (upstream `textNodes` / `ownText` basis).
List<String> _ownTextNodes(Element element) => element.nodes
    .whereType<Text>()
    .map((Text node) => node.data)
    .toList(growable: false);

/// The direct text of [element], whitespace-collapsed the way upstream (jsoup)
/// normalises `ownText()`.
///
/// Matrix #3 compares against this form and matrix #8's `ownText` extracts it, so
/// both go through one definition instead of two that could drift apart.
String _ownTextOf(Element element) =>
    _collapseWhitespace(_ownTextNodes(element).join());

/// Collapses whitespace runs the way upstream (jsoup) normalises text.
///
/// `package:html` only concatenates text nodes, while upstream normalises them,
/// and rules depend on that form — `##` replacements match against single spaces.
String _collapseWhitespace(String text) =>
    text.replaceAll(_whitespace, ' ').trim();

/// Returns a copy of [element] without its `script` / `style` descendants.
///
/// Upstream drops them from the live DOM; copying keeps the engine free of side
/// effects on the caller's document (C-SRC-9). The element itself is never
/// stripped, because an extraction never starts at a `script` or `style` node.
Element _withoutScripts(Element element) {
  final Element copy = element.clone(true);
  for (final Element node in <Element>[
    ...cascadia.queryAll(copy, 'script'),
    ...cascadia.queryAll(copy, 'style'),
  ]) {
    node.remove();
  }

  return copy;
}

/// Applies the `##` replacements of a rule to every extracted value (matrix #9).
///
/// Four parts (`##match##replace###`) select upstream's `replaceFirst` form
/// (`AnalyzeRule.kt:497`).
List<String> _applyReplacement(
  List<String> values,
  List<String> replacementParts,
) {
  if (replacementParts.length < 2) {
    return values;
  }

  final String pattern = replacementParts[1];
  final String replacement = replacementParts.length > 2
      ? replacementParts[2]
      : '';
  final bool firstOnly = replacementParts.length > 3;

  return values
      .map(
        (String value) =>
            _replace(value, pattern, replacement, firstOnly: firstOnly),
      )
      .toList(growable: false);
}

/// Applies one `##` replacement, matching upstream (Java / Kotlin) semantics.
///
/// `firstOnly` is upstream's `##match##replace###` form, and it does **not** mean
/// "replace the first occurrence in the value": upstream takes the first **match**
/// and applies the replacement *inside it*, returning an empty string when nothing
/// matches, and returning the replacement as-is when the pattern cannot be compiled
/// (`AnalyzeRule.kt:497`). Matching that exactly matters more than the simpler
/// reading, because a real source using `###` must produce upstream's output.
String _replace(
  String value,
  String pattern,
  String replacement, {
  required bool firstOnly,
}) {
  final RegExp? regex = _compile(pattern);

  if (firstOnly) {
    return regex == null
        ? replacement
        : _replaceInsideFirstMatch(regex, value, replacement);
  }

  if (regex == null) {
    return value.replaceAll(pattern, replacement);
  }

  return value.replaceAllMapped(
    regex,
    (Match match) => _expand(match, replacement),
  );
}

/// Applies [replacement] inside the first match of [regex] in [value].
///
/// Returns an empty string when [value] does not match at all, which is upstream
/// behaviour for the `###` form.
String _replaceInsideFirstMatch(
  RegExp regex,
  String value,
  String replacement,
) {
  final String? matched = regex.firstMatch(value)?.group(0);

  return matched == null
      ? ''
      : matched.replaceFirstMapped(
          regex,
          (Match match) => _expand(match, replacement),
        );
}

/// Compiles [pattern], or returns `null` when it is not a valid regular
/// expression.
RegExp? _compile(String pattern) {
  try {
    return RegExp(pattern);
  } on FormatException {
    return null;
  }
}

/// Expands the `$1` / `${name}` group references of [template].
///
/// Dart's `replaceAll` writes `$1` literally, while upstream (Java / Kotlin)
/// substitutes the capture group and real book sources rely on that
/// (`##.*共(.*字).*##$1`), so the references are expanded here. A `\` escapes the
/// next character; a `$` that does not start a reference is kept as it is instead
/// of failing the whole rule.
String _expand(Match match, String template) {
  final StringBuffer buffer = StringBuffer();
  var index = 0;

  while (index < template.length) {
    final String character = template[index];

    if (character == r'\' && index + 1 < template.length) {
      buffer.write(template[index + 1]);
      index += 2;
      continue;
    }

    if (character == r'$') {
      final (String? reference, int length) = _referenceAt(template, index);
      if (reference != null) {
        final int? groupIndex = int.tryParse(reference);
        buffer.write(
          groupIndex == null
              ? _namedGroup(match, reference)
              : match.group(groupIndex) ?? '',
        );
        index += length;
        continue;
      }
    }

    buffer.write(character);
    index++;
  }

  return buffer.toString();
}

/// Reads the group reference that starts at the `$` in [template] at [start].
///
/// Returns the reference and how many characters it occupies (including the `$`),
/// or `(null, 0)` when the `$` does not start a reference.
(String?, int) _referenceAt(String template, int start) {
  final int begin = start + 1;

  if (begin < template.length && template[begin] == '{') {
    final int end = template.indexOf('}', begin);
    final String name = end < 0 ? '' : template.substring(begin + 1, end);

    return name.isEmpty ? (null, 0) : (name, end - start + 1);
  }

  var end = begin;
  while (end < template.length && _isDigit(template.codeUnitAt(end))) {
    end++;
  }

  return end == begin
      ? (null, 0)
      : (template.substring(begin, end), end - start);
}

/// Whether [codeUnit] is an ASCII digit.
bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// Returns the named capture group [name] of [match], or an empty string.
///
/// `Match` does not declare `namedGroup` — only [RegExpMatch] does — while
/// `replaceAllMapped` types its callback with the wider `Match`.
String _namedGroup(Match match, String name) =>
    match is RegExpMatch ? match.namedGroup(name) ?? '' : '';
