import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';

/// In-memory [RuleRepository] double (`docs/dev/testing.md` §4).
///
/// It keeps the seeds out of the way: which rules exist is decided by the test, never by the
/// assets. [failWith] makes every write throw, which is how the page's "a failed write leaves the
/// list alone" behaviour is pinned.
final class FakeRuleRepository implements RuleRepository {
  /// Stored rows, in insertion order; ordering is applied by [ofKind].
  final List<Rule> rows = <Rule>[];

  /// Every `reorder` call's id order, in order.
  final List<List<int>> reorderCalls = <List<int>>[];

  /// When set, every write throws it instead of touching [rows].
  Exception? failWith;

  /// When set, every read throws it instead of answering [rows].
  Exception? readFailure;

  int _nextId = 1;

  /// Puts one rule in the store and answers it.
  Rule seed({
    required RuleKind kind,
    required String name,
    required RulePayload payload,
    bool isEnabled = true,
    bool isBuiltIn = false,
  }) {
    final Rule rule = Rule(
      id: _nextId++,
      kind: kind,
      name: name,
      payload: payload,
      isEnabled: isEnabled,
      isBuiltIn: isBuiltIn,
      sortOrder: rows.where((Rule row) => row.kind == kind).length,
    );
    rows.add(rule);

    return rule;
  }

  @override
  Future<List<Rule>> ofKind(RuleKind kind) async {
    final Exception? failure = readFailure;
    if (failure != null) {
      throw failure;
    }

    return <Rule>[
      for (final Rule row in rows)
        if (row.kind == kind) row,
    ]..sort((Rule a, Rule b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> create(RuleDraft draft) async {
    _guard();
    // `sortOrder` 是导入才用得上的字段（ADR-0071 §决策 1）：给了就照给，没给就追加。
    rows.add(
      Rule(
        id: _nextId++,
        kind: draft.kind,
        name: draft.name,
        payload: draft.payload,
        isEnabled: draft.isEnabled,
        isBuiltIn: draft.isBuiltIn,
        sortOrder:
            draft.sortOrder ??
            rows.where((Rule row) => row.kind == draft.kind).length,
      ),
    );
  }

  @override
  Future<void> save(Rule rule) async {
    _guard();
    final int index = rows.indexWhere((Rule row) => row.id == rule.id);
    if (index >= 0) {
      rows[index] = rows[index].copyWith(
        name: rule.name,
        payload: rule.payload,
        isEnabled: rule.isEnabled,
      );
    }
  }

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {
    _guard();
    final int index = rows.indexWhere((Rule row) => row.id == id);
    if (index >= 0) {
      rows[index] = rows[index].copyWith(isEnabled: isEnabled);
    }
  }

  @override
  Future<void> delete(int id) async {
    _guard();
    rows.removeWhere((Rule row) => row.id == id);
  }

  @override
  Future<void> reorder({
    required RuleKind kind,
    required List<int> orderedIds,
  }) async {
    _guard();
    reorderCalls.add(orderedIds);
    for (int index = 0; index < orderedIds.length; index++) {
      final int rowIndex = rows.indexWhere(
        (Rule row) => row.id == orderedIds[index],
      );
      if (rowIndex >= 0) {
        rows[rowIndex] = rows[rowIndex].copyWith(sortOrder: index);
      }
    }
  }

  void _guard() {
    final Exception? failure = failWith;
    if (failure != null) {
      throw failure;
    }
  }
}
