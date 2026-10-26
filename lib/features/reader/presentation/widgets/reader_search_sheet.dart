import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/book_search_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Searches the whole book for a word and jumps to a hit
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The run starts at the chapter the reader is on and walks forward, so the first results are the
/// ones nearest the reader. Closing the sheet disposes the notifier, which cancels the run — a closed
/// page must not keep asking the source for chapters.
class ReaderSearchSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReaderSearchSheet({
    required this.book,
    required this.chapters,
    required this.fromIndex,
    required this.onSelected,
    super.key,
  });

  /// The book being read; the search runs over its chapters.
  final ReaderBook book;

  /// Every chapter, in the source's order.
  final List<ReadingChapter> chapters;

  /// The chapter the reader is on; the run starts there.
  final int fromIndex;

  /// Called with the hit the user picked.
  final ValueChanged<BookSearchHit> onSelected;

  @override
  ConsumerState<ReaderSearchSheet> createState() => _ReaderSearchSheetState();
}

class _ReaderSearchSheetState extends ConsumerState<ReaderSearchSheet> {
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
    final BookSearchProgress? progress = ref.watch(
      bookSearchProvider(widget.book),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _keyword,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _start,
              decoration: InputDecoration(
                hintText: l10n.readerSearchHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.readerSearchStart,
                  onPressed: () => _start(_keyword.text),
                ),
              ),
            ),
            if (progress != null) ...<Widget>[
              SizedBox(height: tokens.spacing.sm),
              _status(context, ref, progress, l10n, tokens),
            ],
            SizedBox(height: tokens.spacing.sm),
            Expanded(child: _results(context, progress, l10n, tokens)),
          ],
        ),
      ),
    );
  }

  /// One line of「搜到哪了」plus the stop button while the run is going.
  Widget _status(
    BuildContext context,
    WidgetRef ref,
    BookSearchProgress progress,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) {
    final String line = switch (progress.stop) {
      BookSearchStop.running => l10n.readerSearchProgress(
        progress.scannedChapters,
        progress.totalChapters,
      ),
      BookSearchStop.finished => l10n.readerSearchProgress(
        progress.scannedChapters,
        progress.totalChapters,
      ),
      BookSearchStop.cancelled => l10n.readerSearchStopped(
        progress.scannedChapters,
        progress.totalChapters,
      ),
      BookSearchStop.budgetSpent => l10n.readerSearchBudgetSpent(
        progress.scannedChapters,
        progress.totalChapters,
      ),
    };

    return Row(
      children: <Widget>[
        Expanded(child: Text(line, style: tokens.typography.base.labelMedium)),
        if (progress.isRunning)
          TextButton(
            onPressed: () =>
                ref.read(bookSearchProvider(widget.book).notifier).cancel(),
            child: Text(l10n.readerSearchStop),
          ),
      ],
    );
  }

  /// The hits, the empty answer, or the prompt before a run.
  Widget _results(
    BuildContext context,
    BookSearchProgress? progress,
    AppLocalizations l10n,
    M3ETheme tokens,
  ) {
    if (progress == null) {
      return StateMessage(message: l10n.readerSearchHint);
    }
    if (progress.hits.isEmpty) {
      return StateMessage(
        message: progress.isRunning
            ? l10n.readerSearchProgress(
                progress.scannedChapters,
                progress.totalChapters,
              )
            : l10n.readerSearchEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (progress.failedChapters > 0)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.xs),
            child: Text(
              l10n.readerSearchFailedChapters(progress.failedChapters),
              style: tokens.typography.base.labelSmall,
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: progress.hits.length,
            itemBuilder: (BuildContext context, int index) {
              final BookSearchHit hit = progress.hits[index];

              return ListTile(
                title: Text(
                  hit.chapterTitle.isEmpty
                      ? l10n.readerSearchUntitledChapter
                      : hit.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  hit.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => widget.onSelected(hit),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Starts a run and drops the keyboard so the results have the screen.
  void _start(String keyword) {
    FocusScope.of(context).unfocus();
    unawaited(
      ref
          .read(bookSearchProvider(widget.book).notifier)
          .start(
            chapters: widget.chapters,
            fromIndex: widget.fromIndex,
            keyword: keyword,
          ),
    );
  }
}
