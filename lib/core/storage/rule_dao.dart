import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/rules.dart';

part 'rule_dao.g.dart';

/// The four kinds [RuleDao] stores (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
abstract final class RuleKind {
  /// 替换净化: `payload = {pattern, replacement, isRegex, timeoutMs?}`.
  static const String replace = 'replace';

  /// 目录规则 (`txt_toc_rule`): `payload = {rule, serialNumber?}`.
  static const String toc = 'toc';

  /// 字典规则: `payload = {urlRule, showRule, ruleGroupType?}`.
  static const String dict = 'dict';

  /// 高亮标签: `payload = {pattern, colorHex?, group?}`.
  static const String highlight = 'highlight';

  /// Every kind, in the order the management page lists them.
  static const List<String> all = <String>[replace, toc, dict, highlight];
}

/// Reads and writes [Rules] rows.
///
/// The page never touches the table directly: the DAO is where "what a kind is" and "what order
/// means" are decided, so the列表 / 编辑 / 启停 pages stay the same code for all four kinds.
@DriftAccessor(tables: <Type>[Rules])
class RuleDao extends DatabaseAccessor<ReaderDatabase> with _$RuleDaoMixin {
  /// Creates the DAO on top of [attachedDatabase].
  RuleDao(super.attachedDatabase);

  /// Every rule of [kind], in manual order then by creation (oldest first).
  ///
  /// [kind] is required: a page always manages one kind, and an accidental "all rules" query is
  /// what makes a purge pattern show up in the highlight editor.
  Future<List<RuleRow>> ofKind(String kind) {
    final SimpleSelectStatement<$RulesTable, RuleRow> query = select(rules)
      ..where((Rules table) => table.kind.equals(kind))
      ..orderBy(<OrderClauseGenerator<$RulesTable>>[
        (Rules table) => OrderingTerm.asc(table.sortOrder),
        (Rules table) => OrderingTerm.asc(table.createdAt),
      ]);

    return query.get();
  }

  /// The **enabled** rules of [kind], in the same order [ofKind] answers.
  Future<List<RuleRow>> enabledOfKind(String kind) {
    final SimpleSelectStatement<$RulesTable, RuleRow> query = select(rules)
      ..where(
        (Rules table) => table.kind.equals(kind) & table.isEnabled.equals(true),
      )
      ..orderBy(<OrderClauseGenerator<$RulesTable>>[
        (Rules table) => OrderingTerm.asc(table.sortOrder),
        (Rules table) => OrderingTerm.asc(table.createdAt),
      ]);

    return query.get();
  }

  /// Inserts one rule and answers its id.
  ///
  /// A missing [sortOrder] appends to the end of its kind, which is what「新增」should do; a rule
  /// inserted in the middle has to be reordered explicitly (M20 only needs append).
  Future<int> insert({
    required String kind,
    required String name,
    required Map<String, Object?> payload,
    bool isEnabled = true,
    bool isBuiltIn = false,
    int? sortOrder,
    DateTime? now,
  }) async {
    final DateTime createdAt = now ?? DateTime.now();
    final int order = sortOrder ?? await _nextSortOrder(kind);

    return into(rules).insert(
      RulesCompanion.insert(
        kind: kind,
        name: name,
        payload: jsonEncode(payload),
        isEnabled: Value<bool>(isEnabled),
        isBuiltIn: Value<bool>(isBuiltIn),
        sortOrder: Value<int>(order),
        createdAt: createdAt,
      ),
    );
  }

  /// Replaces the editable fields of one row; `null` leaves a field alone.
  Future<void> updateRow(
    int id, {
    String? name,
    Map<String, Object?>? payload,
    bool? isEnabled,
  }) => (update(rules)..where((Rules table) => table.id.equals(id))).write(
    RulesCompanion(
      name: name == null ? const Value<String>.absent() : Value<String>(name),
      payload: payload == null
          ? const Value<String>.absent()
          : Value<String>(jsonEncode(payload)),
      isEnabled: isEnabled == null
          ? const Value<bool>.absent()
          : Value<bool>(isEnabled),
    ),
  );

  /// Deletes one rule; answers whether a row was removed.
  Future<bool> deleteById(int id) =>
      (delete(rules)..where((Rules table) => table.id.equals(id))).go().then(
        (int removed) => removed > 0,
      );

  /// Deletes every rule of [kind] (the 编辑页「恢复默认」uses it before re-seeding).
  Future<int> deleteKind(String kind) =>
      (delete(rules)..where((Rules table) => table.kind.equals(kind))).go();

  /// Whether [kind] has any row at all, enabled or not.
  ///
  /// Seeding needs this and not [ofKind]: a kind the user emptied on purpose must not be
  /// re-seeded on the next launch (ADR-0070 §决策 4).
  Future<bool> hasAny(String kind) async {
    final RuleRow? row =
        await (select(rules)
              ..where((Rules table) => table.kind.equals(kind))
              ..limit(1))
            .getSingleOrNull();

    return row != null;
  }

  /// One past the highest [Rules.sortOrder] of [kind].
  Future<int> _nextSortOrder(String kind) async {
    final RuleRow? last =
        await (select(rules)
              ..where((Rules table) => table.kind.equals(kind))
              ..orderBy(<OrderClauseGenerator<$RulesTable>>[
                (Rules table) => OrderingTerm.desc(table.sortOrder),
              ])
              ..limit(1))
            .getSingleOrNull();

    return last == null ? 0 : last.sortOrder + 1;
  }
}
