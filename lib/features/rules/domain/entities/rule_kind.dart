/// The four features sharing one rule table (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// The values are the stored `kind` column, so they are part of the database format: renaming one
/// would orphan every row of that kind. [RuleKind.value] is therefore the only place the strings
/// are spelled; `core/storage/rule_dao.dart`'s constants exist for the DAO's own signature and a
/// test pins the two lists together.
enum RuleKind {
  /// 替换净化: text rewrites applied to every chapter body after `replaceRegex`.
  replace('replace'),

  /// 目录规则 (`txt_toc_rule`): how a local `.txt` file's chapters are recognised.
  toc('toc'),

  /// 字典规则: where a selected word is looked up.
  dict('dict'),

  /// 高亮标签: which text a reading view should highlight.
  highlight('highlight');

  const RuleKind(this.value);

  /// The stored `kind` value.
  final String value;

  /// The kind stored as [value], or `null` when the row names something this build does not know.
  ///
  /// Unknown kinds are **not** an error: a newer build may have written them, and a row nobody can
  /// render must stay in the table rather than being deleted on read.
  static RuleKind? fromValue(String value) {
    for (final RuleKind kind in RuleKind.values) {
      if (kind.value == value) {
        return kind;
      }
    }

    return null;
  }
}
