import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_bookmarks_notifier.g.dart';

/// The bookmarks of the book that is open, and the toggle behind the toolbar button
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The list is watched by the reader so the icon can show whether the current position is marked;
/// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
/// disagreeing after a failed write.
@riverpod
class ReaderBookmarks extends _$ReaderBookmarks {
  /// The book this notifier is bound to; `build` may run more than once, so it is re-assigned.
  late ReaderBook _book;

  @override
  Future<List<Bookmark>> build(ReaderBook book) {
    _book = book;

    return ref
        .watch(bookmarkRepositoryProvider)
        .getForBook(sourceUrl: book.sourceUrl, bookUrl: book.bookUrl);
  }

  /// Adds or removes a mark at the draft's position and answers whether it is now marked.
  ///
  /// Storage failures are absorbed at this boundary (C-ERR-2 allows it for a presentation
  /// Notifier): the reader shows the failure and keeps reading — a lost bookmark must never cost
  /// the chapter.
  Future<bool?> toggle(BookmarkDraft draft) async {
    try {
      final bool marked = await ref
          .read(bookmarkRepositoryProvider)
          .toggle(draft);
      await _reload();

      return marked;
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Toggling a bookmark failed: book=${draft.bookUrl}',
            error,
            stackTrace,
          );

      return null;
    }
  }

  /// Deletes bookmark [id] and reloads the list.
  Future<void> remove(int id) async {
    try {
      await ref.read(bookmarkRepositoryProvider).remove(id);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Removing a bookmark failed.', error, stackTrace);
    }
    await _reload();
  }

  /// Re-reads the book's bookmarks and publishes them.
  ///
  /// Reading the repository directly rather than `invalidateSelf` is the same pattern as
  /// `Bookshelf`: a notifier may not depend on itself, and the guard keeps a failed reload an
  /// error state instead of an exception.
  Future<void> _reload() async {
    final ReaderBook book = _book;
    state = await AsyncValue.guard<List<Bookmark>>(
      () => ref
          .read(bookmarkRepositoryProvider)
          .getForBook(sourceUrl: book.sourceUrl, bookUrl: book.bookUrl),
    );
  }
}
