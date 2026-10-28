/// The pieces the two continuous reading flows share (`docs/dev/adr/0085-continuous-chapter-reading.md`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// One chapter as a continuous flow renders it: TOC index, URL, title and laid-out body.
///
/// The body is the one **after** the presentation transform of `readerBodyText` — the flows stack
/// what they are given and never look at the source's own text. The title travels with it because
/// the scroll flow prints it at the chapter's start, which is what makes a chapter boundary visible
/// in one continuous document (ADR-0086 §决策 7).
typedef ReaderFlowChapter = ({int index, String url, String title, String text});

/// Where an explicit jump lands: a chapter, a character offset inside it, and a nonce.
///
/// The nonce is what makes a second jump to the same position work: the flows only honour a
/// restore they have not seen yet, so the reader's own progress updates (which move
/// character offset continuously) can never be mistaken for a jump it must apply.
typedef ReaderFlowRestore = ({int index, int charOffset, int nonce});

/// The sentence being read aloud, as a range inside the chapter at its URL (ADR-0062 §决策 5).
typedef ReaderFlowHighlight = ({String url, int start, int end});

/// The chapters a continuous flow renders, and the policy that keeps them from moving.
///
/// A flow may only render **contiguous** chapters — a gap would let the reader scroll into
/// nothing — so [sync] answers the contiguous run around the anchor that has a body in hand.
///
/// It also remembers every chapter it handed out ([_rendered]). The page's prefetch window slides
/// with the session chapter, so the body it offered a moment ago may be gone; dropping it from the
/// flow at that moment would delete text that is still on screen. Retention plus [retain] keeps the
/// window stable and lets a flow decide *when* it is cheap to drop a chapter (when the scroll is
/// idle, where the offset can be compensated without a visible shift).
///
/// Plain Dart on purpose: both flows share one policy, and the policy itself is unit-tested.
class ReaderChapterWindow {
  /// Chapters already rendered, by chapter URL.
  final Map<String, ReaderFlowChapter> _rendered =
      <String, ReaderFlowChapter>{};

  /// The TOC the cached index map below was built from, and the map itself.
  ///
  /// [sync] runs on every rebuild (which happens on every progress write), so re-indexing a
  /// thousand-chapter table of contents per frame would be the most expensive thing here
  /// (C-PERF-1). The list identity is stable while the chapter list does not change.
  List<ReadingChapter>? _toc;
  Map<String, int> _indexByUrl = const <String, int>{};

  /// Folds [bodies] (keyed by chapter URL) into the window and answers the contiguous run that
  /// contains [anchorIndex], in TOC order.
  ///
  /// Answers an empty list while the anchor chapter's own body is missing: the page shows its
  /// loading state then, and a flow with a hole in it is worse than no flow at all.
  List<ReaderFlowChapter> sync({
    required List<ReadingChapter> chapters,
    required int anchorIndex,
    required Map<String, String> bodies,
  }) {
    if (chapters.isEmpty || anchorIndex < 0 || anchorIndex >= chapters.length) {
      return const <ReaderFlowChapter>[];
    }
    final Map<String, int> known = _indexOf(chapters);
    // 目录换过（换源 / 重新拉目录）：旧地址的正文不该继续留在窗口里。
    _rendered.removeWhere(
      (String url, ReaderFlowChapter _) => !known.containsKey(url),
    );
    bodies.forEach((String url, String text) {
      final int? index = known[url];
      if (index != null) {
        _rendered[url] = (
          index: index,
          url: url,
          title: chapters[index].title,
          text: text,
        );
      }
    });
    final Map<int, ReaderFlowChapter> byIndex = <int, ReaderFlowChapter>{
      for (final ReaderFlowChapter chapter in _rendered.values)
        chapter.index: chapter,
    };
    if (!byIndex.containsKey(anchorIndex)) {
      return const <ReaderFlowChapter>[];
    }

    return _runAround(byIndex, anchorIndex);
  }

  /// The URL → TOC index map of [chapters], built once per chapter list.
  Map<String, int> _indexOf(List<ReadingChapter> chapters) {
    if (identical(_toc, chapters) && _indexByUrl.length == chapters.length) {
      return _indexByUrl;
    }
    _toc = chapters;
    _indexByUrl = <String, int>{
      for (var index = 0; index < chapters.length; index++)
        chapters[index].url: index,
    };

    return _indexByUrl;
  }

  /// Drops the rendered chapters farther than [radius] from [anchorIndex] and answers them.
  ///
  /// The caller is expected to compensate its scroll offset for the chapters above the anchor that
  /// this returns (a scroll flow then moves its offset by their height); the ones below cost nothing.
  List<ReaderFlowChapter> retain({required int anchorIndex, int radius = 1}) {
    final List<ReaderFlowChapter> dropped = <ReaderFlowChapter>[
      for (final ReaderFlowChapter chapter in _rendered.values)
        if ((chapter.index - anchorIndex).abs() > radius) chapter,
    ];
    for (final ReaderFlowChapter chapter in dropped) {
      _rendered.remove(chapter.url);
    }

    return dropped;
  }

  /// The contiguous chapters around [anchorIndex], walking outwards while a body is in hand.
  List<ReaderFlowChapter> _runAround(
    Map<int, ReaderFlowChapter> byIndex,
    int anchorIndex,
  ) {
    var first = anchorIndex;
    while (byIndex.containsKey(first - 1)) {
      first--;
    }
    var last = anchorIndex;
    while (byIndex.containsKey(last + 1)) {
      last++;
    }

    return <ReaderFlowChapter>[
      for (var index = first; index <= last; index++)
        if (byIndex[index] case final ReaderFlowChapter chapter) chapter,
    ];
  }
}

/// The strip that stands in for a neighbouring chapter that is not in hand yet.
///
/// Both flows show it where the missing chapter will appear — above the first chapter or below the
/// last one — so the reader can keep moving in that direction instead of meeting the end of the
/// document. A failed read keeps the strip but offers the retry instead of a spinner: a chapter
/// that could not be read must not look like a chapter that is still loading.
class ReaderChapterPendingStrip extends StatelessWidget {
  /// Creates the strip; [onRetry] is only called for the failed state.
  const ReaderChapterPendingStrip({
    required this.isFailed,
    required this.onRetry,
    super.key,
  });

  /// Whether the read failed (offers [onRetry]) rather than still being in flight (shows a spinner).
  final bool isFailed;

  /// Called when the reader asks for the chapter to be read again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isFailed)
            TextButton.icon(
              onPressed: onRetry,
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
            SizedBox(height: tokens.spacing.sm),
            Text(
              l10n.readerChapterLoading,
              style: tokens.typography.base.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
