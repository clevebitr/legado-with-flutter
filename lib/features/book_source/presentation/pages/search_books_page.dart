import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_search_scope.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/search_match_mode.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_group.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/aggregate_search_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Landing page: searches the chosen scope of book sources and lists the merged hits
/// (`docs/dev/roadmap.md` 3.8, ADR-0046).
///
/// The page is a thin shell around [AggregateSearch]: it owns the keyword field and the two
/// sheets (scope, filters) and renders whatever the notifier publishes. The three things worth
/// knowing:
///
/// * the **scope** decides which sources are searched (`BookSearchScope`), and it is persisted, so
///   "search this group" survives a restart (ADR-0046 §决策 1);
/// * a hit carries the sources that found it, so tapping one opens it **through the source it came
///   from** — not through whatever source happened to be selected (ADR-0046 §决策 4);
/// * while a run is in flight the page offers pause / resume / stop, and a stopped run keeps what it
///   already found (ADR-0046 §决策 6).
///
/// Accessibility (C-UI-7): the keyword field is labelled by its hint, every action is an
/// `IconButton`/`TextButton` with a tooltip or a label, and each hit is a `ListTile`.
class SearchBooksPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SearchBooksPage({super.key});

  @override
  ConsumerState<SearchBooksPage> createState() => _SearchBooksPageState();
}

