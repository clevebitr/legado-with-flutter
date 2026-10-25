import 'dart:convert';

import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';

/// Turns a row's stored `payload` JSON into a typed [RulePayload] and back
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 1).
///
/// The stored shape is the table's format, so this file is where it is pinned down. Two guarantees
/// matter more than validation:
///
/// * **nothing is silently dropped** — a key this build does not know goes into the payload's
///   `extra` and comes back out on the next write (ADR-0021, the book source's `extra`);
/// * **an unreadable payload is reported, not skipped** — the caller stores it as
///   [MalformedPayload] with the raw text, so the list can show 「规则损坏」and the user can still
///   delete or repair the row.
///
/// Payload JSON always decodes as `Object?` first: the stored text comes from an older or newer
/// build, so "this is not even an object" is an expected input, not a programming error (C-TYPE-1).
RulePayload decodeRulePayload({required RuleKind kind, required String json}) {
  final Object? decoded;
  try {
    // `jsonDecode` 对同一段文本是纯解析：坏文本是「读不懂的 payload」，不是异常路径。
    decoded = jsonDecode(json);
  } on FormatException {
    return RulePayload.malformed(raw: json);
  }

  if (decoded is! Map<String, Object?>) {
    return RulePayload.malformed(raw: json);
  }

  return switch (kind) {
    RuleKind.replace => _decodeReplace(decoded, json),
    RuleKind.toc => _decodeToc(decoded, json),
    RuleKind.dict => _decodeDict(decoded, json),
    RuleKind.highlight => _decodeHighlight(decoded, json),
  };
}

/// The JSON object to store for [payload], unknown keys included.
///
/// Throws an [ArgumentError] for [MalformedPayload]: writing a payload the app cannot read back is
/// a programming error in the caller (C-ERR-1), not a user-facing failure.
Map<String, Object?> encodeRulePayload(RulePayload payload) =>
    switch (payload) {
      ReplacePayload() => _encodeReplace(payload),
      TocPayload() => _encodeToc(payload),
      DictPayload() => _encodeDict(payload),
      HighlightPayload() => _encodeHighlight(payload),
      MalformedPayload() => throw ArgumentError.value(
        payload,
        'payload',
        'A malformed payload cannot be encoded; supply a typed one',
      ),
    };

RulePayload _decodeReplace(Map<String, Object?> json, String raw) {
  final String? pattern = _string(json, 'pattern');

  if (pattern == null) {
    return RulePayload.malformed(raw: raw);
  }

  return RulePayload.replace(
    pattern: pattern,
    replacement: _string(json, 'replacement') ?? '',
    // 上游 `ReplaceRule.isRegex` 默认是 true，缺键时按正则处理与上游一致。
    isRegex: _bool(json, 'isRegex') ?? true,
    timeoutMs: _int(json, 'timeoutMs'),
    extra: _extra(json, const <String>{
      'pattern',
      'replacement',
      'isRegex',
      'timeoutMs',
    }),
  );
}

RulePayload _decodeToc(Map<String, Object?> json, String raw) {
  final String? rule = _string(json, 'rule');

  if (rule == null) {
    return RulePayload.malformed(raw: raw);
  }

  return RulePayload.toc(
    rule: rule,
    serialNumber: _int(json, 'serialNumber'),
    extra: _extra(json, const <String>{'rule', 'serialNumber'}),
  );
}

RulePayload _decodeDict(Map<String, Object?> json, String raw) {
  final String? urlRule = _string(json, 'urlRule');
  final String? showRule = _string(json, 'showRule');

  if (urlRule == null || showRule == null) {
    return RulePayload.malformed(raw: raw);
  }

  return RulePayload.dict(
    urlRule: urlRule,
    showRule: showRule,
    ruleGroupType: _string(json, 'ruleGroupType'),
    extra: _extra(json, const <String>{'urlRule', 'showRule', 'ruleGroupType'}),
  );
}

RulePayload _decodeHighlight(Map<String, Object?> json, String raw) {
  final String? pattern = _string(json, 'pattern');

  if (pattern == null) {
    return RulePayload.malformed(raw: raw);
  }

  return RulePayload.highlight(
    pattern: pattern,
    colorHex: _string(json, 'colorHex'),
    group: _string(json, 'group'),
    extra: _extra(json, const <String>{'pattern', 'colorHex', 'group'}),
  );
}

Map<String, Object?> _encodeReplace(ReplacePayload payload) =>
    _mergeEncoding(payload.extra, <String, Object?>{
      'pattern': payload.pattern,
      'replacement': payload.replacement,
      'isRegex': payload.isRegex,
      'timeoutMs': payload.timeoutMs,
    });

Map<String, Object?> _encodeToc(TocPayload payload) => _mergeEncoding(
  payload.extra,
  <String, Object?>{'rule': payload.rule, 'serialNumber': payload.serialNumber},
);

Map<String, Object?> _encodeDict(DictPayload payload) =>
    _mergeEncoding(payload.extra, <String, Object?>{
      'urlRule': payload.urlRule,
      'showRule': payload.showRule,
      'ruleGroupType': payload.ruleGroupType,
    });

Map<String, Object?> _encodeHighlight(HighlightPayload payload) =>
    _mergeEncoding(payload.extra, <String, Object?>{
      'pattern': payload.pattern,
      'colorHex': payload.colorHex,
      'group': payload.group,
    });

/// Known keys win over `extra`, and a null known value is simply absent.
///
/// `extra` is copied first so a key the row carried before this build learned it still round-trips;
/// a known key that is null must not be written as an explicit `null` — it would read back as "set
/// to nothing" instead of "not set".
Map<String, Object?> _mergeEncoding(
  Map<String, Object?> extra,
  Map<String, Object?> known,
) {
  final Map<String, Object?> json = <String, Object?>{...extra};

  known.forEach((String key, Object? value) {
    if (value == null) {
      json.remove(key);
    } else {
      json[key] = value;
    }
  });

  return json;
}

Map<String, Object?> _extra(Map<String, Object?> json, Set<String> known) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in json.entries)
      if (!known.contains(entry.key)) entry.key: entry.value,
  };
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

  // JSON 的数字可能是 3000.0：整数存储（timeoutMs / serialNumber）接受无小数部分的 double。
  return switch (value) {
    final int number => number,
    final double number when number == number.roundToDouble() => number.toInt(),
    _ => null,
  };
}
