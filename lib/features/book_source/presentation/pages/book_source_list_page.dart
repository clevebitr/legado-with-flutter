import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Lists the imported book sources, with the sort, the two filter axes and the row actions
/// (`docs/dev/roadmap.md` 5.5 / §3.9, ADR-0045, ADR-0050).
///
/// Five things are worth knowing before reading the code:
///
/// * the rows come from [bookSourceListDataProvider], which applies the sort in SQL and both
///   filters in memory, and which drops a stored filter whose group is gone (ADR-0045 §决策 4);
/// * the two filters are **independent axes** (ADR-0050 §决策 1): the **group** chips read the
///   user's `bookSourceGroup` from the payload, the **check-status** chips read the check's own
///   columns. Mixing them is what used to make a checked source look regrouped;
/// * the search field filters the visible rows by name / URL / group without touching the store —
///   it is “what am I looking at”, not a persisted choice;
/// * **dragging is only available in the manual order and outside selection mode**: in any other
///   order a drag would jump back the moment it was dropped (ADR-0045 §决策 3), and dragging a
///   multi-selection would have two meanings;
/// * long-pressing a row starts **selection mode** (ADR-0050 §决策 2): batch enable / disable /
///   delete / regroup, one write each.
///
/// Accessibility (C-UI-7): the sort menu, the batch bar and every row action carry tooltips or
/// labels, the filter rows are labelled `FilterChip`s, and selection mode uses `Checkbox`es whose
/// state is read from the same set the batch actions use.
class BookSourceListPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const BookSourceListPage({super.key});

  @override
  ConsumerState<BookSourceListPage> createState() => _BookSourceListPageState();
}

class _BookSourceListPageState extends ConsumerState<BookSourceListPage> {
  /// The rows the user ticked; empty means “not in selection mode”.
  final Set<int> _selected = <int>{};

