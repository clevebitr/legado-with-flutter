import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shelf_add_notifier.g.dart';

/// The failure reported when the shelf could not store the book.
///
/// No user-visible text (C-ERR-7); `rulePath` names the port so the log points at the write.
const ParseFailure<void> shelfAddFailure = ParseFailure<void>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'shelf.write',
);

/// The 「加入书架」 action of the detail page (`docs/dev/roadmap.md` 5.4)。
///
/// It exists as a Notifier rather than a call inside the page because C-STATE-4 keeps business
/// calls out of widgets; the loading state is what disables the button while a write is in
/// flight. The **port** does the cross-feature part: nothing here knows what a shelf is
/// (ADR-0041 §决策 2).
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
      // 未绑定的端口不会抛（它返回失败）；会抛的是仓储的意外存储错误，归 presentation 兜底
      // （C-ERR-2）：记一条、回到空闲态，并交给页面显示失败文案。
      ref
          .read(appLoggerProvider)
          .warning('Adding a book to the shelf failed.', error, stackTrace);
      state = const AsyncData<void>(null);

      return shelfAddFailure;
    }
  }
}
