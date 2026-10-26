import 'package:flutter_reader/core/logging/app_logger.dart';

/// One 替换净化 rule as the chapter pipeline needs it (`docs/dev/roadmap.md` M20, ADR-0070 §决策 3).
///
/// Only the fields the pipeline acts on: the rule's name, its sort order and its scope flags are the
/// rules feature's business. The two scope flags **are** here, because they decide where a rule runs
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 4).
final class PurgeRule {
  /// Creates one purge rule.
  const PurgeRule({
    required this.pattern,
    required this.replacement,
    required this.isRegex,
    this.appliesToContent = true,
    this.appliesToTitle = false,
    this.timeoutMs,
  });

  /// What to look for: a regular expression when [isRegex], otherwise a literal substring.
  final String pattern;

  /// What to put in its place.
  final String replacement;

  /// Whether [pattern] is a regular expression.
  final bool isRegex;

  /// Whether the rule rewrites a chapter **body** (upstream's `scopeContent`, default true).
  final bool appliesToContent;

  /// Whether the rule rewrites a chapter **title** (upstream's `scopeTitle`, default false).
  final bool appliesToTitle;

  /// Upstream's per-rule limit, in milliseconds, for a `@js:` replacement (ADR-0071 §决策 5).
  ///
  /// A regular-expression rule ignores it: Dart's `RegExp` has no timeout.
  final int? timeoutMs;

  @override
  bool operator ==(Object other) =>
      other is PurgeRule &&
      other.pattern == pattern &&
      other.replacement == replacement &&
      other.isRegex == isRegex &&
      other.appliesToContent == appliesToContent &&
      other.appliesToTitle == appliesToTitle &&
      other.timeoutMs == timeoutMs;

  @override
  int get hashCode => Object.hash(
    pattern,
    replacement,
    isRegex,
    appliesToContent,
    appliesToTitle,
    timeoutMs,
  );

  @override
  String toString() =>
      'PurgeRule($pattern -> $replacement, isRegex: $isRegex, '
      'content: $appliesToContent, title: $appliesToTitle, timeoutMs: $timeoutMs)';
}

/// The enabled purge rules the chapter pipeline applies (`docs/dev/roadmap.md` M20).
///
/// The rules live in the rules feature and the reading pipeline lives here, so the pipeline declares
/// this port and the composition root binds it (C-ARCH-2, ADR-0041 §决策 2).
abstract interface class PurgeRuleSource {
  /// The enabled purge rules, in the order the user arranged them.
  ///
  /// An empty list means "nothing to purge", which is also what a missing binding answers: a
  /// chapter without the user's rewrites is still a readable chapter (ADR-0070 §决策 3).
  Future<List<PurgeRule>> purgeRules();
}

/// The source used when a binding is missing: no rules, plus a debug record.
final class UnboundPurgeRuleSource implements PurgeRuleSource {
  /// Creates the unbound source; a bound logger records the missing binding.
  const UnboundPurgeRuleSource({this.logger});

  /// Where the record goes, when anyone is listening.
  final AppLogger? logger;

  @override
  Future<List<PurgeRule>> purgeRules() async {
    // debug 而不是 warning：正文在这种状态下照样可读，不该让每条章节都刷一条警告。
    logger?.debug(
      'Purge rules are unbound: chapter bodies keep the source text',
    );

    return const <PurgeRule>[];
  }
}
