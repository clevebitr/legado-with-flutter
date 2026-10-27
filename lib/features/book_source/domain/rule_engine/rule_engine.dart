import 'dart:convert';

import 'package:cascadia/cascadia.dart' as cascadia;
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_lib.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
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
///
/// `@put:` / `@get:` / `{{` are gone from this list because matrix #15..#19 implements
/// them: they are handled before the rule is parsed at all (see the expansion step in
/// [RuleEngine]). A bare `{` is gone as well: `{$jsonpath}` is matrix #19, and a `{`
/// without a `$` is not any implemented syntax, so it degrades to a raw CSS selector like
/// every other unknown type (ADR-0032).
const List<String> _deferredFlags = <String>[
  '//',
  ':',
  '@@',
  '@xpath:',
  '@webjs',
  '<js>',
];

/// One `@put:{key:rule,key:rule}` flag of matrix #16.
///
/// Upstream's pattern is `@put:(\{[^}]+?\})` with `IGNORE_CASE`
/// (`AnalyzeRule.kt:944`), so the braces never nest and the flag is dropped from the rule
/// text before it is evaluated (`AnalyzeRule.kt:668-672`).
final RegExp _putFlag = RegExp(r'@put:\{([^{}]*)\}', caseSensitive: false);

/// The `@get:{key}` flag of matrix #16, lower-cased for a case-insensitive scan.
const String _getFlag = '@get:{';

/// How several matches of one **value** rule are joined (upstream `getString`).
///
/// `book-source.md` §6: a single-value field joins its matches with a newline, which is what makes
/// `result.split("\n")` work on an image source's `$.data[*].image` rule
/// (ADR-0069 G9).
const String _valueSeparator = '\n';

/// The trailing `.N` / `.-N` index a degraded segment may carry (matrix #28's dot form).
final RegExp _dotIndex = RegExp(r'^-?\d+$');

/// The `@put:` flag, lower-cased for a case-insensitive scan.
const String _putScanFlag = '@put:';

/// The opening brace of matrix #19's legacy JSONPath rule.
const String _jsonTemplateOpen = r'{$';

/// The literal a URL-rule chain replaces with what it produced so far (`@result`, upstream
/// `AnalyzeUrl.kt:166`).
const String _urlChainVariable = '@result';

/// The `rulePath` marker of a nested **list** rule that would need its own `@js:` job.
///
/// A nested list rule runs inside the job that asked for it, so a script segment there would have to
/// queue behind its own caller (ADR-0030 §决策 1/3). The top-level form is fine — a list rule's own
/// `@js:` is part of the same evaluation (matrix #14) — this marker is only for the nested shape.
const String _jsListMarker = 'unsupported:@js:list';

/// The URL variable that carries the search keyword (`book-source.md` §4).
///
/// It is the one variable a URL rule escapes, and the one a JSON body must receive verbatim.
const String _urlKeywordVariable = 'key';

/// How many nested `{{…}}` / `@put:` expansions one rule may trigger.
///
/// Upstream substitutes embedded rules through recursive `getString` calls with no bound
/// at all (`AnalyzeRule.kt:736-752`). A per-source variable can hold rule text
/// (`java.put`), so a self-referencing variable could otherwise make one field expand
/// forever; the bound turns that into a locatable failure instead of a hung parse
/// (C-SRC-4).
const int _maxExpansionDepth = 8;

/// The start of a `java.*` rule-evaluation call the host can inline (ADR-0037 §决策 3①).
const String _javaRuleCallPrefix = 'java.get';

/// One inlinable `java.getString('literal')`-shaped call: the verb, a quoted rule and an optional
/// `false` second argument.
///
/// Only a **string literal** first argument qualifies, and a call with a third argument does not
/// match at all — it stays in the script, where the binding refuses it by name (ADR-0037 §决策 6).
final RegExp _javaRuleCall = RegExp(
  r'''java\.(getString|getStringList|getElement|getElements)\(\s*(['"])((?:\\.|(?!\2).)*)\2\s*(?:,\s*false\s*)?\)''',
);

/// The `@@` default-rule flag of matrix #15.
///
/// Upstream strips it from the front of a rule and keeps the default mode
/// (`AnalyzeRule.kt:612-615`), which is what makes `{{@@class.a@text}}` mean “evaluate a
/// default rule here” inside a context whose default is JavaScript.
const String _defaultRuleFlag = '@@';

/// The `@js:` flag of matrix #14, lower-cased for a case-insensitive compare.
///
/// It is **terminal**: upstream's `AppPattern.JS_PATTERN` is `@js:([\w\W]*)`, i.e. greedy
/// to the end of the rule, so everything after the flag is the script and a `&&` or `||`
/// inside the script stays part of it instead of being read as a connector.
const String _jsFlag = '@js:';

