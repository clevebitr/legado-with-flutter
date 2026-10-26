// coverage:ignore-file
import 'package:drift/drift.dart';

/// One user-editable rule of any kind (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// Four features share this table — 替换净化 / 目录规则 / 字典规则 / 高亮标签 — because their
/// **CRUD, ordering and enable switch are identical**; only the edit form differs, and that
/// difference lives in [payload] (a JSON object, shape owned by ADR-0070).
///
/// A payload this build does not understand must **not** make the row invisible: the list shows it
/// as broken so the user can still edit or delete it (the same stance as the book source's `extra`).
@DataClassName('RuleRow')
@TableIndex(name: 'rules_kind_order', columns: {#kind, #sortOrder})
class Rules extends Table {
  /// Synthetic primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Which feature owns the row: `replace` / `toc` / `dict` / `highlight`.
  TextColumn get kind => text()();

  /// The display name (a purge rule's name, a dictionary's name, a tag's name).
  TextColumn get name => text()();

  /// The kind-specific fields as JSON (see ADR-0070 §决策 1 for each kind's keys).
  TextColumn get payload => text()();

  /// Whether the rule takes effect.
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// Whether the row came with the app; it is still editable and deletable.
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Manual order inside one [kind]; smaller runs first.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// When the row was created (used to keep inserts in a stable order).
  DateTimeColumn get createdAt => dateTime()();
}
