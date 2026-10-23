import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_list_view.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_light.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_source_list_notifier.g.dart';

/// Every stored book source, in the order the list and the default pick share.
///
/// Kept alive so the selection below survives page navigation.
@Riverpod(keepAlive: true)
Future<List<StoredBookSource>> bookSourceList(Ref ref) =>
    ref.watch(bookSourceRepositoryProvider).getAll();

/// The stored source the pages work with; the only place that changes it.
///
/// When the selected row disappears, the selection falls back to the default source.
@Riverpod(keepAlive: true)
class SelectedBookSource extends _$SelectedBookSource {
  int? _selectedId;

  @override
  Future<StoredBookSource?> build() async {
    // watch 而非 read：列表一变（导入 / 删除 / 开关）就按当前选择重算。
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

  /// Enables or disables every id in [ids] in one write.
  Future<void> setEnabledFor(Set<int> ids, {required bool isEnabled}) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .setEnabledFor(ids.toList(growable: false), isEnabled: isEnabled);
    await _refreshAfterBatch();
  }

  /// Deletes every id in [ids] in one write.
  Future<void> deleteMany(Set<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .deleteMany(ids.toList(growable: false));
    await _refreshAfterBatch();
  }

  /// Enables or disables the discover page of every id in [ids].
  Future<void> setExploreEnabledFor(
    Set<int> ids, {
    required bool isExploreEnabled,
  }) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .setExploreEnabledFor(
          ids.toList(growable: false),
          isExploreEnabled: isExploreEnabled,
        );
    await _refreshAfterBatch();
  }

  /// Moves every id in [ids] to the top or bottom of the manual order.
  Future<void> moveToEdge(Set<int> ids, {required bool toTop}) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .moveToEdge(ids.toList(growable: false), toTop: toTop);
    await _refreshAfterBatch();
  }

  /// Renames [from] to [to] everywhere.
  Future<void> renameGroup(String from, String to) async {
    await ref.read(bookSourceRepositoryProvider).renameGroup(from, to);
    await _refreshAfterBatch();
  }

  /// Drops [group] everywhere.
  Future<void> deleteGroup(String group) async {
    await ref.read(bookSourceRepositoryProvider).deleteGroup(group);
    await _refreshAfterBatch();
  }

  /// Removes [group] from the selected sources only.
  Future<void> removeFromGroup(Set<int> ids, String group) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .removeFromGroup(ids.toList(growable: false), group);
    await _refreshAfterBatch();
  }

  /// Puts every id in [ids] into [group], or clears the group when [group] is `null`.
  ///
  /// Writes the payload's `bookSourceGroup`; the check columns keep the last check's result.
  Future<void> setGroupFor(Set<int> ids, String? group) async {
    if (ids.isEmpty) {
      return;
    }
    await ref
        .read(bookSourceRepositoryProvider)
        .setGroupFor(ids.toList(growable: false), group);
    await _refreshAfterBatch();
  }

  Future<void> _refreshAfterBatch() async {
    ref.invalidate(bookSourceListDataProvider);
    state = AsyncData<StoredBookSource?>(_resolve(await _reload()));
  }

  Future<List<StoredBookSource>> _reload() async {
    ref.invalidate(bookSourceListProvider);

    return ref.read(bookSourceListProvider.future);
  }

  // 选中行消失时回退到默认源，保证页面不会指向一个已删除的源。
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

  StoredBookSource? _defaultOf(List<StoredBookSource> all) {
    for (final StoredBookSource source in all) {
      if (source.isEnabled) {
        return source;
      }
    }

    return null;
  }

  StoredBookSource? _find(List<StoredBookSource> all, int id) {
    for (final StoredBookSource source in all) {
      if (source.id == id) {
        return source;
      }
    }

    return null;
  }
}

/// The book source the parsing pages work with; `null` when none is usable.
@riverpod
BookSource? currentBookSource(Ref ref) =>
    ref.watch(selectedBookSourceProvider).value?.source;

/// The list's sort key and group filter; the only place that changes them.
@Riverpod(keepAlive: true)
class BookSourceView extends _$BookSourceView {
  @override
  Future<BookSourceListView> build() async =>
      (await ref.watch(bookSourceViewStoreProvider.future)).load();

