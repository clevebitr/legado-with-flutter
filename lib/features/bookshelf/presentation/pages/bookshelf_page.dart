import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/bookshelf_route.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/shelf_groups_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The filter that shows every book.
const int _allGroupsFilter = -1;

/// The filter that shows the books without a group.
const int _ungroupedFilter = -2;

/// The books the user put on the shelf (`docs/dev/roadmap.md` 5.4, M19).
///
/// The rows are managed here and nowhere else: pinning, the tracking / finished switch, deletion,
/// the group chips and the batch actions are the user state the shelf owns. Opening a book goes
/// through the presentation port (ADR-0042 §决策 2), so the shelf never imports the reader feature
/// (C-ARCH-2); the row resumes at the stored chapter, which is the whole reason the shelf owns the
/// progress table.
///
/// Three behaviours are deliberate (ADR-0066):
///
/// * **the group filter is page state, not storage**: which chip is selected is a view of the same
///   list, so it lives in [State] (C-STATE-5) instead of a provider;
/// * **selection is the long press**: a tap opens a book, so batch mode needs a different gesture,
///   and an empty selection *is* “not in batch mode” — one state instead of two;
/// * **batch writes are all-or-nothing per action**: one notifier call per action, one reload, one
///   snack bar (ADR-0050 §决策 2's habit for the source list).
///
/// Accessibility (C-UI-7): each row is a [ListTile] (label from its own text) and the menu button
/// carries the row title in its tooltip.
class BookshelfPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