  /// The search field's controller; its text filters the visible rows.
  final TextEditingController _search = TextEditingController();

  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<BookSourceListData> data = ref.watch(
      bookSourceListDataProvider,
    );
    final BookSourceListData? loaded = data.value;
    final String query = _search.text.trim().toLowerCase();
    final List<StoredBookSource> rows = loaded == null
        ? const <StoredBookSource>[]
        : _matching(loaded.rows, query);
    // 选中的行可能被筛掉（搜索 / 筛选变化）：批量动作只作用于仍然看得见的行。
    final Set<int> selected = <int>{
      for (final StoredBookSource source in rows)
        if (_selected.contains(source.id)) source.id,
    };
    if (selected.length != _selected.length) {
      _selected
        ..clear()
        ..addAll(selected);
    }

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: _isSelecting
          ? _selectionAppBar(l10n, selected, rows)
          : AppBar(
              title: Text(l10n.bookSourceListTitle),
              backgroundColor: tokens.colors.surface,
              actions: <Widget>[
                _sortMenu(context, ref, l10n, loaded),
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
              : _body(context, ref, l10n, value, rows),
      },
      bottomNavigationBar: _isSelecting
          ? _batchBar(context, ref, l10n, selected)
          : null,
    );
  }

  /// The app bar while rows are ticked: count, select all / invert, and a way out.
  AppBar _selectionAppBar(
    AppLocalizations l10n,
    Set<int> selected,
    List<StoredBookSource> rows,
  ) {
    final M3ETheme tokens = context.m3e;

    return AppBar(
      backgroundColor: tokens.colors.surface,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.actionCancel,
        onPressed: () => setState(_selected.clear),
      ),
      title: Text(l10n.bookSourceListSelectedCount(selected.length)),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: l10n.bookSourceListSelectAll,
          onPressed: () => setState(() {
            _selected
              ..clear()
              ..addAll(rows.map((StoredBookSource source) => source.id));
          }),
        ),
        IconButton(
          icon: const Icon(Icons.flip_to_back),
          tooltip: l10n.bookSourceListInvertSelection,
          onPressed: () => setState(() {
            final Set<int> all = <int>{
              for (final StoredBookSource source in rows) source.id,
            };
            // 先算差集再清空：写在级联里会拿清空后的集合去求差，结果变成“全选”。
            final Set<int> inverted = all.difference(_selected);
            _selected
              ..clear()
              ..addAll(inverted);
          }),
        ),
      ],
    );
  }

  /// The batch actions, one write per action (ADR-0050 §决策 2).
  Widget _batchBar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Set<int> selected,
  ) {
    final M3ETheme tokens = context.m3e;
    void run(Future<void> Function() action) =>
        unawaited(action().then((_) => setState(_selected.clear)));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _batchAction(
              l10n.bookSourceListBatchEnable,
              Icons.toggle_on_outlined,
              () => run(
                () => ref
                    .read(selectedBookSourceProvider.notifier)
                    .setEnabledFor(selected, isEnabled: true),
              ),
            ),
            _batchAction(
              l10n.bookSourceListBatchDisable,
              Icons.toggle_off_outlined,
              () => run(
                () => ref
                    .read(selectedBookSourceProvider.notifier)
                    .setEnabledFor(selected, isEnabled: false),
              ),
            ),
            _batchAction(
              l10n.bookSourceListBatchGroup,
              Icons.folder_outlined,
              () => unawaited(_openGroupPicker(l10n, selected)),
            ),
            _batchAction(
              l10n.bookSourceListBatchDelete,
              Icons.delete_outline,
              () => unawaited(_confirmBatchDelete(l10n, selected)),
            ),
          ],
        ),
      ),
    );
  }

  /// One labelled batch button.
  Widget _batchAction(String label, IconData icon, VoidCallback onPressed) =>
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );

  /// The rows whose name / URL / group contains [query].
  List<StoredBookSource> _matching(List<StoredBookSource> rows, String query) {
    if (query.isEmpty) {
      return rows;
    }

    return rows
        .where(
          (StoredBookSource source) =>
              source.source.name.toLowerCase().contains(query) ||
              source.source.url.toLowerCase().contains(query) ||
              (source.source.group ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
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

  /// The search field, the two filter rows and the rows themselves (C-PERF-2: built lazily).
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    List<StoredBookSource> rows,
  ) {
    final M3ETheme tokens = context.m3e;
    final bool canDrag =
        data.view.order == BookSourceSortOrder.defaultOrder &&
        data.view.group == null &&
        !_isSelecting;

    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.sm,
            tokens.spacing.lg,
            0,
          ),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: l10n.bookSourceListSearchHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.actionCancel,
                      onPressed: () => setState(_search.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _groupFilter(context, ref, l10n, data),
        _checkFilter(context, ref, l10n),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    l10n.bookSourceListNoMatch,
                    style: tokens.typography.base.bodyLarge,
                  ),
                )
              : canDrag
              ? _draggableList(context, ref, l10n, data, rows)
              : _plainList(context, ref, l10n, data, rows),
        ),
      ],
    );
  }

  /// The check-status chips (ADR-0050 §决策 1's second axis).
  Widget _checkFilter(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final M3ETheme tokens = context.m3e;
    final BookSourceCheckFilter current = ref.watch(
      bookSourceCheckFilterSelectionProvider,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          for (final BookSourceCheckFilter filter
              in BookSourceCheckFilter.values) ...<Widget>[
            ChoiceChip(
              label: Text(_checkFilterLabel(l10n, filter)),
              selected: filter == current,
              onSelected: (_) => ref
                  .read(bookSourceCheckFilterSelectionProvider.notifier)
                  .select(filter),
            ),
            SizedBox(width: tokens.spacing.sm),
          ],
        ],
      ),
    );
  }

  /// The label of one check-status chip.
  String _checkFilterLabel(
    AppLocalizations l10n,
    BookSourceCheckFilter filter,
  ) => switch (filter) {
    BookSourceCheckFilter.all => l10n.bookSourceCheckFilterAll,
    BookSourceCheckFilter.healthy => l10n.bookSourceCheckFilterHealthy,
    BookSourceCheckFilter.failing => l10n.bookSourceCheckFilterFailing,
  };

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
        vertical: tokens.spacing.xs,
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
    List<StoredBookSource> rows,
  ) => ReorderableListView.builder(
    itemCount: rows.length,
    // `onReorderItem` 已经把「向下拖动减一」算好了，直接插到 newIndex 即可。
    onReorderItem: (int oldIndex, int newIndex) {
      final List<int> ids = <int>[
        for (final StoredBookSource source in rows) source.id,
      ];
      ids.insert(newIndex, ids.removeAt(oldIndex));
      unawaited(ref.read(bookSourceViewProvider.notifier).reorder(ids));
    },
    itemBuilder: (BuildContext context, int index) => _row(
      context,
      ref,
      l10n,
      data,
      rows[index],
      key: ValueKey<int>(rows[index].id),
    ),
  );

  /// The rows when a drag would be meaningless (another sort key or a filtered group).
  Widget _plainList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    List<StoredBookSource> rows,
  ) => ListView.builder(
    itemCount: rows.length,
    itemBuilder: (BuildContext context, int index) =>
        _row(context, ref, l10n, data, rows[index]),
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

    final bool ticked = _selected.contains(source.id);

    return ListTile(
      key: key,
      // 长按进入多选（ADR-0050 §决策 2）；多选期间点一下是勾选，不是切换当前源。
      onLongPress: () => setState(() => _selected.add(source.id)),
      onTap: () => _isSelecting
          ? setState(() {
              if (!_selected.remove(source.id)) {
                _selected.add(source.id);
              }
            })
          : unawaited(
              ref.read(selectedBookSourceProvider.notifier).select(source.id),
            ),
      selected: isSelected || ticked,
      leading: _isSelecting
          ? Checkbox(
              value: ticked,
              onChanged: (_) => setState(() {
                if (!_selected.remove(source.id)) {
                  _selected.add(source.id);
                }
              }),
            )
          : isSelected
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
              PopupMenuItem<_RowAction>(
                value: _RowAction.check,
                child: Text(l10n.bookSourceRowCheck),
              ),
              PopupMenuItem<_RowAction>(
                value: _RowAction.edit,
                child: Text(l10n.bookSourceRowEdit),
              ),
              PopupMenuItem<_RowAction>(
                value: _RowAction.export,
                child: Text(l10n.bookSourceRowExport),
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
      case _RowAction.check:
        unawaited(_checkOne(context, ref, l10n, source));
      case _RowAction.edit:
        pushBookSourceRoute(
          context,
          BookSourceRoute.editSource(sourceId: source.id),
        );
      case _RowAction.export:
        unawaited(_export(context, ref, l10n, source));
      case _RowAction.comment:
        unawaited(_showComment(context, l10n, source));
      case _RowAction.delete:
        unawaited(_confirmDelete(context, ref, l10n, source));
    }
  }

  /// Runs the check on **one** source and reports what it found (ADR-0050 §决策 2's neighbour).
  ///
  /// It reuses M10's `CheckBookSource`, so a single check and a batch check cannot disagree; the
  /// outcome lands in the same columns, which is why the list is invalidated afterwards.
  Future<void> _checkOne(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StoredBookSource source,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.bookSourceRowCheckRunning)),
    );

    final ParseResult<SourceCheckReport> checked = await ref
        .read(checkBookSourceProvider)
        .execute(source.source, const SourceCheckSettings());
    ref.invalidate(bookSourceListDataProvider);
    if (!context.mounted) {
      return;
    }

    final String message = switch (checked) {
      ParseSuccess<SourceCheckReport>(:final SourceCheckReport data) =>
        data.invalidGroups.isEmpty
            ? l10n.bookSourceCheckPassed
            : l10n.bookSourceCheckFound(joinGroups(data.invalidGroups)),
      ParseFailure<SourceCheckReport>() => l10n.bookSourceExportFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Copies the source's JSON to the clipboard and offers to save it (ADR-0050 §决策 4).
  ///
  /// The bytes are the stored **payload**, so a re-import of the export produces the same source.
  /// The clipboard write is **not awaited**: it is a platform channel, and a test host that never
  /// answers it must not stop the save dialog from opening (a hung clipboard would otherwise hang
  /// the whole action).
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StoredBookSource source,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? payload = await ref
        .read(bookSourceRepositoryProvider)
        .payloadOf(source.id);
    if (payload == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceExportFailed)),
      );

      return;
    }

    unawaited(_copyToClipboard(payload));
    final ParseResult<bool> saved = await ref
        .read(bookSourceFileSaverProvider)
        .save(suggestedName: '${source.source.name}.json', contents: payload);
    if (!context.mounted) {
      return;
    }
    final String message = switch (saved) {
      // 「已保存」与「已复制」是两条不同的回执：取消保存对话框时，剪贴板里仍然有内容。
      ParseSuccess<bool>(:final bool data) =>
        data ? l10n.bookSourceExportSaved : l10n.bookSourceExportCopied,
      ParseFailure<bool>() => l10n.bookSourceExportFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Puts [payload] on the clipboard; a platform that refuses it is not an export failure.
  Future<void> _copyToClipboard(String payload) async {
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } on Exception {
      // 只读剪贴板 / 无平台通道：保存文件那条路仍然可用。
    }
  }

  /// Offers the existing groups, a new one, or “no group” (ADR-0050 §决策 1).
  Future<void> _openGroupPicker(
    AppLocalizations l10n,
    Set<int> selected,
  ) async {
    final BookSourceListData? data = ref.read(bookSourceListDataProvider).value;
    final List<String> groups = data?.groups ?? const <String>[];

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(l10n.bookSourceListBatchGroup),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_noGroupToken),
            child: Text(l10n.bookSourceListGroupNone),
          ),
          for (final String group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(group),
              child: Text(group),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_newGroupToken),
            child: Text(l10n.bookSourceListGroupNew),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) {
      return;
    }

    String? group = choice;
    if (choice == _newGroupToken) {
      group = await _askGroupName(l10n);
      if (group == null || !mounted) {
        return;
      }
    }
    if (choice == _noGroupToken) {
      group = null;
    }

    await ref
        .read(selectedBookSourceProvider.notifier)
        .setGroupFor(selected, group);
    if (mounted) {
      setState(_selected.clear);
    }
  }

  /// Asks for a group name; `null` when the user cancels or types nothing.
  Future<String?> _askGroupName(AppLocalizations l10n) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.bookSourceListGroupNew),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.bookSourceListGroupNameHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();

    return name == null || name.isEmpty ? null : name;
  }

  /// Asks before deleting the whole selection (ADR-0050 §决策 2).
  Future<void> _confirmBatchDelete(
    AppLocalizations l10n,
    Set<int> selected,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.bookSourceListBatchDeleteTitle(selected.length)),
            content: Text(l10n.bookSourceListBatchDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.bookSourceListBatchDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).deleteMany(selected);
    if (mounted) {
      setState(_selected.clear);
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
enum _RowAction { debug, check, edit, export, comment, delete }

/// The dialog answer that means “put the selection into no group”.
const String _noGroupToken = ' none';

/// The dialog answer that means “ask for a new group name”.
const String _newGroupToken = ' new';

/// Formats a stored millisecond timestamp the way the platform writes a short date.
///
/// `MaterialLocalizations` rather than a hand-written pattern: it follows the locale and the
/// calendar, and it needs no dependency (ADR-0045 §决策 5). The timestamp is read as a **local**
/// instant, which is what a user means by "updated at".
String _formatDate(BuildContext context, int millisecondsSinceEpoch) =>
    MaterialLocalizations.of(context).formatShortDate(
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch),
    );
