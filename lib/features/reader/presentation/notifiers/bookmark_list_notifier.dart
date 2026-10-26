import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bookmark_list_notifier.g.dart';

/// Every bookmark across books, newest first (`docs/dev/roadmap.md` M19).
///
/// The list is global (it is reached from 「我的」), so it neither knows which book is open nor
/// takes a key. Deleting a row reloads, which is what makes the list the stored truth instead of a
/// view of the page's hopes.
@riverpod
class BookmarkList extends _$BookmarkList {
  @override
  Future<List<Bookmark>> build() =>
      ref.watch(bookmarkRepositoryProvider).getAll();

  /// Deletes bookmark [id] and reloads the list.
  Future<void> remove(int id) async {
    try {
      await ref.read(bookmarkRepositoryProvider).remove(id);
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：一条书签删不掉不该让整个列表变成错误态。
      ref
          .read(appLoggerProvider)
          .warning('Removing a bookmark failed.', error, stackTrace);
    }
    state = await AsyncValue.guard<List<Bookmark>>(
      () => ref.read(bookmarkRepositoryProvider).getAll(),
    );
  }
}
