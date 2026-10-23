import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shelf_add_notifier.g.dart';

/// The failure reported when the shelf could not store the book.
const ParseFailure<void> shelfAddFailure = ParseFailure<void>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'shelf.write',
);

/// Adds a book to the shelf from the detail page.
///
/// The write goes through the shelf port, so this feature knows no shelf type.
@riverpod
class ShelfAdd extends _$ShelfAdd {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  /// Adds [draft] to the shelf and answers the outcome the page shows.
  Future<ParseResult<void>> add(ShelfBookDraft draft) async {
    state = const AsyncLoading<void>();
    try {
      final ParseResult<void> result = await ref
          .read(bookshelfWriterProvider)
          .addToShelf(draft);
      state = const AsyncData<void>(null);

      return result;
    } on Exception catch (error, stackTrace) {
      // 未绑定的端口返回失败；会抛的是仓储存储错误，这里兜底记录并回到空闲。
      ref
          .read(appLoggerProvider)
          .warning('Adding a book to the shelf failed.', error, stackTrace);
      state = const AsyncData<void>(null);

      return shelfAddFailure;
    }
  }
}
