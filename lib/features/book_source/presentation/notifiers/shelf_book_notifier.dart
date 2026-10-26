import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shelf_book_notifier.g.dart';

/// The shelf-side identity of one book: primitives only.
typedef ShelfBookKey = ({String sourceUrl, String bookUrl});

/// The failure reported when a shelf-side write of the detail page fails.
const ParseFailure<void> shelfBookWriteFailure = ParseFailure<void>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'shelf.detail',
);

/// What the shelf knows about this book: membership, group and cover.
@riverpod
Future<ShelfMembership> shelfMembership(Ref ref, ShelfBookKey book) => ref
    .watch(bookshelfWriterProvider)
    .membership(sourceUrl: book.sourceUrl, bookUrl: book.bookUrl);

/// The shelf-side writes the detail page offers.
///
/// Each successful write reloads the membership snapshot; failures become [ParseResult] values.
@riverpod
class ShelfBookActions extends _$ShelfBookActions {
  late ShelfBookKey _book;

  @override
  AsyncValue<void> build(ShelfBookKey book) {
    _book = book;

    return const AsyncData<void>(null);
  }

  /// Moves the book into [groupId] (`null` = 未分组).
  Future<ParseResult<void>> assignGroup(int? groupId) => _write(
    () => ref
        .read(bookshelfWriterProvider)
        .assignGroup(
          sourceUrl: _book.sourceUrl,
          bookUrl: _book.bookUrl,
          groupId: groupId,
        ),
    reloadMembership: true,
  );

  /// Lets the user pick a cover; a cancelled dialog answers a success with `null`.
  Future<ParseResult<String?>> chooseCover() async {
    // 端口与日志在 await 之前取好：autoDispose 的 Notifier 写完后可能已被回收。
    final BookshelfWriter port = ref.read(bookshelfWriterProvider);
    final AppLogger logger = ref.read(appLoggerProvider);
    try {
      final ParseResult<String?> result = await port.chooseCustomCover(
        sourceUrl: _book.sourceUrl,
        bookUrl: _book.bookUrl,
      );
      if (ref.mounted) {
        ref.invalidate(shelfMembershipProvider(_book));
      }

      return result;
    } on Exception catch (error, stackTrace) {
      logger.warning('Choosing a cover failed.', error, stackTrace);

      return const ParseFailure<String?>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'shelf.detail.cover',
      );
    }
  }

  /// Goes back to the source's cover.
  Future<ParseResult<void>> resetCover() => _write(
    () => ref
        .read(bookshelfWriterProvider)
        .resetCustomCover(sourceUrl: _book.sourceUrl, bookUrl: _book.bookUrl),
    reloadMembership: true,
  );

  Future<ParseResult<void>> _write(
    Future<ParseResult<void>> Function() action, {
    required bool reloadMembership,
  }) async {
    // 同 [chooseCover]：await 之后 Notifier 可能已被回收。
    final AppLogger logger = ref.read(appLoggerProvider);
    try {
      final ParseResult<void> result = await action();
      if (reloadMembership && ref.mounted) {
        ref.invalidate(shelfMembershipProvider(_book));
      }

      return result;
    } on Exception catch (error, stackTrace) {
      logger.warning('Writing the shelf row failed.', error, stackTrace);

      return shelfBookWriteFailure;
    }
  }
}
