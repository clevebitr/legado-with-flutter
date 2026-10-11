import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/search_results_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/failure_message.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/state_message.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Landing page: searches the selected book source and lists the hits.
///
/// Accessibility (C-UI-7): the keyword field is labelled by its hint, the submit
/// button by its tooltip, and every hit is a [ListTile], which derives its semantics
/// label from the text it shows.
class SearchBooksPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SearchBooksPage({super.key});

  @override
  ConsumerState<SearchBooksPage> createState() => _SearchBooksPageState();
}

class _SearchBooksPageState extends ConsumerState<SearchBooksPage> {
  final TextEditingController _keyword = TextEditingController();

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  /// Runs the search for the current field value.
  ///
  /// A blank keyword is ignored instead of encoded into a meaningless request; the
  /// state a previous search left behind stays visible.
  void _search(BookSource source) {
    final String keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      return;
    }

    unawaited(ref.read(searchResultsProvider.notifier).search(source, keyword));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSource? source = ref.watch(currentBookSourceProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceSearchTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _keyword,
                    decoration: InputDecoration(
                      hintText: l10n.bookSourceSearchHint,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(source),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                IconButton.filled(
                  // 没有书源时按钮不可用：调用用例没有可解析的规则集。
                  onPressed: source == null ? null : () => _submit(source),
                  icon: const Icon(Icons.search),
                  tooltip: l10n.bookSourceSearchAction,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.lg),
            Expanded(child: _results(source, l10n)),
          ],
        ),
      ),
    );
  }

  /// Runs the search for a promoted [source], e.g. from `onSubmitted`.
  void _submit(BookSource? source) {
    if (source == null) {
      return;
    }

    _search(source);
  }

  /// Builds the result area: the seam's empty state, or the search state machine.
  Widget _results(BookSource? source, AppLocalizations l10n) {
    if (source == null) {
      // 导入书源属于 Phase 5；在此之前界面走空态，而不是拿空规则集去请求。
      return StateMessage(message: l10n.bookSourceMissingSource);
    }

    final SearchResultsState state = ref.watch(searchResultsProvider);

    return switch (state) {
      SearchResultsIdle() => StateMessage(message: l10n.bookSourceSearchPrompt),
      SearchResultsSearching() => const Center(
        child: CircularProgressIndicator(),
      ),
      SearchResultsLoaded(:final List<Book> books) =>
        books.isEmpty
            ? StateMessage(message: l10n.bookSourceSearchEmpty)
            : _books(books),
      // 搜索失败后重按搜索按钮即是重试，因此这里不给重试动作。
      SearchResultsFailed(:final ParseFailureKind kind) => FailureMessage(
        kind: kind,
      ),
    };
  }

  /// Builds the lazily built hit list and its navigation (C-PERF-2).
  Widget _books(List<Book> books) => ListView.builder(
    itemCount: books.length,
    itemBuilder: (BuildContext context, int index) {
      final Book book = books[index];
      // 作者缺失时不显示副标题；不做字符串拼接，用户可见文本只来自 ARB/书源。
      final String? author = switch (book.author) {
        final String value when value.isNotEmpty => value,
        _ => null,
      };

      return ListTile(
        title: Text(book.name),
        subtitle: author == null ? null : Text(author),
        onTap: () => pushBookSourceRoute(
          context,
          BookSourceRoute.bookDetail(book: book),
        ),
      );
    },
  );
}
