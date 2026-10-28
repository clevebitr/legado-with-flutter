/// The pieces the two continuous reading flows share (`docs/dev/adr/0085-continuous-chapter-reading.md`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// One chapter as a continuous flow renders it, with the body when it is in hand.
///
/// A `null` body means **it is not here yet**: the flow then prints the chapter's title and a
/// loading block in its place (ADR-0086 §决策 7), which is what keeps a chapter boundary readable
/// while the next chapter is still being fetched.
///
/// The body is the one **after** the presentation transform of `readerBodyText` — the flows render
/// what they are given and never look at the source's own text.
typedef ReaderFlowChapter = ({
  int index,
  String url,
  String title,
  String? text,
});

/// Where an explicit jump lands: a chapter, a character offset inside it, and a nonce.
///
/// The nonce is what makes a second jump to the same position work: the flows only honour a restore
/// they have not seen yet, so the reader's own progress updates (which move the character offset
/// continuously) can never be mistaken for a jump it must apply.
typedef ReaderFlowRestore = ({int index, int charOffset, int nonce});

/// The sentence being read aloud, as a range inside the chapter at its URL (ADR-0062 §决策 5).
typedef ReaderFlowHighlight = ({String url, int start, int end});

/// The chapters a continuous flow renders: the anchor and its immediate neighbours.
///
/// The flow is a **pure function of the session chapter**: slots are `anchor - 1`, `anchor` and
/// `anchor + 1`, each with the body the page has in hand (or `null` while it is missing). Nothing is
/// retained between builds.
///
/// That is deliberate. An earlier version kept a "rendered window" of its own and derived the
/// visible chapters from a URL-keyed body map; two chapters sharing a URL (a real shape in scraped
/// tables of contents) then collapsed onto one body and the same text was printed twice, and a
/// window that had to be reconciled by hand grew a stack of gates (geometry, retention, prepend)
/// that could disagree with each other. Two rules replace all of it:
///
/// * **bodies are keyed by chapter index**, never by URL, so every TOC row is its own chapter;
/// * **the slots are derived, not accumulated**, so a chapter can never appear twice.
class ReaderChapterSlots {
  /// Builds the slots for [anchorIndex] from [chapters] and the bodies in hand.
  ///
  /// The chapter before the anchor is only included when [includePrevious] — a short chapter would
  /// otherwise have the previous chapter's text sitting where its own body should start, because
  /// there is no scroll range left to compensate that shift.
  static List<ReaderFlowChapter> of({
    required List<ReadingChapter> chapters,
    required int anchorIndex,
    required Map<int, String> bodies,
    required bool includePrevious,
  }) {
    if (chapters.isEmpty || anchorIndex < 0 || anchorIndex >= chapters.length) {
      return const <ReaderFlowChapter>[];
    }
    final List<ReaderFlowChapter> slots = <ReaderFlowChapter>[
      if (includePrevious && anchorIndex > 0) _slot(chapters, bodies, anchorIndex - 1),
      _slot(chapters, bodies, anchorIndex),
      if (anchorIndex + 1 < chapters.length) _slot(chapters, bodies, anchorIndex + 1),
    ];

    return slots;
  }

  /// One slot: the TOC row plus its body when [bodies] has it.
  static ReaderFlowChapter _slot(
    List<ReadingChapter> chapters,
    Map<int, String> bodies,
    int index,
  ) {
    final ReadingChapter chapter = chapters[index];

    return (
      index: index,
      url: chapter.url,
      title: chapter.title,
      text: bodies[index],
    );
  }
}

/// The block that stands in for a chapter body that is not in hand yet.
///
/// It sits **under the chapter's own title**, so a reader who scrolls into a boundary sees which
/// chapter is coming and that it is on its way — the upstream reading view shows the same thing
/// (the chapter heading with pages still loading). A failed read keeps the block but offers a retry
/// instead of a spinner: a chapter that could not be read must not look like one that is still
/// loading.
class ReaderChapterPendingStrip extends StatelessWidget {
  /// Creates the block; [onRetry] is only called for the failed state.
  const ReaderChapterPendingStrip({
    required this.isFailed,
    required this.onRetry,
    super.key,
  });

  /// Whether the read failed (offers [onRetry]) rather than still being in flight.
  final bool isFailed;

  /// Called when the reader asks for the chapter to be read again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    // 一行式：调用方给的盒子高度是量过的高度，这里不再加纵向内边距（否则会溢出）。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isFailed)
          TextButton.icon(
            onPressed: onRetry,
            // 盒子高度是量好的：按紧凑尺寸画，别让按钮的最小高度把它撑破。
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.readerChapterRetry),
          )
        else ...<Widget>[
          // 指示器尺寸沿用 `reader_source_sheet` 的 16dp / 2dp 口径（同一个「小号加载」语汇）。
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: tokens.spacing.sm),
          Text(
            l10n.readerChapterLoading,
            style: tokens.typography.base.labelSmall,
          ),
        ],
      ],
    );
  }
}
