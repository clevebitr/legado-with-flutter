import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/shelf_book_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_cache_notifier.g.dart';

/// How many chapter bodies of this book are cached; a missing database answers `0`.
@riverpod
Future<int> bookCacheCount(Ref ref, ShelfBookKey book) => ref
    .watch(contentCacheProvider)
    .countForBook(sourceId: book.sourceUrl, bookUrl: book.bookUrl);

/// Clears one book's cached chapter bodies.
///
/// Failures are returned as [ParseResult] rather than thrown.
@riverpod
class BookCacheActions extends _$BookCacheActions {
  late ShelfBookKey _book;

  @override
  AsyncValue<void> build(ShelfBookKey book) {
    _book = book;

    return const AsyncData<void>(null);
  }

  /// Clears this book's cache and answers how many entries went away.
  Future<ParseResult<int>> clear() async {
    // 端口与日志在 await 之前取好：autoDispose 的 Notifier 写完之后可能已被回收。
    final ContentCache cache = ref.read(contentCacheProvider);
    final AppLogger logger = ref.read(appLoggerProvider);
    try {
      final int removed = await cache.clearForBook(
        sourceId: _book.sourceUrl,
        bookUrl: _book.bookUrl,
      );
      if (ref.mounted) {
        ref.invalidate(bookCacheCountProvider(_book));
      }

      return ParseSuccess<int>(removed);
    } on Exception catch (error, stackTrace) {
      logger.warning('Clearing the book cache failed.', error, stackTrace);

      return const ParseFailure<int>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'cache.book',
      );
    }
  }
}
