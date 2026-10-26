import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';

/// The exchange format of 替换净化 rules: upstream Legado's `ReplaceRule` JSON
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1).
///
/// It is one file, two directions: [parseReplaceRuleDocument] reads a document a user got from
/// upstream (or from this app's own export), and [replaceRuleToLegadoJson] writes one back. Keeping
/// them together is what makes「导入一次再导出」verifiable — the key table in the ADR is implemented
/// exactly here and nowhere else.

/// Keys this format consumes, so they never leak into a payload's `extra`.
const Set<String> _knownKeys = <String>{
  'name',
  'pattern',
  'replacement',
  'isRegex',
  'timeoutMillisecond',
  'timeoutMs',
  'group',
  'scopeContent',
  'scopeTitle',
  'isEnabled',
  'order',
  // 上游遗留字段：认了就吃掉，不留在 extra 里再来一遍。
  'regex',
  'replaceSummary',
  'enable',
  'serialNumber',
  // 上游的主键属于它自己的库；带过来只会在下次导出时撞号（ADR-0071 §决策 1）。
  'id',
};

/// The identity an imported rule is matched on: its name **and** its pattern.
///
/// A rule that kept its name but changed its pattern is a different rule; matching on the name alone
/// would silently overwrite the user's tuned expression.
String replaceRuleKey(String name, String pattern) => '$name\u0000$pattern';

/// Parses one document into preview entries (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1).
///
/// Accepts a JSON array (what both apps export), a single object (a hand-made one-rule file) and
/// upstream's legacy key names. [existingKeys] holds [replaceRuleKey]s of the stored rules, so each
/// entry already knows whether it will create or rewrite.
///
/// A bad **entry** never fails the document: it comes back with a [ReplaceRuleImportProblem] and can
/// be unticked in the preview (ADR-0052 §决策 5 的同一口径). Only a document that is not JSON, or has
/// no entries at all, is a failure.
ParseResult<List<ReplaceRuleImportEntry>> parseReplaceRuleDocument(
  String text, {
  Set<String> existingKeys = const <String>{},
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return failureAt<List<ReplaceRuleImportEntry>>(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'rules.import.notJson',
    );
  }

  final List<Object?> items = decoded is List<Object?>
      ? decoded
      : <Object?>[decoded];
  if (items.isEmpty) {
    return failureAt<List<ReplaceRuleImportEntry>>(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'rules.import.noEntries',
    );
  }

  return ParseSuccess<List<ReplaceRuleImportEntry>>(<ReplaceRuleImportEntry>[
    for (var index = 0; index < items.length; index++)
      _entryOf(index: index, item: items[index], existingKeys: existingKeys),
  ]);
}

/// One stored rule as the JSON object upstream imports.
///
/// Throws an [ArgumentError] for a rule whose payload this build cannot read: exporting it would
/// mean inventing a pattern, and the caller is expected to leave such rows out (with a warning).
Map<String, Object?> replaceRuleToLegadoJson(Rule rule) {
  final RulePayload payload = rule.payload;
  if (payload is! ReplacePayload) {
    throw ArgumentError.value(
      payload,
      'rule',
      'Only a replace payload can be exported as a replace rule',
    );
  }

  return <String, Object?>{
    ...payload.extra,
    'name': rule.name,
    if (payload.group case final String group) 'group': group,
    'pattern': payload.pattern,
    'replacement': payload.replacement,
    'isRegex': payload.isRegex,
    if (payload.timeoutMs case final int timeoutMs)
      'timeoutMillisecond': timeoutMs,
    'scopeContent': payload.scopeContent,
    'scopeTitle': payload.scopeTitle,
    // 用户态以列为准：文件里的 enabled / order 是导入那一刻的快照（ADR-0071 §决策 1）。
    'isEnabled': rule.isEnabled,
    'order': rule.sortOrder,
  };
}

ReplaceRuleImportEntry _entryOf({
  required int index,
  required Object? item,
  required Set<String> existingKeys,
}) {
  if (item is! Map<String, Object?>) {
    return ReplaceRuleImportEntry(
      index: index,
      name: '',
      payload: null,
      isEnabled: true,
      isUpdate: false,
      problem: ReplaceRuleImportProblem.notAnObject,
    );
  }

  final String name =
      _string(item, 'name') ?? _string(item, 'replaceSummary') ?? '';
  final String? pattern = _string(item, 'pattern') ?? _string(item, 'regex');
  final bool isEnabled =
      _bool(item, 'isEnabled') ?? _bool(item, 'enable') ?? true;
  final int? sortOrder = _int(item, 'order') ?? _int(item, 'serialNumber');

  if (pattern == null || pattern.isEmpty) {
    return ReplaceRuleImportEntry(
      index: index,
      name: name,
      payload: null,
      isEnabled: isEnabled,
      sortOrder: sortOrder,
      isUpdate: false,
      problem: ReplaceRuleImportProblem.missingPattern,
    );
  }

  return ReplaceRuleImportEntry(
    index: index,
    name: name,
    isEnabled: isEnabled,
    sortOrder: sortOrder,
    isUpdate: existingKeys.contains(replaceRuleKey(name, pattern)),
    payload: RulePayload.replace(
      pattern: pattern,
      replacement: _string(item, 'replacement') ?? '',
      // 上游 `ReplaceRule.isRegex` 默认 true；缺键时按正则处理与上游一致。
      isRegex: _bool(item, 'isRegex') ?? true,
      timeoutMs: _int(item, 'timeoutMillisecond') ?? _int(item, 'timeoutMs'),
      group: _string(item, 'group'),
      // 上游默认：作用于正文、不作用于标题（ADR-0071 §决策 4）。
      scopeContent: _bool(item, 'scopeContent') ?? true,
      scopeTitle: _bool(item, 'scopeTitle') ?? false,
      extra: <String, Object?>{
        for (final MapEntry<String, Object?> entry in item.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    ),
  );
}

String? _string(Map<String, Object?> json, String key) {
  final Object? value = json[key];

  return value is String ? value : null;
}

bool? _bool(Map<String, Object?> json, String key) {
  final Object? value = json[key];

  return value is bool ? value : null;
}

int? _int(Map<String, Object?> json, String key) {
  final Object? value = json[key];

  return switch (value) {
    final int number => number,
    final double number when number == number.roundToDouble() => number.toInt(),
    _ => null,
  };
}
