import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/usecases/export_replace_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level;

import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_rule_repository.dart';

void main() {
  group('ExportReplaceRules', () {
    late FakeLogPrinter printer;
    late ExportReplaceRules useCase;

    setUp(() {
      printer = FakeLogPrinter();
      useCase = ExportReplaceRules(
        repository: FakeRuleRepository(),
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    test('execute_givenStoredRules_writesUpstreamDocument', () async {
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '数字标题',
          payload: const RulePayload.replace(
            pattern: '^第',
            replacement: '@js:result',
            scopeTitle: true,
            scopeContent: false,
            group: '格式',
          ),
        )
        ..seed(
          kind: RuleKind.replace,
          name: '去广告',
          payload: const RulePayload.replace(pattern: '广告', replacement: ''),
          isEnabled: false,
        );
      final ExportReplaceRules useCase = ExportReplaceRules(
        repository: repository,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ReplaceRuleExport document = await useCase.execute();
      final List<Object?> decoded =
          jsonDecode(document.contents) as List<Object?>;

      expect(document.count, 2);
      expect(document.skipped, 0);
      expect(document.fileName, 'replaceRules-2.json');
      expect(decoded, hasLength(2));
      final Map<String, Object?> first = decoded.first as Map<String, Object?>;
      expect(first['name'], '数字标题');
      expect(first['scopeTitle'], isTrue);
      expect(first['scopeContent'], isFalse);
      expect(first['group'], '格式');
      expect(first['replacement'], '@js:result');
      // `isEnabled` 以列为准（用户启停是用户态）。
      expect((decoded.last as Map<String, Object?>)['isEnabled'], isFalse);
    });

    test('execute_givenAnUnreadableRule_leavesItOutAndSaysSo', () async {
      // 猜一个 pattern 会往用户的文件里塞一条自己编的规则；静默丢掉又会把「导出了两条」说成三条。
      final FakeRuleRepository repository = FakeRuleRepository()
        ..seed(
          kind: RuleKind.replace,
          name: '好的',
          payload: const RulePayload.replace(pattern: 'a', replacement: 'b'),
        )
        ..seed(
          kind: RuleKind.replace,
          name: '坏的',
          payload: const RulePayload.malformed(raw: '{oops'),
        );
      final ExportReplaceRules useCase = ExportReplaceRules(
        repository: repository,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ReplaceRuleExport document = await useCase.execute();

      expect(document.count, 1);
      expect(document.skipped, 1);
      expect(document.fileName, 'replaceRules-1.json');
      expect(printer.events.single.level, Level.warning);
      expect(printer.events.single.message, contains('id=2'));
    });

    test('execute_givenNoRules_writesAnEmptyArray', () async {
      final ReplaceRuleExport document = await useCase.execute();

      expect(document.count, 0);
      expect(jsonDecode(document.contents), isEmpty);
    });
  });
}
