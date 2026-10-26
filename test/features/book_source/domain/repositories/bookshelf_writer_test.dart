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

  group('ShelfGroupOption', () {
    test('new_whenCalled_keepsTheIdAndName', () {
      // 运行时构造（参数来自调用方）：`const` 构造会被编译期折叠，覆盖率看不到这一行。
      final ShelfGroupOption option = _option(7, '仙侠');

      expect(option.id, 7);
      expect(option.name, '仙侠');
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

    test('membership_whenNothingIsBound_answersAbsent', () async {
      // 读侧是 total 的：未绑定时回答「不在书架上」，页面把那几个动作置灰。
      final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );

      final ShelfMembership membership = await writer.membership(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );

      expect(membership.onShelf, isFalse);
      expect(membership.groups, isEmpty);
    });

    test('assignGroup_whenNothingIsBound_answersALocatableFailure', () async {
      final FakeLogPrinter printer = FakeLogPrinter();
      final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<void> result = await writer.assignGroup(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        groupId: 1,
      );

      expect(result, isA<ParseFailure<void>>());
      expect((result as ParseFailure<void>).rulePath, 'shelf.writer.group');
      expect(printer.events.single.message, contains('group assignment'));
    });

    test('chooseCustomCover_whenNothingIsBound_answersCancelled', () async {
      final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
        logger: AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      );

      final ParseResult<String?> result = await writer.chooseCustomCover(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
      );

      // 取消与「没有实现」对页面是同一件事：什么都不发生（platform.md §2）。
      expect((result as ParseSuccess<String?>).data, isNull);
    });

    test(
      'resetCustomCover_whenNothingIsBound_answersALocatableFailure',
      () async {
        final FakeLogPrinter printer = FakeLogPrinter();
        final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<void> result = await writer.resetCustomCover(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
        );

        expect((result as ParseFailure<void>).rulePath, 'shelf.writer.cover');
        expect(printer.events.single.message, contains('resetting the cover'));
      },
    );

    test(
      'migrateIdentity_whenNothingIsBound_answersALocatableFailure',
      () async {
        final FakeLogPrinter printer = FakeLogPrinter();
        final UnboundBookshelfWriter writer = UnboundBookshelfWriter(
          logger: AppLogger(level: LogLevel.debug, printer: printer),
        );

        final ParseResult<void> result = await writer.migrateIdentity(
          sourceUrl: 'https://source.test',
          bookUrl: 'https://source.test/book/1',
          newSourceUrl: 'https://other.test',
          newBookUrl: 'https://other.test/book/1',
          newTocUrl: 'https://other.test/book/1/',
          newName: '剑来',
        );

        expect(
          (result as ParseFailure<void>).rulePath,
          'shelf.writer.migrateIdentity',
        );
        expect(
          printer.events.single.message,
          contains('migrating the shelf identity'),
        );
      },
    );
  });
}

/// Builds a group option at runtime, so the const constructor's line is measured.
ShelfGroupOption _option(int id, String name) =>
    ShelfGroupOption(id: id, name: name);
