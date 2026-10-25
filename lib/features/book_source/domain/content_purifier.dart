import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';

/// Applies the user's 替换净化 rules to a finished chapter body
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 3).
///
/// The position is fixed by the ADR: **after** the source's own `replaceRegex` and **before** the
/// body is cached, so what the reader shows and what the cache holds are the same text. That also
/// means a purge-rule edit has to retire the cached bodies — the rules feature does that through
/// `ChapterBodyInvalidator` (ADR-0070 增补 §7).
///
/// Degradation follows ADR-0026 §决策 2: a rule this build cannot run is **skipped with a warning**,
/// never turned into a failed chapter. Reading a chapter with one fewer rewrite is the smaller
/// failure, and it keeps one bad user-written pattern from hiding every book.
final class ContentPurifier {
  /// Creates the purifier.
  const ContentPurifier({
    this.rules = const UnboundPurgeRuleSource(),
    this.logger,
  });

  /// Where the enabled rules come from.
  final PurgeRuleSource rules;

  /// Where degradations are recorded.
  final AppLogger? logger;

  /// Returns [text] with every enabled purge rule applied in order.
  Future<String> purge(String text) async {
    final List<PurgeRule> purgeRules = await rules.purgeRules();
    if (purgeRules.isEmpty || text.isEmpty) {
      return text;
    }

    String result = text;
    for (final PurgeRule rule in purgeRules) {
      result = _apply(text: result, rule: rule);
    }

    return result;
  }

  String _apply({required String text, required PurgeRule rule}) {
    // 空 pattern 在上游直接被跳过；正则化它只会命中「每个位置」并把正文清空。
    if (rule.pattern.isEmpty) {
      return text;
    }

    // 上游的 `replacement` 以 `@js:` 开头时是「每个匹配跑一段脚本」（`RegexExtensions.kt:32-58`）。
    // 本仓没有这条通道，按字面替换会把整段脚本源码写进正文——那比不替换坏得多，所以显式跳过
    // 并记 warning（ADR-0026 §决策 2、ADR-0070 增补 §7 的登记项）。
    if (rule.replacement.startsWith('@js:')) {
      logger?.warning(
        'Purge rule skipped: @js: replacements are not supported '
        '(${rule.pattern})',
      );

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
