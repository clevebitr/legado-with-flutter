import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/explore_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The discover page: one row of category chips, then the books of the chosen category.
///
/// Accessibility (C-UI-7): a chip is named by its label, an empty or failed category is explained
/// by text, and every hit is a [ListTile], which derives its semantics from the text it shows.
class ExplorePage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  /// The id of the stored source whose discover categories were already requested.
  ///
  /// 用 id 而不是一个「只做一次」的布尔标记：发现页在 shell 的 `IndexedStack` 里常驻，
  /// 用户到书源管理里换一个源再切回来时页面**不会重建** —— 只有看 id 变了才会重拉分类，
  /// 否则 chip 行会一直是上一个源的分类（ADR-0058）。
  int? _loadedSourceId;

  @override
  void initState() {
    super.initState();
    // 选中的源是异步投影（先列表、再取行），第一次 build 时它可能还在 loading：
    // 所以在 provider 上挂监听，等它真的给出源再拉分类，而不是在 initState 里赌一次 read。
    // 发现被关掉的源一个请求都不发（ADR-0052 §决策 3）。
    ref.listenManual<AsyncValue<StoredBookSource?>>(
      selectedBookSourceProvider,
      (
        AsyncValue<StoredBookSource?>? previous,
        AsyncValue<StoredBookSource?> next,
      ) => _loadCategoriesIfNeeded(next.value),
      fireImmediately: true,
    );
  }

  /// Loads the categories once the selected source is known and its discover page is on.
  ///
  /// 换源（或从「发现已关闭」的源切回来）会重拉一次：分类是**源的属性**，不是页面的属性。
  ///
  /// The work is deferred to the next frame: `exploreProvider` is auto-dispose, and reading its
  /// notifier before the first `build` has watched it would create an element nobody keeps alive
  /// (the first attempt at this did exactly that, and the notifier then ran on a disposed `Ref`).
  void _loadCategoriesIfNeeded(StoredBookSource? stored) {
    if (stored == null || !stored.isExploreEnabled) {
      // 当前没有可展示的源：下一次真的选中源时必须重拉，所以清掉标记。
      _loadedSourceId = null;

      return;
    }
    if (_loadedSourceId == stored.id) {
      return;
    }
    _loadedSourceId = stored.id;
    final BookSource source = stored.source;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(exploreProvider.notifier).loadCategories(source));
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StoredBookSource? stored = ref
        .watch(selectedBookSourceProvider)
        .value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookSourceExploreTitle)),
      body: switch (stored) {
        null => StateMessage(message: l10n.bookSourceMissingSource),
        StoredBookSource(isExploreEnabled: false) => StateMessage(
          message: l10n.bookSourceExploreDisabled,
        ),
        StoredBookSource(:final BookSource source) => _body(l10n, source),
      },
    );
  }

  /// Renders the state the notifier published.
  Widget _body(AppLocalizations l10n, BookSource source) {
    final ExploreState state = ref.watch(exploreProvider);

    return switch (state) {
      ExploreIdle() => const Center(child: CircularProgressIndicator()),
      ExploreCategoriesFailed(:final ParseFailureKind kind) => FailureMessage(
        kind: kind,
        onRetry: () => unawaited(
          ref.read(exploreProvider.notifier).loadCategories(source),
        ),
      ),
      ExploreCategories(:final List<ExploreCategory> categories)
          when categories.isEmpty =>
        StateMessage(message: l10n.bookSourceExploreEmpty),
      _ => _withCategories(l10n, source, state),
    };
  }

  /// The chip row plus what is below it: books, a failure, or a hint to pick one.
  Widget _withCategories(
    AppLocalizations l10n,
    BookSource source,
    ExploreState state,
  ) {
    final List<ExploreCategory> categories = switch (state) {
      ExploreCategories(:final List<ExploreCategory> categories) => categories,
      ExploreLoadingBooks(:final List<ExploreCategory> categories) =>
        categories,
      ExploreBooksLoaded(:final List<ExploreCategory> categories) => categories,
      ExploreBooksFailed(:final List<ExploreCategory> categories) => categories,
      ExploreIdle() || ExploreCategoriesFailed() => const <ExploreCategory>[],
    };
    final ExploreCategory? selected = switch (state) {
      ExploreCategories() => null,
      ExploreLoadingBooks(:final ExploreCategory category) => category,
      ExploreBooksLoaded(:final ExploreCategory category) => category,
      ExploreBooksFailed(:final ExploreCategory category) => category,
      ExploreIdle() || ExploreCategoriesFailed() => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: context.m3e.spacing.md,
            vertical: context.m3e.spacing.sm,
          ),
          child: Row(
            spacing: context.m3e.spacing.sm,
            children: <Widget>[
              for (final ExploreCategory category in categories)
                ChoiceChip(
                  label: Text(category.title),
                  selected: category == selected,
                  // 已选中的分类再点一次只是重新加载它，不会取消选择（没有「无分类」这个视图）。
                  onSelected: (_) => unawaited(
                    ref
                        .read(exploreProvider.notifier)
                        .openCategory(source, category),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _below(l10n, source, state, selected)),
      ],
    );
  }

  /// What is below the chip row.
  Widget _below(
    AppLocalizations l10n,
    BookSource source,
    ExploreState state,
    ExploreCategory? selected,
  ) => switch (state) {
    ExploreCategories() => StateMessage(message: l10n.bookSourceExplorePrompt),
    ExploreLoadingBooks() => const Center(child: CircularProgressIndicator()),
    ExploreBooksFailed(:final ParseFailureKind kind) => FailureMessage(
      kind: kind,
      onRetry: selected == null
          ? null
          : () => unawaited(
              ref.read(exploreProvider.notifier).openCategory(source, selected),
            ),
    ),
    // 分类页没有可用的书目（列表命中但每一条都没有可用地址，§9）：这里没有关键词，
    // 所以不能借用搜索的空态文案（它会说「没有匹配该关键词的书」）。
    ExploreBooksLoaded(:final List<Book> books) when books.isEmpty =>
      StateMessage(message: l10n.bookSourceExploreEmptyCategory),
    ExploreBooksLoaded(:final List<Book> books) => ListView.builder(
      itemCount: books.length,
      itemBuilder: (BuildContext context, int index) {
        final Book book = books[index];

        return ListTile(
          // 封面是 S1（roadmap §3.9）：书源给了 `coverUrl` 就显示，没给就是占位块。
          leading: CoverImage(url: book.coverUrl, width: 48, height: 64),
          title: Text(book.name),
          subtitle: book.author == null ? null : Text(book.author ?? ''),
          onTap: () => pushBookSourceRoute(
            context,
            BookSourceRoute.bookDetail(book: book),
          ),
        );
      },
    ),
    // `ExploreCategories` 已在前面处理（提示选一个分类），这里只剩两个不可达的变体——
    // 列出来只为让这个 switch 穷尽。
    ExploreIdle() || ExploreCategoriesFailed() => const SizedBox.shrink(),
  };
}