/// State of the shelf page: the chip filter and the batch selection.
class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  /// The selected chip: [_allGroupsFilter], [_ungroupedFilter] or a group id.
  int _filter = _allGroupsFilter;

  /// The ids of the rows selected for a batch action; empty means “not in batch mode”.
  final Set<int> _selected = <int>{};

  /// Whether a batch action is in flight (the toolbar's buttons are disabled meanwhile).
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<ShelvedBook>> shelf = ref.watch(bookshelfProvider);
    final List<ShelfGroup> groups =
        ref.watch(shelfGroupsProvider).value ?? const <ShelfGroup>[];

    // 分组被删掉时（管理页里删的），筛选不能停在一个不存在的组上。
    if (_filter >= 0 &&
        !groups.any((ShelfGroup group) => group.id == _filter)) {
      _filter = _allGroupsFilter;
    }

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: _selected.isEmpty
          ? AppBar(
              title: Text(l10n.shelfTitle),
              backgroundColor: tokens.colors.surface,
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: l10n.shelfManageGroups,
                  onPressed: () => pushBookshelfRoute(
                    context,
                    const BookshelfRoute.groups(),
                  ),
                ),
              ],
            )
          : _selectionBar(context, l10n, shelf.value ?? const <ShelvedBook>[]),
      body: switch (shelf) {
        AsyncData<List<ShelvedBook>>(:final List<ShelvedBook> value) =>
          value.isEmpty
              ? StateMessage(
                  message: l10n.shelfEmpty,
                  icon: Icons.library_books_outlined,
                )
              : _body(context, value, groups, tokens, l10n),
        // 读取失败与「书架为空」是两件事：空态会误导用户以为书没了。
        AsyncError<List<ShelvedBook>>() => StateMessage(
          message: l10n.shelfLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The group chips followed by the lazily built list of entries (C-PERF-2).
  Widget _body(
    BuildContext context,
    List<ShelvedBook> books,
    List<ShelfGroup> groups,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) {
    final List<ShelvedBook> visible = _visible(books);
    final bool hasUngrouped = books.any(
      (ShelvedBook book) => book.groupId == null,
    );

    return Column(
      children: <Widget>[
        if (groups.isNotEmpty || hasUngrouped)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.md,
              vertical: tokens.spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                _chip(_allGroupsFilter, l10n.shelfGroupAll, tokens),
                for (final ShelfGroup group in groups)
                  _chip(group.id, group.name, tokens),
                if (hasUngrouped)
                  _chip(_ungroupedFilter, l10n.shelfGroupUngrouped, tokens),
              ],
            ),
          ),
        Expanded(
          child: visible.isEmpty
              // 分组里没有书与「书架为空」不同：前者是筛选的结果，不是数据丢了。
              ? StateMessage(
                  message: l10n.shelfGroupEmpty,
                  icon: Icons.filter_alt_off_outlined,
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _row(context, visible[index], tokens, l10n),
                ),
        ),
      ],
    );
  }

  /// One filter chip; tapping it only changes the page's filter.
  Widget _chip(int value, String label, M3ETheme tokens) => Padding(
    padding: EdgeInsets.only(right: tokens.spacing.xs),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  /// The entries the current chip shows.
  List<ShelvedBook> _visible(List<ShelvedBook> books) => switch (_filter) {
    _allGroupsFilter => books,
    _ungroupedFilter =>
      books.where((ShelvedBook book) => book.groupId == null).toList(),
    final int groupId =>
      books.where((ShelvedBook book) => book.groupId == groupId).toList(),
  };

  /// One shelf row.
  Widget _row(
    BuildContext context,
    ShelvedBook book,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ListTile(
    selected: _selected.contains(book.id),
    // 从书架打开阅读器：`tocUrl` 在 5.3 之后入库，老行回落到书籍页（ADR-0044 §决策 3）。
    onTap: () => _selected.isEmpty
        ? _open(context, book)
        : setState(() => _toggleSelected(book.id)),
    // 长按进入多选：行上的点击已经属于「打开这本书」。
    onLongPress: () => setState(() {
      _selected
        ..clear()
        ..add(book.id);
    }),
    // 书架封面：用户换过的本地封面优先，否则用入库时存的 `coverUrl`（5.4 起就有），
    // 都没有时是占位块（S1）。
    leading: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        CoverImage(
          url: book.coverUrl,
          localPath: book.customCoverPath,
          // 宽高由间距令牌推导，保持书封约 3:4 的比例，不写死像素。
          width: tokens.spacing.xxl + tokens.spacing.sm,
          height: (tokens.spacing.xxl + tokens.spacing.sm) * 1.35,
        ),
        // 已读完仍然要在封面上留一个角标：封面替换掉了原来的图标位，状态不能丢。
        if (book.status == ShelfStatus.read)
          Positioned(
            right: -tokens.spacing.xs,
            bottom: -tokens.spacing.xs,
            child: Icon(
              Icons.check_circle,
              size: tokens.spacing.lg,
              semanticLabel: l10n.shelfStatusRead,
            ),
          ),
      ],
    ),
    title: Text(book.name),
    subtitle: Text(_subtitle(book, l10n)),
    trailing: PopupMenuButton<_ShelfAction>(
      tooltip: book.name,
      onSelected: (_ShelfAction action) => unawaited(_act(book, action, l10n)),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_ShelfAction>>[
        PopupMenuItem<_ShelfAction>(
          value: _ShelfAction.edit,
          child: Text(l10n.shelfEditTitle),
        ),
        if (book.isPinned)
          PopupMenuItem<_ShelfAction>(
            value: _ShelfAction.unpin,
            child: Text(l10n.shelfActionUnpin),
          )
        else
          PopupMenuItem<_ShelfAction>(
            value: _ShelfAction.pin,
            child: Text(l10n.shelfActionPin),
          ),
        if (book.status == ShelfStatus.read)
          PopupMenuItem<_ShelfAction>(
            value: _ShelfAction.markTracking,
            child: Text(l10n.shelfActionMarkTracking),
          )
        else
          PopupMenuItem<_ShelfAction>(
            value: _ShelfAction.markRead,
            child: Text(l10n.shelfActionMarkRead),
          ),
        PopupMenuItem<_ShelfAction>(
          value: _ShelfAction.remove,
          child: Text(l10n.shelfActionRemove),
        ),
      ],
    ),
  );

  /// The app bar while rows are selected: select-all, batch actions and exit.
  AppBar _selectionBar(
    BuildContext context,
    AppLocalizations l10n,
    List<ShelvedBook> books,
  ) {
    final List<ShelvedBook> visible = _visible(books);
    final bool allSelected =
        visible.isNotEmpty &&
        visible.every((ShelvedBook book) => _selected.contains(book.id));

    return AppBar(
      backgroundColor: context.m3e.colors.surface,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.shelfSelectionExit,
        onPressed: () => setState(_selected.clear),
      ),
      title: Text(l10n.shelfSelectionCount(_selected.length)),
      actions: <Widget>[
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? l10n.shelfSelectionClear : l10n.shelfSelectAll,
          onPressed: _busy
              ? null
              : () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(visible.map((ShelvedBook book) => book.id));
                  }
                }),
        ),
        PopupMenuButton<_BatchAction>(
          tooltip: l10n.shelfBatchAction,
          enabled: !_busy,
          onSelected: (_BatchAction action) =>
              unawaited(_runBatch(action, l10n)),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<_BatchAction>>[
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.assignGroup,
              child: Text(l10n.shelfBatchGroup),
            ),
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.pin,
              child: Text(l10n.shelfActionPin),
            ),
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.unpin,
              child: Text(l10n.shelfActionUnpin),
            ),
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.markRead,
              child: Text(l10n.shelfActionMarkRead),
            ),
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.markTracking,
              child: Text(l10n.shelfActionMarkTracking),
            ),
            PopupMenuItem<_BatchAction>(
              value: _BatchAction.remove,
              child: Text(l10n.shelfActionRemove),
            ),
          ],
        ),
      ],
    );
  }

  /// Adds [id] to the selection, or removes it when it is already there.
  void _toggleSelected(int id) {
    if (!_selected.remove(id)) {
      _selected.add(id);
    }
  }

  /// Opens [book] in the reader (ADR-0042 §决策 2).
  ///
  /// Refresh is not this page's job: the progress write goes through the composition root, which
  /// invalidates the shelf after storing a position — so 「阅读到」 is fresh whenever it is shown,
  /// including after a chapter switch inside the reader.
  void _open(BuildContext context, ShelvedBook book) => ref
      .read(appNavigationProvider)
      .openReader(
        context,
        sourceUrl: book.sourceUrl,
        bookUrl: book.bookUrl,
        bookName: book.name,
        // `tocUrl` 是 5.3 起入库的目录地址；老行没有它时回落到书籍页（ADR-0044 §决策 3）。
        tocUrl: book.tocUrl ?? book.bookUrl,
      );

  /// The second line of a row: author, then where the reader stopped (or the last chapter).
  ///
  /// Progress wins over `lastChapter` because it is about **this** user rather than about the
  /// site; a book that was never opened falls back to the snapshot taken when it was added.
  String _subtitle(ShelvedBook book, AppLocalizations l10n) {
    final String? progressChapter = book.progress?.chapterName;
    final String line = switch (progressChapter) {
      final String chapter when chapter.isNotEmpty => l10n.shelfProgressLine(
        chapter,
      ),
      _ => switch (book.lastChapter) {
        final String chapter when chapter.isNotEmpty =>
          l10n.bookSourceLastChapterLine(chapter),
        _ => l10n.shelfStatusTracking,
      },
    };

    return switch (book.author) {
      final String author when author.isNotEmpty => '$author · $line',
      _ => line,
    };
  }

  /// Runs one row action: confirmation first for deletion, then the write.
  Future<void> _act(
    ShelvedBook book,
    _ShelfAction action,
    AppLocalizations l10n,
  ) async {
    if (action == _ShelfAction.edit) {
      // 编辑页是 bookshelf 自己的一页（M33）：带上整行，页面用当前值填表。
      pushBookshelfRoute(context, BookshelfRoute.editBook(book: book));

      return;
    }
    if (action == _ShelfAction.remove) {
      final bool confirmed = await _confirmRemove(context, l10n);
      if (!confirmed) {
        return;
      }
    }
    if (!mounted) {
      return;
    }

    final Bookshelf shelf = ref.read(bookshelfProvider.notifier);
    final ParseResult<void> result = switch (action) {
      // `edit` 在上面已经返回：编辑器不是一次仓储写入。
      _ShelfAction.edit => const ParseResult<void>.success(null),
      _ShelfAction.pin => await shelf.updateUserState(
        id: book.id,
        status: book.status,
        isPinned: true,
      ),
      _ShelfAction.unpin => await shelf.updateUserState(
        id: book.id,
        status: book.status,
        isPinned: false,
      ),
      _ShelfAction.markRead => await shelf.updateUserState(
        id: book.id,
        status: ShelfStatus.read,
        isPinned: book.isPinned,
      ),
      _ShelfAction.markTracking => await shelf.updateUserState(
        id: book.id,
        status: ShelfStatus.tracking,
        isPinned: book.isPinned,
      ),
      _ShelfAction.remove => await shelf.remove(book.id),
    };

    if (!mounted) {
      return;
    }
    if (result is ParseFailure<void>) {
      _showMessage(l10n.shelfWriteFailed);
    }
  }

  /// Runs one batch action over the selection and leaves batch mode on success.
  ///
  /// The dialog-based actions are awaited first: a dismissed dialog answers `null` and writes
  /// nothing, which is why it is not reported as a failure.
  Future<void> _runBatch(_BatchAction action, AppLocalizations l10n) async {
    final List<int> ids = _selected.toList();
    if (ids.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    final ParseResult<void>? result = switch (action) {
      _BatchAction.assignGroup => await _assignGroup(ids, l10n),
      _BatchAction.remove => await _confirmAndRemove(ids, l10n),
      _ => await _applyBatch(ids, action),
    };
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result == null) {
      return;
    }
    if (result is ParseFailure<void>) {
      _showMessage(l10n.shelfWriteFailed);

      return;
    }
    setState(_selected.clear);
  }

  /// Applies a batch action that needs no further input.
  Future<ParseResult<void>> _applyBatch(List<int> ids, _BatchAction action) {
    final Bookshelf shelf = ref.read(bookshelfProvider.notifier);

    return switch (action) {
      _BatchAction.pin => shelf.setPinnedFor(ids: ids, isPinned: true),
      _BatchAction.unpin => shelf.setPinnedFor(ids: ids, isPinned: false),
      _BatchAction.markRead => shelf.setStatusFor(
        ids: ids,
        status: ShelfStatus.read,
      ),
      _BatchAction.markTracking => shelf.setStatusFor(
        ids: ids,
        status: ShelfStatus.tracking,
      ),
      // 这两个由 [_runBatch] 先问一句再写，不会走到这里。
      _BatchAction.assignGroup || _BatchAction.remove =>
        Future<ParseResult<void>>.value(const ParseResult<void>.success(null)),
    };
  }

  /// Asks for the target group and moves [ids] into it; `null` means the dialog was dismissed.
  Future<ParseResult<void>?> _assignGroup(
    List<int> ids,
    AppLocalizations l10n,
  ) async {
    final List<ShelfGroup> groups =
        ref.read(shelfGroupsProvider).value ?? const <ShelfGroup>[];
    final int? chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: Text(l10n.shelfBatchGroup),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(_ungroupedFilter),
            child: Text(l10n.shelfGroupUngrouped),
          ),
          for (final ShelfGroup group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(group.id),
              child: Text(group.name),
            ),
        ],
      ),
    );
    if (chosen == null) {
      return null;
    }

    return ref
        .read(bookshelfProvider.notifier)
        .setGroupFor(
          ids: ids,
          groupId: chosen == _ungroupedFilter ? null : chosen,
        );
  }

  /// Confirms and then deletes every selected row.
  Future<ParseResult<void>> _confirmAndRemove(
    List<int> ids,
    AppLocalizations l10n,
  ) async {
    final bool confirmed = await _confirmRemove(context, l10n);
    if (!confirmed || !mounted) {
      return const ParseResult<void>.success(null);
    }

    return ref.read(bookshelfProvider.notifier).removeMany(ids);
  }

  /// Shows one transient message.
  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// Asks before a shelf entry (and its progress) is deleted.
  Future<bool> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shelfRemoveTitle),
        content: Text(l10n.shelfRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}

/// The actions the row menu offers.
enum _ShelfAction { edit, pin, unpin, markRead, markTracking, remove }

/// The actions the selection toolbar offers.
enum _BatchAction { assignGroup, pin, unpin, markRead, markTracking, remove }