/// State of the page: the keyword field.
class _SearchBooksPageState extends ConsumerState<SearchBooksPage> {
  final TextEditingController _keyword = TextEditingController();

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AppNavigation navigation = ref.watch(appNavigationProvider);
    final AsyncValue<List<StoredBookSource>> rows = ref.watch(
      bookSourceListProvider,
    );
    final BookSearchScope scope =
        ref.watch(searchScopeSelectionProvider).value ??
        BookSearchScope.defaults;
    final AggregateSearchState search = ref.watch(aggregateSearchProvider);
    final bool hasSources = rows.value?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceSearchTitle),
        backgroundColor: tokens.colors.surface,
        actions: <Widget>[
          // 设置属于**其他 feature**：经 AppNavigation 端口打开，而不是 import 对方的 route
          // （C-ARCH-2、ADR-0042）。书架不再放一个入口：它就是底部导航的第一个 tab。
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => navigation.openSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            tooltip: l10n.bookSourceListTitle,
            onPressed: () => pushBookSourceRoute(
              context,
              const BookSourceRoute.importedSources(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: l10n.bookSourceExploreAction,
            onPressed: hasSources
                ? () => pushBookSourceRoute(
                    context,
                    const BookSourceRoute.explore(),
                  )
                : null,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _keywordRow(l10n, hasSources),
            SizedBox(height: tokens.spacing.sm),
            _scopeRow(l10n, scope, rows.value ?? const <StoredBookSource>[]),
            // 运行中显示进度；跑完后如果有源失败、或范围被回退，仍要把这件事留在屏幕上
            // （否则用户只会看到结果变少，不知道为什么）。
            if (search.isRunning ||
                search.failedSources > 0 ||
                search.scopeFellBack) ...<Widget>[
              SizedBox(height: tokens.spacing.sm),
              _progressRow(l10n, search),
            ],
            SizedBox(height: tokens.spacing.md),
            Expanded(child: _results(context, l10n, hasSources, search)),
          ],
        ),
      ),
    );
  }

  /// The keyword field and the search button.
  Widget _keywordRow(AppLocalizations l10n, bool hasSources) {
    final M3ETheme tokens = context.m3e;

    return Row(
      children: <Widget>[
        Expanded(
          // 只重建输入框本身：每敲一个字都重建结果列表既浪费又会让滚动位置跳动。
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _keyword,
            builder:
                (BuildContext context, TextEditingValue value, Widget? _) =>
                    TextField(
                      controller: _keyword,
                      decoration: InputDecoration(
                        hintText: l10n.bookSourceSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: l10n.actionCancel,
                                onPressed: _keyword.clear,
                              ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        _submit();
                      },
                    ),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        IconButton.filled(
          onPressed: hasSources ? _submit : null,
          icon: const Icon(Icons.search),
          tooltip: l10n.bookSourceSearchAction,
        ),
      ],
    );
  }

  /// The scope chip plus the filter button.
  Widget _scopeRow(
    AppLocalizations l10n,
    BookSearchScope scope,
    List<StoredBookSource> rows,
  ) {
    final M3ETheme tokens = context.m3e;

    return Row(
      children: <Widget>[
        Expanded(
          child: ActionChip(
            avatar: const Icon(Icons.filter_alt_outlined),
            label: Text(
              _scopeLabel(l10n, scope, rows),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => _openScopeSheet(l10n, scope, rows),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        IconButton.outlined(
          icon: const Icon(Icons.tune),
          tooltip: l10n.searchFilterLabel,
          onPressed: () => _openFilterSheet(l10n),
        ),
      ],
    );
  }

  /// The progress line with pause / resume / stop.
  Widget _progressRow(AppLocalizations l10n, AggregateSearchState search) {
    final M3ETheme tokens = context.m3e;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (search.isRunning)
          LinearProgressIndicator(
            value: search.totalSources == 0
                ? null
                : search.processedSources / search.totalSources,
            semanticsLabel: l10n.searchProgress(
              search.processedSources,
              search.totalSources,
            ),
          ),
        SizedBox(height: tokens.spacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                <String>[
                  l10n.searchProgress(
                    search.processedSources,
                    search.totalSources,
                  ),
                  if (search.failedSources > 0)
                    l10n.searchPartialFailed(search.failedSources),
                ].join(' · '),
                style: tokens.typography.base.bodySmall,
              ),
            ),
            if (search.isRunning)
              TextButton(
                onPressed: search.isPaused
                    ? ref.read(aggregateSearchProvider.notifier).resume
                    : ref.read(aggregateSearchProvider.notifier).pause,
                child: Text(
                  search.isPaused ? l10n.searchResume : l10n.searchPause,
                ),
              ),
            if (search.isRunning)
              TextButton(
                onPressed: ref.read(aggregateSearchProvider.notifier).cancel,
                child: Text(l10n.searchStop),
              ),
          ],
        ),
        // 范围已不存在的回退要说出来：否则「我选了一个分组，结果搜了全库」看起来就像
        // 筛选坏了（ADR-0058）。单独一行，窄屏上也不会把暂停/停止挤出屏幕。
        if (search.scopeFellBack)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.xs),
            child: Text(
              l10n.searchScopeFellBack,
              style: tokens.typography.base.bodySmall,
            ),
          ),
      ],
    );
  }

  /// The result area: idle prompt, failure, empty, or the merged list.
  Widget _results(
    BuildContext context,
    AppLocalizations l10n,
    bool hasSources,
    AggregateSearchState search,
  ) {
    if (!hasSources) {
      return _missingSource(context, l10n);
    }

    return switch (search.status) {
      AggregateSearchStatus.idle => StateMessage(
        message: l10n.bookSourceSearchPrompt,
        icon: Icons.search,
      ),
      AggregateSearchStatus.running when search.books.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      // 失败只在**没有结果**时占满结果区：一次「有源解析失败」不能把已经拿到的命中盖掉
      // （那正是用户看到的「成功的结果也被覆盖」）。有结果时失败计数由上方的进度行说出来。
      AggregateSearchStatus.failed when search.books.isEmpty => FailureMessage(
        kind: search.failureKind ?? ParseFailureKind.parseFailed,
      ),
      _ when search.books.isEmpty => StateMessage(
        message: l10n.bookSourceSearchEmpty,
      ),
      _ => _books(context, l10n, search),
    };
  }

  /// The merged hits, plus the "load more" action when another page exists.
  Widget _books(
    BuildContext context,
    AppLocalizations l10n,
    AggregateSearchState search,
  ) {
    final M3ETheme tokens = context.m3e;
    final List<StoredBookSource> rows =
        ref.watch(bookSourceListProvider).value ?? const <StoredBookSource>[];
    final BookSearchScope scope =
        ref.watch(searchScopeSelectionProvider).value ??
        BookSearchScope.defaults;

    return ListView.builder(
      itemCount: search.books.length + (search.hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index == search.books.length) {
          return Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: OutlinedButton(
              onPressed: () => unawaited(
                ref
                    .read(aggregateSearchProvider.notifier)
                    .loadMore(keyword: _keyword.text, rows: rows, scope: scope),
              ),
              child: Text(l10n.searchLoadMore),
            ),
          );
        }

        return _hit(context, l10n, search.books[index], rows);
      },
    );
  }

  /// One merged hit: title, author, and how many sources found it.
  Widget _hit(
    BuildContext context,
    AppLocalizations l10n,
    SearchBook book,
    List<StoredBookSource> rows,
  ) {
    final String? author = switch (book.author) {
      final String value when value.isNotEmpty => value,
      _ => null,
    };
    // 更新时间是展示用字符串（`book-source.md` §2）：规则给了就显示，没给就不显示。
    final String? updated = switch (book.updateTime) {
      final String value when value.isNotEmpty => value,
      _ => null,
    };

    return ListTile(
      // 封面来自命中它的**第一个**源（ADR-0046 §决策 4 的单条合并口径）。
      leading: CoverImage(url: book.coverUrl, width: 48, height: 64),
      title: Text(book.name),
      // 标题 + 两行副标题（作者/更新时间一行、来源数一行）：`isThreeLine` 与之对应，
      // 有更新时间的命中不会因为三行副标题被截断。
      subtitle: Text(
        <String>[
          if (author != null || updated != null)
            <String>[
              if (author != null) l10n.bookSourceAuthorLine(author),
              if (updated != null) l10n.bookSourceUpdateTimeLine(updated),
            ].join(' · '),
          l10n.searchOriginsLine(book.origins.length),
        ].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () => unawaited(_openHit(context, book, rows)),
    );
  }

  /// Opens [book] through the **first source that found it** (ADR-0046 §决策 4).
  ///
  /// The detail page reads the selected source, so the selection has to move first; a source that
  /// was deleted meanwhile is reported as a failure rather than opening the wrong one.
  ///
  /// 选择写入后才推页：`select` 要读一次书源表，先推页会让详情页用上一个源发一轮请求
  /// （然后才重建到正确的源），看起来就是先闪一下旧书 / 解析失败。
  Future<void> _openHit(
    BuildContext context,
    SearchBook book,
    List<StoredBookSource> rows,
  ) async {
    final String sourceUrl = book.origins.isEmpty ? '' : book.origins.first;
    StoredBookSource? stored;
    for (final StoredBookSource row in rows) {
      if (row.source.url == sourceUrl) {
        stored = row;
        break;
      }
    }
    if (stored == null) {
      // 命中项的来源已被删除：不是「重试搜索」，而是这条结果已经没有可打开的源。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).bookSourceCheckFailureSourceMissing,
          ),
        ),
      );

      return;
    }

    await ref.read(selectedBookSourceProvider.notifier).select(stored.id);
    if (!context.mounted) {
      return;
    }
    pushBookSourceRoute(
      context,
      BookSourceRoute.bookDetail(
        book: Book(
          name: book.name,
          author: book.author,
          kind: book.kind,
          coverUrl: book.coverUrl,
          intro: book.intro,
          lastChapter: book.lastChapter,
          updateTime: book.updateTime,
          url: book.url,
        ),
      ),
    );
  }

  /// Runs the search for the current field value.
  void _submit() {
    final String keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(aggregateSearchProvider.notifier)
          .search(
            keyword: keyword,
            rows:
                ref.read(bookSourceListProvider).value ??
                const <StoredBookSource>[],
            scope:
                ref.read(searchScopeSelectionProvider).value ??
                BookSearchScope.defaults,
          ),
    );
  }

  /// The label of the scope chip.
  String _scopeLabel(
    AppLocalizations l10n,
    BookSearchScope scope,
    List<StoredBookSource> rows,
  ) => switch (scope) {
    SearchScopeAll() => l10n.searchScopeAll,
    SearchScopeGroups(:final Set<String> groups) =>
      groups.isEmpty ? l10n.searchScopeAll : groups.join('、'),
    SearchScopeSources(:final List<ScopeSource> sources) =>
      sources.isEmpty
          ? l10n.searchScopeAll
          : sources.map((ScopeSource source) => source.name).join('、'),
  };

  /// Opens the scope sheet: everything, a group, or specific sources.
  ///
  /// One sheet instead of a nested picker: "all" and the groups are the radio part, the named
  /// sources are the check-box part, and ticking any source switches the scope to `sources`
  /// (ADR-0046 §决策 1).
  ///
  /// The body is a [Consumer] that **watches** the scope instead of rendering a snapshot
  /// (ADR-0058): with a snapshot, ticking a source changed the provider but not the sheet — the box
  /// stayed empty, and because the tile kept reporting `false` the tick could never be undone.
  void _openScopeSheet(
    AppLocalizations l10n,
    BookSearchScope scope,
    List<StoredBookSource> rows,
  ) {
    final List<String> groups = <String>{
      for (final StoredBookSource row in rows)
        ...splitGroups(row.groupName ?? row.source.group),
    }.toList()..sort();

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) => SafeArea(
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final BookSearchScope current =
                  ref.watch(searchScopeSelectionProvider).value ??
                  BookSearchScope.defaults;
              final Set<String> named = <String>{
                for (final ScopeSource source in current.sourcesOrEmpty)
                  source.url,
              };

              return ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ListTile(title: Text(l10n.searchScopeLabel)),
                  RadioGroup<String>(
                    groupValue: _scopeKeyOf(current),
                    onChanged: (String? key) => unawaited(
                      _selectScope(
                        key == null || key.isEmpty
                            ? BookSearchScope.defaults
                            : BookSearchScope.groups(<String>{
                                key.substring(_groupKeyPrefix.length),
                              }),
                        sheetContext,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<String>(
                          value: '',
                          title: Text(l10n.searchScopeAll),
                        ),
                        for (final String group in groups)
                          RadioListTile<String>(
                            value: '$_groupKeyPrefix$group',
                            title: Text(group),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(l10n.searchScopeNamed),
                    subtitle: Text(
                      named.isEmpty
                          ? l10n.searchScopeAll
                          : rows
                                .where(
                                  (StoredBookSource row) =>
                                      named.contains(row.source.url),
                                )
                                .map((StoredBookSource row) => row.source.name)
                                .join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final StoredBookSource row in rows)
                    CheckboxListTile(
                      value: named.contains(row.source.url),
                      title: Text(row.source.name),
                      onChanged: (bool? checked) => unawaited(
                        _toggleNamed(current, rows, row, checked ?? false),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The radio value of [scope]: `''` for everything / several groups / named sources, or
  /// `group:<token>` for exactly one group.
  String _scopeKeyOf(BookSearchScope scope) => switch (scope) {
    SearchScopeAll() => '',
    SearchScopeGroups(:final Set<String> groups) when groups.length == 1 =>
      '$_groupKeyPrefix${groups.first}',
    SearchScopeGroups() || SearchScopeSources() => '',
  };

  /// Applies [scope] and closes the sheet.
  ///
  /// The write is awaited **before** popping: 范围是持久化的偏好，弹回后用户可能立刻点搜索，
  /// 写入还没落地就会拿到旧范围（ADR-0058）。
  Future<void> _selectScope(
    BookSearchScope scope,
    BuildContext sheetContext,
  ) async {
    await ref.read(searchScopeSelectionProvider.notifier).select(scope);
    if (!sheetContext.mounted) {
      return;
    }
    Navigator.of(sheetContext).pop();
  }

  /// Adds or removes one named source, switching the scope to `sources` as soon as one is ticked.
  ///
  /// The sheet stays open so a user can tick several sources; the boxes redraw themselves because
  /// the sheet watches the scope ([Consumer] above).
  Future<void> _toggleNamed(
    BookSearchScope current,
    List<StoredBookSource> rows,
    StoredBookSource row,
    bool checked,
  ) async {
    final Set<String> next = <String>{
      for (final ScopeSource named in current.sourcesOrEmpty) named.url,
    };
    if (checked) {
      next.add(row.source.url);
    } else {
      next.remove(row.source.url);
    }
    await ref
        .read(searchScopeSelectionProvider.notifier)
        .select(
          next.isEmpty
              ? BookSearchScope.defaults
              : BookSearchScope.sources(<ScopeSource>[
                  for (final StoredBookSource candidate in rows)
                    if (next.contains(candidate.source.url))
                      ScopeSource(
                        name: candidate.source.name,
                        url: candidate.source.url,
                      ),
                ]),
        );
  }

  /// Opens the filters sheet: source types and match mode.
  void _openFilterSheet(AppLocalizations l10n) {
    final AggregateSearchState search = ref.read(aggregateSearchProvider);

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => SafeArea(
          child: StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(void Function()) setSheetState,
                ) {
                  final AggregateSearch notifier = ref.read(
                    aggregateSearchProvider.notifier,
                  );

                  return ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      ListTile(title: Text(l10n.searchTypeLabel)),
                      for (final BookSourceType type in BookSourceType.values)
                        CheckboxListTile(
                          value: search.types.contains(type),
                          title: Text(_typeLabel(l10n, type)),
                          onChanged: (bool? checked) {
                            final Set<BookSourceType> next = <BookSourceType>{
                              ...search.types,
                            };
                            if (checked ?? false) {
                              next.add(type);
                            } else {
                              next.remove(type);
                            }
                            // 一个类型都不选等于搜不到任何源：保持至少一个。
                            if (next.isEmpty) {
                              return;
                            }
                            notifier.setTypes(next);
                            setSheetState(() {});
                          },
                        ),
                      const Divider(),
                      ListTile(title: Text(l10n.searchMatchLabel)),
                      RadioGroup<SearchMatchMode>(
                        groupValue: search.matchMode,
                        onChanged: (SearchMatchMode? selected) {
                          if (selected == null) {
                            return;
                          }
                          notifier.setMatchMode(selected);
                          setSheetState(() {});
                        },
                        child: Column(
                          children: <Widget>[
                            for (final SearchMatchMode mode
                                in SearchMatchMode.values)
                              RadioListTile<SearchMatchMode>(
                                value: mode,
                                title: Text(_matchLabel(l10n, mode)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
          ),
        ),
      ),
    );
  }

  /// The ARB label of [type].
  String _typeLabel(AppLocalizations l10n, BookSourceType type) =>
      switch (type) {
        BookSourceType.text => l10n.searchTypeText,
        BookSourceType.audio => l10n.searchTypeAudio,
        BookSourceType.image => l10n.searchTypeImage,
        BookSourceType.file => l10n.searchTypeFile,
        BookSourceType.video => l10n.searchTypeVideo,
      };

  /// The ARB label of [mode].
  String _matchLabel(AppLocalizations l10n, SearchMatchMode mode) =>
      switch (mode) {
        SearchMatchMode.defaultMode => l10n.searchMatchDefault,
        SearchMatchMode.exact => l10n.searchMatchExact,
      };

  /// The empty state of “no usable source”, with the way to fix it.
  Widget _missingSource(BuildContext context, AppLocalizations l10n) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.bookSourceMissingSource,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: () => pushBookSourceRoute(
                context,
                const BookSourceRoute.importedSources(),
              ),
              child: Text(l10n.bookSourceMissingSourceAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// The radio-value prefix of a single-group scope in the scope sheet.
const String _groupKeyPrefix = 'group:';
