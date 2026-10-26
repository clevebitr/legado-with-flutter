import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/replace_rule_exchange.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'export_replace_rules.freezed.dart';

/// One ready-to-save replace-rule document (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1).
@freezed
abstract class ReplaceRuleExport with _$ReplaceRuleExport {
  /// Creates a document.
  const factory ReplaceRuleExport({
    /// The file name to suggest to the save dialog.
    required String fileName,

    /// The JSON text to write.
    required String contents,

    /// How many rules the document holds.
    required int count,

    /// How many stored rules were left out because their payload cannot be read.
    required int skipped,
  }) = _ReplaceRuleExport;
}

/// Writes every 替换净化 rule as an upstream-compatible document
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1).
///
/// A rule whose payload this build cannot read is left out **and counted**: writing a guess for it
/// would put a made-up pattern into the user's file, and dropping it silently would make the export
/// look complete when it is not.
final class ExportReplaceRules {
  /// Creates the use case.
  const ExportReplaceRules({required this._repository, required this._logger});

  final RuleRepository _repository;
  final AppLogger _logger;

  /// Builds the document for every stored purge rule.
  Future<ReplaceRuleExport> execute() async {
    final List<Rule> rules = await _repository.ofKind(RuleKind.replace);
    final List<Map<String, Object?>> exported = <Map<String, Object?>>[];
    var skipped = 0;

    for (final Rule rule in rules) {
      if (rule.payload is! ReplacePayload) {
        _logger.warning(
          'Replace rule left out of the export: id=${rule.id} kind=${rule.kind.value}',
        );
        skipped++;

        continue;
      }
      exported.add(replaceRuleToLegadoJson(rule));
    }

    return ReplaceRuleExport(
      fileName: 'replaceRules-${exported.length}.json',
      contents: const JsonEncoder.withIndent('  ').convert(exported),
      count: exported.length,
      skipped: skipped,
    );
  }
}
