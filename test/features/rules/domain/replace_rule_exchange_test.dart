import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/replace_rule_exchange.dart';
import 'package:flutter_test/flutter_test.dart';

/// The smallest document upstream would export: one rule with the keys this build models.
const String _oneRule = '''
[
  {
    "id": 7,
    "name": "去广告",
    "group": "格式",
    "pattern": "广告\\\\d+",
    "replacement": "",
    "isRegex": true,
    "timeoutMillisecond": 3000,
    "scopeContent": true,
    "scopeTitle": false,
    "isEnabled": false,
    "order": 3,
    "excludeScope": "@js:true"
  }
]''';

/// The entries of a parsed document, or a failed expectation.
List<ReplaceRuleImportEntry> _entriesOf(
  String text, {
  Set<String> existingKeys = const <String>{},
}) {
  final ParseResult<List<ReplaceRuleImportEntry>> parsed =
      parseReplaceRuleDocument(text, existingKeys: existingKeys);

  return switch (parsed) {
    ParseSuccess<List<ReplaceRuleImportEntry>>(
      :final List<ReplaceRuleImportEntry> data,
    ) =>
      data,
    ParseFailure<List<ReplaceRuleImportEntry>>(:final String rulePath) => fail(
      'the document should parse ($rulePath)',
    ),
  };
}

