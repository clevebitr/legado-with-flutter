import 'dart:async';
import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

/// The prefix that marks a purge rule's replacement as a script (`@js:`).
const String _scriptFlag = '@js:';

/// The `rulePath` every purge degradation is logged under.
const String _rulePath = 'rules.purge';

/// Applies the user's 替换净化 rules to chapter bodies and titles
/// (`docs/dev/roadmap.md` M20/M23, ADR-0070 §决策 3, ADR-0071 §决策 4/§决策 5).
///
/// Three properties are fixed by those ADRs and visible in the signature:
///
/// * **where the rules run** — after the source's own `replaceRegex` and before the body is cached,
///   so what the reader shows and what the cache holds are the same text (which is why a rule edit
///   has to retire the cache, ADR-0070 增补 §7);
/// * **which rules run** — the scope flags decide (ADR-0071 §决策 4), and a title batch is one pass
///   over the whole chapter list rather than one pass per title;
/// * **how a `@js:` replacement runs** — one sandbox job per rule per batch: the chapter's matches
///   become an array the script walks (ADR-0071 §决策 5), because the sandbox is an isolate and a
///   per-match round trip would cost thousands of them for one chapter.
///
/// Degradation follows ADR-0026 §决策 2: a rule this build cannot run is **skipped with a warning**,
/// never turned into a failed chapter.
final class ContentPurifier {
  /// Creates the purifier.
  const ContentPurifier({
    this.rules = const UnboundPurgeRuleSource(),
    this.logger,
    this.js,
  });

  /// Where the enabled rules come from.
  final PurgeRuleSource rules;

  /// Where degradations are recorded.
  final AppLogger? logger;

  /// The sandbox `@js:` replacements run in; `null` skips them with a warning.
  final JsBridge? js;

  /// Returns [text] (a chapter body) with every content-scoped purge rule applied in order.
  Future<String> purgeContent(
    String text, {
    required JsPageContext context,
  }) async {
    final List<PurgeRule> purgeRules = <PurgeRule>[
      for (final PurgeRule rule in await rules.purgeRules())
        if (rule.appliesToContent) rule,
    ];
    if (purgeRules.isEmpty || text.isEmpty) {
      return text;
    }

    return (await _run(<String>[text], purgeRules, context)).single;
  }

  /// Returns [titles] with every title-scoped purge rule applied, in the same order.
  ///
  /// The whole list is one batch: a 2000-chapter book must not ask the sandbox for one job per title
  /// (ADR-0071 §决策 4/§决策 5).
  Future<List<String>> purgeTitles(
    List<String> titles, {
    required JsPageContext context,
  }) async {
    final List<PurgeRule> purgeRules = <PurgeRule>[
      for (final PurgeRule rule in await rules.purgeRules())
        if (rule.appliesToTitle) rule,
    ];
    if (purgeRules.isEmpty || titles.isEmpty) {
      return titles;
    }

    return _run(titles, purgeRules, context);
  }

  /// Applies [purgeRules] to every text of [texts], one rule at a time.
  Future<List<String>> _run(
    List<String> texts,
    List<PurgeRule> purgeRules,
    JsPageContext context,
  ) async {
    List<String> result = texts;
    for (final PurgeRule rule in purgeRules) {
      result = rule.replacement.startsWith(_scriptFlag)
          ? await _runScript(result, rule, context)
          : <String>[for (final String text in result) _apply(text, rule)];
    }

    return result;
  }

