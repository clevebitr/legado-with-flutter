import 'package:flutter_reader/core/logging/app_logger.dart';

/// One replace rule as the reader sees it (ADR-0094 §决策 1).
///
/// Primitives only: the reader must not see `rules`' entity (C-ARCH-2), and a switch needs nothing
/// more than "which rule", "what it does" and "is it on".
final class PurgeRuleSwitch {
  /// Creates one rule row.
  const PurgeRuleSwitch({
    required this.id,
    required this.pattern,
    required this.isEnabled,
    this.replacement,
  });

  /// The rule's stored id, which is what a write takes.
  final int id;

  /// The pattern the rule matches — the text the panel shows.
  final String pattern;

  /// What the rule replaces the match with, when it declared a replacement.
  final String? replacement;

  /// Whether the rule is applied to chapter bodies right now.
  final bool isEnabled;
}

/// Turns the user's 替换净化 rules on and off **without leaving the reader**
/// (`docs/dev/roadmap.md` §3.12, ADR-0094).
///
/// The port carries the two things a reader can do: read the list, flip one rule. Everything else
/// (create / edit / delete / reorder) stays in the rules feature — the reader is not a second rule
/// manager.
abstract interface class PurgeRuleSwitches {
  /// Every replace rule, in the order the rules page shows them.
  Future<List<PurgeRuleSwitch>> list();

  /// Writes [enabled] for rule [id] and answers whether the switch changed anything.
  ///
  /// The implementation also drops the cached chapter bodies of the book being read, because a
  /// cached body was purified with the old rules — otherwise flipping the switch would visibly do
  /// nothing until the cache expired (ADR-0094 §决策 1).
  Future<bool> setEnabled({
    required int id,
    required bool enabled,
    required String sourceUrl,
    required String bookUrl,
  });
}

/// The answer when nothing bound [PurgeRuleSwitches]: an empty list, a warning, no writes.
///
/// It matches the other ports' habit (ADR-0041 §决策 2): a forgotten binding shows an empty panel and
/// logs one line instead of throwing inside the reader.
final class UnboundPurgeRuleSwitches implements PurgeRuleSwitches {
  /// Creates the unbound port; `_logger` receives the warning.
  const UnboundPurgeRuleSwitches({required this._logger});

  final AppLogger _logger;

  @override
  Future<List<PurgeRuleSwitch>> list() async {
    _logger.warning(
      'No PurgeRuleSwitches is bound: the reader shows no replace rules.',
    );

    return const <PurgeRuleSwitch>[];
  }

  @override
  Future<bool> setEnabled({
    required int id,
    required bool enabled,
    required String sourceUrl,
    required String bookUrl,
  }) async {
    _logger.warning(
      'No PurgeRuleSwitches is bound: toggling a rule did nothing.',
    );

    return false;
  }
}
