import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rule.freezed.dart';

/// One stored rule with its kind-specific [payload] (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// [kind] is stored next to the payload rather than derived from it: a row whose payload this build
/// cannot read still belongs to a kind, and the user has to find it under that kind's list in order
/// to delete or repair it.
///
/// [isBuiltIn] records where the row came from — a rule shipped with the app is still **editable and
/// deletable**; the flag never protects it (ADR-0070 §决策 4).
@freezed
abstract class Rule with _$Rule {
  /// Creates one stored rule.
  const factory Rule({
    required int id,
    required RuleKind kind,
    required String name,
    required RulePayload payload,
    required bool isEnabled,
    required bool isBuiltIn,
    required int sortOrder,
  }) = _Rule;
}

/// A rule that is about to be stored, i.e. one without an id yet.
///
/// Creating and seeding differ only in [isBuiltIn], so they share this shape: the repository appends
/// the row to the end of its kind and answers the stored [Rule].
@freezed
abstract class RuleDraft with _$RuleDraft {
  /// Creates a draft of [kind] with [payload].
  const factory RuleDraft({
    required RuleKind kind,
    required String name,
    required RulePayload payload,
    @Default(true) bool isEnabled,
    @Default(false) bool isBuiltIn,

    /// Where the row should sit inside its kind; `null` appends (what「新增」does).
    ///
    /// An import is the one caller that needs it: the file carries an `order` per rule and the
    /// imported list must come out in the file's order (ADR-0071 §决策 1).
    int? sortOrder,
  }) = _RuleDraft;
}
