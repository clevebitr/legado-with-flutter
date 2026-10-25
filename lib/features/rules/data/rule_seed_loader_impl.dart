import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_seed_loader.dart';

/// One bundled seed asset and the kind every entry in it becomes.
const List<(String, RuleKind)> _seedAssets = <(String, RuleKind)>[
  ('assets/rules/txt_toc_rule.json', RuleKind.toc),
  ('assets/rules/dict_rule.json', RuleKind.dict),
];

/// [RuleSeedLoader] reading the bundled assets (`docs/dev/roadmap.md` M20, ADR-0070 增补 §5).
///
/// The assets are **upstream's** `defaultData/` files, so this loader maps their field names onto
/// the payload shapes ADR-0070 owns instead of asking upstream to change:
///
/// | asset field | where it lands |
/// |---|---|
/// | `name` | the row's `name` (a column, not a payload field) |
/// | `chapterRule` / `rule` | `toc.payload.rule` |
/// | `serialNumber` | `toc.payload.serialNumber` |
/// | `volumeRule` / `example` | `toc.payload.extra` — kept verbatim, upstream's txt import reads them |
/// | `enable` / `enabled` | the row's `is_enabled` |
/// | `urlRule` / `showRule` | `dict.payload.*` |
///
/// Row order is the asset order: the repository appends each draft to its kind, so the built-in
/// lists come out in upstream's order without needing `sort_order` from the file.
final class AssetRuleSeedLoader implements RuleSeedLoader {
  /// Creates the loader; [bundle] defaults to the app's root bundle.
  AssetRuleSeedLoader({required this._logger, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AppLogger _logger;
  final AssetBundle _bundle;

  @override
  Future<ParseResult<List<RuleDraft>>> load() async {
    final List<RuleDraft> drafts = <RuleDraft>[];

    for (final (String asset, RuleKind kind) in _seedAssets) {
      // 资源缺失时 `loadString` 抛的是 `FlutterError`（`Error` 的子类，ADR-0022 禁止捕）；
      // 那本来也是打包配置出错（`pubspec.yaml` 少登记一行），不是用户能碰到的运行期失败，
      // 所以让它尽早炸掉，而不是伪装成「这次没有内置规则」。
      final String text = await _bundle.loadString(asset);

      drafts.addAll(_decodeAsset(asset: asset, kind: kind, text: text));
    }

    return ParseSuccess<List<RuleDraft>>(drafts);
  }

  /// Decodes one asset, skipping entries this build cannot read (they are our own data, so a
  /// skip is a data bug worth a warning rather than a reason to seed nothing at all).
  List<RuleDraft> _decodeAsset({
    required String asset,
    required RuleKind kind,
    required String text,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error, stackTrace) {
      _logger.error('Rule seed asset is not JSON: $asset', error, stackTrace);

      return const <RuleDraft>[];
    }

    if (decoded is! List<Object?>) {
      _logger.warning('Rule seed asset is not a JSON array: $asset');

      return const <RuleDraft>[];
    }

    final List<RuleDraft> drafts = <RuleDraft>[];
    for (final Object? entry in decoded) {
      final RuleDraft? draft = entry is Map<String, Object?>
          ? _draftOf(kind: kind, json: entry)
          : null;
      if (draft == null) {
        _logger.warning('Rule seed entry skipped: $asset');
        continue;
      }
      drafts.add(draft);
    }

    return drafts;
  }

  RuleDraft? _draftOf({
    required RuleKind kind,
    required Map<String, Object?> json,
  }) {
    final String? name = _string(json, 'name');
    if (name == null) {
      return null;
    }

    return switch (kind) {
      RuleKind.toc => _tocDraft(name, json),
      RuleKind.dict => _dictDraft(name, json),
      // 播种清单里只有这两类（ADR-0070 增补 §5）：其余 kind 没有随包数据。
      RuleKind.replace || RuleKind.highlight => null,
    };
  }

  RuleDraft? _tocDraft(String name, Map<String, Object?> json) {
    final String? rule = _string(json, 'chapterRule') ?? _string(json, 'rule');
    if (rule == null) {
      return null;
    }

    return RuleDraft(
      kind: RuleKind.toc,
      name: name,
      isEnabled: _bool(json, 'enable') ?? true,
      isBuiltIn: true,
      payload: RulePayload.toc(
        rule: rule,
        serialNumber: _int(json, 'serialNumber'),
        // 上游的 txt 导入还要读这两项，本仓的 payload 形状没有它们，所以留在 extra 里不丢。
        extra: <String, Object?>{
          if (json['volumeRule'] case final String volumeRule)
            'volumeRule': volumeRule,
          if (json['example'] case final String example) 'example': example,
        },
      ),
    );
  }

  RuleDraft? _dictDraft(String name, Map<String, Object?> json) {
    final String? urlRule = _string(json, 'urlRule');
    final String? showRule = _string(json, 'showRule');
    if (urlRule == null || showRule == null) {
      return null;
    }

    return RuleDraft(
      kind: RuleKind.dict,
      name: name,
      isEnabled: _bool(json, 'enabled') ?? true,
      isBuiltIn: true,
      payload: RulePayload.dict(urlRule: urlRule, showRule: showRule),
    );
  }
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

  return value is int ? value : null;
}
