import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rules_route.freezed.dart';

/// The typed routes of the rules feature (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// One list route per [RuleKind] and one edit route that either edits an existing rule or creates a
/// new one of the same kind — the four kinds share the pages and differ only in the form, so four
/// copies of each route would be four chances to drift.
@freezed
sealed class RulesRoute with _$RulesRoute {
  const RulesRoute._();

  /// The list of every rule of [kind].
  const factory RulesRoute.list({required RuleKind kind}) = RulesListRoute;

  /// The form for one rule of [kind]; a `null` [ruleId] creates a new one.
  const factory RulesRoute.edit({required RuleKind kind, int? ruleId}) =
      RulesEditRoute;

  /// The 替换净化 import (paste / URL / file, then a ticked preview).
  const factory RulesRoute.import() = RulesImportRoute;

  /// The path this route is served under.
  String get path => switch (this) {
    RulesListRoute(:final RuleKind kind) => '/rules/${kind.value}',
    RulesEditRoute(:final RuleKind kind) => '/rules/${kind.value}/edit',
    RulesImportRoute() => _importPath,
  };
}

/// Path of [RulesImportRoute].
const String _importPath = '/rules/import';

/// Pushes [route] through the app's route table (ADR-0011 §4).
void pushRulesRoute(BuildContext context, RulesRoute route) =>
    AppRouter.push(context, path: route.path, arguments: route);
