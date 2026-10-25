import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rule_payload.freezed.dart';

/// The kind-specific fields of one rule, typed (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// The stored shape is JSON so that adding a field never needs a schema migration; this type is
/// what the pages and the content pipeline read. Two rules of the format:
///
/// * **unknown keys are kept** in [ReplacePayload.extra] and friends, so importing a rule file from
///   upstream and exporting it again is not a lossy operation (the same stance as a book source's
///   `extra`, ADR-0021);
/// * a payload this build cannot read becomes [MalformedPayload] instead of disappearing from the
///   list — the user can still see, edit or delete the row (ADR-0070 §决策 1).
@freezed
sealed class RulePayload with _$RulePayload {
  /// A 替换净化 rule: rewrite [pattern] into [replacement] across a chapter body.
  ///
  /// [isRegex] selects `RegExp` or a literal search; [timeoutMs] is upstream's guard for a slow
  /// regular expression and is **only preserved**, because Dart has no regex timeout (ADR-0070
  /// 增补 §7 的登记项).
  const factory RulePayload.replace({
    required String pattern,
    required String replacement,
    @Default(true) bool isRegex,
    int? timeoutMs,
    @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = ReplacePayload;

  /// A 目录规则 (`txt_toc_rule`): [rule] recognises chapter titles in a local text file.
  const factory RulePayload.toc({
    required String rule,
    int? serialNumber,
    @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = TocPayload;

  /// A 字典规则: [urlRule] builds the lookup page, [showRule] extracts the entry from it.
  const factory RulePayload.dict({
    required String urlRule,
    required String showRule,
    String? ruleGroupType,
    @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = DictPayload;

  /// A 高亮标签: [pattern] (a regular expression) matched text is highlighted in [colorHex].
  const factory RulePayload.highlight({
    required String pattern,
    String? colorHex,
    String? group,
    @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = HighlightPayload;

  /// A payload the app cannot read, kept verbatim in [raw].
  ///
  /// [raw] is the stored JSON text, so the edit form can show the user what is broken even though
  /// this build understands none of it.
  const factory RulePayload.malformed({required String raw}) = MalformedPayload;
}

/// The kind a typed payload belongs to.
extension RulePayloadKindExtension on RulePayload {
  /// The [RuleKind] owning this payload, or `null` for [MalformedPayload].
  ///
  /// A malformed payload has no kind of its own: the row it came from still names one, and that is
  /// the kind the user has to look under to repair it.
  RuleKind? get kind => switch (this) {
    ReplacePayload() => RuleKind.replace,
    TocPayload() => RuleKind.toc,
    DictPayload() => RuleKind.dict,
    HighlightPayload() => RuleKind.highlight,
    MalformedPayload() => null,
  };
}
