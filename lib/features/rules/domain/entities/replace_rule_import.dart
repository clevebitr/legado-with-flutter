import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'replace_rule_import.freezed.dart';

/// Why one entry of an imported document cannot be stored (`docs/dev/roadmap.md` M23, ADR-0071).
///
/// A reason is a **kind**, not a sentence: the page turns it into text, so a translated build says
/// the same thing without the domain carrying user-visible strings (C-ERR-7 的同一口径).
enum ReplaceRuleImportProblem {
  /// The entry is not a JSON object at all.
  notAnObject,

  /// The entry names no pattern (neither `pattern` nor the legacy `regex`).
  missingPattern,
}

/// One entry of an imported replace-rule document, as the preview shows it.
@freezed
abstract class ReplaceRuleImportEntry with _$ReplaceRuleImportEntry {
  const ReplaceRuleImportEntry._();

  /// Creates one preview entry.
  const factory ReplaceRuleImportEntry({
    /// Where the entry sat in the document; the page's selection is a set of these.
    required int index,

    /// The rule's name (`name`, or the legacy `replaceSummary`); may be empty.
    required String name,

    /// The typed payload, or `null` when the entry cannot be stored (see [problem]).
    required RulePayload? payload,

    /// Whether the rule will be in effect after the import.
    required bool isEnabled,

    /// The file's `order` (legacy `serialNumber`), or `null` to append.
    int? sortOrder,

    /// Whether a stored rule has the same `name` + `pattern` and will be rewritten.
    required bool isUpdate,

    /// Why the entry is unusable; `null` for a usable one.
    ReplaceRuleImportProblem? problem,
  }) = _ReplaceRuleImportEntry;

  /// Whether this entry can be stored.
  bool get isUsable => payload != null;
}

/// One document's worth of entries, before anything is written
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
@freezed
abstract class ReplaceRuleImportPreview with _$ReplaceRuleImportPreview {
  const ReplaceRuleImportPreview._();

  /// Creates a preview.
  const factory ReplaceRuleImportPreview({
    /// Every entry of the document, usable or not, in document order.
    required List<ReplaceRuleImportEntry> entries,
  }) = _ReplaceRuleImportPreview;

  /// How many entries can be stored.
  int get usableCount =>
      entries.where((ReplaceRuleImportEntry entry) => entry.isUsable).length;

  /// How many entries cannot be stored.
  int get rejectedCount => entries.length - usableCount;
}

/// What one commit did.
@freezed
abstract class ReplaceRuleImportReport with _$ReplaceRuleImportReport {
  const ReplaceRuleImportReport._();

  /// Creates a report.
  const factory ReplaceRuleImportReport({
    /// How many rules were appended.
    required int created,

    /// How many rules were rewritten in place (same `name` + `pattern`).
    required int updated,

    /// How many entries of the document could not be stored at all.
    required int skipped,
  }) = _ReplaceRuleImportReport;

  /// The count reported as 「导入」; updates count too.
  int get imported => created + updated;
}
