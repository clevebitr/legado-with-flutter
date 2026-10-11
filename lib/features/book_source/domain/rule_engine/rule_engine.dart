import 'package:cascadia/cascadia.dart' as cascadia;
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:html/dom.dart';

/// Prefixes of the rule flags that a later phase of the matrix owns.
///
/// `docs/dev/book-source.md` §3 declares the prefix casing insensitive
/// (`@css:` and `@CSS:` are the same flag), so these are matched lower-cased.
/// The order matters: `{{` has to be tested before `{`.
const List<String> _deferredFlags = <String>[
  '{{',
  '//',
  r'$.',
  r'$[',
  '{',
  ':',
  '@@',
  '@json:',
  '@js:',
  '@xpath:',
  '@put:',
  '@get:',
  '@webjs',
];

/// Operators that join several rules; matrix #10 / #11 / #27 own them.
const List<String> _deferredOperators = <String>['||', '&&', '%%'];

/// The `@css:` flag of matrix #12, lower-cased for a case-insensitive compare.
const String _cssFlag = '@css:';

/// jsoup's index pseudo-classes, which cascadia does not implement.
///
/// `book-source.md` §3 row #12 declares **standard** CSS selectors, so these are
/// named as unsupported instead of being handed to cascadia, where they would come
/// back as an unlocatable parse failure (C-SRC-4). Requiring the `(` keeps standard
/// pseudos such as `:first-child` out of the match.
/// jsoup's index pseudo-classes (matrix #29) and the cascadia form each maps onto.
///
/// The replacement receives the argument jsoup was given and returns the
/// `:nth-child` form with the same **sibling-index** meaning. Immutable on purpose:
/// the engine holds no shared mutable state (C-SRC-9).
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
/// | #12 | the `@css:` flag, handing the rest of the segment to cascadia |
/// | #26 | the `[...]` index list, with ranges, steps and `[!...]` exclusion |
/// | #28 | an index as the first rule of a segment (`.1` / `[1]` / `children[1]`) |
///
/// Everything else in the matrix is reported as
/// [ParseFailureKind.unsupportedRule] — never silently mis-parsed (C-SRC-4) — with
/// `rulePath` naming the syntax, e.g. `unsupported:@css:`. A rule that is
/// structurally broken (a missing name, a non-numeric position) is reported as
/// [ParseFailureKind.parseFailed] with the field path as `rulePath`.
///
/// The engine is stateless, so one instance can evaluate rules concurrently
/// (C-SRC-9), and it never mutates the scope it is given or its elements.
final class RuleEngine {
  /// Creates an engine that reports rejected rules through `logger`.
  RuleEngine({required this._logger});

  final AppLogger _logger;

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
  ParseResult<List<Element>> selectAll(
    String rule,
    Node scope, {
    required String rulePath,
  }) {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<Element>>(<Element>[]);
    }

    final _ParsedRule parsed = _parse(rule);
    final _Parsed<List<_SelectorStep>> check = _check(
      parsed,
      field: rulePath,
      hasExtraction: false,
    );

