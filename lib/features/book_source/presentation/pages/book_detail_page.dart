import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/bookshelf_writer.dart';
import 'package:flutter_reader/features/book_source/presentation/book_source_route.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_queries.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/shelf_add_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Detail page of one search hit: the book information above its chapter list.
///
/// The two stages fail independently: a chapter list that cannot be read still
/// shows the information that was read, and each section has its own retry
/// (`docs/dev/book-source.md` §9).
class BookDetailPage extends ConsumerWidget {
  /// Creates the page.
  const BookDetailPage({required this.book, super.key});

  /// The hit this page was opened for.
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSource? source = ref.watch(currentBookSourceProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceDetailTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: source == null
          ? StateMessage(message: l10n.bookSourceMissingSource)
          : _detail(context, ref, source, tokens, l10n),
    );
  }

  /// Builds the body for the selected [source].
  Widget _detail(
    BuildContext context,
    WidgetRef ref,
    BookSource source,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) {
    final AsyncValue<ParseResult<BookInfo>> info = ref.watch(
      bookInfoProvider(source, book),
    );

    return switch (info) {
      AsyncData<ParseResult<BookInfo>>(:final ParseResult<BookInfo> value) =>
        switch (value) {
          ParseSuccess<BookInfo>(:final BookInfo data) => _sections(
            context,
            ref,
            source,
            data,
            tokens,
            l10n,
          ),
          ParseFailure<BookInfo>(:final ParseFailureKind kind) =>
            FailureMessage(
              kind: kind,
              onRetry: () => ref.invalidate(bookInfoProvider(source, book)),
            ),
        },
      // 用例按 C-ERR-1 不抛异常：这里只兜住意外错误，避免用户看到白屏。
      AsyncError<ParseResult<BookInfo>>() => FailureMessage(
        kind: ParseFailureKind.parseFailed,
        onRetry: () => ref.invalidate(bookInfoProvider(source, book)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// Builds the information block followed by the lazily built chapter list.
  Widget _sections(
    BuildContext context,
    WidgetRef ref,
    BookSource source,
    BookInfo info,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) {
    // 目录地址由详情阶段解析（`tocUrl` 规则缺失时回落到书籍页），因此这里才请求。
    final AsyncValue<ParseResult<List<Chapter>>> toc = ref.watch(
      tocProvider(source, info.tocUrl),
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _infoBlock(context, ref, source, info, tokens, l10n),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.sm,
              tokens.spacing.lg,
              tokens.spacing.xs,
            ),
            child: Text(
              l10n.bookSourceTocTitle,
              style: tokens.typography.base.titleMedium,
            ),
          ),
        ),
        switch (toc) {
          AsyncData<ParseResult<List<Chapter>>>(
            :final ParseResult<List<Chapter>> value,
          ) =>
            switch (value) {
              ParseSuccess<List<Chapter>>(:final List<Chapter> data) =>
                SliverList.builder(
                  itemCount: data.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Chapter chapter = data[index];

                    return ListTile(
                      title: Text(chapter.name),
                      onTap: () => pushBookSourceRoute(
                        context,
                        BookSourceRoute.reader(chapter: chapter),
                      ),
                    );
                  },
                ),
              ParseFailure<List<Chapter>>(:final ParseFailureKind kind) =>
                SliverToBoxAdapter(
                  child: _tocFailure(ref, source, info.tocUrl, kind),
                ),
            },
          AsyncError<ParseResult<List<Chapter>>>() => SliverToBoxAdapter(
            child: _tocFailure(
              ref,
              source,
              info.tocUrl,
              ParseFailureKind.parseFailed,
            ),
          ),
          _ => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.xl),
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        },
      ],
    );
  }

  /// Builds the retryable failure of the chapter list.
  Widget _tocFailure(
    WidgetRef ref,
    BookSource source,
    String url,
    ParseFailureKind kind,
  ) => FailureMessage(
    kind: kind,
    onRetry: () => ref.invalidate(tocProvider(source, url)),
  );

  /// Builds the information block; an absent field is simply not shown.
  Widget _infoBlock(
    BuildContext context,
    WidgetRef ref,
    BookSource source,
    BookInfo info,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => Padding(
    padding: EdgeInsets.all(tokens.spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(info.name, style: tokens.typography.base.headlineSmall),
        SizedBox(height: tokens.spacing.sm),
        if (info.author case final String author)
          Text(
            l10n.bookSourceAuthorLine(author),
            style: tokens.typography.base.bodyMedium,
          ),
        if (info.kind case final String kind)
          Text(
            l10n.bookSourceKindLine(kind),
            style: tokens.typography.base.bodyMedium,
          ),
        if (info.lastChapter case final String chapter)
          Text(
            l10n.bookSourceLastChapterLine(chapter),
            style: tokens.typography.base.bodyMedium,
          ),
        SizedBox(height: tokens.spacing.md),
        _shelfButton(context, ref, source, info, l10n),
      ],
    ),
  );

  /// Builds the 「加入书架」 action (`docs/dev/roadmap.md` 5.4)。
  ///
  /// It talks to a **port** (`BookshelfWriter`), not to the shelf feature: the composition root
  /// binds the real writer, so this page cannot import `features/bookshelf` (C-ARCH-2、ADR-0041).
  /// The button is disabled while a write is in flight, which is what the notifier's loading
  /// state is for.
  Widget _shelfButton(
    BuildContext context,
    WidgetRef ref,
    BookSource source,
    BookInfo info,
    AppLocalizations l10n,
  ) {
    final AsyncValue<void> action = ref.watch(shelfAddProvider);

    return FilledButton.icon(
      onPressed: action.isLoading
          ? null
          : () => unawaited(_addToShelf(context, ref, source, info, l10n)),
      icon: const Icon(Icons.bookmark_add_outlined),
      label: Text(l10n.shelfAddAction),
    );
  }

  /// Sends the detail page's snapshot to the shelf and reports the outcome.
  Future<void> _addToShelf(
    BuildContext context,
    WidgetRef ref,
    BookSource source,
    BookInfo info,
    AppLocalizations l10n,
  ) async {
    final ParseResult<void> result = await ref
        .read(shelfAddProvider.notifier)
        .add(
          ShelfBookDraft(
            sourceUrl: source.url,
            bookUrl: info.url,
            name: info.name,
            author: info.author,
            kind: info.kind,
            coverUrl: info.coverUrl,
            intro: info.intro,
            lastChapter: info.lastChapter,
          ),
        );
    if (!context.mounted) {
      return;
    }

    final String message = switch (result) {
      ParseSuccess<void>() => l10n.shelfAddSucceeded,
      ParseFailure<void>() => l10n.shelfAddFailed,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
