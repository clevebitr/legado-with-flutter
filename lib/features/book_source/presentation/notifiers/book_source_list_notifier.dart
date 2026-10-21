import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_source_list_notifier.g.dart';

/// Every stored book source, in the order the list and the default pick share
/// (`BookSourceDao.findAll`: enabled first, then `customOrder`, then `id`).
///
/// `keepAlive` on purpose: the selection below watches it, so the list must not be re-read
/// (and the selection must not be lost) when the user walks from the reader back to the list.
/// Mutations invalidate it explicitly, so "fresh" is a decision rather than a side effect.
@Riverpod(keepAlive: true)
Future<List<StoredBookSource>> bookSourceList(Ref ref) =>
    ref.watch(bookSourceRepositoryProvider).getAll();

/// Which stored source the pages work with, and the only place that changes it.
///
/// The selection is a plain id in a private field, so a reload of the list (after an import, a
/// toggle or a delete) keeps the user's choice **and** re-resolves it: when the selected row is
/// gone the notifier falls back to the default source, because a dangling selection would leave
/// every page pointing at a source that no longer exists (`docs/dev/roadmap.md` 5.1).
@Riverpod(keepAlive: true)
class SelectedBookSource extends _$SelectedBookSource {
  int? _selectedId;

  @override
  Future<StoredBookSource?> build() async {
    // `ref.watch` 而不是 `read`：列表一变（导入 / 删除 / 开关）就按当前选择重算。
    final List<StoredBookSource> all = await ref.watch(
      bookSourceListProvider.future,
    );

    return _resolve(all);
  }

  /// Selects the source with [id]; an unknown id leaves the selection alone.
  Future<void> select(int id) async {
    final List<StoredBookSource> all = await _reload();

    final StoredBookSource? chosen = _find(all, id);
    if (chosen == null) {
      return;
    }
    _selectedId = id;
    state = AsyncData<StoredBookSource?>(chosen);
  }

  /// Enables or disables the source with [id] — user state, so this is the only writer.
  Future<void> toggleEnabled({required int id, required bool isEnabled}) async {
    await ref
        .read(bookSourceRepositoryProvider)
        .setEnabled(id: id, isEnabled: isEnabled);
    state = AsyncData<StoredBookSource?>(_resolve(await _reload()));
  }

  /// Deletes the source with [id] and re-resolves the selection.
  Future<void> remove(int id) async {
    await ref.read(bookSourceRepositoryProvider).delete(id);
    state = AsyncData<StoredBookSource?>(_resolve(await _reload()));
  }

  /// Reads a fresh list and publishes nothing; the callers decide what state to set.
  Future<List<StoredBookSource>> _reload() async {
    ref.invalidate(bookSourceListProvider);

    return ref.read(bookSourceListProvider.future);
  }

  /// The source the selection should point at: the remembered one, or the default.
  ///
  /// Falling back here (rather than in each page) is what makes "the selected source was
  /// deleted" a contract instead of a per-screen accident.
  StoredBookSource? _resolve(List<StoredBookSource> all) {
    final int? id = _selectedId;
    if (id != null) {
      final StoredBookSource? remembered = _find(all, id);
      if (remembered != null) {
        return remembered;
      }
      _selectedId = null;
    }

    final StoredBookSource? fallback = _defaultOf(all);
    _selectedId = fallback?.id;

    return fallback;
  }

  /// The default source: the first **enabled** row, or none (ADR-0040 §决策 3).
  StoredBookSource? _defaultOf(List<StoredBookSource> all) {
    for (final StoredBookSource source in all) {
      if (source.isEnabled) {
        return source;
      }
    }

    return null;
  }

  /// The row with [id], or `null`.
  StoredBookSource? _find(List<StoredBookSource> all, int id) {
    for (final StoredBookSource source in all) {
      if (source.id == id) {
        return source;
      }
    }

    return null;
  }
}

/// The book source the parsing pages work with (`docs/dev/roadmap.md` 2.5's seam, now filled by 5.1).
///
/// It stays a **synchronous** projection of [SelectedBookSource] so the four parsing pages keep
/// reading a `BookSource?`; only the pages that manage sources look at the load state.
/// `null` means "no usable source", which is what makes every page show its empty state instead
/// of requesting pages with an empty rule set.
@riverpod
BookSource? currentBookSource(Ref ref) =>
    ref.watch(selectedBookSourceProvider).value?.source;
