import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/bookmark_list_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/reader_route.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Every bookmark across books, reached from 「我的」 (`docs/dev/roadmap.md` M19).
///
/// Tapping a row opens the reader **at that position**: the bookmark carries its own `tocUrl`, so
/// the chapter list is rebuilt exactly as it was when the mark was made (ADR-0066 §决策 3), and the
/// offset is what makes 「跳到书签」 land on the sentence instead of the chapter's first line.
class BookmarkListPage extends ConsumerWidget {
  /// Creates the page.
  const BookmarkListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<Bookmark>> bookmarks = ref.watch(
      bookmarkListProvider,
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookmarkTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (bookmarks) {
        AsyncData<List<Bookmark>>(:final List<Bookmark> value) =>
          value.isEmpty
              ? StateMessage(message: l10n.bookmarkEmpty)
              : _list(context, ref, value, tokens, l10n),
        // 读取失败与「没有书签」是两件事：空态会误导用户以为标记被删了。
        AsyncError<List<Bookmark>>() => StateMessage(
          message: l10n.bookmarkLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds the lazily built bookmark list (C-PERF-2).
  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<Bookmark> bookmarks,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ListView.builder(
    padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
    itemCount: bookmarks.length,
    itemBuilder: (BuildContext context, int index) {
      final Bookmark bookmark = bookmarks[index];
      final String? excerpt = bookmark.excerpt;
      final String chapter = bookmark.chapterName ?? '';

      return ListTile(
        leading: const Icon(Icons.bookmark),
        title: Text(bookmark.bookName),
        subtitle: Text(
          <String>[
            if (chapter.isNotEmpty) chapter,
            if (excerpt != null && excerpt.isNotEmpty) excerpt,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.bookmarkDeleteAction,
          onPressed: () => unawaited(
            ref.read(bookmarkListProvider.notifier).remove(bookmark.id),
          ),
        ),
        onTap: () => _open(context, bookmark),
      );
    },
  );

  /// Opens the reader on the bookmarked position.
  ///
  /// `tocUrl ?? bookUrl` is the same fallback the shelf uses for rows stored before the TOC address
  /// existed (ADR-0044 §决策 3); dismissing the current page first keeps the back button returning
  /// to the list rather than to a reader the user already left.
  void _open(BuildContext context, Bookmark bookmark) {
    pushReaderRoute(
      context,
      ReaderRoute.read(
        book: ReaderBook(
          sourceUrl: bookmark.sourceUrl,
          bookUrl: bookmark.bookUrl,
          name: bookmark.bookName,
          tocUrl: bookmark.tocUrl ?? bookmark.bookUrl,
        ),
        chapterUrl: bookmark.chapterUrl,
        charOffset: bookmark.charOffset,
      ),
    );
  }
}
