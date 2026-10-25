import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_record.dart';
import 'package:flutter_reader/features/book_source/domain/entities/source_check_settings.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_light.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/export_book_sources.dart';
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
/// * long-pressing a row starts **selection mode** (ADR-0050 §决策 2): check / enable / disable /
///   delete / regroup, one write each. The check action does not write: it hands the ticked rows
///   to the check page (`BookSourceRoute.checkSources`), and the toolbar's check entry hands over
///   the group filter that is active (ADR-0057).
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
  /// The rows the user ticked.
  final Set<int> _selected = <int>{};

  /// Whether selection mode is on.
  ///
  /// A flag of its own, not `_selected.isNotEmpty`: the toolbar's 「多选」 entry has to open the
  /// mode with nothing ticked yet (ADR-0059), and long-press opens it with the pressed row.
  bool _selecting = false;

  /// The search field's controller; its text filters the visible rows.
  final TextEditingController _search = TextEditingController();

  bool get _isSelecting => _selecting;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Enters selection mode, optionally with [ids] already ticked.
  void _startSelecting([Iterable<int> ids = const <int>[]]) => setState(() {
    _selecting = true;
    _selected
      ..clear()
      ..addAll(ids);
  });

  /// Leaves selection mode and drops the ticks.
  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

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
                _directionToggle(context, ref, l10n, loaded),
                _viewMenu(context, ref, l10n, loaded),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: l10n.bookSourceListSelectMode,
                  onPressed: _startSelecting,
                ),
                IconButton(
                  icon: const Icon(Icons.fact_check_outlined),
                  tooltip: l10n.bookSourceCheckTitle,
                  // 带着当前的分组筛选进校验页：用户点了「玄幻」再点校验，想测的就是这一组
                  // （ADR-0057）。没筛选时 group 为 null，校验页照旧跟着它自己的 chips 走。
                  onPressed: () => pushBookSourceRoute(
                    context,
                    BookSourceRoute.checkSources(group: loaded?.view.group),
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
                // 全部导出放进溢出菜单：主工具条已经有 6 个按钮，再加一个会让标题在窄屏上被挤掉。
                PopupMenuButton<_ViewAction>(
                  tooltip: l10n.bookSourceListMoreActions,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (_ViewAction action) =>
                      unawaited(_exportSources(context, ref, l10n)),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_ViewAction>>[
                        PopupMenuItem<_ViewAction>(
                          value: _ViewAction.groupByDomain,
                          child: Text(l10n.bookSourceExportAll),
                        ),
                      ],
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
        onPressed: _stopSelecting,
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
    final String? currentGroup = ref
        .watch(bookSourceListDataProvider)
        .value
        ?.view
        .group;
    void run(Future<void> Function() action) =>
        unawaited(action().then((_) => _stopSelecting()));

    return SafeArea(
      // 横向滚动而不是 spaceAround：宽屏上都排得下，窄屏上也不会把删除挤出可视区（M15 踩坑）。
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            // 「测试选中的源」：把勾选的行交给校验页，改动落在那里（ADR-0057）。
            _batchAction(
              l10n.bookSourceListBatchCheck,
              Icons.fact_check_outlined,
              () => pushBookSourceRoute(
                context,
                BookSourceRoute.checkSources(sourceIds: selected),
              ),
            ),
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
            // 其余动作放进溢出菜单（置顶 / 置底 / 移出分组 / 探索开关）。
            PopupMenuButton<_BatchAction>(
              tooltip: l10n.bookSourceListMoreActions,
              icon: const Icon(Icons.more_horiz),
              onSelected: (_BatchAction action) => _runBatchOverflow(
                action: action,
                currentGroup: currentGroup,
                l10n: l10n,
                selected: selected,
                run: run,
              ),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_BatchAction>>[
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.export,
                      child: Text(
                        l10n.bookSourceExportSelected(selected.length),
                      ),
                    ),
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.moveTop,
                      child: Text(l10n.bookSourceListBatchMoveTop),
                    ),
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.moveBottom,
                      child: Text(l10n.bookSourceListBatchMoveBottom),
                    ),
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.removeGroup,
                      enabled: currentGroup != null,
                      child: Text(l10n.bookSourceListBatchRemoveGroup),
                    ),
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.exploreOn,
                      child: Text(l10n.bookSourceRowExploreEnable),
                    ),
                    PopupMenuItem<_BatchAction>(
                      value: _BatchAction.exploreOff,
                      child: Text(l10n.bookSourceRowExploreDisable),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  /// Runs one overflow batch action.
  void _runBatchOverflow({
    required _BatchAction action,
    required String? currentGroup,
    required AppLocalizations l10n,
    required Set<int> selected,
    required void Function(Future<void> Function()) run,
  }) {
    switch (action) {
      case _BatchAction.export:
        run(() => _exportSources(context, ref, l10n, ids: selected));
      case _BatchAction.moveTop:
        run(
          () => ref
              .read(selectedBookSourceProvider.notifier)
              .moveToEdge(selected, toTop: true),
        );
      case _BatchAction.moveBottom:
        run(
          () => ref
              .read(selectedBookSourceProvider.notifier)
              .moveToEdge(selected, toTop: false),
        );
      case _BatchAction.removeGroup:
        unawaited(_removeFromCurrentGroup(l10n, selected));
      case _BatchAction.exploreOn:
        run(
          () => ref
              .read(selectedBookSourceProvider.notifier)
              .setExploreEnabledFor(selected, isExploreEnabled: true),
        );
      case _BatchAction.exploreOff:
        run(
          () => ref
              .read(selectedBookSourceProvider.notifier)
              .setExploreEnabledFor(selected, isExploreEnabled: false),
        );
    }
  }

  /// One labelled batch button; `null` [onPressed] greys it out.
  Widget _batchAction(String label, IconData icon, VoidCallback? onPressed) =>
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

  /// The direction toggle: the icon and tooltip name the direction in use
  /// (`docs/dev/roadmap.md` §3.10 V4).
  Widget _directionToggle(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData? data,
  ) {
    final bool ascending = data?.view.ascending ?? true;

    return IconButton(
      icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
      tooltip: ascending
          ? l10n.bookSourceListSortAscending
          : l10n.bookSourceListSortDescending,
      onPressed: () => unawaited(
        ref.read(bookSourceViewProvider.notifier).toggleAscending(),
      ),
    );
  }

  /// The view options: one section per host, and the group management dialog.
  Widget _viewMenu(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData? data,
  ) {
    final bool grouped = data?.view.groupByDomain ?? false;
    final List<String> groups = data?.groups ?? const <String>[];

    return PopupMenuButton<_ViewAction>(
      tooltip: l10n.bookSourceListViewOptions,
      icon: const Icon(Icons.visibility_outlined),
      onSelected: (_ViewAction action) => unawaited(_viewAction(ref, action)),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_ViewAction>>[
        CheckedPopupMenuItem<_ViewAction>(
          value: _ViewAction.groupByDomain,
          checked: grouped,
          child: Text(l10n.bookSourceListGroupByDomain),
        ),
        PopupMenuItem<_ViewAction>(
          value: _ViewAction.manageGroups,
          // 没有分组时这一项只会打开一个空对话框（C-BAN-2 的死链接）：直接禁用。
          enabled: groups.isNotEmpty,
          child: Text(l10n.bookSourceListGroupManage),
        ),
      ],
    );
  }

  /// Runs one view-menu action.
  Future<void> _viewAction(WidgetRef ref, _ViewAction action) async {
    switch (action) {
      case _ViewAction.groupByDomain:
        final bool grouped =
            ref.read(bookSourceListDataProvider).value?.view.groupByDomain ??
            false;
        await ref
            .read(bookSourceViewProvider.notifier)
            .setGroupByDomain(!grouped);
      case _ViewAction.manageGroups:
        await _openGroupManagement();
    }
  }

  /// Lists the groups with rename / delete actions (ADR-0052 §决策 4).
  Future<void> _openGroupManagement() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> groups =
        ref.read(bookSourceListDataProvider).value?.groups ?? const <String>[];
    if (groups.isEmpty) {
      return;
    }

    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(l10n.bookSourceListGroupManage),
        children: <Widget>[
          for (final String group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(group),
              child: Text(group),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }

    final _GroupAction? action = await showDialog<_GroupAction>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(chosen),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_GroupAction.rename),
            child: Text(l10n.bookSourceListGroupRename),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_GroupAction.delete),
            child: Text(l10n.bookSourceListGroupDelete),
          ),
          // 下面两项作用于**书源**，而不只是分组标签（ADR-0059 §决策 3）：
          // 「选中」进入多选，后续用批量动作；「删除」连书源一起删，所以带二次确认。
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_GroupAction.selectSources),
            child: Text(l10n.bookSourceListGroupSelectSources),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_GroupAction.deleteSources),
            child: Text(l10n.bookSourceListGroupDeleteSources),
          ),
        ],
      ),
    );
    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case _GroupAction.rename:
        final String? next = await _askGroupName(
          l10n,
          title: l10n.bookSourceListGroupRename,
        );
        if (next == null || !mounted) {
          return;
        }
        await ref
            .read(selectedBookSourceProvider.notifier)
            .renameGroup(chosen, next);
      case _GroupAction.delete:
        final bool confirmed = await _confirmGroupDelete(chosen, l10n);
        if (!confirmed || !mounted) {
          return;
        }
        await ref.read(selectedBookSourceProvider.notifier).deleteGroup(chosen);
      case _GroupAction.selectSources:
        await _selectGroup(chosen);
      case _GroupAction.deleteSources:
        await _deleteGroupSources(l10n, chosen);
    }
  }

  /// The ids of every stored source that carries the user group [group].
  ///
  /// 读的是**未筛选**的全量列表（`bookSourceListProvider`）：分组动作针对「该组全部」，
  /// 不该被当前的分组 / 校验 / 搜索三个筛子左右。分组轴取 payload 里的 `bookSourceGroup`，
  /// 与分组 chips 同一口径（ADR-0050 §决策 1）。
  Set<int> _idsOfGroup(String group) {
    final List<StoredBookSource> all =
        ref.read(bookSourceListProvider).value ?? const <StoredBookSource>[];

    return <int>{
      for (final StoredBookSource source in all)
        if (splitGroups(source.source.group).contains(group)) source.id,
    };
  }

  /// Switches the list to [group] and enters selection mode with every one of its sources ticked.
  ///
  /// 先切视图再勾选：多选只作用于看得见的行（ADR-0050 §决策 2），如果分组筛选停在别处、
  /// 或者「全正常 / 有失效」把行藏了一部分，刚勾上的 id 会在下一帧被剪掉。搜索框也清掉，
  /// 否则用户看到的是一份被关键词缩小的清单。
  Future<void> _selectGroup(String group) async {
    final Set<int> ids = _idsOfGroup(group);
    _search.clear();
    await ref.read(bookSourceViewProvider.notifier).setGroup(group);
    ref
        .read(bookSourceCheckFilterSelectionProvider.notifier)
        .select(BookSourceCheckFilter.all);
    if (!mounted) {
      return;
    }
    _startSelecting(ids);
  }

  /// Asks, then deletes every source of [group].
  ///
  /// 与「删除分组」不同：那个只把 `bookSourceGroup` 里的 token 去掉（书源保留），这个连行一起删
  /// （ADR-0059 §决策 3），所以标题里要同时点名分组与条数。
  Future<void> _deleteGroupSources(AppLocalizations l10n, String group) async {
    final Set<int> ids = _idsOfGroup(group);
    if (ids.isEmpty) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              l10n.bookSourceListGroupDeleteSourcesTitle(ids.length, group),
            ),
            content: Text(l10n.bookSourceListBatchDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.bookSourceListGroupDeleteSources),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).deleteMany(ids);
  }

  /// Asks before removing [group] from every source.
  Future<bool> _confirmGroupDelete(String group, AppLocalizations l10n) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(l10n.bookSourceListGroupDelete),
          content: Text(l10n.bookSourceListGroupDeleteBody(group)),
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

  /// Takes the selection out of the group currently filtered on.
  Future<void> _removeFromCurrentGroup(
    AppLocalizations l10n,
    Set<int> selected,
  ) async {
    final String? group = ref
        .read(bookSourceListDataProvider)
        .value
        ?.view
        .group;
    if (group == null) {
      return;
    }
    await ref
        .read(selectedBookSourceProvider.notifier)
        .removeFromGroup(selected, group);
    if (mounted) {
      setState(_selected.clear);
    }
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
        data.view.ascending &&
        data.view.group == null &&
        !data.view.groupByDomain &&
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
        _checkFilter(context, ref, l10n, rows),
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
              : data.view.groupByDomain
              ? _sectionedList(context, ref, l10n, data, rows)
              : _plainList(context, ref, l10n, data, rows),
        ),
      ],
    );
  }

  /// The check-status chips (ADR-0050 §决策 1's second axis), plus the one-click actions that only
  /// make sense there.
  ///
  /// When the axis is 「有失效」 the row is exactly “the failing sources you can see”, so the two
  /// buttons that act on them belong next to the chip that selected them (ADR-0059 §决策 2): no
  /// second entry to discover, and the list under the buttons is the confirmation of what will be
  /// hit. They work on [rows] — the same visible set the 「有失效」 chip produced — not on the whole
  /// library.
  Widget _checkFilter(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<StoredBookSource> rows,
  ) {
    final M3ETheme tokens = context.m3e;
    final BookSourceCheckFilter current = ref.watch(
      bookSourceCheckFilterSelectionProvider,
    );
    final Set<int> failing = <int>{
      if (current == BookSourceCheckFilter.failing)
        for (final StoredBookSource source in rows)
          if (hasCheckFailure(source)) source.id,
    };

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
          if (current == BookSourceCheckFilter.failing) ...<Widget>[
            SizedBox(width: tokens.spacing.sm),
            TextButton.icon(
              onPressed: failing.isEmpty
                  ? null
                  : () => unawaited(_disableFailing(failing)),
              icon: const Icon(Icons.toggle_off_outlined),
              label: Text(l10n.bookSourceListInvalidDisable),
            ),
            SizedBox(width: tokens.spacing.sm),
            TextButton.icon(
              onPressed: failing.isEmpty
                  ? null
                  : () => unawaited(_confirmFailingDelete(l10n, failing)),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.bookSourceListInvalidDelete),
            ),
          ],
        ],
      ),
    );
  }

  /// Disables every source in [ids] in one write.
  ///
  /// 没有二次确认：禁用是用户态且可逆，校验失败本身已经是他想要的信号；删除另说。
  Future<void> _disableFailing(Set<int> ids) async {
    await ref
        .read(selectedBookSourceProvider.notifier)
        .setEnabledFor(ids, isEnabled: false);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)
              .bookSourceListInvalidDisabled(ids.length),
        ),
      ),
    );
  }

  /// Asks before deleting every failing source of the current list.
  Future<void> _confirmFailingDelete(
    AppLocalizations l10n,
    Set<int> ids,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.bookSourceListInvalidDeleteTitle(ids.length)),
            content: Text(l10n.bookSourceListBatchDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.bookSourceListInvalidDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).deleteMany(ids);
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

  /// The rows in one section per host (`docs/dev/roadmap.md` §3.10 V4).
  ///
  /// The sections are built from the rows already loaded and keep [ListView.builder]'s laziness
  /// (C-PERF-2): the headers are just extra entries in the same flat list.
  Widget _sectionedList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    List<StoredBookSource> rows,
  ) {
    final List<_ListEntry> entries = <_ListEntry>[];
    String? previousHost;
    for (final StoredBookSource source in rows) {
      final String host = _hostOf(source.source.url);
      if (host != previousHost) {
        entries.add(_SectionEntry(host));
        previousHost = host;
      }
      entries.add(_RowEntry(source));
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) =>
          switch (entries[index]) {
            _SectionEntry(:final String host) => _sectionHeader(context, host),
            _RowEntry(:final StoredBookSource source) => _row(
              context,
              ref,
              l10n,
              data,
              source,
            ),
          },
    );
  }

  /// One host header inside the domain-grouped list.
  Widget _sectionHeader(BuildContext context, String host) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xs,
      ),
      child: Text(host, style: tokens.typography.base.titleSmall),
    );
  }

  /// One row: name, the four projected fields, and the row actions in a menu.
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BookSourceListData data,
    StoredBookSource source, {
    Key? key,
  }) {
    final bool isSelected =
        ref.watch(selectedBookSourceProvider).value?.id == source.id;
    final String? group = source.groupName ?? source.source.group;
    final String? comment = source.comment;
    final DateTime now = ref.read(clockProvider).now();
    final SourceCheckRecord? lastCheck = source.lastCheck;
    final List<String> lines = <String>[
      // 同 URL 的多条变体在列表里逐条呈现（ADR-0040 §决策 3），但用户得知道它们来自同一站点。
      if (_hasVariant(data.rows, source)) l10n.bookSourceVariantLabel,
      if (group != null && group.isNotEmpty) group,
      // 状态行紧跟分组：「上次校验 2 分钟前 · 620 毫秒」（ADR-0052 §决策 2）。
      if (lastCheck != null) _lastCheckLine(context, l10n, lastCheck, now),
      if (!source.isExploreEnabled) l10n.bookSourceListExploreOff,
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
      onLongPress: () => _startSelecting(<int>[source.id]),
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
          // 状态灯：颜色不单独承载信息，tooltip + Semantics 给出四态标签（C-UI-7）。
          : _StatusLight(light: sourceCheckLightOf(source), l10n: l10n),
      title: Text(source.source.name),
      subtitle: Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: source.isEnabled,
            // 多选期间行内的开关与行菜单都关掉：此时点行内的东西一律是「勾选」意图，
            // 一个误触就把单条源改了（ADR-0059）。
            onChanged: _isSelecting
                ? null
                : (bool isEnabled) => unawaited(
                    ref
                        .read(selectedBookSourceProvider.notifier)
                        .toggleEnabled(id: source.id, isEnabled: isEnabled),
                  ),
          ),
          PopupMenuButton<_RowAction>(
            tooltip: source.source.name,
            enabled: !_isSelecting,
            onSelected: (_RowAction action) =>
                _act(context, ref, l10n, data, source, action),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_RowAction>>[
              PopupMenuItem<_RowAction>(
                value: _RowAction.toggleExplore,
                child: Text(
                  source.isExploreEnabled
                      ? l10n.bookSourceRowExploreDisable
                      : l10n.bookSourceRowExploreEnable,
                ),
              ),
              // 只有声明了登录能力的源才给这个入口：否则它只是一个会打开首页的菜单项
              // （ADR-0068 增补）。
              if (source.source.loginGuard.isDeclared)
                PopupMenuItem<_RowAction>(
                  value: _RowAction.signIn,
                  child: Text(l10n.bookSourceRowSignIn),
                ),
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
      case _RowAction.toggleExplore:
        unawaited(
          ref.read(selectedBookSourceProvider.notifier).setExploreEnabledFor(
            <int>{source.id},
            isExploreEnabled: !source.isExploreEnabled,
          ),
        );
      case _RowAction.signIn:
        unawaited(_signIn(context, ref, l10n, source));
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

  /// Opens the source's login page in the visible WebView (`loginUrl`, else the source URL).
  ///
  /// Cookies the page earns land in the v8 jar (`PersistentCookieManager`) and the next request
  /// carries them, so this is the actionable half of `ParseFailureKind.loginRequired`
  /// (ADR-0068 §决策 3/4 and its 2026-10-24 addendum). The native `loginUi` form is the M21b
  /// login/Cookie management UI (`docs/dev/ui-gap.md` U15), not this entry.
  ///
  /// Reuses the same [SourceVerification] port the JS family pushes, so a source's own
  /// `java.startBrowser` and this menu entry cannot behave differently.
  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    StoredBookSource source,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SourceVerification verification = ref.read(
      sourceVerificationProvider,
    );
    if (!verification.isSupported) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceSignInUnsupported)),
      );

      return;
    }

    final ParseResult<SourceVerificationOutcome> outcome = await verification
        .verify(
          SourceVerificationRequest(
            sourceUrl: source.source.url,
            sourceName: source.source.name,
            url: _signInUrl(source.source),
            title: source.source.name,
            headers: source.source.headers,
          ),
        );
    if (!context.mounted) {
      return;
    }

    switch (outcome) {
      case ParseSuccess<SourceVerificationOutcome>():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceSignInDone)),
        );
      case ParseFailure<SourceVerificationOutcome>(
        :final ParseFailureKind kind,
      ):
        // 用户自己关掉页面时什么都不说：那是「算了」，不是失败。
        if (kind == ParseFailureKind.cancelled) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceSignInFailed)),
        );
    }
  }

  /// The address the login entry opens: `loginUrl` when it is an address, else the source URL.
  ///
  /// `loginUrl` is a **URL rule**, so it may carry the `,{…}` suffix of `book-source.md` §4.3
  /// (the suffix is dropped here: the page does its own requests) or be a `@js:` script defining
  /// `login()`; a script has no address to open, so the source's own page is shown instead — that
  /// is where the human check usually lives.
  String _signInUrl(BookSource source) {
    final String? loginUrl = source.loginUrl;
    if (loginUrl == null || loginUrl.trim().isEmpty) {
      return source.url;
    }

    return switch (parseUrlRule(loginUrl, rulePath: 'loginUrl')) {
      ParseSuccess<UrlRule>(:final UrlRule data)
          when data.template.trim().toLowerCase().startsWith('http') =>
        resolveAbsoluteUrl(data.template.trim(), source.url),
      ParseFailure<UrlRule>() || ParseSuccess<UrlRule>() => source.url,
    };
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

  /// Writes every source (or the ticked [ids]) to a file the user picks
  /// (`docs/dev/roadmap.md` 5.8, ADR-0071 §决策 3).
  ///
  /// The bytes are the stored payloads with `enabled` / `customOrder` written over the imported
  /// values, so a re-import elsewhere reproduces the list the user is looking at.
  Future<void> _exportSources(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    Set<int>? ids,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ParseResult<BookSourceExport> exported = await ref
        .read(exportBookSourcesProvider)
        .execute(ids: ids);
    final BookSourceExport document;
    switch (exported) {
      case ParseSuccess<BookSourceExport>(:final BookSourceExport data):
        document = data;
      case ParseFailure<BookSourceExport>():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bookSourceExportEmpty)),
        );

        return;
    }

    final ParseResult<bool> saved = await ref
        .read(jsonFileSaverProvider)
        .save(suggestedName: document.fileName, contents: document.contents);
    if (!context.mounted) {
      return;
    }

    final String message = switch (saved) {
      ParseSuccess<bool>(data: false) => l10n.actionCancel,
      ParseSuccess<bool>() => l10n.bookSourceExportAllSaved(document.count),
      ParseFailure<bool>() => l10n.bookSourceExportFailed,
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
    // 走批量导出同一个方法：单条导出也要把 `enabled` / `customOrder` 换成当前用户态
    // （ADR-0071 §决策 3 修订了 ADR-0050 §决策 4 的「字节就是 payload」）。
    final List<String> payloads = await ref
        .read(bookSourceRepositoryProvider)
        .exportPayloads(ids: <int>{source.id});
    if (payloads.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookSourceExportFailed)),
      );

      return;
    }

    final String payload = payloads.first;
    unawaited(_copyToClipboard(payload));
    final ParseResult<bool> saved = await ref
        .read(jsonFileSaverProvider)
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
      group = await _askGroupName(l10n, title: l10n.bookSourceListGroupNew);
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
  ///
  /// The dialog owns its [TextEditingController] (`_GroupNameDialog`): disposing it right after
  /// `showDialog` returns would leave the closing route's animation rebuilding a disposed
  /// controller (this is what the first version did, and the widget test caught it).
  Future<String?> _askGroupName(
    AppLocalizations l10n, {
    required String title,
  }) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _GroupNameDialog(
        title: title,
        hint: l10n.bookSourceListGroupNameHint,
        cancelLabel: l10n.actionCancel,
        saveLabel: l10n.actionSave,
      ),
    );

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
      _stopSelecting();
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
enum _RowAction {
  toggleExplore,
  signIn,
  debug,
  check,
  edit,
  export,
  comment,
  delete,
}

