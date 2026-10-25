import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';

/// Reads and writes the stored rules (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// The four kinds share one interface on purpose: their CRUD, ordering and enable switch are the
/// same operation, and only the edit form differs. A page therefore never sees the table.
abstract interface class RuleRepository {
  /// Every rule of [kind] — enabled or not — in manual order (oldest first on a tie).
  ///
  /// The first call also seeds the rules that ship with the app, so a fresh install has the upstream
  /// 目录 / 字典 rules without either of them being written by a migration (ADR-0070 §决策 4).
  Future<List<Rule>> ofKind(RuleKind kind);

  /// Appends [draft] to the end of its kind.
  ///
  /// The caller reloads the list rather than being handed the row: `sort_order` is the table's
  /// business, and a page that inserted one rule has to show the whole list anyway.
  Future<void> create(RuleDraft draft);

  /// Saves the editable fields (name, payload, enable switch) of [rule].
  ///
  /// The kind never changes: a purge rule cannot become a dictionary entry, so a payload of another
  /// kind is rejected by the implementation instead of silently rewriting the row's owner.
  Future<void> save(Rule rule);

  /// Turns one rule on or off without touching its payload.
  Future<void> setEnabled({required int id, required bool isEnabled});

  /// Deletes one rule; a rule that ships with the app is deleted just the same.
  Future<void> delete(int id);
}
