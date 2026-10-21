import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
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
    // 列表页读的是 `bookSourceListDataProvider`（排序 + 筛选后的行），开关会改变它的行内容。
    ref.invalidate(bookSourceListDataProvider);
    state = AsyncData<StoredBookSource?>(_resolve(await _reload()));
  }

  /// Deletes the source with [id] and re-resolves the selection.
  Future<void> remove(int id) async {
    await ref.read(bookSourceRepositoryProvider).delete(id);
    ref.invalidate(bookSourceListDataProvider);
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

/// The list's own view state — sort key and group filter — and the only place that changes it
/// (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// `keepAlive` like the list itself: the choice survives walking to a source's debug console and
/// back, and the store write happens once per change rather than once per visit.
@Riverpod(keepAlive: true)
class BookSourceView extends _$BookSourceView {
  @override
  Future<BookSourceListView> build() async =>
      (await ref.watch(bookSourceViewStoreProvider.future)).load();

  /// Sorts by [order] and stores the choice.
  Future<void> setOrder(BookSourceSortOrder order) =>
      _apply((BookSourceListView view) => view.copyWith(order: order));

  /// Filters to [group]; `null` means «all groups».
  Future<void> setGroup(String? group) => _apply(
    (BookSourceListView view) => group == null
        ? view.copyWith(clearGroup: true)
        : view.copyWith(group: group),
  );

  /// Writes the manual order following [orderedIds] and refreshes the list (ADR-0045 §决策 3).
  Future<void> reorder(List<int> orderedIds) async {
    await ref.read(bookSourceRepositoryProvider).reorder(orderedIds);
    // 手动序同时是默认排序键与「第一条源」的依据，所以两个列表都要重新读。
    ref.invalidate(bookSourceListProvider);
    ref.invalidate(bookSourceListDataProvider);
  }

  /// Applies [change], stores it and publishes it.
  Future<void> _apply(
    BookSourceListView Function(BookSourceListView view) change,
  ) async {
    final BookSourceListView next = change(
      state.value ?? BookSourceListView.defaults,
    );
    await (await ref.read(bookSourceViewStoreProvider.future)).save(next);
    state = AsyncData<BookSourceListView>(next);
  }
}

/// What the list page renders: the rows after the filter, the groups they carry, and the view.
///
/// The group fallback lives **here** rather than in the store: whether a group still exists depends
/// on the rows, which the store cannot see. A stored filter that names a group nobody carries is
/// therefore dropped while rendering instead of being written back from a `build`
/// (ADR-0045 §决策 4).
@riverpod
Future<BookSourceListData> bookSourceListData(Ref ref) async {
  final BookSourceListView view = await ref.watch(
    bookSourceViewProvider.future,
  );
  final List<StoredBookSource> all = await ref
      .watch(bookSourceRepositoryProvider)
      .getAll(order: view.order);
  final List<String> groups = _groupsOf(all);
  final String? stored = view.group;
  final String? group = stored != null && groups.contains(stored)
      ? stored
      : null;
  final List<StoredBookSource> rows = group == null
      ? all
      : all
            .where(
              (StoredBookSource source) =>
                  splitGroups(_groupOf(source)).contains(group),
            )
            .toList(growable: false);

  return (
    rows: rows,
    groups: groups,
    view: group == null ? view.copyWith(clearGroup: true) : view,
  );
}

/// The rows the list shows, the groups they carry and the view that produced them.
typedef BookSourceListData = ({
  List<StoredBookSource> rows,
  List<String> groups,
  BookSourceListView view,
});

/// Every group token the loaded rows carry, sorted, de-duplicated.
List<String> _groupsOf(List<StoredBookSource> sources) {
  final Set<String> groups = <String>{
    for (final StoredBookSource source in sources)
      ...splitGroups(_groupOf(source)),
  };
  final List<String> sorted = groups.toList()..sort();

  return sorted;
}

/// The group column of [source], falling back to the payload for rows stored before 5.5.
String? _groupOf(StoredBookSource source) =>
    source.groupName ?? source.source.group;
