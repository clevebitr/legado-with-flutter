import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Lists the imported book sources, with the sort, the group filter and the check's own verdicts
/// (`docs/dev/roadmap.md` 5.5, ADR-0045).
///
/// Three things are worth knowing before reading the code:
///
/// * the rows come from [bookSourceListDataProvider], which applies the sort in SQL and the group
///   filter in memory, and which drops a stored filter whose group is gone (ADR-0045 §决策 4);
/// * **dragging is only available in the manual order**: in any other order the list is a plain
///   `ListView`, because a drag there would jump back the moment it was dropped
///   (ADR-0045 §决策 3);
/// * every row shows the **column** projections (`groupName`, `respondTime`, `comment`), not the
///   payload's copies — those are what the batch check of 5.10 writes (ADR-0045 §决策 1).
///
/// Accessibility (C-UI-7): the sort menu and every row action carry tooltips, the group filter is a
/// row of `FilterChip`s with their own labels, and the drag handle is provided by
/// `ReorderableListView` whose items are labelled by their text.
class BookSourceListPage extends ConsumerWidget {
  /// Creates the page.
  const BookSourceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<BookSourceListData> data = ref.watch(
      bookSourceListDataProvider,
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceListTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          _sortMenu(context, ref, l10n, data.value),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: l10n.bookSourceCheckTitle,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.checkSources(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.actionImport,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.importSources(),
            ),
          ),
        ],
      ),
      body: switch (data) {
        AsyncLoading<BookSourceListData>() => const Center(
          child: CircularProgressIndicator(),
        ),
        // 存储层自己是唯一会在这里抛异常的地方（C-ERR-2 允许 presentation 兜底）：
        // 给一条可重试的说明，而不是一个空白页。
        AsyncError<BookSourceListData>() => _loadFailed(context, ref, l10n),
        AsyncData<BookSourceListData>(:final BookSourceListData value) =>
          value.rows.isEmpty && value.groups.isEmpty
              ? _empty(context, l10n)
              : _body(context, ref, l10n, value),
      },
    );
  }

  /// The sort menu; a check mark marks the key in use.
  Widget _sortMenu(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData? data,
  ) {
    final BookSourceSortOrder current =
        data?.view.order ?? BookSourceSortOrder.defaultOrder;

    return PopupMenuButton<BookSourceSortOrder>(
      tooltip: l10n.bookSourceListSortLabel,
      icon: const Icon(Icons.sort),
      onSelected: (BookSourceSortOrder order) =>
          unawaited(ref.read(bookSourceViewProvider.notifier).setOrder(order)),
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<BookSourceSortOrder>>[
            for (final BookSourceSortOrder order in BookSourceSortOrder.values)
              CheckedPopupMenuItem<BookSourceSortOrder>(
                value: order,
                checked: order == current,
                child: Text(_sortLabel(l10n, order)),
              ),
          ],
    );
  }

  /// The state shown when reading the stored sources failed.
  Widget _loadFailed(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.bookSourceListLoadFailed,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: () => ref.invalidate(bookSourceListDataProvider),
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// The state shown while no source is stored: the way in is the import screen.
  Widget _empty(BuildContext context, AppLocalizations l10n) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.bookSourceListEmpty,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: () => pushBookSourceRoute(
                context,
                const BookSourceRoute.importSources(),
              ),
              child: Text(l10n.actionImport),
            ),
          ],
        ),
      ),
    );
  }

  /// The group filter followed by the rows (C-PERF-2: built lazily).
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
  ) {
    final bool canDrag =
        data.view.order == BookSourceSortOrder.defaultOrder &&
        data.view.group == null;

    return Column(
      children: <Widget>[
        _groupFilter(context, ref, l10n, data),
        Expanded(
          child: data.rows.isEmpty
              ? Center(
                  child: Text(
                    l10n.bookSourceListNoMatch,
                    style: context.m3e.typography.base.bodyLarge,
                  ),
                )
              : canDrag
              ? _draggableList(context, ref, l10n, data)
              : _plainList(context, ref, l10n, data),
        ),
      ],
    );
  }

  /// The「全部分组 / 分组…」chips.
  Widget _groupFilter(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
  ) {
    final M3ETheme tokens = context.m3e;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.sm,
      ),
      child: Row(
        children: <Widget>[
          FilterChip(
            label: Text(l10n.bookSourceListGroupAll),
            selected: data.view.group == null,
            onSelected: (_) => unawaited(
              ref.read(bookSourceViewProvider.notifier).setGroup(null),
            ),
          ),
          for (final String group in data.groups) ...<Widget>[
            SizedBox(width: tokens.spacing.sm),
            FilterChip(
              label: Text(group),
              selected: data.view.group == group,
              onSelected: (bool isSelected) => unawaited(
                ref
                    .read(bookSourceViewProvider.notifier)
                    .setGroup(isSelected ? group : null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The rows, draggable into a new manual order (ADR-0045 §决策 3).
  Widget _draggableList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
  ) => ReorderableListView.builder(
    itemCount: data.rows.length,
    // `onReorderItem` 已经把「向下拖动减一」算好了，直接插到 newIndex 即可。
    onReorderItem: (int oldIndex, int newIndex) {
      final List<int> ids = <int>[
        for (final StoredBookSource source in data.rows) source.id,
      ];
      ids.insert(newIndex, ids.removeAt(oldIndex));
      unawaited(ref.read(bookSourceViewProvider.notifier).reorder(ids));
    },
    itemBuilder: (BuildContext context, int index) => _row(
      context,
      ref,
      l10n,
      data,
      data.rows[index],
      key: ValueKey<int>(data.rows[index].id),
    ),
  );

  /// The rows when a drag would be meaningless (another sort key or a filtered group).
  Widget _plainList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
  ) => ListView.builder(
    itemCount: data.rows.length,
    itemBuilder: (BuildContext context, int index) =>
        _row(context, ref, l10n, data, data.rows[index]),
  );

  /// One row: name, the four projected fields, and the row actions in a menu.
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    StoredBookSource source, {
    Key? key,
  }) {
    final M3ETheme tokens = context.m3e;
    final bool isSelected =
        ref.watch(selectedBookSourceProvider).value?.id == source.id;
    final String? group = source.groupName ?? source.source.group;
    final String? comment = source.comment;
    final List<String> lines = <String>[
      // 同 URL 的多条变体在列表里逐条呈现（ADR-0040 §决策 3），但用户得知道它们来自同一站点。
      if (_hasVariant(data.rows, source)) l10n.bookSourceVariantLabel,
      if (group != null && group.isNotEmpty) group,
      if (source.lastUpdateTime case final int millis)
        l10n.bookSourceUpdateTimeLine(_formatDate(context, millis)),
      if (source.respondTime case final int millis)
        l10n.bookSourceListRespondTimeLine(millis),
      if (comment != null && comment.isNotEmpty) comment.split('\n').first,
    ];

    return ListTile(
      key: key,
      onTap: () => unawaited(
        ref.read(selectedBookSourceProvider.notifier).select(source.id),
      ),
      selected: isSelected,
      leading: isSelected
          ? Icon(
              Icons.check_circle,
              color: tokens.colors.primary,
              semanticLabel: l10n.bookSourceCurrentLabel,
            )
          : const Icon(Icons.circle_outlined),
      title: Text(source.source.name),
      subtitle: Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: source.isEnabled,
            onChanged: (bool isEnabled) => unawaited(
              ref
                  .read(selectedBookSourceProvider.notifier)
                  .toggleEnabled(id: source.id, isEnabled: isEnabled),
            ),
          ),
          PopupMenuButton<_RowAction>(
            tooltip: source.source.name,
            onSelected: (_RowAction action) =>
                _act(context, ref, l10n, data, source, action),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_RowAction>>[
              PopupMenuItem<_RowAction>(
                value: _RowAction.debug,
                child: Text(l10n.bookSourceCheckOpenDebug),
              ),
              if (comment != null && comment.isNotEmpty)
                PopupMenuItem<_RowAction>(
                  value: _RowAction.comment,
                  child: Text(l10n.bookSourceListCommentAction),
                ),
              PopupMenuItem<_RowAction>(
                value: _RowAction.delete,
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Runs one row action.
  void _act(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    StoredBookSource source,
    _RowAction action,
  ) {
    switch (action) {
      case _RowAction.debug:
        pushBookSourceRoute(
          context,
          BookSourceRoute.debugSource(sourceId: source.id),
        );
      case _RowAction.comment:
        unawaited(_showComment(context, l10n, source));
      case _RowAction.delete:
        unawaited(_confirmDelete(context, ref, l10n, source));
    }
  }

  /// Shows the full check note (the row only shows its first line).
  Future<void> _showComment(
    BuildContext context,
    AppLocalizations l10n,
    StoredBookSource source,
  ) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l10n.bookSourceListCommentTitle),
      content: SingleChildScrollView(child: Text(source.comment ?? '')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
      ],
    ),
  );

  /// Asks before deleting, then deletes and lets the selection fall back.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StoredBookSource source,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.bookSourceListDeleteTitle),
            content: Text(l10n.bookSourceListDeleteBody(source.source.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).remove(source.id);
  }

  /// Whether another shown source shares this one's `bookSourceUrl`.
  bool _hasVariant(List<StoredBookSource> rows, StoredBookSource source) {
    for (final StoredBookSource other in rows) {
      if (other.id != source.id && other.source.url == source.source.url) {
        return true;
      }
    }

    return false;
  }

  /// The ARB label of [order].
  String _sortLabel(AppLocalizations l10n, BookSourceSortOrder order) =>
      switch (order) {
        BookSourceSortOrder.defaultOrder => l10n.bookSourceListSortDefault,
        BookSourceSortOrder.weight => l10n.bookSourceListSortWeight,
        BookSourceSortOrder.respondTime => l10n.bookSourceListSortRespondTime,
        BookSourceSortOrder.name => l10n.bookSourceListSortName,
      };
}

/// The actions a row's menu offers.
enum _RowAction { debug, comment, delete }

/// Formats a stored millisecond timestamp the way the platform writes a short date.
///
/// `MaterialLocalizations` rather than a hand-written pattern: it follows the locale and the
/// calendar, and it needs no dependency (ADR-0045 §决策 5). The timestamp is read as a **local**
/// instant, which is what a user means by "updated at".
String _formatDate(BuildContext context, int millisecondsSinceEpoch) =>
    MaterialLocalizations.of(context).formatShortDate(
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch),
    );
