import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/purge_rules_port.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logger/logger.dart' show Level;

import '../../../support/fake_log_printer.dart';

void main() {
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
