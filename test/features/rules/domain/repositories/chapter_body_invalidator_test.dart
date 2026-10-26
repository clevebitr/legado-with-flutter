import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/rules/domain/repositories/chapter_body_invalidator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level;

import '../../../../support/fake_log_printer.dart';

void main() {
  group('UnboundChapterBodyInvalidator', () {
    test(
      'invalidateChapterBodies_givenNoLogger_completesWithoutDropping',
      () async {
        // 没绑定时旧正文多活一阵，比抛给「改一条净化规则」这个操作要么失败要好。
        await expectLater(
          const UnboundChapterBodyInvalidator().invalidateChapterBodies(),
          completes,
        );
      },
    );

    test(
      'invalidateChapterBodies_givenALogger_warnsAboutTheMissingBinding',
      () async {
        final FakeLogPrinter printer = FakeLogPrinter();

        await UnboundChapterBodyInvalidator(logger: AppLogger(printer: printer))
            .invalidateChapterBodies();

        expect(printer.events.single.level, Level.warning);
        expect(
          printer.events.single.message,
          contains('Chapter-body invalidation is unbound'),
        );
      },
    );
  });
}
