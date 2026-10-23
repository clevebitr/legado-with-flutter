import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_log_printer.dart';

void main() {
  group('ShelfBookDraft', () {
    test('new_givenBothIdentityParts_isAccepted', () {
      final ShelfBookDraft draft = ShelfBookDraft(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        name: '剑来',
      );

      expect(draft.name, '剑来');
    });

    test('new_givenAnEmptySourceUrl_throws', () {
      expect(
        () => ShelfBookDraft(sourceUrl: '', bookUrl: 'b', name: 'n'),
        throwsArgumentError,
      );
    });

    test('new_givenAnEmptyBookUrl_throws', () {
      expect(
        () => ShelfBookDraft(sourceUrl: 's', bookUrl: '', name: 'n'),
        throwsArgumentError,
      );
    });
  });

  group('UnboundBookshelfWriter', () {
    test('addToShelf_whenNothingIsBound_answersALocatableFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<void> result = await writer.addToShelf(
        ShelfBookDraft(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
          name: '剑来',
        ),
      );

      // ADR-0041 §决策 2：未绑定的端口返回失败 + 一条 warning，而不是抛异常。
      expect(result, isA<ParseFailure<void>>());
      expect(
        (result as ParseFailure<void>).kind,
        ParseFailureKind.unsupportedRule,
      );
      expect(result.rulePath, 'shelf.writer');
      expect(printer.events.single.message, contains('No BookshelfWriter'));
    });
  });
}
