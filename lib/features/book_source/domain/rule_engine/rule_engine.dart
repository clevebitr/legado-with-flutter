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
  '@css:',
  '@json:',
  '@js:',
  '@xpath:',
  '@put:',
  '@get:',
  '@webjs',
];

/// Operators that join several rules; matrix #10 / #11 own them.
const List<String> _deferredOperators = <String>['||', '&&', '%%'];

/// Selector types this phase implements (matrix #2).
const Set<String> _implementedTypes = <String>{'class', 'id', 'tag'};

/// Selector types the matrix knows but a later phase owns (matrix #3 / #4).
const Set<String> _deferredTypes = <String>{'text', 'children'};

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
/// Implemented so far — the five syntaxes the Phase 2 vertical slice needs:
///
/// | Matrix | Syntax |
/// |---|---|
/// | #1 / #2 | selector segments `类型.名称.位置` with the types `class`, `id`, `tag` |
/// | #5 | the position segment, positive and negative (`-1` is the last match) |
/// | #8 | extraction `text`, `textNodes`, `ownText`, `html`, `all`, or an attribute name |
/// | #9 | `##regex##replacement`, with `$1` / `${name}` group references |
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
    final _RuleRejection? rejection = _validate(
      parsed,
      field: rulePath,
      hasExtraction: false,
    );
    if (rejection != null) {
      return _fail<List<Element>>(rejection, field: rulePath);
    }

    return ParseSuccess<List<Element>>(_selectAll(parsed.segments, scope));
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
    final _RuleRejection? rejection = _validate(
      parsed,
      field: rulePath,
      hasExtraction: true,
    );
    if (rejection != null) {
      return _fail<List<String>>(rejection, field: rulePath);
    }

    return ParseSuccess<List<String>>(_extractAll(parsed, scope));
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
        ParseFailure<String?>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<String>>(:final List<String> data) =>
        ParseSuccess<String?>(data.isEmpty ? null : data.first),
    };
  }

  /// Extracts every value of a rule that passed validation.
  List<String> _extractAll(_ParsedRule parsed, Node scope) {
    final List<String> segments = parsed.segments;
    final List<Element> elements = _selectAll(
      segments.sublist(0, segments.length - 1),
      scope,
    );

    return _applyReplacement(
      _extract(segments.last, elements),
      parsed.replacementParts,
    );
  }

  /// Applies [segments] as selector steps, starting from [scope].
  ///
  /// With no segment the scope itself is the single match, which is what makes an
  /// extraction-only rule such as `href` work (upstream applies the extraction to
  /// the current element).
  List<Element> _selectAll(List<String> segments, Node scope) {
    List<Node> current = <Node>[scope];

    for (final String segment in segments) {
      final _SelectorStep step = _step(segment);
      final List<Element> next = <Element>[];
      for (final Node node in current) {
        next.addAll(_match(step, node));
      }
      current = next;
    }

    return current.whereType<Element>().toList();
  }

  /// Returns the elements matched by [step] inside [scope].
  ///
  /// Upstream (jsoup) matches the scope element itself as well as its
  /// descendants, while `cascadia.queryAll` deliberately excludes the root, so the
  /// scope is tested separately.
  List<Element> _match(_SelectorStep step, Node scope) {
    final String selector = _selectorFor(step);
    final List<Element> matched = <Element>[
      if (scope is Element && cascadia.matches(scope, selector)) scope,
      ...cascadia.queryAll(scope, selector),
    ];

    return _applyIndex(matched, step.index);
  }

  /// Keeps only [index] of [matched], counting from the end when it is negative.
  ///
  /// Out-of-range positions yield no match instead of an error, which is upstream
  /// behaviour and lets a rule degrade to "nothing found".
  List<Element> _applyIndex(List<Element> matched, int? index) {
    if (index == null) {
      return matched;
    }

    final int resolved = index < 0 ? matched.length + index : index;
    if (resolved < 0 || resolved >= matched.length) {
      return const <Element>[];
    }

    return <Element>[matched[resolved]];
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
          _addValue(values, _collapseWhitespace(_ownTextNodes(element).join()));
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
    'class' => '.${cascadia.escapeCssIdent(step.name)}',
    'id' => '#${cascadia.escapeCssIdent(step.name)}',
    _ => cascadia.escapeCssIdent(step.name),
  };

  /// Splits [rule] into its `##` parts and its `@`-separated segments.
  ///
  /// Total on purpose: a rejected rule still needs its segments to name the
  /// offending syntax.
  _ParsedRule _parse(String rule) {
    final List<String> replacementParts = rule.split('##');

    return _ParsedRule(
      replacementParts: replacementParts,
      segments: replacementParts.first
          .split('@')
          .map((String segment) => segment.trim())
          .toList(),
    );
  }

  /// Reads an already-validated selector segment into its parts.
  _SelectorStep _step(String segment) {
    final List<String> parts = segment.split('.');

    return _SelectorStep(
      type: parts[0],
      name: parts.length > 1 ? parts[1] : '',
      // 校验阶段已确认第三段是整数，这里让它直接抛出，避免再写一条不可达分支。
      index: parts.length > 2 ? int.parse(parts[2]) : null,
    );
  }

  /// Returns why [parsed] cannot be evaluated yet, or `null` when it can.
  ///
  /// [hasExtraction] says whether the last segment is the extraction (value rules)
  /// or one more selector (list rules).
  _RuleRejection? _validate(
    _ParsedRule parsed, {
    required String field,
    required bool hasExtraction,
  }) {
    final String body = parsed.body;

    if (parsed.replacementParts.length > 3) {
      return _unsupported('###');
    }
    for (final String flag in _deferredFlags) {
      if (body.toLowerCase().startsWith(flag)) {
        // 用原文截取，保留作者写的 `@webJs` 这类大小写（book-source.md §3 前缀大小写不敏感）。
        return _unsupported(body.substring(0, flag.length));
      }
    }
    for (final String operator in _deferredOperators) {
      if (body.contains(operator)) {
        return _unsupported(operator);
      }
    }
    if (body.startsWith('-')) {
      // 矩阵 #7：首字符 `-` 使结果倒置，Phase 3.1 实现。
      return _unsupported('-');
    }

    final List<String> segments = parsed.segments;
    final List<String> selectors = hasExtraction
        ? segments.sublist(0, segments.length - 1)
        : segments;
    for (final String segment in selectors) {
      final _RuleRejection? rejection = _validateSelector(
        segment,
        field: field,
      );
      if (rejection != null) {
        return rejection;
      }
    }

    if (hasExtraction) {
      final String extraction = segments.last;
      if (extraction.isEmpty) {
        return _malformed(field);
      }
      final String? flag = _flagOf(extraction);
      if (flag != null) {
        // `class.a@css:.b`：原版把末段当作嵌套规则，Phase 3.2 实现。
        return _unsupported(flag);
      }
    }

    return null;
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

  /// Returns why one selector segment cannot be evaluated, or `null` when it can.
  _RuleRejection? _validateSelector(String segment, {required String field}) {
    if (segment.isEmpty) {
      return _malformed(field);
    }
    final String? flag = _flagOf(segment);
    if (flag != null) {
      // 例如 `class.a@css:.b`：原版把这种段当作嵌套规则，Phase 3.2 实现。
      return _unsupported(flag);
    }
    if (segment.contains('!') || segment.contains(':')) {
      // 矩阵 #6：`!` 排除与 `:` 分隔的序号列表，Phase 3.1 实现。
      return _unsupported('!');
    }
    if (segment.contains('[') || segment.contains(']')) {
      // 原版的 `[]` 索引列表写法不在本仓矩阵内，显式拒绝而不是当作选择器。
      return _unsupported('[]');
    }

    final List<String> parts = segment.split('.');
    final String type = parts[0];
    if (_deferredTypes.contains(type)) {
      return _unsupported(type);
    }
    if (!_implementedTypes.contains(type)) {
      // 未知类型在原版里会退化成原始 CSS 选择器，即矩阵 #12 的能力。
      return _unsupported(type);
    }
    if (parts.length > 3 || parts.length < 2 || parts[1].isEmpty) {
      return _malformed(field);
    }
    if (parts.length == 3 && int.tryParse(parts[2]) == null) {
      return _malformed(field);
    }

    return null;
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

    return ParseFailure<T>(kind: rejection.kind, rulePath: rejection.rulePath);
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

/// One parsed rule: its `##` parts and the `@`-separated segments of the body.
final class _ParsedRule {
  const _ParsedRule({required this.replacementParts, required this.segments});

  /// The `##`-separated parts: `[rule]`, `[regex]`, `[replacement]`.
  final List<String> replacementParts;

  /// The trimmed segments of the rule body.
  final List<String> segments;

  /// The rule itself, i.e. the part before the first `##`.
  String get body => replacementParts.first.trim();
}

/// One selector segment: `类型.名称.位置` (matrix #1).
final class _SelectorStep {
  const _SelectorStep({
    required this.type,
    required this.name,
    required this.index,
  });

  /// `class`, `id` or `tag` — validated before this step is built.
  final String type;

  /// The class name, id or tag name.
  final String name;

  /// The position within the matches, or `null` for "all of them".
  final int? index;
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

  return values
      .map((String value) => _replace(value, pattern, replacement))
      .toList(growable: false);
}

/// Replaces every match of [pattern] in [value] with [replacement].
///
/// An unparsable pattern degrades to a literal replacement, which is what
/// upstream does when its regex cache cannot compile the pattern.
String _replace(String value, String pattern, String replacement) {
  final RegExp? regex = _compile(pattern);
  if (regex == null) {
    return value.replaceAll(pattern, replacement);
  }

  return value.replaceAllMapped(
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
