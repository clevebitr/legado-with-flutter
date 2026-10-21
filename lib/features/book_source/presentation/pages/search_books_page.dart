import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/app_navigation_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/router/app_navigation.dart';
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
          // 书架与设置都是**其他 feature** 的页面：经 AppNavigation 端口打开，而不是
          // import 对方的 route（C-ARCH-2、ADR-0042）。
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: l10n.shelfTitle,
            onPressed: () => navigation.openBookshelf(context),
          ),
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
            // 运行中显示进度；跑完后如果有源失败，仍要把「几个源失败」留在屏幕上
            // （否则用户只会看到结果变少，不知道为什么）。
            if (search.isRunning || search.failedSources > 0) ...<Widget>[
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
          child: TextField(
            controller: _keyword,
            decoration: InputDecoration(hintText: l10n.bookSourceSearchHint),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
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
            label: Text(_scopeLabel(l10n, scope, rows)),
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
      ),
      AggregateSearchStatus.running when search.books.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      AggregateSearchStatus.failed => FailureMessage(
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
      title: Text(book.name),
      subtitle: Text(
        <String>[
          if (author != null) l10n.bookSourceAuthorLine(author),
          if (updated != null) l10n.bookSourceUpdateTimeLine(updated),
          l10n.searchOriginsLine(book.origins.length),
        ].join('\n'),
      ),
      isThreeLine: author != null || updated != null,
      onTap: () => _openHit(context, book, rows),
    );
  }

  /// Opens [book] through the **first source that found it** (ADR-0046 §决策 4).
  ///
  /// The detail page reads the selected source, so the selection has to move first; a source that
  /// was deleted meanwhile is reported as a failure rather than opening the wrong one.
  void _openHit(
    BuildContext context,
    SearchBook book,
    List<StoredBookSource> rows,
  ) {
    final String sourceUrl = book.origins.isEmpty ? '' : book.origins.first;
    StoredBookSource? stored;
    for (final StoredBookSource row in rows) {
      if (row.source.url == sourceUrl) {
        stored = row;
        break;
      }
    }
    if (stored == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).actionRetry)),
      );

      return;
    }

    unawaited(ref.read(selectedBookSourceProvider.notifier).select(stored.id));
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
  void _openScopeSheet(
    AppLocalizations l10n,
    BookSearchScope scope,
    List<StoredBookSource> rows,
  ) {
    final List<String> groups = <String>{
      for (final StoredBookSource row in rows)
        ...splitGroups(row.groupName ?? row.source.group),
    }.toList()..sort();
    final Set<String> named = <String>{
      for (final ScopeSource source in scope.sourcesOrEmpty) source.url,
    };
    final String currentKey = switch (scope) {
      SearchScopeAll() => '',
      SearchScopeGroups(:final Set<String> groups) when groups.length == 1 =>
        'group:${groups.first}',
      SearchScopeGroups() => '',
      SearchScopeSources() => '',
    };

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(title: Text(l10n.searchScopeLabel)),
              RadioGroup<String>(
                groupValue: currentKey,
                onChanged: (String? key) => _selectScope(
                  l10n,
                  key == null || key.isEmpty
                      ? BookSearchScope.defaults
                      : BookSearchScope.groups(<String>{
                          key.substring('group:'.length),
                        }),
                ),
                child: Column(
                  children: <Widget>[
                    RadioListTile<String>(
                      value: '',
                      title: Text(l10n.searchScopeAll),
                    ),
                    for (final String group in groups)
                      RadioListTile<String>(
                        value: 'group:$group',
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
                  onChanged: (bool? checked) =>
                      _toggleNamed(l10n, rows, named, row, checked ?? false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Applies [scope], closes the sheet and stores the choice.
  void _selectScope(AppLocalizations l10n, BookSearchScope scope) {
    unawaited(ref.read(searchScopeSelectionProvider.notifier).select(scope));
    Navigator.of(context).pop();
  }

  /// Adds or removes one named source, switching the scope to `sources` as soon as one is ticked.
  void _toggleNamed(
    AppLocalizations l10n,
    List<StoredBookSource> rows,
    Set<String> named,
    StoredBookSource row,
    bool checked,
  ) {
    final Set<String> next = <String>{...named};
    if (checked) {
      next.add(row.source.url);
    } else {
      next.remove(row.source.url);
    }
    if (next.isEmpty) {
      _selectScope(l10n, BookSearchScope.defaults);

      return;
    }
    ref
        .read(searchScopeSelectionProvider.notifier)
        .select(
          BookSearchScope.sources(<ScopeSource>[
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
