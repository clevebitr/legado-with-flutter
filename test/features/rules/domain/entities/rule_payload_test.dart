import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RulePayloadKindExtension', () {
    test('kind_givenAReplacePayload_answersReplace', () {
      expect(
        const RulePayload.replace(pattern: 'a', replacement: 'b').kind,
        RuleKind.replace,
      );
    });

    test('kind_givenATocPayload_answersToc', () {
      expect(const RulePayload.toc(rule: 'r').kind, RuleKind.toc);
    });

    test('kind_givenADictPayload_answersDict', () {
      expect(
        const RulePayload.dict(urlRule: 'u', showRule: 's').kind,
        RuleKind.dict,
      );
    });

    test('kind_givenAHighlightPayload_answersHighlight', () {
      expect(
        const RulePayload.highlight(pattern: 'p').kind,
        RuleKind.highlight,
      );
    });

    test('kind_givenAMalformedPayload_answersNull', () {
      // 读坏的 payload 没有自己的 kind：种类来自那一行，用户要按行所属的列表去修它。
      expect(const RulePayload.malformed(raw: '{}').kind, isNull);
    });
  });
}
