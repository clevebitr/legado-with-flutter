import 'package:flutter/material.dart';

/// Splits [text] into the character offsets its pages start at (`docs/dev/roadmap.md` 5.3).
///
/// The split is a **layout measurement, not a guess**: a [TextPainter] lays the remaining text out
/// at [size]'s width, and the position under the bottom-right corner of the page becomes the next
/// page's start. Two consequences are deliberate and recorded in ADR-0044 §决策 4:
///
/// * when that position is not the start of a line, the page ends a few words early — an
///   approximation, never an overlap that would hide text;
/// * the result depends on [style] and [textScaler], which is exactly why it is recomputed when the
///   reader's typography changes instead of being stored.
///
/// The list always starts with `0`; a text that fits on one page answers `[0]`.
///
/// [firstPageInset] is the space the **chapter heading** takes at the top of this text
/// (`docs/dev/adr/0087-reader-page-table-and-chapter-heading.md` §决策 3): the first page then holds
/// that much less body, so the heading is part of the page rather than something painted over it.
List<int> readerPageStarts({
  required String text,
  required TextStyle style,
  required Size size,
  required TextScaler textScaler,
  double firstPageInset = 0,
}) {
  final List<int> starts = <int>[0];
  final double width = size.width;
  final double height = size.height;
  if (text.isEmpty || width <= 0 || height <= 0) {
    return starts;
  }

  var start = 0;
  while (start < text.length) {
    // 首页要让出章头的高度；让出去以后连一行都放不下时，宁可忽略章头也不产出空页
    // （否则下面按「页面右下角」取位置会落到第 0 个字符，循环里的 `next` 只能靠兜底前进）。
    final double usable = starts.length == 1
        ? (height - firstPageInset <= 0 ? height : height - firstPageInset)
        : height;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text.substring(start), style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    if (painter.height <= usable) {
      // 剩下的正文一页装得下：当前页就是最后一页。
      break;
    }
    final int pageEnd = painter
        .getPositionForOffset(Offset(width, usable))
        .offset;
    // 位置算不出来时至少前进一个字符：否则循环不终止（宁可多切一页，也不挂死）。
    final int next = start + (pageEnd <= 0 ? 1 : pageEnd);
    if (next >= text.length) {
      break;
    }
    starts.add(next);
    start = next;
  }

  return starts;
}

/// The height [text] occupies at [style] inside a [width]-wide box.
///
/// The continuous scroll flow stacks whole chapters instead of pages, so it has no page numbers to
/// count: it needs the rendered height of each chapter to answer three questions with the same one
/// measurement (`docs/dev/adr/0085-continuous-chapter-reading.md`):
///
/// * which chapter the top of the viewport is in, and how far into it (the estimate of
///   ADR-0044 §决策 4);
/// * how far the scroll offset has to move when a chapter is prepended or dropped above it, so the
///   text under the reader's eyes never shifts;
/// * whether the end of the last chapter in hand is close enough to ask for the next one.
///
/// It uses the same measurement as [readerPageStarts] — a [TextPainter] at the width and
/// [textScaler] the viewport will use — because the very same `Text` paints the body afterwards.
double readerTextHeight({
  required String text,
  required TextStyle style,
  required double width,
  required TextScaler textScaler,
}) {
  if (text.isEmpty || width <= 0) {
    return 0;
  }
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: width);

  return painter.height;
}

/// The index of the page that contains [charOffset] (`docs/dev/roadmap.md` 5.3).
///
/// Restoration uses it to turn a stored offset back into a page number; an offset past the end
/// answers the last page rather than throwing.
int readerPageOf(List<int> starts, int charOffset) {
  var page = 0;
  for (var index = 0; index < starts.length; index++) {
    if (starts[index] <= charOffset) {
      page = index;
    } else {
      break;
    }
  }

  return page;
}