  /// Runs one `@js:` rule over the whole batch with a **single** sandbox job.
  ///
  /// Every match of every text is collected in order, the script answers one replacement per match,
  /// and the texts are rebuilt from that answer. A script that fails, times out, or answers a list of
  /// the wrong length leaves the batch untouched — the rule is skipped, not the chapter.
  Future<List<String>> _runScript(
    List<String> texts,
    PurgeRule rule,
    JsPageContext context,
  ) async {
    final RegExp regex;
    try {
      regex = RegExp(rule.pattern);
    } on FormatException catch (error) {
      logger?.warning('Purge rule skipped: invalid regular expression', error);

      return texts;
    }

    final List<List<RegExpMatch>> perText = <List<RegExpMatch>>[
      for (final String text in texts) regex.allMatches(text).toList(),
    ];
    final int total = perText.fold<int>(
      0,
      (int sum, List<RegExpMatch> matches) => sum + matches.length,
    );
    if (total == 0) {
      return texts;
    }

    final JsBridge? js = this.js;
    if (js == null) {
      // 没有沙箱（例如只接了正则的宿主）时不能按字面量替换——那会把脚本文本写进正文。
      logger?.warning('Purge rule skipped: no sandbox for a @js: replacement');

      return texts;
    }

    final List<String> matches = <String>[
      for (final List<RegExpMatch> textMatches in perText)
        for (final RegExpMatch match in textMatches) match.group(0) ?? '',
    ];

    final List<String>? replacements = await _evaluateScript(
      js: js,
      rule: rule,
      matches: matches,
      context: context,
    );
    if (replacements == null || replacements.length != matches.length) {
      if (replacements != null) {
        logger?.warning(
          'Purge rule skipped: the script answered the wrong count',
        );
      }

      return texts;
    }

    final List<String> rebuilt = <String>[];
    var cursor = 0;
    for (var index = 0; index < texts.length; index++) {
      final StringBuffer buffer = StringBuffer();
      var consumed = 0;
      for (final RegExpMatch match in perText[index]) {
        buffer
          ..write(texts[index].substring(consumed, match.start))
          ..write(replacements[cursor++]);
        consumed = match.end;
      }
      buffer.write(texts[index].substring(consumed));
      rebuilt.add(buffer.toString());
    }

    return rebuilt;
  }

  /// Evaluates one batched script and answers its replacements, or `null` when it degraded.
  Future<List<String>?> _evaluateScript({
    required JsBridge js,
    required PurgeRule rule,
    required List<String> matches,
    required JsPageContext context,
  }) async {
    final JsJob job = JsJob(
      script: _scriptOf(
        rule.replacement.substring(_scriptFlag.length),
        matches,
      ),
      rulePath: _rulePath,
      baseUrl: context.baseUrl,
      page: context.page,
      source: context.source,
      bookName: context.bookName,
      chapterTitle: context.chapterTitle,
      book: context.book,
    );

    try {
      final Future<ParseResult<Object?>> evaluation = js.evaluate(job);
      final int? timeoutMs = rule.timeoutMs;
      final ParseResult<Object?> answer = timeoutMs == null || timeoutMs <= 0
          ? await evaluation
          : await evaluation.timeout(Duration(milliseconds: timeoutMs));

      return switch (answer) {
        // 桥自己的失败（脚本抛错 / 被拒的 API）也走这里：跳过该规则。
        ParseFailure<Object?>() => _reject(),
        ParseSuccess<Object?>(:final Object? data) => switch (data) {
          final List<Object?> list => <String>[
            for (final Object? item in list) item?.toString() ?? '',
          ],
          _ => _reject(),
        },
      };
    } on TimeoutException {
      // `timeoutMs` 终于有了用处：一条跑不完的脚本按上游的做法禁用掉，而不是卡住整章。
      logger?.warning('Purge rule skipped: the script timed out');

      return null;
    }
  }

  /// Logs a script answer this build cannot use and answers `null`.
  List<String>? _reject() {
    logger?.warning('Purge rule skipped: the script answered no list');

    return null;
  }

  /// The one job's script: walk the matches, evaluate the rule's expression for each of them.
  ///
  /// `result` is the match text, as upstream binds it (`RegexExtensions.kt:52`), and `eval` is used
  /// for its **completion value**: a purge replacement is often written as
  /// `if (cond) { … } else { "" }`, which is a statement — `new Function` would need every rule to
  /// `return`.
  String _scriptOf(String expression, List<String> matches) => <String>[
    'var __matches = ${jsonEncode(matches)};',
    'var __out = [];',
    'for (var __i = 0; __i < __matches.length; __i++) {',
    '  var result = __matches[__i];',
    '  __out.push(eval(${jsonEncode(expression)}));',
    '}',
    '__out;',
  ].join('\n');

