import 'dart:convert';

import 'package:flutter_reader/features/rules/data/rule_payload_codec.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeRulePayload', () {
    test('decodeRulePayload_givenAReplacePayload_readsEveryField', () {
      final RulePayload payload = decodeRulePayload(
        kind: RuleKind.replace,
        json:
            '{"pattern":"广告","replacement":"","isRegex":true,"timeoutMs":3000}',
      );

      expect(
        payload,
        const RulePayload.replace(
          pattern: '广告',
          replacement: '',
          isRegex: true,
          timeoutMs: 3000,
        ),
      );
    });

    test('decodeRulePayload_givenNoIsRegex_defaultsToRegexLikeUpstream', () {
      final RulePayload payload = decodeRulePayload(
        kind: RuleKind.replace,
        json: '{"pattern":"a"}',
      );

      expect((payload as ReplacePayload).isRegex, isTrue);
      expect(payload.replacement, '');
    });

    test('decodeRulePayload_givenAWholeNumberAsDouble_readsItAsAnInt', () {
      // 某些导出把 3000 写成 3000.0：整数存储不该因为一个点就整条读坏。
      final RulePayload payload = decodeRulePayload(
        kind: RuleKind.replace,
        json: '{"pattern":"a","timeoutMs":3000.0}',
      );

      expect((payload as ReplacePayload).timeoutMs, 3000);
    });

    test('decodeRulePayload_givenAFractionalNumber_ignoresIt', () {
      final RulePayload payload = decodeRulePayload(
        kind: RuleKind.replace,
        json: '{"pattern":"a","timeoutMs":30.5}',
      );

      expect((payload as ReplacePayload).timeoutMs, isNull);
    });

    test('decodeRulePayload_givenATocPayload_readsRuleAndSerialNumber', () {
      expect(
        decodeRulePayload(
          kind: RuleKind.toc,
          json: '{"rule":"^第.+章","serialNumber":2}',
        ),
        const RulePayload.toc(rule: '^第.+章', serialNumber: 2),
      );
    });

    test('decodeRulePayload_givenADictPayload_readsBothRules', () {
      expect(
        decodeRulePayload(
          kind: RuleKind.dict,
          json: '{"urlRule":"https://d.test/?q={{key}}","showRule":"tag.body@all"}',
        ),
        const RulePayload.dict(
          urlRule: 'https://d.test/?q={{key}}',
          showRule: 'tag.body@all',
        ),
      );
    });

    test('decodeRulePayload_givenAHighlightPayload_readsColorAndGroup', () {
      expect(
        decodeRulePayload(
          kind: RuleKind.highlight,
          json: '{"pattern":"第.章","colorHex":"#80FF0000","group":"默认"}',
        ),
        const RulePayload.highlight(
          pattern: '第.章',
          colorHex: '#80FF0000',
          group: '默认',
        ),
      );
    });

    test('decodeRulePayload_givenUnknownKeys_keepsThemInExtra', () {
      // 上游的净化规则还有 group / scope / excludeScope：本版不认，但导出时不能丢（ADR-0021）。
      final RulePayload payload = decodeRulePayload(
        kind: RuleKind.replace,
        json: '{"pattern":"a","replacement":"b","excludeScope":"@js:x"}',
      );

      expect((payload as ReplacePayload).extra, <String, Object?>{
        'excludeScope': '@js:x',
      });
    });

    test('decodeRulePayload_givenTextThatIsNotJson_answersMalformed', () {
      expect(
        decodeRulePayload(kind: RuleKind.replace, json: '{oops'),
        const RulePayload.malformed(raw: '{oops'),
      );
    });

    test('decodeRulePayload_givenJsonThatIsNotAnObject_answersMalformed', () {
      expect(
        decodeRulePayload(kind: RuleKind.replace, json: '["a"]'),
        const RulePayload.malformed(raw: '["a"]'),
      );
    });

    test('decodeRulePayload_givenAMissingRequiredField_answersMalformed', () {
      // 每类都至少有一个必填字段：缺了就无法执行，只能标坏（但仍留在列表里可删可改）。
      expect(
        decodeRulePayload(kind: RuleKind.replace, json: '{"replacement":"b"}'),
        const RulePayload.malformed(raw: '{"replacement":"b"}'),
      );
      expect(
        decodeRulePayload(kind: RuleKind.toc, json: '{"serialNumber":1}'),
        const RulePayload.malformed(raw: '{"serialNumber":1}'),
      );
      expect(
        decodeRulePayload(kind: RuleKind.dict, json: '{"urlRule":"u"}'),
        const RulePayload.malformed(raw: '{"urlRule":"u"}'),
      );
      expect(
        decodeRulePayload(
          kind: RuleKind.highlight,
          json: '{"colorHex":"#fff"}',
        ),
        const RulePayload.malformed(raw: '{"colorHex":"#fff"}'),
      );
    });

    test('decodeRulePayload_givenAFieldOfTheWrongType_answersMalformed', () {
      expect(
        decodeRulePayload(kind: RuleKind.replace, json: '{"pattern":42}'),
        const RulePayload.malformed(raw: '{"pattern":42}'),
      );
    });
  });

  group('encodeRulePayload', () {
    test('encodeRulePayload_givenAKnownPayload_writesEveryField', () {
      expect(
        encodeRulePayload(
          const RulePayload.replace(
            pattern: 'a',
            replacement: 'b',
            isRegex: false,
            timeoutMs: 1000,
          ),
        ),
        <String, Object?>{
          'pattern': 'a',
          'replacement': 'b',
          'isRegex': false,
          'timeoutMs': 1000,
        },
      );
    });

    test('encodeRulePayload_givenNullOptionals_leavesThemOut', () {
      // 写显式 null 会读回「设成了空」，而不是「没设」。
      expect(
        encodeRulePayload(const RulePayload.toc(rule: 'r')),
        <String, Object?>{'rule': 'r'},
      );
      expect(
        encodeRulePayload(const RulePayload.dict(urlRule: 'u', showRule: 's')),
        <String, Object?>{'urlRule': 'u', 'showRule': 's'},
      );
      expect(
        encodeRulePayload(const RulePayload.highlight(pattern: 'p')),
        <String, Object?>{'pattern': 'p'},
      );
    });

    test('encodeRulePayload_givenExtra_keepsTheUnknownKeys', () {
      expect(
        encodeRulePayload(
          const RulePayload.highlight(
            pattern: 'p',
            extra: <String, Object?>{'scope': 'title'},
          ),
        ),
        <String, Object?>{'pattern': 'p', 'scope': 'title'},
      );
    });

    test('encodeRulePayload_givenAMalformedPayload_throws', () {
      expect(
        () => encodeRulePayload(const RulePayload.malformed(raw: '{oops')),
        throwsArgumentError,
      );
    });

    test('roundTrip_givenAPayloadWithExtra_keepsItIdentical', () {
      const RulePayload original = RulePayload.replace(
        pattern: 'a',
        replacement: 'b',
        extra: <String, Object?>{'scopeTitle': true, 'excludeScope': 'x'},
      );

      expect(
        decodeRulePayload(
          kind: RuleKind.replace,
          json: jsonEncode(encodeRulePayload(original)),
        ),
        original,
      );
    });
  });
}