/// One `<js>…</js>` block or a trailing `@js:…` script (matrix #31 / #14).
///
/// Upstream splits a rule on this pattern **before** it looks at selectors
/// (`AppPattern.JS_PATTERN`, `AnalyzeRule.splitSourceRule`), which is why `<js>` may sit in the
/// middle of a rule and why the text after it is one more rule read against the script's result.
final RegExp _jsSegmentPattern = RegExp(
  r'<js>([\w\W]*?)</js>|@js:([\w\W]*)',
  caseSensitive: false,
);

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
/// | #15 | the `@@` default-rule flag, including inside a `{{…}}` template |
/// | #16 | `@put:{key:rule}` and `@get:{key}` over the source's variables |
/// | #17 | `java.put` / `java.get` inside a script (the same store) |
/// | #18 | `{{…}}` as a JS template, or as a nested rule when the head is a rule flag |
/// | #19 | `{$jsonpath}` inside a JSON rule |
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
  /// Creates an engine that reports rejected rules through `logger`, runs `@js:` rules
  /// on `jsBridge` and reads / writes the rules' variables in `variables`.
  ///
  /// The bridge is the only door to JavaScript (C-SRC-2), which is why the engine takes it
  /// as a collaborator instead of the engine library: a unit test passes a fake
  /// (`docs/dev/testing.md` §4) and `domain/` never imports `flutter_qjs_next`.
  ///
  /// [JsVariableStore] is the host side of the `@put:` / `@get:` / `java.*` contract
  /// (`book-source.md` §6). The engine reads it for `@get:` and `{{name}}`, writes it for
  /// `@put:`, and the bridge applies what a script wrote through `java.put` — one store,
  /// two ends (ADR-0034 §决策 1).
  ///
  /// [sourceVariables] is the **persisted** map behind `source.getVariable` / `setVariable`
  /// (ADR-0076 §决策 1). It defaults to an unwired store, which behaves exactly like a source that
  /// never wrote a variable — which is what a unit test wants by default.
  ///
  /// [jsLib] resolves a source's own JavaScript library before every job it runs (ADR-0078 S1).
  /// The default store handles plain-JavaScript libraries only and reports a URL-shaped one as
  /// unsupported; the app wires one that can download.
  RuleEngine({
    required this._logger,
    required this._jsBridge,
    required this._variables,
    SourceVariableStore? sourceVariables,
    JsLibStore? jsLib,
  }) : _sourceVariables = sourceVariables ?? SourceVariableStore(),
       _jsLib = jsLib ?? JsLibStore();

  final AppLogger _logger;
  final JsBridge _jsBridge;
  final JsVariableStore _variables;
  final SourceVariableStore _sourceVariables;
  final JsLibStore _jsLib;

  /// Evaluates one **whole-field** JavaScript expression and returns its raw value.
  ///
  /// It exists for `exploreUrl` (`book-source.md` §4.2, ADR-0035 §决策 4): the field may be a
  /// single JS expression whose result is a JSON **array** or a separated string, and the array
  /// form has to survive as a value. Going through [extractFirst] would not do: that path turns a
  /// list into one value per element (matrix #8), which is right for rules and wrong here.
  ///
  /// The sandbox sees the same surface as any other `@js:` rule ([JsJob]), with the field's own
  /// bindings: [context] carries `baseUrl` / `page` / `source` (`page` is 1 and `baseUrl` is the
  /// book source URL for this field, ADR-0035 §决策 4), `result` is `null` because no page has been
  /// fetched, and **no `key`** is bound. `parse.*` is not offered: a whole-field expression has no
  /// page scope, so a rule using it gets `js:parse-scope` instead of an empty answer (C-SRC-4).
  ///
  /// The variables of `@put:` / `@get:` / `java.*` are the source's, exactly as everywhere else
  /// (ADR-0034). A script error, a timeout or a quota overrun come back as
  /// [ParseFailureKind.parseFailed] with the bridge's marker, never as a thrown exception.
  ///
  /// [response] replaces the `result` binding with a response object. It is how a `loginCheckJs`
  /// interceptor sees the page it may replace (`book-source.md` §6, ADR-0068 addendum): upstream
  /// hands that script a `StrResponse`, not the page text.
  ///
  /// [result] is the ordinary `result` binding of a script that follows some text — the response
  /// body for a `bodyJs` URL option (ADR-0068 §决策 7). [response] wins when both are passed.
  Future<ParseResult<Object?>> evaluateJs(
    String script, {
    required String rulePath,
    required JsPageContext context,
    Object? result,
    JsResponseView? response,
  }) async {
    if (script.trim().isEmpty) {
      return const ParseSuccess<Object?>(null);
    }

    final ParseResult<String?> lib = await _jsLibOf(context, rulePath);
    switch (lib) {
      case ParseFailure<String?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<Object?>(kind: kind, rulePath: rulePath);
      case ParseSuccess<String?>(:final String? data):
        return _jsBridge.evaluate(
          JsJob(
            script: script,
            rulePath: rulePath,
            baseUrl: context.baseUrl,
            page: context.page,
            source: context.source,
            sourceHeaders: context.headers,
            variables: _variables.snapshot(context.source.url),
            jsLib: data,
            bookName: context.bookName,
            chapterTitle: context.chapterTitle,
            book: context.book,
            src: context.src,
            chapter: context.chapter,
            nextChapterUrl: context.nextChapterUrl,
            fromBookInfo: context.fromBookInfo,
            result: result,
            response: response,
          ),
        );
    }
  }

  /// The source's `jsLib` as runnable JavaScript, or `null` when it declares none
  /// (ADR-0078 S1).
  ///
  /// Resolution happens **before** the job: the worker is an isolate and cannot fetch, and a
  /// library that cannot be resolved must fail the rule with [jsLibMarker] instead of running it
  /// without its helpers (C-SRC-4).
  Future<ParseResult<String?>> _jsLibOf(JsPageContext context, String field) =>
      _jsLib.resolve(
        sourceUrl: context.source.url,
        jsLib: context.source.jsLib,
        rulePath: field,
      );

  /// Rewrites chapter names with a `tocRule.formatJs` rule (ADR-0078 S2).
  ///
  /// One job for the whole list, because upstream evaluates the script once per chapter **inside
  /// one scope**: `index` is rebound each round while `gInt` keeps its value across rounds
  /// (`BookChapterList.kt:141-163`). A script that throws leaves that chapter's title alone
  /// (upstream `runCatching(...).onFailure`), so the answer is always the same length as
  /// [chapters]: a string replaces the title, `null` keeps it.
  Future<ParseResult<List<String?>>> formatTitles({
    required String script,
    required List<JsChapterInfo> chapters,
    required JsPageContext context,
    required String rulePath,
  }) async {
    if (script.trim().isEmpty || chapters.isEmpty) {
      return const ParseSuccess<List<String?>>(<String?>[]);
    }

    final ParseResult<String?> lib = await _jsLibOf(context, rulePath);
    switch (lib) {
      case ParseFailure<String?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<List<String?>>(kind: kind, rulePath: rulePath);
      case ParseSuccess<String?>(:final String? data):
        final ParseResult<Object?> formatted = await _jsBridge.evaluate(
          JsJob(
            script: script,
            rulePath: rulePath,
            baseUrl: context.baseUrl,
            page: context.page,
            source: context.source,
            sourceHeaders: context.headers,
            variables: _variables.snapshot(context.source.url),
            sourceVariables: _sourceVariables.snapshot(context.source.url),
            jsLib: data,
            titleFormatChapters: chapters,
            bookName: context.bookName,
            chapterTitle: context.chapterTitle,
            book: context.book,
          ),
        );

        return switch (formatted) {
          ParseFailure<Object?>(
            :final ParseFailureKind kind,
            rulePath: final String failedAt,
          ) =>
            failureAt<List<String?>>(kind: kind, rulePath: failedAt),
          ParseSuccess<Object?>(:final Object? data) =>
            ParseSuccess<List<String?>>(<String?>[
              if (data is List)
                for (final Object? title in data)
                  if (title is String) title else null,
            ]),
        };
    }
  }

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
  }) => _selectAllRule(rule, scope, rulePath: rulePath, depth: 0);

  /// [selectAll] with the `{{…}}` / `@put:` expansion depth of the current recursion.
  ///
  /// A list rule expands like a value rule (upstream reads both through one `SourceRule`,
  /// `AnalyzeRule.kt:380-430`), but it does **not** switch to “the substituted text is the
  /// value”: a list rule has to produce elements. A rule that builds its selector through
  /// JS (`{{java.get('listRule')}}`) therefore still works — a registered difference from
  /// upstream, whose `Mode.Regex` branch returns the text there (`book-source.md` §3, #18).
  Future<ParseResult<List<RuleScope>>> _selectAllRule(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required int depth,
  }) async {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<RuleScope>>(<RuleScope>[]);
    }

    // 矩阵 #14 / #31 的列表形态：**任一段**是 JS 段（`<js>` 或 `@js:`，包括
    // `class.list@tag.li@js:result` 这种尾部写法）就走段链解释器——上游 `getElements` 的段循环
    // 里，`Mode.Js` 分支同样是 `evalJS`，它的结果成为下一段的输入（`AnalyzeRule.kt:435-440`）。
    //
    // 脚本看到的是上一段的**条目内容**（元素的 `outerHtml`、JSON 值），不是 jsoup 元素：沙箱里
    // 没有 DOM 句柄（§6），所以 `attr()` / `text()` 这类写法仍然不成立，差异登记在 §3。
    if (_jsSegmentsOf(rule).any((_RuleSegment segment) => segment.isScript)) {
      return _selectAllSegments(rule, scope, rulePath: rulePath, depth: depth);
    }

    final _Parsed<_Expansion> expansion = await _expandRule(
      rule,
      scope,
      rulePath: rulePath,
      allowJs: true,
      depth: depth,
    );
    final String expanded;
    final bool substituted;
    switch (expansion) {
      case _ParsedFailure<_Expansion>(:final _RuleRejection rejection):
        return _fail<List<RuleScope>>(rejection, field: rulePath);
      case _ParsedValue<_Expansion>(:final _Expansion value):
        expanded = value.text;
        substituted = value.substituted;
    }

    if (expanded.trim().isEmpty && !substituted) {
      // 只剩下 `@put:{…}` 的列表规则：没有选择器可跑，也没有元素产出。
      return const ParseSuccess<List<RuleScope>>(<RuleScope>[]);
    }

    final _ParsedRule parsed = _parse(expanded);
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

  /// Evaluates a **list** rule that mixes `<js>…</js>` / `@js:` with selectors
  /// (matrix #14 / #31, upstream `AnalyzeRule.getElements`).
  ///
  /// The chain is the value chain, but the intermediate value is a **list of scopes**: a
  /// segment's scopes are what the next one reads, and a script receives them as `result`
  /// (the element list, or the page body when it comes first). What a script returns becomes
  /// scopes on the way back:
  ///
  /// * a JSON object / array / scalar → a [JsonScope], so `$.name` works on it;
  /// * a string → a **DOM** scope parsed from it, which is how upstream reads an HTML
  ///   fragment a script produced (`AnalyzeByJSoup(String)` parses the text).
  Future<ParseResult<List<RuleScope>>> _selectAllSegments(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required int depth,
  }) async {
    List<RuleScope> scopes = const <RuleScope>[];

    for (final _RuleSegment segment in _jsSegmentsOf(rule)) {
      final ParseResult<Object?> scripted;
      if (segment.isScript) {
        scripted = await _runScript(
          segment.text,
          scopes.isEmpty ? _resultOf(scope) : _resultOfScopes(scopes),
          scope,
          field: rulePath,
          allowJs: true,
        );
        switch (scripted) {
          case ParseFailure<Object?>(
            :final ParseFailureKind kind,
            rulePath: final String failedAt,
          ):
            return failureAt<List<RuleScope>>(kind: kind, rulePath: failedAt);
          case ParseSuccess<Object?>(:final Object? data):
            scopes = _scopesOfScriptResult(
              data,
              jsContext: _jsContextOf(scope),
            );
        }
        continue;
      }

      // 选择器段读的是**上一段产出的条目**：一段脚本产出 N 个条目时，选择器在每一个条目上
      // 各跑一次、结果按条目顺序拼接（上游把整个列表交给 `AnalyzeByJSoup` 会直接失败，而
      // 「逐条目读」是唯一有意义的口径）。没有上一段时读整页。
      final List<RuleScope> inputs = scopes.isEmpty
          ? <RuleScope>[scope]
          : scopes;
      final List<RuleScope> matchedScopes = <RuleScope>[];
      for (final RuleScope input in inputs) {
        final ParseResult<List<RuleScope>> matched = await _selectAllRule(
          segment.text,
          input,
          rulePath: rulePath,
          depth: depth,
        );
        switch (matched) {
          case ParseFailure<List<RuleScope>>():
            return matched;
          case ParseSuccess<List<RuleScope>>(:final List<RuleScope> data):
            matchedScopes.addAll(data);
        }
      }
      scopes = matchedScopes;
    }

    return ParseSuccess<List<RuleScope>>(scopes);
  }

  /// The `result` a list-rule script sees: its scopes' contents (§6).
  ///
  /// An element becomes its `outerHtml` and a JSON item its value, which is exactly what
  /// upstream's `Elements` / `ArrayList` bindings turn into on the JavaScript side.
  Object? _resultOfScopes(List<RuleScope> scopes) =>
      scopes.map(_resultOf).toList(growable: false);

  /// The scopes a list-rule script's return value contributes.
  List<RuleScope> _scopesOfScriptResult(
    Object? value, {
    required JsPageContext? jsContext,
  }) {
    if (value == null) {
      return const <RuleScope>[];
    }
    final Iterable<Object?> items = value is List<Object?>
        ? value
        : <Object?>[value];

    return <RuleScope>[
      for (final Object? item in items)
        if (item != null)
          switch (item) {
            final String text => RuleScope.dom(
              html_parser.parse(text),
              jsContext: jsContext,
            ),
            _ => RuleScope.json(item, jsContext: jsContext),
          },
    ];
  }

  /// Runs every branch of a candidate from [scope] and merges the matches.
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
          // 列表规则只看其中的 JSONPath：字面文本不贡献元素（矩阵 #19 的「只能用 JSONPath」）。
          for (final _JsonPathPiece piece in json.paths)
            for (final JsonPathMatch match in piece.path.read(value))
              ..._jsonScopesOf(match.value, jsContext: _jsContextOf(scope)),
        ]),
    },
  };

  /// The scopes one JSON match contributes to a **list** rule (matrix #13).
  ///
  /// A match that is a **list** contributes its elements: upstream reads the path as an
  /// `ArrayList<Any>` (`AnalyzeByJSonPath.kt:137`, `getList`), so a `bookList` of
  /// `$.info.Datas` yields one item per book rather than one item for the whole array. Real
  /// JSON API sources are written that way — the `docs/dev/roadmap.md` 3.7 regression found it on 猫耳FM,
  /// where `$.info.Datas` plus per-item `$.name` rules produced an empty book list before.
  Iterable<RuleScope> _jsonScopesOf(
    Object? value, {
    required JsPageContext jsContext,
  }) => switch (value) {
    final List<Object?> list => <RuleScope>[
      for (final Object? item in list)
        RuleScope.json(item, jsContext: jsContext),
    ],
    _ => <RuleScope>[RuleScope.json(value, jsContext: jsContext)],
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

  /// Returns **every** value of [rule] joined with `\n`, i.e. upstream `getString`.
  ///
  /// It exists for fields upstream reads as one string even when the rule matches several
  /// elements: `ruleContent.content` is read with `getString` for **every** book type, so an image
  /// source whose rule is `$.data[*].image` plus a `@js:` tail gets one newline-joined string as
  /// `result` — not a list (ADR-0069 G9). Taking the first match instead would drop pages.
  ///
  /// A rejected rule stays a failure; an empty match answers an empty string.
  Future<ParseResult<String>> extractJoined(
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
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<String>(data.join(_valueSeparator)),
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
    bool allowJs = true,
    int depth = 0,
    Object? chainedResult,
  }) async {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<String>>(<String>[]);
    }

    // 矩阵 #31：`<js>…</js>` 可以出现在规则中间，上游把它切成「默认段 / JS 段」依次求值，
    // 上一段的产出就是下一段的 `result`（`AnalyzeRule.getString` 的链式循环）。只有真的
    // 出现 `<js>` 时才走这条链，尾部 `@js:` 的既有语义保持逐字节不变。
    if (_hasJsBlock(rule)) {
      return _evaluateSegments(
        rule,
        scope,
        rulePath: rulePath,
        single: single,
        allowJs: allowJs,
        depth: depth,
      );
    }

    final _Parsed<_Expansion> expansion = await _expandRule(
      rule,
      scope,
      rulePath: rulePath,
      allowJs: allowJs,
      depth: depth,
      chainedResult: chainedResult,
    );
    if (expansion case _ParsedFailure<_Expansion>(
      :final _RuleRejection rejection,
    )) {
      return _fail<List<String>>(rejection, field: rulePath);
    }
    final _Expansion expanded = (expansion as _ParsedValue<_Expansion>).value;
    if (expanded.text.trim().isEmpty && !expanded.substituted) {
      // 规则只剩下 `@put:{…}`（矩阵 #16）：写入已经发生，这条规则没有选择器可跑。
      // 上游同样把这种规则读成空值（`AnalyzeRule.getString` 对空规则直接返回 ""）。
      return const ParseSuccess<List<String>>(<String>[]);
    }
    if (expanded.substituted) {
      // 上游把带 `{{}}` / `@get:` 的规则切成 **Regex 模式**（`AnalyzeRule.kt:674-680`），
      // 而 `AnalyzeByRegex` 不拿它当选择器读：替换后的整段文本就是这一条规则的值。
      // 这也是 `{{@@class.a@text}}` / `“地址/{{@get:{x}}}”` 这类写法能工作的原因。
      final _ParsedRule substituted = _parse(expanded.text);
      if (substituted.body.isEmpty) {
        return const ParseSuccess<List<String>>(<String>[]);
      }

      return ParseSuccess<List<String>>(
        _finish(<String>[substituted.body], substituted),
      );
    }

    final _ParsedRule parsed = _parse(expanded.text);
    final List<String> merged;
    if (parsed.isBareJs) {
      // `@js:` 独立成规则：没有选择器要跑，`result` 就是这一层的内容（§6 的 result 绑定：
      // 页面给正文，JSON 条目给条目对象）。
      merged = const <String>[];
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
      // 独立 `@js:` 的 `result` 是这一层的内容（§6）；有选择器时才是上游 `getString` /
      // `getStringList` 的形态：单值字段给字符串，多值字段给列表（§4.1 的 URL 数组靠它）。
      // 上游 `getString` 把多个匹配用 `\n` 拼成一个字符串再交给脚本
      // （`AnalyzeRule.getString` → `joinToString("\n")`），所以 `result.split("\n")`
      // 这类写法在单值字段上是成立的；只给第一个匹配会让这类正文规则直接
      // `not a function`（ADR-0069 G9）。
      parsed.isBareJs
          ? _resultOf(scope)
          : (single
                ? (merged.isEmpty ? null : merged.join(_valueSeparator))
                : merged),
      scope,
      field: rulePath,
      allowJs: allowJs,
    );

    return switch (evaluated) {
      ParseFailure<List<String>>() => evaluated,
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<List<String>>(_finish(data, parsed)),
    };
  }

  /// Runs one terminal `@js:` script on [result] (matrix #14).
  ///
  /// The sandbox receives it as `result`, plus the page context the scope carries
  /// ([JsPageContext]) and the `parse.*` evaluator for that page ([_parseEvaluatorFor]). What
  /// it returns becomes the rule's value: a String is one value, a List is many — which is how
  /// `nextTocUrl` gets an array, and `null` yields no value (matrix #8's “no value” for an
  /// empty extract).
  ///
  /// A timeout or a JS exception comes back as [ParseFailureKind.parseFailed] with the
  /// bridge's `rulePath` marker (§6); a `parse.*` boundary comes back with the boundary's own
  /// marker. Nothing is swallowed (C-SRC-4).
  Future<ParseResult<List<String>>> _runJs(
    String script,
    Object? result,
    RuleScope scope, {
    required String field,
    required bool allowJs,
  }) async {
    final ParseResult<Object?> evaluated = await _runScript(
      script,
      result,
      scope,
      field: field,
      allowJs: allowJs,
    );

    return switch (evaluated) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        rulePath: final String rulePath,
      ) =>
        failureAt<List<String>>(kind: kind, rulePath: rulePath),
      ParseSuccess<Object?>(:final Object? data) => ParseSuccess<List<String>>(
        _jsValues(data),
      ),
    };
  }

  /// Runs one `@js:` / `<js>` script and answers its **raw** value
  /// (`_runJs` is the value-rule wrapper that turns it into strings).
  ///
  /// Kept apart because a **list** rule needs the value's shape: an array of objects is a
  /// list of JSON scopes, while the value-rule lane reads it as strings (§6).
  Future<ParseResult<Object?>> _runScript(
    String script,
    Object? result,
    RuleScope scope, {
    required String field,
    required bool allowJs,
  }) async {
    if (!allowJs) {
      // 嵌套求值（`parse.*` 的递推，或 `{{}}` 里的 JS）不能碰沙箱：单 worker 正在跑的就是
      // 发起它的那个 job（ADR-0030 §决策 1/3），嵌套的 evaluate 只会排在自己的队后面。
      return ParseFailure<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$field:$jsParseRecursionMarker',
      );
    }

    // ADR-0037 §决策 3①：字面量首参的 `java.getString('规则')` 族在构造 job **之前**就地求值
    // 并内联——引擎就在宿主上，而且此刻还没有 job 在飞。这让表达式里的嵌套保持同步语义
    // （`java.timeFormat(java.getString('$.x')*1000)`）。
    final ParseResult<String> inlined = await _inlineLiteralJavaRules(
      script,
      scope,
      field: field,
    );
    final String scriptText;
    switch (inlined) {
      case ParseSuccess<String>(:final String data):
        scriptText = data;
      case ParseFailure<String>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ):
        return failureAt<Object?>(kind: kind, rulePath: rulePath);
    }

    final JsPageContext context = _jsContextOf(scope);
    // 每源变量是持久表：首个 job 前读一次，之后走内存（ADR-0076 §决策 1）。
    await _sourceVariables.ensureLoaded(context.source.url);
    // 库脚本先解析（可能要下载），失败就是这条规则的失败（ADR-0078 S1）。
    final ParseResult<String?> lib = await _jsLibOf(context, field);
    if (lib case ParseFailure<String?>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<Object?>(kind: kind, rulePath: rulePath);
    }
    final ParseResult<Object?> evaluated = await _jsBridge.evaluate(
      JsJob(
        script: scriptText,
        rulePath: field,
        baseUrl: context.baseUrl,
        page: context.page,
        source: context.source,
        result: result,
        sourceHeaders: context.headers,
        parseEvaluator: _parseEvaluatorFor(scope, field: field),
        variables: _variables.snapshot(context.source.url),
        sourceVariables: _sourceVariables.snapshot(context.source.url),
        jsLib: switch (lib) {
          ParseSuccess<String?>(:final String? data) => data,
          // 上面已经返回；这里给编译器一个不可能是别的值的分支。
          ParseFailure<String?>() => null,
        },
        bookName: context.bookName,
        chapterTitle: context.chapterTitle,
        book: context.book,
        src: context.src,
        chapter: context.chapter,
        nextChapterUrl: context.nextChapterUrl,
        fromBookInfo: context.fromBookInfo,
      ),
    );

    return evaluated;
  }

  /// Whether [rule] carries a `<js>…</js>` block (matrix #31).
  ///
  /// A trailing `@js:` is **not** one: it keeps its own lane, so nothing about the
  /// matrix #14 path changes when a rule does not use the newer wrapper.
  bool _hasJsBlock(String rule) => rule.toLowerCase().contains('<js>');

  /// Splits [rule] on `<js>…</js>` / `@js:…` into the segments upstream evaluates in turn.
  ///
  /// The pattern mirrors upstream's `AppPattern.JS_PATTERN`: `<js>` blocks do not nest and a
  /// `@js:` runs to the end of the rule. Empty text between two adjacent scripts is dropped
  /// (upstream trims each piece before keeping it).
  List<_RuleSegment> _jsSegmentsOf(String rule) {
    final List<_RuleSegment> segments = <_RuleSegment>[];
    var start = 0;
    for (final RegExpMatch match in _jsSegmentPattern.allMatches(rule)) {
      if (match.start > start) {
        final String text = rule.substring(start, match.start).trim();
        if (text.isNotEmpty) {
          segments.add(_RuleSegment(text, isScript: false));
        }
      }
      final String? block = match.group(1);
      final String script = (block ?? match.group(2) ?? '').trim();
      if (script.isNotEmpty) {
        segments.add(_RuleSegment(script, isScript: true));
      }
      start = match.end;
    }
    if (start < rule.length) {
      final String text = rule.substring(start).trim();
      if (text.isNotEmpty) {
        segments.add(_RuleSegment(text, isScript: false));
      }
    }

    return segments;
  }

  /// Evaluates a rule that mixes `<js>…</js>` with selectors (matrix #31).
  ///
  /// This is upstream's chaining loop (`AnalyzeRule.getString` / `getStringList`): the first
  /// segment reads the **page**, every later one reads the previous segment's value as
  /// `result` — and a script that answers a whole document becomes the page the next selector
  /// reads (see [_chainedPageOf]), which is how a rule replaces a shell page before reading it.
  /// That is also what makes `<js>java.put(…)</js>https://…/{{result}}.html` produce a
  /// URL: the script's value becomes `{{result}}` in the text that follows.
  ///
  /// A failing segment fails the whole rule (C-SRC-4); a script is subject to the same
  /// sandbox boundaries as any other `@js:` (`allowJs`, `js:parse-recursion`).
  Future<ParseResult<List<String>>> _evaluateSegments(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required bool single,
    required bool allowJs,
    required int depth,
  }) async {
    List<String> values = const <String>[];
    var hasResult = false;
    // 脚本段可能把整页换掉（过盾后重取的真实页面）：下一段选择器要读它，而不是原页面。
    var pageScope = scope;

    for (final _RuleSegment segment in _jsSegmentsOf(rule)) {
      final Object? previous = hasResult
          ? (single
                ? (values.isEmpty ? null : values.join(_valueSeparator))
                : values)
          : _resultOf(pageScope);
      final ParseResult<List<String>> evaluated;
      if (segment.isScript) {
        // `<js>…</js>` 里的 `{{…}}` / `@get:` 同样在脚本执行前展开（上游 makeUpRule 对
        // 所有规则段一视同仁；脚本里的 `result` 绑定仍是上一段的值）。
        final _Parsed<_Expansion> expanded = await _expandText(
          segment.text,
          scope,
          rulePath: rulePath,
          allowJs: allowJs,
          depth: depth,
          chainedResult: previous,
        );
        if (expanded case _ParsedFailure<_Expansion>(
          :final _RuleRejection rejection,
        )) {
          return _fail<List<String>>(rejection, field: rulePath);
        }
        evaluated = await _runJs(
          (expanded as _ParsedValue<_Expansion>).value.text,
          previous,
          scope,
          field: rulePath,
          allowJs: allowJs,
        );
      } else {
        evaluated = await _evaluate(
          segment.text,
          pageScope,
          rulePath: rulePath,
          single: single,
          allowJs: allowJs,
          depth: depth,
          chainedResult: previous,
        );
      }
      switch (evaluated) {
        case ParseFailure<List<String>>():
          return evaluated;
        case ParseSuccess<List<String>>(:final List<String> data):
          values = data;
      }
      hasResult = true;
      if (segment.isScript) {
        pageScope = _chainedPageOf(values, pageScope);
      }
    }

    return ParseSuccess<List<String>>(values);
  }

  /// The page a selector segment after `<js>…</js>` reads.
  ///
  /// 上游 `AnalyzeRule.getString` 的链式循环把上一段的产出当成新的 content 交给
  /// `AnalyzeByJSoup`：脚本换掉的页面（`java.startBrowserAwait` / 过盾后重取的真实页面）
  /// 就是下一段选择器要读的正文。只有长得像标记的值才重建 scope——一个普通字符串（URL、
  /// 章节名）留在原页面上，语义与今天的完全一致，也不白解析一次 HTML。
  RuleScope _chainedPageOf(List<String> values, RuleScope origin) {
    final String text = values.join(_valueSeparator);
    if (!_looksLikeMarkup(text)) {
      return origin;
    }

    return RuleScope.dom(
      html_parser.parse(text),
      body: text,
      jsContext: _jsContextOf(origin),
    );
  }

  /// Whether a value carries an HTML tag (`<div`, `</p`, or an opening comment).
  static final RegExp _markupPattern = RegExp(r'<[a-zA-Z!/]');

  /// Whether a value is a document rather than a plain value (URL, chapter name).
  static bool _looksLikeMarkup(String text) =>
      text.length > 3 && _markupPattern.hasMatch(text);

  /// The `result` binding a script sees on [scope].
  ///
  /// Upstream hands `evalJS` the **content**: the page body (a String) for a fetched page, but
  /// the decoded **object** for a JSON item — which is why `@js:result.Name` works on a
  /// `bookList` entry (b7, `book-source.md` §6). A [JsonScope] therefore answers its value, and
  /// a [DomScope] its body text.
  Object? _resultOf(RuleScope scope) => switch (scope) {
    JsonScope(:final Object? value) => value,
    DomScope(:final String? body, :final Node node) =>
      body ?? (node is Element ? node.outerHtml : (node.text ?? '')),
  };

  /// Inlines every `java.getString('literal')`-shaped call of [script] with its value.
  ///
  /// This is the synchronous half of ADR-0037 §决策 3: upstream evaluates those rules inside the
  /// script, and 395 real calls (359 of `getString` alone) sit **inside expressions**
  /// (`java.timeFormat(java.getString('$.x')*1000)`), where a Promise would be a type error. The
  /// host can answer them before the worker ever sees the script, so it does: each call whose
  /// first argument is a **string literal** is evaluated against this scope and replaced by its
  /// JSON form, which leaves the script without the call at all.
  ///
  /// A call that cannot take this path stays in the script and reaches the sandbox, where the
  /// binding answers a Promise through the same evaluation path; a Promise inside an expression
  /// then fails loudly as `js:error` rather than silently producing the wrong value (C-SRC-4).
  ///
  /// Three rules keep the two paths from disagreeing:
  ///
  /// * a literal whose **inner rule needs the sandbox itself** (`@js:`, `{{…}}`, `@put:`, `@get:`,
  ///   `<js>`) is skipped here — inlining it would run a nested job before this one, and the
  ///   asynchronous path refuses it through the existing `js:parse-recursion` boundary instead;
  /// * a failing inner rule fails the whole rule, because half a script with a failed lookup would
  ///   be a silently different value;
  /// * the second argument is only accepted as `false`, which is what upstream's
  ///   `unescape = false` means and what this repository does anyway (ADR-0037 §决策 6).
  Future<ParseResult<String>> _inlineLiteralJavaRules(
    String script,
    RuleScope scope, {
    required String field,
  }) async {
    if (!script.contains(_javaRuleCallPrefix)) {
      return ParseSuccess<String>(script);
    }

    // 从后往前替换：前面的 match 下标不会因后面的替换而失效。
    final List<RegExpMatch> matches = _javaRuleCall
        .allMatches(script)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    String inlined = script;

    for (final RegExpMatch match in matches) {
      final String? rule = match.group(3);
      if (rule == null || rule.isEmpty || _needsSandbox(rule)) {
        continue;
      }

      final String verb = match.group(1) ?? '';
      // `java.getStringList` 求的是**值**（含提取段，`@css:.box img@src` 要 URL 列表）；
      // `getElements` / `getElement` 要元素文档（ADR-0037 §决策 3）。两者不能混。
      final bool wantsValues = verb == 'getStringList';
      final bool wantsElements = verb == 'getElements';
      // `getElement` 是**单值**形态（上游拿一个元素），异步路径同样只答第一个（ADR-0037 §决策 3）。
      final bool wantsDoc = verb == 'getElement';
      final ParseResult<List<Object?>> values = wantsValues
          ? switch (await _evaluate(
              rule,
              scope,
              rulePath: field,
              single: false,
              depth: 1,
            )) {
              ParseFailure<List<String>>(
                :final ParseFailureKind kind,
                :final String rulePath,
              ) =>
                failureAt<List<Object?>>(kind: kind, rulePath: rulePath),
              ParseSuccess<List<String>>(:final List<String> data) =>
                ParseSuccess<List<Object?>>(<Object?>[...data]),
            }
          : wantsElements || wantsDoc
          ? await _selectAllValues(rule, scope, field: field)
          : await _evaluate(
              rule,
              scope,
              rulePath: field,
              single: true,
              depth: 1,
            );
      switch (values) {
        case ParseFailure<List<Object?>>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          return failureAt<String>(kind: kind, rulePath: rulePath);
        case ParseSuccess<List<Object?>>(:final List<Object?> data):
          inlined = inlined.replaceRange(match.start, match.end, switch ((
            wantsValues || wantsElements,
            wantsDoc,
          )) {
            (true, _) => jsonEncode(data),
            // 单文档形态无匹配时与异步路径一致地给 `null`。
            (_, true) => jsonEncode(data.isEmpty ? null : data.first),
            // `getString`：多匹配用换行拼接（上游 `AnalyzeRule.getString`），无匹配给空串
            // ——异步路径（`parse.getString`）就是这个形状（ADR-0069 G9）。
            _ => jsonEncode(data.join(_valueSeparator)),
          });
      }
    }

    return ParseSuccess<String>(inlined);
  }

  /// Evaluates one nested **list** rule into the values `getStringList` / `getElements` answer.
  ///
  /// It reads the matches the way the sandbox's own `parse.getElements` does — an element becomes
  /// its `outerHtml`, a JSON match **its value** — a JSON match carries numbers, booleans and
  /// objects, and `book-source.md` §6 keeps them typed — so the inlined value and the
  /// asynchronous one agree (ADR-0037 §决策 3). Stringifying here would hand `"7"` to a script
  /// where the asynchronous path hands `7`.
  Future<ParseResult<List<Object?>>> _selectAllValues(
    String rule,
    RuleScope scope, {
    required String field,
  }) async => switch (await selectAll(rule, scope, rulePath: field)) {
    ParseFailure<List<RuleScope>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ) =>
      failureAt<List<Object?>>(kind: kind, rulePath: rulePath),
    ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
      ParseSuccess<List<Object?>>(<Object?>[
        for (final RuleScope match in data) _jsDocOf(match),
      ]),
  };

  /// Whether [rule] needs the sandbox (or the rule variables), i.e. cannot be inlined.
  bool _needsSandbox(String rule) =>
      rule.contains(_jsFlag) ||
      rule.contains('{{') ||
      rule.contains(_putScanFlag) ||
      rule.contains(_getFlag) ||
      rule.toLowerCase().contains('<js>');

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

  /// Applies matrix #15..#19 to [rule] before it is parsed as a selector rule.
  ///
  /// Upstream substitutes embedded rules and `@get:` flags into the rule **text** and only
  /// then reads the result (`AnalyzeRule.SourceRule.init` / `makeUpRule`,
  /// `AnalyzeRule.kt:666-760`), which is why every branch of a candidate, a list rule and a
  /// value rule all go through here.
  ///
  /// A terminal `@js:` script is **not** expanded: `@js:` swallows the rest of the rule
  /// (matrix #14), so a `{{…}}` inside the script belongs to the script.
  ///
  /// Only a substitution **before the first `##`** flips [\_Expansion.substituted]: upstream
  /// switches to its regex mode exactly when the first `{{…}}` / `@get:` it finds has no
  /// `##` in front of it (`AnalyzeRule.kt:674-680`), so a template inside a replacement
  /// part keeps the rule a normal rule whose replacement is expanded.
  Future<_Parsed<_Expansion>> _expandRule(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required bool allowJs,
    required int depth,
    Object? chainedResult,
  }) async {
    // 两个扫描常量都是小写，所以必须先折小写再判：`@PUT:` / `@Get:` 与 `@put:` / `@get:`
    // 是同一条规则（`book-source.md` §3 的前缀大小写不敏感；上游的 `putPattern` /
    // `getPattern` 也都带 CASE_INSENSITIVE）。大小写不影响长度，后面的偏移量照旧。
    final String lowered = rule.toLowerCase();
    if (!rule.contains('{{') &&
        !lowered.contains(_putScanFlag) &&
        !lowered.contains(_getFlag)) {
      return _ParsedValue<_Expansion>(
        _Expansion(text: rule, substituted: false),
      );
    }
    if (depth > _maxExpansionDepth) {
      _logger.warning(
        'Rule expansion exceeded $_maxExpansionDepth levels: field=$rulePath',
      );

      return _ParsedFailure<_Expansion>(_malformed(rulePath));
    }

    // ① `@put:{…}` 先求值并从**整条**规则里摘掉（上游 `splitPutRule` 在 `init` 里先跑）。
    // 顺序很重要：`@put` 的值里可以出现 `##`，先切 `##` 会把它当成规则的替换段。
    final _Parsed<String> stripped = await _stripPutFlags(
      rule,
      scope,
      rulePath: rulePath,
      allowJs: allowJs,
      depth: depth,
    );
    if (stripped case _ParsedFailure<String>(:final _RuleRejection rejection)) {
      return _ParsedFailure<_Expansion>(rejection);
    }
    final String withoutPuts = (stripped as _ParsedValue<String>).value;

    // ② 切区域：`##` 之前是规则体，`@js:` 之后到 `##` 之前是脚本，`##` 之后是替换段。
    // `##` 的定位要**跳过 `{{…}}` 内部**：`{{$.a##x##y}}` 里那个 `##` 是内层规则的替换段。
    final int headEnd = _replacementIndex(withoutPuts);
    final String head = headEnd < 0
        ? withoutPuts
        : withoutPuts.substring(0, headEnd);
    final int jsAt = head.toLowerCase().indexOf(_jsFlag);
    final String body = jsAt < 0 ? head : head.substring(0, jsAt);
    final String script = jsAt < 0 ? '' : head.substring(jsAt);

    final _Parsed<_Expansion> expandedBody = await _expandText(
      body,
      scope,
      rulePath: rulePath,
      allowJs: allowJs,
      depth: depth,
      chainedResult: chainedResult,
    );
    if (expandedBody case _ParsedFailure<_Expansion>(
      :final _RuleRejection rejection,
    )) {
      return _ParsedFailure<_Expansion>(rejection);
    }
    final _Expansion before = (expandedBody as _ParsedValue<_Expansion>).value;

    // 上游 `SourceRule.makeUpRule` 在**执行 JS 之前**就把整条规则里的 `{{…}}` / `@get:`
    // 展开（AnalyzeRule.kt:666-768），脚本里的模板因此拿到的是条目/页面的值。
    // 本仓过去把脚本当不透明文本（矩阵 #14），真实音频源 `movieId={{$.id}}` 因此把大括号
    // 原样送进了 URL（M17 真源普查）。
    final _Parsed<_Expansion> expandedScript = jsAt < 0
        ? const _ParsedValue<_Expansion>(
            _Expansion(text: '', substituted: false),
          )
        : await _expandText(
            script,
            scope,
            rulePath: rulePath,
            allowJs: allowJs,
            depth: depth,
            chainedResult: chainedResult,
          );
    if (expandedScript case _ParsedFailure<_Expansion>(
      :final _RuleRejection rejection,
    )) {
      return _ParsedFailure<_Expansion>(rejection);
    }
    final _Expansion after = (expandedScript as _ParsedValue<_Expansion>).value;

    final StringBuffer text = StringBuffer()
      ..write(before.text)
      ..write(after.text);
    if (headEnd >= 0) {
      final _Parsed<_Expansion> expandedTail = await _expandText(
        withoutPuts.substring(headEnd),
        scope,
        rulePath: rulePath,
        allowJs: allowJs,
        depth: depth,
        chainedResult: chainedResult,
      );
      if (expandedTail case _ParsedFailure<_Expansion>(
        :final _RuleRejection rejection,
      )) {
        return _ParsedFailure<_Expansion>(rejection);
      }
      text.write((expandedTail as _ParsedValue<_Expansion>).value.text);
    }

    return _ParsedValue<_Expansion>(
      _Expansion(
        text: text.toString(),
        // 只有**规则体**里的替换会影响「正则模式」判定；脚本内的替换不改变 body 的解析方式。
        substituted: before.substituted,
      ),
    );
  }

  /// Evaluates every `@put:{key:rule}` of [rule] and removes the flags from its text.
  ///
  /// Upstream runs this before anything else (`AnalyzeRule.kt:668-672`), which is what lets a
  /// put value contain a `##` without being taken for the rule's replacement part.
  /// A failing value rule fails the whole rule: a `@put` is part of the rule, not an
  /// optional side note (C-SRC-4).
  Future<_Parsed<String>> _stripPutFlags(
    String rule,
    RuleScope scope, {
    required String rulePath,
    required bool allowJs,
    required int depth,
  }) async {
    if (!rule.toLowerCase().contains(_putScanFlag)) {
      return _ParsedValue<String>(rule);
    }

    var working = rule;
    for (final RegExpMatch match in _putFlag.allMatches(rule)) {
      final _Parsed<void> stored = await _storePutEntries(
        match.group(1) ?? '',
        scope,
        rulePath: rulePath,
        allowJs: allowJs,
        depth: depth,
      );
      if (stored case _ParsedFailure<void>(:final _RuleRejection rejection)) {
        return _ParsedFailure<String>(rejection);
      }
      working = working.replaceFirst(match.group(0) ?? '', '');
    }

    return _ParsedValue<String>(working);
  }

  /// The offset of the first `##` in [text] that is **not inside** a `{{…}}` template, or `-1`.
  ///
  /// The replacement split has to ignore a `##` inside a template: `{{$.a##x##y}}` is
  /// **one** inline rule whose own `##` is the inner rule's replacement (matrix #9), not a
  /// terminator of the outer rule. Splitting there used to truncate the template at the
  /// first `##`, which made the field `parseFailed` (b5: 腾讯搜索系真源的
  /// `{{$.tag_views##\s+##,}}` is exactly that shape).
  ///
  /// Brace and quote counting is [_templateEnd]'s, so a `}}` / `##` inside a JS string
  /// literal of the template does not end anything. An **unclosed** `{{…` keeps the old
  /// behaviour of “leave it to the parser to complain”: no replacement split is reported.
  int _replacementIndex(String text) {
    var index = 0;
    while (index < text.length) {
      final int replacement = text.indexOf('##', index);
      if (replacement < 0) {
        return -1;
      }
      final int template = text.indexOf('{{', index);
      if (template < 0 || replacement < template) {
        return replacement;
      }
      final int end = _templateEnd(text, template);
      if (end < 0) {
        return -1;
      }
      index = end;
    }

    return -1;
  }

  /// Replaces the `@get:` / `{{…}}` occurrences of [text] with their values.
  ///
  /// `@get:{key}` and `{{…}}` are replaced in one left-to-right pass, the order upstream's
  /// single `evalPattern` scan visits them (`AnalyzeRule.kt:944`): `{{@get:{k}}}` therefore
  /// reaches the template first and the `@get:` is resolved by the nested evaluation, not by
  /// the outer scan. `@put:{…}` is already gone by then ([_stripPutFlags]).
  ///
  /// A substituted value is inserted **verbatim** and never rescanned, so data a rule
  /// produced can never turn into a new rule.
  Future<_Parsed<_Expansion>> _expandText(
    String text,
    RuleScope scope, {
    required String rulePath,
    required bool allowJs,
    required int depth,
    Object? chainedResult,
  }) async {
    final String lower = text.toLowerCase();
    final StringBuffer out = StringBuffer();
    var substituted = false;
    var index = 0;
    while (index < text.length) {
      final int template = text.indexOf('{{', index);
      final int get = lower.indexOf(_getFlag, index);
      final int at = template >= 0 && (get < 0 || template <= get)
          ? template
          : get;
      if (at < 0) {
        out.write(text.substring(index));
        break;
      }

      out.write(text.substring(index, at));
      if (at == template) {
        final int end = _templateEnd(text, at);
        if (end < 0) {
          // 括号不平衡：上游的 `{{[\w\W]*?}}` 也匹配不上，所以原样留下，由后面的解析报错。
          out.write(text.substring(at));
          break;
        }
        final _Parsed<String> value = await _templateValue(
          text.substring(at + 2, end - 2).trim(),
          scope,
          rulePath: rulePath,
          allowJs: allowJs,
          depth: depth,
          chainedResult: chainedResult,
        );
        if (value case _ParsedFailure<String>(
          :final _RuleRejection rejection,
        )) {
          return _ParsedFailure<_Expansion>(rejection);
        }
        out.write((value as _ParsedValue<String>).value);
        index = end;
      } else {
        final int close = text.indexOf('}', at);
        if (close < 0) {
          // `@get:{` 没闭合：这不是“未定义变量”而是畸形规则，按 C-SRC-4 显式失败。
          return _ParsedFailure<_Expansion>(_malformed(rulePath));
        }
        final String key = text.substring(at + _getFlag.length, close).trim();
        // §4：未定义的变量渲染为空串，不保留 `{{…}}` 原文。
        out.write(_variables.read(_sourceIdOf(scope), key) ?? '');
        index = close + 1;
      }
      substituted = true;
    }

    return _ParsedValue<_Expansion>(
      _Expansion(text: out.toString(), substituted: substituted),
    );
  }

  /// Evaluates one `{{…}}` expression into the text it contributes.
  ///
  /// The inner text follows upstream's `isRule` test (`AnalyzeRule.kt:786-791`): a rule head
  /// (`@…`, `$.`, `$[`, `//`) means “evaluate it as a rule”, anything else means “evaluate it
  /// as JavaScript”. That is exactly why matrix #15 exists: inside `{{…}}` the default is
  /// JavaScript, so a default rule has to announce itself with `@@`.
  ///
  /// A rule expression returns its **first** value, and a JavaScript expression its single
  /// scalar; `null` / no value both become an empty string, like upstream inserting
  /// `jsEval ?: ""` (`AnalyzeRule.kt:744-751`).
  Future<_Parsed<String>> _templateValue(
    String inner,
    RuleScope scope, {
    required String rulePath,
    required bool allowJs,
    required int depth,
    Object? chainedResult,
  }) async {
    if (inner.isEmpty) {
      return const _ParsedValue<String>('');
    }

    final ParseResult<List<String>> evaluated;
    if (_isRuleExpression(inner)) {
      evaluated = await _evaluate(
        inner,
        scope,
        rulePath: rulePath,
        single: true,
        allowJs: allowJs,
        depth: depth + 1,
      );
    } else {
      evaluated = await _runJs(
        inner,
        // 矩阵 #31 的链式求值：`{{result}}` 必须看到上一段的产出，否则
        // `<js>…</js>https://…/{{result}}.html` 会拼出整页正文。
        chainedResult ?? _resultOf(scope),
        scope,
        field: rulePath,
        allowJs: allowJs,
      );
    }

    return switch (evaluated) {
      ParseFailure<List<String>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        _ParsedFailure<String>(_RuleRejection(kind: kind, rulePath: rulePath)),
      ParseSuccess<List<String>>(:final List<String> data) =>
        _ParsedValue<String>(data.isEmpty ? '' : data.first),
    };
  }

  /// Evaluates every entry of one `@put:{key:rule}` flag and writes it to the store.
  ///
  /// Each value is a rule of its own, read the way upstream's `getString(value)`
  /// (`AnalyzeRule.kt:641-647`) reads it: the first value, or an empty string. The value is
  /// written even when the rule matched nothing, because a source that clears a variable by
  /// pointing at a missing field expects exactly that.
  Future<_Parsed<void>> _storePutEntries(
    String body,
    RuleScope scope, {
    required String rulePath,
    required bool allowJs,
    required int depth,
  }) async {
    final String sourceId = _sourceIdOf(scope);
    for (final MapEntry<String, String> entry in _putEntries(body).entries) {
      final ParseResult<List<String>> stored = await _evaluate(
        entry.value,
        scope,
        rulePath: rulePath,
        single: true,
        allowJs: allowJs,
        depth: depth + 1,
      );
      switch (stored) {
        case ParseFailure<List<String>>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          return _ParsedFailure<void>(
            _RuleRejection(kind: kind, rulePath: rulePath),
          );
        case ParseSuccess<List<String>>(:final List<String> data):
          _variables.write(sourceId, entry.key, data.isEmpty ? '' : data.first);
      }
    }

    return const _ParsedValue<void>(null);
  }

  /// Renders a **URL** template, including the `{{…}}` JavaScript of matrix #18.
  ///
  /// The M0 variables come from [params] and keep their template semantics — `key` in
  /// particular stays form-encoded exactly once (`book-source.md` §4) — so a source that
  /// spells `?q={{key}}&page={{page}}` behaves exactly as before. Every other `{{…}}` is
  /// evaluated as JavaScript, which is what §4 allows in a search or explore URL: a **rule**
  /// head there (`@@`, `$.`, `//`, `@xpath:`) is rejected by name instead of being guessed
  /// (C-SRC-4).
  ///
  /// The keyword is exposed to that JavaScript as `key` (upstream's `AnalyzeUrl.evalJS`,
  /// `AnalyzeUrl.kt:377`), because the template form cannot reach it: `{{key}}` is consumed
  /// by [params] first.
  ///
  /// [rulePath] names the field the URL came from (`searchUrl`, `tocRule.nextTocUrl`), so a
  /// failing script stays locatable (C-SRC-8).
  ///
  /// [charset] is the request's declared encoding (`url,{“charset”:“gbk”}`,
  /// `book-source.md` §4.3) and only affects how `key` is escaped; [encodeKeyword] is `false`
  /// when the template is a **body** that must carry the keyword verbatim (a JSON payload,
  /// which upstream does not form-encode either).
  ///
  /// [expandSegments] runs upstream's `analyzeJs` first: a URL rule may be a **chain** of literal
  /// text and `@js:` / `<js>` scripts, where a literal piece replaces `@result` with what the chain
  /// produced so far and each script receives it as `result` (`AnalyzeUrl.kt:157-176`). A rule that
  /// is nothing but a script therefore renders its value — the form a source writes as
  /// `searchUrl: "@js:'https://a.test/s?q=' + key"`. A **body** keeps it off ([expandSegments]
  /// `false`): upstream expands the address only.
  Future<ParseResult<String>> renderUrl(
    String template, {
    required String rulePath,
    required Map<String, String> params,
    required JsPageContext context,
    String? charset,
    bool encodeKeyword = true,
    bool expandSegments = true,
  }) async {
    String source = template;
    if (expandSegments) {
      final _Parsed<String> chained = await _expandUrlSegments(
        template,
        rulePath: rulePath,
        context: context,
      );
      switch (chained) {
        case _ParsedFailure<String>(:final _RuleRejection rejection):
          return _fail<String>(rejection, field: rulePath);
        case _ParsedValue<String>(:final String value):
          source = value;
      }
    }

    final StringBuffer out = StringBuffer();
    var index = 0;
    while (index < source.length) {
      final int at = source.indexOf('{{', index);
      if (at < 0) {
        out.write(source.substring(index));
        break;
      }
      final int end = _templateEnd(source, at);
      if (end < 0) {
        // §4：不得把字面 `{{…}}` 交给请求层 —— 在 URL 里它只能显式失败。
        return _fail<String>(_malformed(rulePath), field: rulePath);
      }

      out.write(source.substring(index, at));
      final String inner = source.substring(at + 2, end - 2).trim();
      if (params.containsKey(inner)) {
        if (!encodeKeyword && inner == _urlKeywordVariable) {
          // 非表单载荷（JSON / XML body）里关键词必须原样出现。
          out.write(params[inner]);
        } else {
          // 交给同步渲染器统一处理（`key` 只编码一次）：原样搬过去。
          out.write(source.substring(at, end));
        }
      } else {
        final _Parsed<String> value = await _urlJsValue(
          inner,
          rulePath: rulePath,
          context: context,
          params: params,
        );
        if (value case _ParsedFailure<String>(
          :final _RuleRejection rejection,
        )) {
          return _fail<String>(rejection, field: rulePath);
        }
        out.write((value as _ParsedValue<String>).value);
      }
      index = end;
    }

    return ParseSuccess<String>(
      renderUrlTemplate(
        out.toString(),
        params,
        logger: _logger,
        charset: charset,
        page: context.page,
      ),
    );
  }

  /// Upstream's `AnalyzeUrl.analyzeJs` (`:160-176`): a URL rule is a chain of literal pieces and
  /// `@js:` / `<js>` scripts.
  ///
  /// The running value starts as the whole rule. A literal piece **replaces** `@result` with it (all
  /// occurrences), and a script receives it as `result`; the script's value becomes the new running
  /// value. Upstream trims every literal piece, and a piece that trims to nothing contributes
  /// nothing — an empty piece must not wipe the chain.
  Future<_Parsed<String>> _expandUrlSegments(
    String template, {
    required String rulePath,
    required JsPageContext context,
  }) async {
    final Iterable<RegExpMatch> matches = _jsSegmentPattern.allMatches(
      template,
    );
    if (matches.isEmpty) {
      return _ParsedValue<String>(template);
    }

    String running = template;
    var start = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        final String literal = template.substring(start, match.start).trim();
        if (literal.isNotEmpty) {
          running = literal.replaceAll(_urlChainVariable, running);
        }
      }
      final String block = (match.group(1) ?? '').trim();
      final String script = block.isNotEmpty ? block : (match.group(2) ?? '');
      final ParseResult<Object?> evaluated = await evaluateJs(
        script,
        rulePath: rulePath,
        context: context,
        result: running,
      );
      switch (evaluated) {
        case ParseFailure<Object?>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          return _ParsedFailure<String>(
            _RuleRejection(kind: kind, rulePath: rulePath),
          );
        case ParseSuccess<Object?>(:final Object? data):
          running = data?.toString() ?? '';
      }
      start = match.end;
    }
    if (template.length > start) {
      final String literal = template.substring(start).trim();
      if (literal.isNotEmpty) {
        running = literal.replaceAll(_urlChainVariable, running);
      }
    }

    return _ParsedValue<String>(running);
  }

  /// Evaluates one non-template `{{…}}` of a URL (§4, matrix #18).
  ///
  /// A rule head is rejected: a search or explore URL may only run JavaScript there, and
  /// saying so is what keeps a default selector from being sent to the network as a literal
  /// URL. The JavaScript runs with the URL's bindings (`baseUrl`, `page`, `source`, `key`)
  /// and no `result`, because no page has been fetched yet (upstream binds `result` to null
  /// in `AnalyzeUrl.evalJS`).
  ///
  /// Numbers are written without a trailing `.0`, matching upstream's formatting of an
  /// integral result (`AnalyzeUrl.kt:203-207`): a page number that came back as `2.0` must
  /// not become `2.0` in the URL.
  Future<_Parsed<String>> _urlJsValue(
    String inner, {
    required String rulePath,
    required JsPageContext context,
    required Map<String, String> params,
  }) async {
    final String? head = _rejectedUrlRuleHead(inner);
    if (head != null) {
      return _ParsedFailure<String>(_unsupported(head));
    }

    final ParseResult<Object?> evaluated = await _jsBridge.evaluate(
      JsJob(
        script: inner,
        rulePath: rulePath,
        baseUrl: context.baseUrl,
        page: context.page,
        source: context.source,
        sourceHeaders: context.headers,
        variables: _variables.snapshot(context.source.url),
        bookName: context.bookName,
        chapterTitle: context.chapterTitle,
        key: params['key'],
      ),
    );

    return switch (evaluated) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        _ParsedFailure<String>(_RuleRejection(kind: kind, rulePath: rulePath)),
      ParseSuccess<Object?>(:final Object? data) => _ParsedValue<String>(
        switch (data) {
          null => '',
          final double number when number == number.roundToDouble() =>
            number.toInt().toString(),
          _ => _jsValues(data).isEmpty ? '' : _jsValues(data).first,
        },
      ),
    };
  }

  /// The rule head [inner] carries when a URL may not evaluate it, or `null` when it is
  /// JavaScript.
  String? _rejectedUrlRuleHead(String inner) {
    if (inner.startsWith(_defaultRuleFlag)) {
      return _defaultRuleFlag;
    }
    if (inner.startsWith(r'$.')) {
      return r'$';
    }
    if (inner.startsWith(r'$[')) {
      return r'$';
    }
    if (inner.startsWith('//')) {
      return '//';
    }
    if (inner.startsWith('@')) {
      // `_flagOf` 认的是去掉 `@` 之后的部分，所以这里要少传一位（`@css:` → `css:`）。
      return _flagOf(inner.substring(1)) ?? '@';
    }

    return null;
  }

  /// The source id the variables of [scope] are keyed by (`book-source.md` §6).
  ///
  /// A scope built without a fetch carries no source, and its variables live under the
  /// empty key — they are still consistent with themselves, they just belong to nobody.
  String _sourceIdOf(RuleScope scope) {
    final JsPageContext context = _jsContextOf(scope);

    return context.source.url;
  }

  /// Whether [text] is a rule (upstream's `isRule`, `AnalyzeRule.kt:786-791`).
  bool _isRuleExpression(String text) =>
      text.startsWith('@') ||
      text.startsWith(r'$.') ||
      text.startsWith(r'$[') ||
      text.startsWith('//');

  /// The end offset of the `{{…}}` template starting at [start], or `-1` when it is not
  /// balanced.
  ///
  /// Every brace counts: `{{@get:{k}}}` is one template, and the `{` of the nested
  /// `@get:{k}` must not be mistaken for the closing `}}`. Quotes are skipped so a brace
  /// inside a string literal does not open or close anything — the same tolerance
  /// upstream's `chompCodeBalanced` gives (`RuleAnalyzer.kt:91`).
  int _templateEnd(String text, int start) {
    var depth = 0;
    String? quote;

    for (var index = start; index < text.length; index++) {
      final String character = text[index];
      // 反斜杠转义的字符不参与括号计数：`/{{\}\}/` 这类脚本字面量不是模板
      // （上游 `\{\{[\w\W]*?\}\}` 也匹配不到它），必须原样留给脚本。
      if (character.codeUnitAt(0) == 0x5C) {
        index++;
        continue;
      }
      if (quote != null) {
        if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        continue;
      }
      if (character == '{') {
        depth++;
        continue;
      }
      if (character == '}') {
        depth--;
        if (depth == 0) {
          return index + 1;
        }
      }
    }

    return -1;
  }

  /// Reads the entries of one `@put:{…}` body.
  ///
  /// Upstream parses it as JSON — strictly first, then leniently (`AnalyzeRule.kt:673-686`) —
  /// which accepts both `@put:{bid:"//*[@bid-data]/@bid-data"}` and the unquoted JSONPath
  /// form the matrix documents. This reader accepts the same two shapes without a JSON
  /// parser: `key: value` pairs split on top-level commas, with an optional pair of quotes
  /// around either half. A pair without a colon is skipped rather than guessed.
  Map<String, String> _putEntries(String body) {
    final Map<String, String> entries = <String, String>{};
    final List<String> parts = <String>[];
    final StringBuffer current = StringBuffer();
    var depth = 0;
    String? quote;
    var escaped = false;

    for (var index = 0; index < body.length; index++) {
      final String character = body[index];
      if (quote != null) {
        current.write(character);
        if (escaped) {
          // 引号里的 `\"` / `\\` 是被转义的字符，不能当引号结束。
          escaped = false;
          continue;
        }
        if (character == r'\') {
          escaped = true;
          continue;
        }
        if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        current.write(character);
        continue;
      }
      switch (character) {
        case '[' || '(' || '{':
          depth++;
        case ']' || ')' || '}':
          depth--;
        case ',' when depth == 0:
          parts.add(current.toString());
          current.clear();
          continue;
      }
      current.write(character);
    }
    if (current.isNotEmpty) {
      parts.add(current.toString());
    }

    for (final String part in parts) {
      final int colon = _topLevelColon(part);
      if (colon < 0) {
        continue;
      }
      final String key = _unquote(part.substring(0, colon).trim());
      if (key.isEmpty) {
        continue;
      }
      entries[key] = _unquote(part.substring(colon + 1).trim());
    }

    return entries;
  }

  /// The offset of the `:` separating a `@put` key from its rule, or `-1` when there is
  /// none outside brackets and quotes.
  int _topLevelColon(String text) {
    var depth = 0;
    String? quote;
    var escaped = false;

    for (var index = 0; index < text.length; index++) {
      final String character = text[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (character == r'\') {
          escaped = true;
          continue;
        }
        if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        continue;
      }
      switch (character) {
        case '[' || '(' || '{':
          depth++;
        case ']' || ')' || '}':
          depth--;
        case ':' when depth == 0:
          return index;
      }
    }

    return -1;
  }

  /// Removes one optional pair of quotes around [text], undoing `\\` and `\"` escapes.
  String _unquote(String text) {
    if (text.length < 2) {
      return text;
    }
    final String quote = text[0];
    if ((quote != '"' && quote != "'") || text[text.length - 1] != quote) {
      return text;
    }

    return text
        .substring(1, text.length - 1)
        .replaceAllMapped(
          RegExp(r'\\(.)'),
          (Match match) => match.group(1) ?? '',
        );
  }

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
  ///
  /// A **JSON item** keeps the page's context: `_jsonScopesOf` builds every item with the page's
  /// [JsPageContext], and a per-item `@js:` field is exactly where `baseUrl` (and the book /
  /// chapter names) has to stay visible — without this, a JSON API source's `@js:` URL rule sees
  /// an empty `baseUrl` and produces a relative or truncated address (M17 真源抽查发现).
  JsPageContext _jsContextOf(RuleScope scope) => switch (scope) {
    DomScope(:final JsPageContext? jsContext) =>
      jsContext ?? const JsPageContext(baseUrl: ''),
    JsonScope(:final JsPageContext? jsContext) =>
      jsContext ?? const JsPageContext(baseUrl: ''),
  };

  /// The page content a bare `@js:` rule receives as `result` (`book-source.md` §6).
  ///
  /// A page scope answers with its response body. An **element** scope answers with the
  /// element's `outerHtml`, because the sandbox has no DOM to hand over (ADR-0029 §决策 5) and
  /// a rule on a per-item field (`searchRule.name`) still has to see the item it belongs to.
  /// A JSON scope answers with its JSON text.
  /// Builds the `parse.*` evaluator a `@js:` job carries (`book-source.md` §6).
  ///
  /// The nested rule is evaluated **here**, on the isolate that owns the engine, so the worker
  /// never has to rebuild a scope (ADR-0029 §决策 5). Two boundaries are refused by name instead
  /// of being answered with an empty value (C-SRC-4):
  ///
  /// * anything but the page scope (`js:parse-scope`) — an element scope, a JSON item, or a
  ///   `doc` that is not exactly this page's body has nothing a rule could read;
  /// * a nested rule that itself needs `@js:` — the one worker is busy running the job that asked
  ///   (ADR-0030 §决策 1/3), so a nested evaluation could only wait on its own queue. The value
  ///   shape (`parse.getString`) reports it as `js:parse-recursion`; the element shape
  ///   (`parse.getElements`) reports `unsupported:@js:list`, because a nested **list** rule that
  ///   needs `@js:` would have to run another job (the top-level rule form is fine: matrix #14 and
  ///   the trailing-`@js:` list chain both go through `_selectAllSegments`).
  ///
  /// `parse.getString` answers with the first value, or `''` when the nested rule matched
  /// nothing — upstream's `getString` shape, which rules do string work on. `parse.getElements`
  /// answers with every match: an element becomes its `outerHtml` and a JSON match its value,
  /// since the sandbox has no DOM handles.
  JsParseEvaluator _parseEvaluatorFor(
    RuleScope scope, {
    required String field,
  }) => (JsParseRequest request) async {
    // `java.setContent(html)` 换掉页级 scope（ADR-0076 §决策 1）：上游在同一个评价里换 content，
    // 本仓的 scope 在宿主上，所以按覆盖后的正文重建一个页级 scope 再求值。
    final RuleScope effective = _withContent(scope, request.content);
    final String? page = _pageBodyOf(effective);
    if (page == null || (request.doc != null && request.doc != page)) {
      return failureAt<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$field:$jsParseScopeMarker',
      );
    }

    if (request.wantsList && request.wantsValues) {
      // `java.getStringList`：抽取值（上游 `AnalyzeRule.getStringList` 会跑提取段）。
      return switch (await _evaluate(
        request.rule,
        effective,
        rulePath: field,
        single: false,
        allowJs: false,
      )) {
        ParseFailure<List<String>>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ) =>
          failureAt<Object?>(kind: kind, rulePath: rulePath),
        ParseSuccess<List<String>>(:final List<String> data) =>
          ParseSuccess<Object?>(data),
      };
    }

    if (request.wantsList) {
      // 元素形状（`parse.getElements`）的 `@js:` 柜口：段链里的脚本要再起一个 job，而 worker
      // 正在跑发起这次嵌套的 job（ADR-0030 §决策 1/3）——顶层列表规则的 `@js:` 不受影响，
      // 那是同一次评价里的段链（矩阵 #14），这里只是「嵌套再嵌套」这一档。
      if (_jsSegmentsOf(request.rule)
          .any((_RuleSegment segment) => segment.isScript)) {
        return failureAt<Object?>(
          kind: ParseFailureKind.unsupportedRule,
          rulePath: '$field:$_jsListMarker',
        );
      }

      return switch (await selectAll(
        request.rule,
        effective,
        rulePath: field,
      )) {
        ParseFailure<List<RuleScope>>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ) =>
          failureAt<Object?>(kind: kind, rulePath: rulePath),
        ParseSuccess<List<RuleScope>>(:final List<RuleScope> data) =>
          ParseSuccess<Object?>(<Object?>[
            for (final RuleScope match in data) _jsDocOf(match),
          ]),
      };
    }

    return switch (await _evaluate(
      request.rule,
      effective,
      rulePath: field,
      single: true,
      allowJs: false,
    )) {
      ParseFailure<List<String>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<Object?>(kind: kind, rulePath: rulePath),
      // 上游 `getString`：多匹配用换行拼接（ADR-0069 G9），不是只给第一个。
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<Object?>(data.join(_valueSeparator)),
    };
  };

  /// The scope a `parse.*` request has to be evaluated against: `java.setContent(html)` replaces
  /// body a rule reads inside the same job (ADR-0076 §决策 1).
  ///
  /// Upstream mutates `AnalyzeUrl.content` in place; here the page scope lives on the host, so the
  /// override arrives with the call and the engine rebuilds a page scope around it — same URL, same
  /// page number, same source, new body.
  RuleScope _withContent(RuleScope scope, String? content) {
    if (content == null) {
      return scope;
    }
    final JsPageContext? context = switch (scope) {
      DomScope(:final JsPageContext? jsContext) => jsContext,
      JsonScope(:final JsPageContext? jsContext) => jsContext,
    };

    return RuleScope.dom(
      html_parser.parse(content),
      body: content,
      jsContext: context,
    );
  }

  /// The response body [scope] carries, or `null` when it is not a page scope.
  String? _pageBodyOf(RuleScope scope) => switch (scope) {
    DomScope(:final String? body) => body,
    JsonScope() => null,
  };

  /// The value one `parse.getElements` match becomes in the sandbox (§6).
  Object? _jsDocOf(RuleScope match) => switch (match) {
    DomScope(:final Node node) => node is Element ? node.outerHtml : node.text,
    JsonScope(:final Object? value) => value,
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
  /// Asynchronous like the rest of the evaluation API: a `@js:` body is evaluated by the
  /// sandbox (upstream applies `replaceRegex` through `analyzeRule.getString`,
  /// `BookContent.kt:190-193`), and one shared shape keeps a caller from branching on which
  /// engine entry point it holds. [jsContext] is the page the rule runs against; without it
  /// a rule reading `baseUrl` would silently see an empty string.
  Future<ParseResult<String>> applyReplaceRule(
    String rule,
    String text, {
    required String rulePath,
    JsPageContext? jsContext,
  }) async {
    final List<String> parts = rule.split('##');
    final String body = parts.first.trim();
    if (body.toLowerCase().startsWith(_jsFlag)) {
      // 上游把 `replaceRegex` 交给同一套规则求值（`analyzeRule.getString(replaceRegex,
      // contentStr)`），所以 `@js:` 净化规则在沙箱里跑，`result` 是拼接后的整章正文。
      final JsPageContext context =
          jsContext ?? const JsPageContext(baseUrl: '');
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
        _jsonValuesOf(json, value),
      ),
    },
  };

  /// The values one JSON branch contributes (matrix #13 / #19).
  ///
  /// A plain path is read as before. A rule with embedded `{$jsonpath}` templates becomes
  /// **one** value — the expression with every template replaced by its result, which is
  /// what upstream does when the substitution succeeded (`AnalyzeByJSonPath.kt:79-90`); an
  /// embedded path that matched a list joins its elements with a newline, upstream's
  /// `getString` (`AnalyzeByJSonPath.kt:45-48`).
  List<String> _jsonValuesOf(_JsonBranch branch, Object? value) {
    final _JsonPiece first = branch.pieces.first;
    if (branch.pieces.length == 1 && first is _JsonPathPiece) {
      return <String>[
        for (final JsonPathMatch match in first.path.read(value))
          ..._jsonValues(match.value),
      ];
    }

    final StringBuffer expanded = StringBuffer();
    for (final _JsonPiece piece in branch.pieces) {
      switch (piece) {
        case _JsonLiteralPiece(:final String text):
          expanded.write(text);
        case _JsonPathPiece(:final JsonPath path):
          expanded.write(
            <String>[
              for (final JsonPathMatch match in path.read(value))
                ..._jsonValues(match.value),
            ].join('\n'),
          );
      }
    }
    final String text = expanded.toString();

    return text.isEmpty ? const <String>[] : <String>[text];
  }

  /// The values one JSON match contributes to a value rule (matrix #13).
  ///
  /// A JSON string is its own value, a number or a boolean is written the way JSON
  /// writes it, and `null` — like an empty string — yields no value at all, which is
  /// the same “no value” an unmatched selector gives (matrix #8). A **list** is expanded
  /// into its elements, which is what upstream does (`AnalyzeByJSonPath.kt:83-87`: `for
  /// (o in obj) result.add(o.toString())`), so `$.data.tags` hands over `a` and `b`
  /// rather than one JSON text — confirmed against a real source by the `docs/dev/roadmap.md` 3.7
  /// regression. A **map** stays JSON text: upstream's Java `toString` of a map (`{a=1}`)
  /// is not reproducible and no rule can rely on it, so the lossless form is used and the
  /// difference stays registered (`book-source.md` §3, matrix #13).
  Iterable<String> _jsonValues(Object? value) => switch (value) {
    null => const <String>[],
    final String text => text.isEmpty ? const <String>[] : <String>[text],
    final List<Object?> list => <String>[
      for (final Object? item in list) ..._jsonValues(item),
    ],
    final Map<Object?, Object?> map => <String>[jsonEncode(map)],
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
    // 上游 `getElementsByClass(rules[1])`（jsoup）把带空格的类名按**全部命中**处理：
    // `class.col-lg-3 col-md-4 col-6 mb-2` 表示「这四个类都要有」。只取第一个（或把空格
    // 当后代选择器）会让这类源的每一条列表规则都返回空（ADR-0069 G13）。
    'class' => _classSelector(step.name),
    'id' => '#${cascadia.escapeCssIdent(step.name)}',
    _ => cascadia.escapeCssIdent(step.name),
  };

  /// The CSS selector for a `class.` segment: every whitespace-separated class is required.
  ///
  /// An empty name keeps the old single-token behaviour (`.`) so the failure stays the same
  /// `parseFailed` the caller already handles.
  String _classSelector(String name) {
    final Iterable<String> classes = name
        .split(_whitespace)
        .where((String token) => token.isNotEmpty);
    if (classes.isEmpty) {
      return '.';
    }

    return classes
        .map((String token) => '.${cascadia.escapeCssIdent(token)}')
        .join();
  }

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
    // `+` 是「正序」的显式写法：上游先剥 `-` 再剥 `+`，两个都只当标记（`BookList.kt:73-75`、
    // `BookChapterList.kt:59-65`），所以 `-+rule` 仍然是倒序。
    final String withoutReverse = (reverse ? rawBody.substring(1) : rawBody)
        .trim();
    final String stripped = withoutReverse.startsWith('+')
        ? withoutReverse.substring(1).trim()
        : withoutReverse;
    // 矩阵 #15：`@@` 是规则体前缀（上游 `AnalyzeRule.kt:612-615`：剥掉两字符、模式不变），
    // 所以必须比 `@` 切段早——否则它会变成一个空段。
    final String body = stripped.startsWith(_defaultRuleFlag)
        ? stripped.substring(_defaultRuleFlag.length).trim()
        : stripped;
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
      // 列表规则上的 `@js:` 由 `_selectAllRule` 提前交给段链解释器（矩阵 #14 / `AnalyzeRule.kt:439`），
      // 走到这里的只可能是**没有 JS 段**的规则；留着这一档是为了让 `_check` 与 `_parse` 的契约
      // 完整（两个入口共享同一个解析），而不是一条可达分支。
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
    // 上游把**任何**段末尾的 `.N` 当索引（`ElementsSingle`）：`#image_div img.0` 读的是
    // 「`#image_div img` 的第 0 个」，不是「类名 0」。只有纯数字（可带负号）才算索引，
    // 所以 `div.item` / `.result-item` 仍是 CSS（ADR-0069 G3）。
    final int dot = segment.lastIndexOf('.');
    if (dot > 0 && _dotIndex.hasMatch(segment.substring(dot + 1))) {
      return _indexSuffix(
        segment.substring(0, dot),
        segment.substring(dot + 1),
        field: field,
      );
    }

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
  /// (matrix #13 / #19).
  ///
  /// The flag is case-insensitive like every other flag (`@Json:` works), and it may be
  /// omitted when the path starts with `$.` or `$[` — the two spellings upstream's rule
  /// documentation lists. Matrix #19's `{$jsonpath}` is recognised from its opening
  /// `{$`: upstream reads those templates **inside** a JSON rule
  /// (`AnalyzeByJSonPath.kt:41`), and a rule that is nothing but one template is exactly
  /// the legacy `{$.data.name}` form. A bare `$` is not one of them, so it stays an
  /// unknown rule type instead of being guessed.
  String? _jsonPathOf(String branch) {
    final String trimmed = branch.trim();
    if (trimmed.toLowerCase().startsWith(_jsonFlag)) {
      return trimmed.substring(_jsonFlag.length);
    }
    if (trimmed.startsWith(r'$.') || trimmed.startsWith(r'$[')) {
      return trimmed;
    }
    if (trimmed.contains(_jsonTemplateOpen)) {
      return trimmed;
    }

    return null;
  }

  /// Reads a JSON branch (matrix #13 / #19) into the pieces it evaluates.
  ///
  /// The paths are parsed while the rule is read, for the same reason `@css:` parses its
  /// selector here: a malformed path has to become a locatable
  /// [ParseFailureKind.parseFailed] carrying the field path, instead of an unlocatable
  /// throw out of the matcher (C-SRC-8). That includes each `{$jsonpath}` template of
  /// matrix #19, which is validated the same way.
  _Parsed<_RuleBranch> _readJsonBranch(
    String expression, {
    required String field,
  }) {
    final String trimmed = expression.trim();
    if (trimmed.isEmpty) {
      return _ParsedFailure<_RuleBranch>(_malformed(field));
    }

    final List<_JsonPiece>? pieces = _jsonPiecesOf(trimmed);

    return pieces == null
        ? _ParsedFailure<_RuleBranch>(_malformed(field))
        : _ParsedValue<_RuleBranch>(_JsonBranch(pieces));
  }

  /// Splits a JSON expression into the literal text and the paths it evaluates, or `null`
  /// when a path cannot be parsed.
  ///
  /// Without a `{$jsonpath}` template the whole expression is one path (matrix #13). With
  /// them, the expression is text with embedded paths (matrix #19) — upstream substitutes
  /// each one with its value in place (`AnalyzeByJSonPath.kt:29-31`).
  List<_JsonPiece>? _jsonPiecesOf(String expression) {
    if (!expression.contains(_jsonTemplateOpen)) {
      return _asJsonPathPiece(expression);
    }

    final List<_JsonPiece> pieces = <_JsonPiece>[];
    var index = 0;
    while (index < expression.length) {
      final int at = expression.indexOf(_jsonTemplateOpen, index);
      if (at < 0) {
        pieces.add(_JsonLiteralPiece(expression.substring(index)));
        break;
      }
      if (at > index) {
        pieces.add(_JsonLiteralPiece(expression.substring(index, at)));
      }
      final int end = _jsonTemplateEnd(expression, at);
      if (end < 0) {
        return null;
      }
      final List<_JsonPiece>? path = _asJsonPathPiece(
        expression.substring(at + 1, end),
      );
      if (path == null) {
        return null;
      }
      pieces.addAll(path);
      index = end + 1;
    }

    return pieces.isEmpty ? null : pieces;
  }

  /// Parses [expression] as a JSONPath, or `null` when it is not one.
  ///
  /// The expression is first put through [_normalizeJsonPath]: Legado's JsonPath accepts a
  /// member name directly after a bracket, RFC 9535's does not (b5).
  List<_JsonPiece>? _asJsonPathPiece(String expression) {
    try {
      return <_JsonPiece>[
        _JsonPathPiece(JsonPath(_normalizeJsonPath(expression.trim()))),
      ];
    } on FormatException {
      return null;
    }
  }

  /// Rewrites two Legado JSONPath shorthands into their RFC 9535 spelling.
  ///
  /// * `]member` → `].member`;
  /// * `$.[…]` → `$[…]` (the dot is not allowed before a subscript in RFC 9535).
  ///
  /// Upstream's JsonPath (the library Legado ships) reads `$.a[0]b` and
  /// `$.data.page[*]image`; the RFC 9535 parser behind [JsonPath] only reads `$.a[0].b`
  /// (`$.data.page[*]image` was a real source's `contentRule.content` that b1b's regression
  /// could not run). Only an identifier start is joined — letters, `_` and non-ASCII (a
  /// Chinese member name) — so `].`, `][`, a trailing `]` and `]` followed by whitespace are
  /// left exactly as written, and a `]` **inside a quoted member** (`$['a]']b`) is skipped
  /// because it is not a bracket at all.
  String _normalizeJsonPath(String path) {
    if (!path.contains(']')) {
      return path;
    }

    final StringBuffer out = StringBuffer();
    String? quote;
    for (var index = 0; index < path.length; index++) {
      final String character = path[index];
      if (quote != null) {
        out.write(character);
        if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        out.write(character);
        continue;
      }

      // Legado 的 JsonPath 接受 `$.[*]`（`$.` 之后直接跟下标）；RFC 9535 不接受这个点。
      // 真实语料里 `宜搜小说` / `有声听书网` 的 `bookList` 就是 `$.[*]`（M12-A6）。
      if (character == '.' &&
          index + 1 < path.length &&
          path[index + 1] == '[') {
        continue;
      }
      out.write(character);
      if (character != ']' || index + 1 >= path.length) {
        continue;
      }
      final String next = path[index + 1];
      if (_isJsonMemberStart(next)) {
        out.write('.');
      }
    }

    return out.toString();
  }

  /// Whether [character] can start an unquoted JSONPath member name (RFC 9535
  /// `name-first`: a letter, `_`, or any non-ASCII character).
  bool _isJsonMemberStart(String character) {
    final int code = character.codeUnitAt(0);
    if (code >= 0x80) {
      return true;
    }
    final bool isAsciiLetter =
        (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);

    return isAsciiLetter || character == '_';
  }

  /// The offset of the `}` closing the `{$` template that starts at [start], or `-1` when
  /// it is not balanced.
  ///
  /// Quotes are skipped so a `}` inside a JSONPath string literal does not end the
  /// template; nesting is counted the same way upstream's `chompCodeBalanced` does it
  /// (`RuleAnalyzer.kt:91-130`).
  int _jsonTemplateEnd(String expression, int start) {
    var depth = 0;
    String? quote;

    for (var index = start; index < expression.length; index++) {
      final String character = expression[index];
      if (quote != null) {
        if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == '"' || character == "'") {
        quote = character;
        continue;
      }
      if (character == '{') {
        depth++;
      } else if (character == '}') {
        depth--;
        if (depth == 0) {
          return index;
        }
      }
    }

    return -1;
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

/// One piece of a rule that mixes `<js>…</js>` with selectors (matrix #31).
///
/// Upstream evaluates the pieces in order and feeds each one the previous one's value as
/// `result` (`AnalyzeRule.getString` / `getStringList`), so the split is a pipeline rather
/// than a single selector.
final class _RuleSegment {
  const _RuleSegment(this.text, {required this.isScript});

  /// The piece itself: a script when [isScript], otherwise rule text with its templates intact.
  final String text;

  /// Whether this piece is JavaScript (`true`) or a rule to evaluate (`false`).
  final bool isScript;
}

/// One rule after the matrix #15..#19 expansion: the text that is left to parse, and
/// whether a `{{…}}` / `@get:` substitution happened.
///
/// The flag matters: upstream evaluates a rule that carried a substitution in **regex
/// mode**, where the substituted text *is* the value (`AnalyzeRule.kt:674-680`), so a value
/// rule has to stop here instead of reading the text as a selector.
final class _Expansion {
  const _Expansion({required this.text, required this.substituted});

  /// The rule text after the `@put:` / `@get:` / `{{…}}` occurrences were resolved.
  final String text;

  /// Whether at least one `{{…}}` or `@get:` was substituted.
  final bool substituted;
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

/// A branch that reads JSON: `@json:`, the bare `$.` / `$[` form (matrix #13) and the
/// legacy `{$jsonpath}` templates (matrix #19).
final class _JsonBranch extends _RuleBranch {
  const _JsonBranch(this.pieces);

  /// The expression's pieces, in order: one path for a plain JSON rule, or literal text
  /// with embedded paths for a legacy template.
  final List<_JsonPiece> pieces;

  /// The paths [pieces] carries, in order (matrix #13 / #19).
  Iterable<_JsonPathPiece> get paths => pieces.whereType<_JsonPathPiece>();
}

/// One piece of a JSON expression (matrix #13 / #19).
sealed class _JsonPiece {
  const _JsonPiece();
}

/// Text a JSON expression carries verbatim (matrix #19).
final class _JsonLiteralPiece extends _JsonPiece {
  const _JsonLiteralPiece(this.text);

  /// The literal text of the expression.
  final String text;
}

/// A JSONPath the expression evaluates against the scope.
final class _JsonPathPiece extends _JsonPiece {
  const _JsonPathPiece(this.path);

  /// The parsed path.
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
