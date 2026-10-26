import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logger/logger.dart' show Level;

import '../../../support/fake_log_printer.dart';

void main() {
  group('PurgeRule', () {
    test('equality_givenTheSameFields_isTrue', () {
      const PurgeRule rule = PurgeRule(
        pattern: 'a',
        replacement: 'b',
        isRegex: true,
      );

      expect(
        rule,
        const PurgeRule(pattern: 'a', replacement: 'b', isRegex: true),
      );
      expect(
        rule.hashCode,
        const PurgeRule(pattern: 'a', replacement: 'b', isRegex: true).hashCode,
      );
      // 三个字段都参与相等：改一个就当两条不同的规则。
      expect(
        rule,
        isNot(const PurgeRule(pattern: 'a', replacement: 'c', isRegex: true)),
      );
      expect(
        rule,
        isNot(const PurgeRule(pattern: 'c', replacement: 'b', isRegex: true)),
      );
      expect(
        rule,
        isNot(const PurgeRule(pattern: 'a', replacement: 'b', isRegex: false)),
      );
      // 作用范围也参与相等：只改标题的规则与改正文的规则是两条。
      expect(
        rule,
        isNot(
          const PurgeRule(
            pattern: 'a',
            replacement: 'b',
            isRegex: true,
            appliesToContent: false,
          ),
        ),
      );
      expect(
        rule,
        isNot(
          const PurgeRule(
            pattern: 'a',
            replacement: 'b',
            isRegex: true,
            appliesToTitle: true,
          ),
        ),
      );
      expect(rule, isNot('a'));
    });

    test('toString_givenARule_showsBothSidesAndBothScopes', () {
      expect(
        const PurgeRule(
          pattern: 'a',
          replacement: 'b',
          isRegex: false,
          appliesToTitle: true,
        ).toString(),
        'PurgeRule(a -> b, isRegex: false, content: true, title: true, timeoutMs: null)',
      );
    });
  });

  group('UnboundPurgeRuleSource', () {
    test('purgeRules_givenNoLogger_answersAnEmptyList', () async {
      // 没接上净化时正文照样可读：空列表就是「这次不净化」，不抛也不报失败。
      expect(await const UnboundPurgeRuleSource().purgeRules(), isEmpty);
    });

    test('purgeRules_givenALogger_recordsADebugRecordNotAWarning', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundPurgeRuleSource source = UnboundPurgeRuleSource(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await source.purgeRules();

      expect(printer.events, hasLength(1));
      expect(printer.events.single.level, Level.debug);
      expect(
        printer.events.single.message,
        contains('Purge rules are unbound'),
      );
    });
  });
}
