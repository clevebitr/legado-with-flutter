import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_bookshelf_repository.dart';

void main() {
  group('Bookshelf', () {
    late FakeBookshelfRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeBookshelfRepository();
      container = ProviderContainer(
        overrides: [bookshelfRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    /// Reads the shelf and returns the entries.
    Future<List<ShelvedBook>> settle() =>
        container.read(bookshelfProvider.future);

    test('build_whenNothingIsStored_answersEmpty', () async {
      expect(await settle(), isEmpty);
    });

    test('build_givenPinnedAndReadBooks_ordersPinnedFirst', () async {
      final ShelvedBook plain = repository.seed(name: '普通');
      repository.seed(name: '置顶', isPinned: true);
      repository.seed(
        name: '已读',
        status: ShelfStatus.read,
        progress: ReadingProgressPosition(
          chapterUrl: 'https://source.test/book/9/1.html',
          updatedAt: DateTime(2026, 10, 20),
        ),
      );

      final List<ShelvedBook> books = await settle();

      expect(books.first.name, '置顶');
      expect(books.last.id, plain.id);
    });

    test('add_whenTheWriteSucceeds_reloadsTheShelf', () async {
      final ParseResult<void> result = await container
          .read(bookshelfProvider.notifier)
          .add(
            ShelfCandidate(
              sourceUrl: 'https://source.test',
              bookUrl: 'https://source.test/book/1',
              name: '剑来',
            ),
          );

      expect(result, isA<ParseSuccess<void>>());
      expect((await settle()).single.name, '剑来');
    });

    test('add_givenTheSameBookTwice_keepsOneEntry', () async {
      final ShelfCandidate candidate = ShelfCandidate(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        name: '剑来',
      );
      await container.read(bookshelfProvider.notifier).add(candidate);

      await container.read(bookshelfProvider.notifier).add(candidate);

      expect(await settle(), hasLength(1));
    });

    test('add_whenTheRepositoryThrows_answersAFailure', () async {
      repository.failWrites = true;

      final ParseResult<void> result = await container
          .read(bookshelfProvider.notifier)
          .add(
            ShelfCandidate(
              sourceUrl: 'https://source.test',
              bookUrl: 'https://source.test/book/1',
              name: '剑来',
            ),
          );

      // presentation 兜底把存储异常变成失败态（C-ERR-2），而不是抛到页面。
      expect(result, isA<ParseFailure<void>>());
      expect(await settle(), isEmpty);
    });

    test('updateUserState_whenTheWriteSucceeds_isVisible', () async {
      final ShelvedBook book = repository.seed(name: '剑来');

      final ParseResult<void> result = await container
          .read(bookshelfProvider.notifier)
          .updateUserState(
            id: book.id,
            status: ShelfStatus.read,
            isPinned: true,
          );

      expect(result, isA<ParseSuccess<void>>());
      final ShelvedBook updated = (await settle()).single;
      expect(updated.status, ShelfStatus.read);
      expect(updated.isPinned, isTrue);
    });

    test('updateUserState_whenTheRepositoryThrows_answersAFailure', () async {
      final ShelvedBook book = repository.seed(name: '剑来');
      repository.failWrites = true;

      final ParseResult<void> result = await container
          .read(bookshelfProvider.notifier)
          .updateUserState(
            id: book.id,
            status: ShelfStatus.read,
            isPinned: false,
          );

      expect(result, isA<ParseFailure<void>>());
    });

    test('remove_whenTheWriteSucceeds_dropsTheEntry', () async {
      final ShelvedBook book = repository.seed(name: '剑来');

      final ParseResult<void> result = await container
          .read(bookshelfProvider.notifier)
          .remove(book.id);

      expect(result, isA<ParseSuccess<void>>());
      expect(await settle(), isEmpty);
    });

    test('remove_whenTheRepositoryThrows_answersAFailure', () async {
      final ShelvedBook book = repository.seed(name: '剑来');
      repository.failWrites = true;

      expect(
        await container.read(bookshelfProvider.notifier).remove(book.id),
        isA<ParseFailure<void>>(),
      );
    });

    test('shelfWriteFailure_whenRead_locatesTheEntry', () {
      // 失败必须可定位（C-SRC-8 的同一条理由）：页面显示文案，日志靠 rulePath 指到写入点。
      expect(shelfWriteFailure.rulePath, 'shelf.entry');
      expect(shelfWriteFailure.kind, ParseFailureKind.parseFailed);
    });
  });
}