    return switch (check) {
      _ParsedFailure<List<_SelectorStep>>(:final _RuleRejection rejection) =>
        _fail<List<Element>>(rejection, field: rulePath),
      _ParsedValue<List<_SelectorStep>>(:final List<_SelectorStep> value) =>
        ParseSuccess<List<Element>>(
          _run(value, scope, reverse: parsed.reverse),
        ),
    };
  }

  /// Returns every value extracted by the **value** rule [rule] from [scope].
  ///
  /// The last `@`-separated segment is the extraction and every preceding one is a
  /// selector (upstream `getStringList`). Values that extract to an empty string
  /// are dropped, duplicates of an attribute value are dropped, and an empty
  /// result is a success.
  ParseResult<List<String>> extractAll(
    String rule,
    Node scope, {
    required String rulePath,
  }) {
    if (rule.trim().isEmpty) {
      return const ParseSuccess<List<String>>(<String>[]);
    }

    final _ParsedRule parsed = _parse(rule);
    final _Parsed<List<_SelectorStep>> check = _check(
      parsed,
      field: rulePath,
      hasExtraction: true,
    );

    return switch (check) {
      _ParsedFailure<List<_SelectorStep>>(:final _RuleRejection rejection) =>
        _fail<List<String>>(rejection, field: rulePath),
      _ParsedValue<List<_SelectorStep>>(:final List<_SelectorStep> value) =>
        ParseSuccess<List<String>>(_extractAll(value, parsed, scope)),
    };
  }

  /// Returns the first value of [rule], or `null` when nothing matched.
  ///
  /// Upstream `getString`. A `null` data is not a failure: it keeps an optional
  /// book source field (an absent cover, an absent intro) non-fatal, while a
  /// rejected rule still comes back as a [ParseFailure].
  ParseResult<String?> extractFirst(
    String rule,
    Node scope, {
    required String rulePath,
  }) {
    final ParseResult<List<String>> values = extractAll(
      rule,
      scope,
      rulePath: rulePath,
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

  /// Extracts every value of a rule whose selectors already parsed into [steps].
  List<String> _extractAll(
    List<_SelectorStep> steps,
    _ParsedRule parsed,
    Node scope,
  ) {
    return _applyReplacement(
      _extract(
        parsed.segments.last,
        _run(steps, scope, reverse: parsed.reverse),
      ),
      parsed.replacementParts,
    );
  }

  /// Runs [steps] from [scope] and returns the elements they matched.
  ///
  /// With no step the scope itself is the single match, which is what makes an
  /// extraction-only rule such as `href` work (upstream applies the extraction to
  /// the current element).
  ///
  /// A rule that starts with `-` reverses the whole result list (matrix #7) rather
  /// than each step's own matches — that is what “列表倒置” means upstream, and a
  /// reversed chapter list is the case it exists for.
  List<Element> _run(
    List<_SelectorStep> steps,
    Node scope, {
    required bool reverse,
  }) {
    List<Node> current = <Node>[scope];

    for (final _SelectorStep step in steps) {
      final List<Element> next = <Element>[];
      for (final Node node in current) {
        next.addAll(_match(step, node));
      }
      current = next;
    }

    final List<Element> matched = current.whereType<Element>().toList();

    return reverse ? matched.reversed.toList(growable: false) : matched;
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
    // `@css:…` 这类规则以标志头开头，按 `@` 切段会在最前面留一个空段（`''`），
    // 它会被当成畸形段。摘掉这个 `@`，让第一段正好是标志头本身；只在确实是标志头时
    // 才摘，避免把 `@foo` 这种非标志写法当成正常规则。`body` 保留原样，供
    // [_check] 做 body 级标志判定。
    final String segmentBody =
        body.startsWith('@') && _flagSegment.hasMatch(body.substring(1))
        ? body.substring(1)
        : body;

    return _ParsedRule(
      body: body,
      replacementParts: replacementParts,
      reverse: reverse,
      segments: segmentBody
          .split('@')
          .map((String segment) => segment.trim())
          .toList(),
    );
  }

  /// Reads [parsed] into the selector steps it runs, or reports the rejection.
  ///
  /// Validation and evaluation share this one parse, so the two can never disagree
  /// about what a rule means. [hasExtraction] says whether the last segment is the
  /// extraction (value rules) or one more selector (list rules).
  _Parsed<List<_SelectorStep>> _check(
    _ParsedRule parsed, {
    required String field,
    required bool hasExtraction,
  }) {
    final String body = parsed.body;

    for (final String flag in _deferredFlags) {
      if (body.toLowerCase().startsWith(flag)) {
        // 用原文截取，保留作者写的 `@webJs` 这类大小写（book-source.md §3 前缀大小写不敏感）。
        return _ParsedFailure<List<_SelectorStep>>(
          _unsupported(body.substring(0, flag.length)),
        );
      }
    }
    if (body.contains('@@')) {
      // 矩阵 #15：`@@` 默认规则标志。`@` 切分后中段的 `@@` 会留下一个空段，
      // 因此必须在切段之前判掉，否则会被误报成畸形规则。
      return _ParsedFailure<List<_SelectorStep>>(_unsupported('@@'));
    }
    for (final String operator in _deferredOperators) {
      if (body.contains(operator)) {
        return _ParsedFailure<List<_SelectorStep>>(_unsupported(operator));
      }
    }

    final List<String> segments = parsed.segments;
    final List<String> selectorTexts = hasExtraction
        ? segments.sublist(0, segments.length - 1)
        : segments;
    final List<_SelectorStep> steps = <_SelectorStep>[];
    for (final String segment in selectorTexts) {
      final _Parsed<_SelectorStep> read = _readSelector(segment, field: field);
      switch (read) {
        case _ParsedFailure<_SelectorStep>(:final _RuleRejection rejection):
          return _ParsedFailure<List<_SelectorStep>>(rejection);
        case _ParsedValue<_SelectorStep>(:final _SelectorStep value):
          steps.add(value);
      }
    }

    if (hasExtraction) {
      final String extraction = segments.last;
      if (extraction.isEmpty) {
        return _ParsedFailure<List<_SelectorStep>>(_malformed(field));
      }
      final String? flag = _flagOf(extraction);
      if (flag != null) {
        // 末段是提取段，而上游在那里允许**嵌套规则**（矩阵 #30，M2/暂不实现）。
        // 名字必须与中段的 `@css:` 区分开：中段已支持（矩阵 #12），末段仍未支持，
        // 否则 UI 与日志分不清两者（架构师 F3）。
        return _ParsedFailure<List<_SelectorStep>>(_unsupported('nested-rule'));
      }
    }

    return _ParsedValue<List<_SelectorStep>>(steps);
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
      // `@json:` / `@js:` / `@xpath:` … 仍属后续阶段（矩阵 #13 / #14 / #21）。
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
      // 类型段为空又不是索引写法（如 `.li`）：结构性错误，不猜。
      return _ParsedFailure<_SelectorStep>(_malformed(field));
    }
    if (!_implementedTypes.contains(type)) {
      // 未知类型在原版里会退化成原始 CSS 选择器，即矩阵 #12 的能力（Phase 3.2）。
      return _ParsedFailure<_SelectorStep>(_unsupported(type));
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

/// One parsed rule: its body, its leading `-` and its `@`-separated segments.
final class _ParsedRule {
  const _ParsedRule({
    required this.body,
    required this.replacementParts,
    required this.reverse,
    required this.segments,
  });

  /// The rule itself: everything before the first `##`, without the leading `-`.
  final String body;

  /// The `##`-separated parts: `[rule]`, `[regex]`, `[replacement]`.
  final List<String> replacementParts;

  /// Whether the rule starts with `-`, i.e. its result list is reversed (matrix #7).
  final bool reverse;

  /// The trimmed segments of the rule body.
  final List<String> segments;
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