  /// Sorts by [order], resets the direction to that key's natural one, and stores the choice.
  Future<void> setOrder(BookSourceSortOrder order) => _apply(
    (BookSourceListView view) =>
        view.copyWith(order: order, ascending: order.defaultAscending),
  );

  /// Flips the sort direction and stores the choice.
  Future<void> toggleAscending() => _apply(
    (BookSourceListView view) => view.copyWith(ascending: !view.ascending),
  );

  /// Turns the one-section-per-host rendering on or off.
  Future<void> setGroupByDomain(bool groupByDomain) => _apply(
    (BookSourceListView view) => view.copyWith(groupByDomain: groupByDomain),
  );

  /// Filters to [group]; `null` means «all groups».
  Future<void> setGroup(String? group) => _apply(
    (BookSourceListView view) => group == null
        ? view.copyWith(clearGroup: true)
        : view.copyWith(group: group),
  );

  /// Writes the manual order following [orderedIds] and refreshes the list.
  Future<void> reorder(List<int> orderedIds) async {
    await ref.read(bookSourceRepositoryProvider).reorder(orderedIds);
    // 手动序同时是默认排序键与「第一条源」的依据，所以两个列表都要重新读。
    ref.invalidate(bookSourceListProvider);
    ref.invalidate(bookSourceListDataProvider);
  }

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

/// What the list page renders: the rows after filtering, the groups and the view.
///
/// A stored group filter that no longer exists is dropped while rendering, not written back.
@riverpod
Future<BookSourceListData> bookSourceListData(Ref ref) async {
  final BookSourceListView view = await ref.watch(
    bookSourceViewProvider.future,
  );
  final BookSourceCheckFilter checkFilter = ref.watch(
    bookSourceCheckFilterSelectionProvider,
  );
  final List<StoredBookSource> all = await ref
      .watch(bookSourceRepositoryProvider)
      .getAll(order: view.order, ascending: view.ascending);
  final List<String> groups = _groupsOf(all);
  final String? stored = view.group;
  final String? group = stored != null && groups.contains(stored)
      ? stored
      : null;
  final Iterable<StoredBookSource> byGroup = group == null
      ? all
      : all.where(
          (StoredBookSource source) =>
              splitGroups(_groupOf(source)).contains(group),
        );
  // 两个轴互相独立：分组是用户写的，校验状态是上一次校验写的。
  final List<StoredBookSource> rows = byGroup
      .where(checkFilter.accepts)
      .toList(growable: false);

  return (
    rows: rows,
    groups: groups,
    view: group == null ? view.copyWith(clearGroup: true) : view,
  );
}

/// Which side of the last check the list shows.
enum BookSourceCheckFilter {
  /// Every source, checked or not.
  all,

  /// Sources with no failure group and no error note — including ones never checked.
  healthy,

  /// Sources whose last check wrote a failure group or an error note.
  failing;

  /// Whether [source] belongs to this side.
  bool accepts(StoredBookSource source) => switch (this) {
    BookSourceCheckFilter.all => true,
    BookSourceCheckFilter.healthy => !hasCheckFailure(source),
    BookSourceCheckFilter.failing => hasCheckFailure(source),
  };
}

/// The check-status axis of the list filter; session state, not persisted.
@Riverpod(keepAlive: true)
class BookSourceCheckFilterSelection extends _$BookSourceCheckFilterSelection {
  @override
  BookSourceCheckFilter build() => BookSourceCheckFilter.all;

  /// Switches the axis.
  void select(BookSourceCheckFilter filter) => state = filter;
}

/// The rows the list shows, the groups they carry and the view that produced them.
typedef BookSourceListData = ({
  List<StoredBookSource> rows,
  List<String> groups,
  BookSourceListView view,
});

List<String> _groupsOf(List<StoredBookSource> sources) {
  final Set<String> groups = <String>{
    for (final StoredBookSource source in sources)
      ...splitGroups(_groupOf(source)),
  };
  final List<String> sorted = groups.toList()..sort();

  return sorted;
}

// 不回退到 groupName：那是校验输出，混用会让源看起来像被重新分组。
String? _groupOf(StoredBookSource source) => source.source.group;