/// The view-menu actions (`docs/dev/roadmap.md` §3.10 V4).
enum _ViewAction { groupByDomain, manageGroups }

/// The batch actions that live in the overflow menu (ADR-0052 §决策 4).
enum _BatchAction {
  export,
  moveTop,
  moveBottom,
  removeGroup,
  exploreOn,
  exploreOff,
}

/// What to do with a group in the management dialog (ADR-0052 §决策 4).
enum _GroupAction { rename, delete, selectSources, deleteSources }

/// One entry of the domain-grouped list: either a host header or a source row.
sealed class _ListEntry {
  const _ListEntry();
}

/// A host header inside the domain-grouped list.
final class _SectionEntry extends _ListEntry {
  const _SectionEntry(this.host);

  /// The host the following rows share.
  final String host;
}

/// A source row inside the domain-grouped list.
final class _RowEntry extends _ListEntry {
  const _RowEntry(this.source);

  /// The row to render.
  final StoredBookSource source;
}

/// The host of [url], or the raw text when it does not parse as a URI.
String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;

/// The ARB label of one status light (ADR-0052 §决策 2).
String _lightLabel(AppLocalizations l10n, SourceCheckLight light) =>
    switch (light) {
      SourceCheckLight.passed => l10n.bookSourceCheckStatusPassed,
      SourceCheckLight.failed => l10n.bookSourceCheckStatusFailed,
      SourceCheckLight.degraded => l10n.bookSourceCheckStatusDegraded,
      SourceCheckLight.unchecked => l10n.bookSourceCheckStatusUnchecked,
    };

