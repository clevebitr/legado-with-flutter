import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/shelf_add_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A writer that records the draft and answers whatever the test configured.
final class _RecordingWriter implements BookshelfWriter {
  ShelfBookDraft? lastDraft;
  ParseResult<void> result = const ParseSuccess<void>(null);
  bool throwOnWrite = false;

  @override
  Future<ParseResult<void>> addToShelf(ShelfBookDraft draft) async {
    lastDraft = draft;
    if (throwOnWrite) {
      throw Exception('the shelf is unavailable');
    }

    return result;
  }

  @override
  Future<ShelfMembership> membership({
    required String sourceUrl,
    required String bookUrl,
  }) async => ShelfMembership.absent;

  @override
  Future<ParseResult<void>> assignGroup({
    required String sourceUrl,
    required String bookUrl,
    required int? groupId,
  }) async => const ParseSuccess<void>(null);

  @override
  Future<ParseResult<String?>> chooseCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async => const ParseSuccess<String?>(null);

  @override
  Future<ParseResult<void>> resetCustomCover({
    required String sourceUrl,
    required String bookUrl,
  }) async => const ParseSuccess<void>(null);

  @override
  Future<ParseResult<void>> migrateIdentity({
    required String sourceUrl,
    required String bookUrl,
    required String newSourceUrl,
    required String newBookUrl,
    required String newTocUrl,
    required String newName,
    String? newAuthor,
    String? newCoverUrl,
    String? newLastChapter,
  }) async => const ParseSuccess<void>(null);
}

void main() {
  group('ShelfAdd', () {
    late _RecordingWriter writer;
    late ProviderContainer container;

    setUp(() {
      writer = _RecordingWriter();
      container = ProviderContainer(
        overrides: [bookshelfWriterProvider.overrideWithValue(writer)],
      );
      addTearDown(container.dispose);
    });

    /// The draft every test sends.
    ShelfBookDraft draft() => ShelfBookDraft(
      sourceUrl: 'https://source.test',
      bookUrl: 'https://source.test/book/1',
      name: '剑来',
      author: '烽火戏诸侯',
    );

    test('build_whenRead_isIdle', () {
      expect(container.read(shelfAddProvider).isLoading, isFalse);
    });

    test('add_whenThePortSucceeds_answersSuccessAndPassesTheDraft', () async {
      final ParseResult<void> result = await container
          .read(shelfAddProvider.notifier)
          .add(draft());

      expect(result, isA<ParseSuccess<void>>());
      expect(writer.lastDraft?.name, '剑来');
      expect(container.read(shelfAddProvider).isLoading, isFalse);
    });

    test('add_whenThePortReportsAFailure_passesItThrough', () async {
      writer.result = const ParseFailure<void>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'shelf.writer',
      );

      final ParseResult<void> result = await container
          .read(shelfAddProvider.notifier)
          .add(draft());

      expect(result, isA<ParseFailure<void>>());
    });

    test('add_whenThePortThrows_answersTheNotifierFailure', () async {
      writer.throwOnWrite = true;

      final ParseResult<void> result = await container
          .read(shelfAddProvider.notifier)
          .add(draft());

      // C-ERR-2 的 presentation 兜底：异常变成失败态，并且状态回到空闲（按钮可再点）。
      expect(result, isA<ParseFailure<void>>());
      expect((result as ParseFailure<void>).rulePath, 'shelf.write');
      expect(container.read(shelfAddProvider).isLoading, isFalse);
    });
  });
}
