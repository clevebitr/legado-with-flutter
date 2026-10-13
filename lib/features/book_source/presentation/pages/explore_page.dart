import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/explore_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/failure_message.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/state_message.dart';
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
  @override
  void initState() {
    super.initState();
    // 分类只拉一次（`currentBookSourceProvider` 是「选中哪个书源」的唯一接缝）。
    final BookSource? source = ref.read(currentBookSourceProvider);
    if (source != null) {
      unawaited(
        Future<void>.microtask(
          () => ref.read(exploreProvider.notifier).loadCategories(source),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookSource? source = ref.watch(currentBookSourceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookSourceExploreTitle)),
      body: source == null
          ? StateMessage(message: l10n.bookSourceMissingSource)
          : _body(l10n, source),
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