/// A one-field dialog that owns its text controller (ADR-0052 §决策 4).
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String saveLabel;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: Text(widget.saveLabel),
      ),
    ],
  );
}

/// The coloured dot that carries the four-state verdict (`docs/dev/roadmap.md` §3.10 V1).
///
/// It is decorative in the ARIA sense — the colour is one channel only — so the label travels in
/// a [Tooltip] and a [Semantics] node (C-UI-7). Colours are tokens, never literals (C-UI-1).
class _StatusLight extends StatelessWidget {
  const _StatusLight({required this.light, required this.l10n});

  final SourceCheckLight light;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;
    final String label = _lightLabel(l10n, light);
    final Color color = switch (light) {
      SourceCheckLight.passed => tokens.colors.primary,
      SourceCheckLight.failed => tokens.colors.error,
      // 降级态（超时 / JS 失效）用 tertiary：不是源的错，但也不能当绿。
      SourceCheckLight.degraded => tokens.colors.tertiary,
      SourceCheckLight.unchecked => tokens.colors.outline,
    };

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox(
          width: tokens.spacing.lg,
          height: tokens.spacing.lg,
          child: Center(
            child: Container(
              width: tokens.spacing.sm,
              height: tokens.spacing.sm,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "last checked" line of a row (`docs/dev/roadmap.md` §3.10 V1).
String _lastCheckLine(
  BuildContext context,
  AppLocalizations l10n,
  SourceCheckRecord record,
  DateTime now,
) => l10n.bookSourceListLastCheckLine(
  _lastCheckWhen(context, l10n, record, now),
  record.elapsedMillis,
);

/// How long ago [record] ran, expressed the way the row shows it.
String _lastCheckWhen(
  BuildContext context,
  AppLocalizations l10n,
  SourceCheckRecord record,
  DateTime now,
) {
  final Duration age = now.difference(record.checkedAt);
  if (age.isNegative || age.inMinutes < 1) {
    return l10n.bookSourceListLastCheckJustNow;
  }
  if (age.inMinutes < 60) {
    return l10n.bookSourceListLastCheckMinutesAgo(age.inMinutes);
  }
  if (age.inHours < 24) {
    return l10n.bookSourceListLastCheckHoursAgo(age.inHours);
  }
  if (age.inDays < 7) {
    return l10n.bookSourceListLastCheckDaysAgo(age.inDays);
  }

  return l10n.bookSourceListLastCheckOn(
    MaterialLocalizations.of(context).formatShortDate(record.checkedAt),
  );
}

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