void main() {
  group('parseReplaceRuleDocument', () {
    test('parse_givenAnUpstreamArray_readsEveryModelledKey', () {
      final ReplaceRuleImportEntry entry = _entriesOf(_oneRule).single;

      expect(entry.name, '去广告');
      expect(entry.isEnabled, isFalse);
      expect(entry.sortOrder, 3);
      expect(entry.isUsable, isTrue);
      expect(entry.isUpdate, isFalse);
      expect(
        entry.payload,
        const RulePayload.replace(
          pattern: '广告\\d+',
          replacement: '',
          isRegex: true,
          timeoutMs: 3000,
          group: '格式',
          scopeContent: true,
          scopeTitle: false,
          // `id` 属于上游自己的库，不进 payload；`excludeScope` 本版不认但也不能丢。
          extra: <String, Object?>{'excludeScope': '@js:true'},
        ),
      );
    });

    test('parse_givenASingleObject_treatsItAsAOneEntryDocument', () {
      final List<ReplaceRuleImportEntry> entries = _entriesOf(
        '{"name":"一条","pattern":"a","replacement":"b"}',
      );

      expect(entries.single.name, '一条');
      expect(entries.single.sortOrder, isNull);
    });

    test('parse_givenUpstreamLegacyKeys_mapsThemOntoThePayload', () {
      // 上游 `ReplaceAnalyzer.jsonToReplaceRule` 兼容的那一套：regex / replaceSummary / enable /
      // serialNumber。老规则包只写这些键，认不出来就整份不可用。
      final ReplaceRuleImportEntry entry = _entriesOf('''
[
  {
    "replaceSummary": "旧格式",
    "regex": "旧",
    "replacement": "新",
    "enable": false,
    "serialNumber": 5
  }
]''').single;

      expect(entry.name, '旧格式');
      expect(entry.isEnabled, isFalse);
      expect(entry.sortOrder, 5);
      expect(
        entry.payload,
        const RulePayload.replace(pattern: '旧', replacement: '新'),
      );
    });

    test('parse_givenAnEntryThatIsNotAnObject_marksItUnusable', () {
      final List<ReplaceRuleImportEntry> entries = _entriesOf(
        '[42, {"name":"好的","pattern":"a"}]',
      );

      expect(entries.first.problem, ReplaceRuleImportProblem.notAnObject);
      expect(entries.first.isUsable, isFalse);
      // 一条坏条目不会带走整份文件。
      expect(entries.last.isUsable, isTrue);
    });

    test('parse_givenAnEntryWithoutAPattern_marksItUnusable', () {
      final ReplaceRuleImportEntry entry = _entriesOf(
        '[{"name":"空的","pattern":""}]',
      ).single;

      expect(entry.problem, ReplaceRuleImportProblem.missingPattern);
      expect(entry.name, '空的');
      expect(entry.payload, isNull);
    });

    test('parse_givenExistingKeys_flagsTheEntryAsAnUpdate', () {
      final List<ReplaceRuleImportEntry> entries = _entriesOf(
        '[{"name":"去广告","pattern":"广告"}]',
        existingKeys: <String>{replaceRuleKey('去广告', '广告')},
      );

      expect(entries.single.isUpdate, isTrue);
    });

    test('parse_givenTheSameNameWithAnotherPattern_isNotAnUpdate', () {
      // 名字一样、pattern 改过是**另一条**规则：按名字覆盖会悄悄改掉用户调好的表达式。
      final List<ReplaceRuleImportEntry> entries = _entriesOf(
        '[{"name":"去广告","pattern":"广告\\\\d+"}]',
        existingKeys: <String>{replaceRuleKey('去广告', '广告')},
      );

      expect(entries.single.isUpdate, isFalse);
    });

    test('parse_givenTextThatIsNotJson_failsTheDocument', () {
      final ParseResult<List<ReplaceRuleImportEntry>> parsed =
          parseReplaceRuleDocument('{oops');

      expect(
        parsed,
        isA<ParseFailure<List<ReplaceRuleImportEntry>>>().having(
          (ParseFailure<List<ReplaceRuleImportEntry>> failure) => failure.kind,
          'kind',
          ParseFailureKind.parseFailed,
        ),
      );
    });

    test('parse_givenAnEmptyArray_failsTheDocument', () {
      expect(
        parseReplaceRuleDocument('[]'),
        isA<ParseFailure<List<ReplaceRuleImportEntry>>>(),
      );
    });
  });

  group('replaceRuleToLegadoJson', () {
    Rule rule({
      RulePayload payload = const RulePayload.replace(
        pattern: 'a',
        replacement: 'b',
      ),
      bool isEnabled = true,
      int sortOrder = 0,
      String name = '规则',
    }) => Rule(
      id: 1,
      kind: RuleKind.replace,
      name: name,
      payload: payload,
      isEnabled: isEnabled,
      isBuiltIn: false,
      sortOrder: sortOrder,
    );

    test('replaceRuleToLegadoJson_givenARule_writesUpstreamKeys', () {
      expect(
        replaceRuleToLegadoJson(
          rule(
            payload: const RulePayload.replace(
              pattern: 'a',
              replacement: 'b',
              isRegex: false,
              timeoutMs: 3000,
              group: '格式',
              scopeTitle: true,
            ),
            isEnabled: false,
            sortOrder: 4,
          ),
        ),
        <String, Object?>{
          'name': '规则',
          'group': '格式',
          'pattern': 'a',
          'replacement': 'b',
          'isRegex': false,
          'timeoutMillisecond': 3000,
          'scopeContent': true,
          'scopeTitle': true,
          'isEnabled': false,
          'order': 4,
        },
      );
    });

    test('replaceRuleToLegadoJson_givenNullOptionals_omitsThem', () {
      // 上游的 `timeoutMillisecond` 有默认值，写显式 null 会把默认值顶掉。
      expect(
        replaceRuleToLegadoJson(rule()).keys,
        isNot(contains('timeoutMillisecond')),
      );
      expect(replaceRuleToLegadoJson(rule()).keys, isNot(contains('group')));
    });

    test('replaceRuleToLegadoJson_givenExtra_keepsIt', () {
      expect(
        replaceRuleToLegadoJson(
          rule(
            payload: const RulePayload.replace(
              pattern: 'a',
              replacement: 'b',
              extra: <String, Object?>{'excludeScope': '@js:true'},
            ),
          ),
        )['excludeScope'],
        '@js:true',
      );
    });

    test('replaceRuleToLegadoJson_givenAnotherKind_throws', () {
      expect(
        () => replaceRuleToLegadoJson(
          rule(payload: const RulePayload.toc(rule: '^章')),
        ),
        throwsArgumentError,
      );
    });

    test('roundTrip_givenAnUpstreamDocument_survivesExportAndImport', () {
      // 「导入一次再导出」对已建模的键与未知键都无损——ADR-0071 §决策 1 的验收口径。
      final Rule rule = Rule(
        id: 9,
        kind: RuleKind.replace,
        name: '去广告',
        payload:
            _entriesOf(_oneRule).single.payload ??
            const RulePayload.toc(rule: ''),
        isEnabled: false,
        isBuiltIn: false,
        sortOrder: 3,
      );

      final ReplaceRuleImportEntry again = _entriesOf(
        jsonEncode(<Map<String, Object?>>[replaceRuleToLegadoJson(rule)]),
      ).single;

      expect(again.payload, rule.payload);
      expect(again.isEnabled, isFalse);
      expect(again.sortOrder, 3);
    });
  });
}