  /// Applies one non-script rule to [text].
  String _apply(String text, PurgeRule rule) {
    // 空 pattern 在上游直接被跳过；正则化它只会命中「每个位置」并把正文清空。
    if (rule.pattern.isEmpty) {
      return text;
    }

    if (!rule.isRegex) {
      return text.replaceAll(rule.pattern, rule.replacement);
    }

    // 上游 `ReplaceRule.isValid()` 也拒两种正则：语法错误，以及以未转义的 `|` 结尾（会让回溯爆掉）。
    // Dart 的 RegExp 没有超时，所以这两种在**应用前**拒掉，而不是等它在 UI isolate 上卡住。
    if (rule.pattern.endsWith('|') && !rule.pattern.endsWith(r'\|')) {
      logger?.warning(
        'Purge rule skipped: pattern ends with a bare "|" (${rule.pattern})',
      );

      return text;
    }

    final RegExp regex;
    try {
      regex = RegExp(rule.pattern);
    } on FormatException catch (error) {
      logger?.warning(
        'Purge rule skipped: invalid regular expression (${rule.pattern})',
        error,
      );

      return text;
    }

    // 手写 appendReplacement 而不是 `replaceAllMapped`：后者把回调声明成 `Match`，
    // 而分组引用需要 `RegExpMatch`（`allMatches` 直接给的就是它），省掉一次向下强转。
    final StringBuffer buffer = StringBuffer();
    int consumed = 0;
    for (final RegExpMatch match in regex.allMatches(text)) {
      buffer
        ..write(text.substring(consumed, match.start))
        ..write(_expand(rule.replacement, match));
      consumed = match.end;
    }
    buffer.write(text.substring(consumed));

    return buffer.toString();
  }

  /// Expands the replacement the way Java's `Matcher.appendReplacement` does.
  ///
  /// Upstream runs every purge rule through `appendReplacement`, where `$1` / `${name}` name a
  /// capture group and `\$` is a literal dollar. Dart's `replaceAll` treats the replacement as a
  /// literal, so the expansion has to happen here or `$1` would land in the text verbatim.
  String _expand(String replacement, RegExpMatch match) {
    if (!replacement.contains(r'$') && !replacement.contains('\\')) {
      // 没有 $ 也没有反斜杠就没有可展开的东西：绝大多数规则走这条短路。
      return replacement;
    }

    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < replacement.length; index++) {
      final String character = replacement[index];

      if (character == '\\' && index + 1 < replacement.length) {
        final String nextCharacter = replacement[index + 1];
        if (nextCharacter == r'$') {
          buffer.write(r'$');
          index++;
          continue;
        }
      }

      if (character != r'$') {
        buffer.write(character);
        continue;
      }

      final int expanded = _expandGroup(replacement, index, match, buffer);
      if (expanded > index) {
        index = expanded;
      } else {
        // 孤立的 `$`（后面既不是数字也不是 `{`）：Java 会抛错，这里按字面保留更宽容。
        buffer.write(character);
      }
    }

    return buffer.toString();
  }

  /// Writes one `$n` / `${name}` group and answers the index it consumed (or [start] when the `$`
  /// names nothing).
  int _expandGroup(
    String replacement,
    int start,
    RegExpMatch match,
    StringBuffer buffer,
  ) {
    final int next = start + 1;
    if (next >= replacement.length) {
      return start;
    }

    if (replacement[next] == '{') {
      final int close = replacement.indexOf('}', next);
      if (close < 0) {
        return start;
      }
      final String name = replacement.substring(next + 1, close);
      buffer.write(match.namedGroup(name) ?? '');

      return close;
    }

    int end = next;
    while (end < replacement.length && _isDigit(replacement[end])) {
      end++;
    }
    if (end == next) {
      return start;
    }

    final int group = int.parse(replacement.substring(next, end));
    // 越界的组号上游会抛错；这里退化成空串，与「这个组没参与匹配」同一结果。
    buffer.write(group <= match.groupCount ? (match.group(group) ?? '') : '');

    return end - 1;
  }

  bool _isDigit(String character) {
    final int code = character.codeUnitAt(0);

    return code >= 0x30 && code <= 0x39;
  }
}
