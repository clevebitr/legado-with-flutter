import 'package:flutter_reader/core/storage/rule_dao.dart' as dao;
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleKind', () {
    test('values_givenTheStoredColumn_areTheSameStringsTheDaoUses', () {
      // 两处各写一份 kind 常量（`core/storage` 的 DAO 签名与这里的枚举），谁改了谁报错。
      expect(
        RuleKind.values.map((RuleKind kind) => kind.value),
        dao.RuleKind.all,
      );
    });

    test('fromValue_givenAKnownValue_answersThatKind', () {
      expect(RuleKind.fromValue('replace'), RuleKind.replace);
      expect(RuleKind.fromValue('toc'), RuleKind.toc);
      expect(RuleKind.fromValue('dict'), RuleKind.dict);
      expect(RuleKind.fromValue('highlight'), RuleKind.highlight);
    });

    test('fromValue_givenAKindFromANewerBuild_answersNull', () {
      // 未来版本写进来的 kind 读不懂，但不该被当成错误：行还在表里，本版只是不展示它。
      expect(RuleKind.fromValue('multiRole'), isNull);
      expect(RuleKind.fromValue(''), isNull);
    });
  });
}
