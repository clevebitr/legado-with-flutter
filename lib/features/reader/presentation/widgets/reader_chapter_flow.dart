/// The pieces both reading flows share
/// (`docs/dev/adr/0087-reader-page-table-and-chapter-heading.md`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Where an explicit jump lands: a chapter, a character offset inside it, and a nonce.
///
/// The nonce is what makes a second jump to the same position work: the flows only honour a restore
/// they have not seen yet, so the reader's own progress updates (which move the character offset
/// continuously) can never be mistaken for a jump the flow must apply.
typedef ReaderFlowRestore = ({int chapterIndex, int charOffset, int nonce});

/// The sentence being read aloud, as a range inside the chapter at its URL (ADR-0062 §决策 5).
typedef ReaderFlowHighlight = ({String url, int start, int end});

/// The block that stands in for a chapter body that is not in hand yet.
///
/// It sits **under the chapter's own heading**, so a reader who scrolls into a boundary sees which
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

/// One page of the table, painted: the chapter heading (first page only) and the body slice.
///
/// Both flows render pages through this widget, so "what a page looks like" has one definition and
/// its height is the height the table measured (ADR-0087 §决策 1/3). Nothing here measures anything.
class ReaderPageView extends StatelessWidget {
  /// Creates the page; [highlight] is the sentence being read aloud, when it belongs here.
  const ReaderPageView({
    required this.page,
    required this.style,
    required this.highlightStyle,
    required this.titleStyle,
    required this.highlight,
    required this.onNeedChapter,
    super.key,
  });

  /// The page to paint.
  final ReaderPageEntry page;

  /// The body text style (the very value the page was measured with).
  final TextStyle style;

  /// The style of the sentence being read aloud (ADR-0062 §决策 5).
  final TextStyle highlightStyle;

  /// The chapter heading's style.
  final TextStyle titleStyle;

  /// The sentence being read aloud, when it belongs to this page's chapter.
  final ReaderFlowHighlight? highlight;

  /// Called when a chapter's body is needed: a page that has none, or the reader's own retry.
  ///
  /// [ReaderPageView] passes `explicit: true` only for the retry button. A relay request (a page that
  /// is merely waiting) must **not** undo the "this chapter failed" mark, or the screen and the
  /// prefetch queue would take turns asking for a chapter that is not coming
  /// (`docs/dev/adr/0088-crossing-limit-and-prefetch-window.md`).
  final void Function(int chapterIndex, {bool explicit}) onNeedChapter;

  @override
  Widget build(BuildContext context) {
    final ReaderFlowHighlight? spoken = highlight;
    final String? body = page.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 章头的高度就是页表量出来的那一段（标题 + 与正文的间距）：标题顶对齐，留白落在下方，
        // 于是「量到的」与「画出的」是同一件事（ADR-0087 §决策 3）。
        if (page.hasTitle)
          SizedBox(
            height: page.titleExtent,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(page.title, style: titleStyle),
            ),
          ),
        if (body == null)
          SizedBox(
            height: page.bodyExtent,
            child: Center(
              child: ReaderChapterPendingStrip(
                isFailed: page.isFailed,
                onRetry: () =>
                    onNeedChapter(page.id.chapterIndex, explicit: true),
              ),
            ),
          )
        else
          readingText(
            body: body,
            start: page.start,
            end: page.end,
            style: style,
            highlightStyle: highlightStyle,
            highlight: spoken != null && spoken.url == page.url
                ? (start: spoken.start, end: spoken.end)
                : null,
          ),
      ],
    );
  }
}
