/// The continuous scroll body: the page table stacked vertically, scrolled by the reader.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Renders the page table as **one** scrolling document
/// (`docs/dev/adr/0087-reader-page-table-and-chapter-heading.md`).
///
/// Upstream Legado never stops at a chapter boundary, and neither does this: the pages of the
/// chapters in hand are stacked with the heights the table measured, so scrolling runs straight
/// through a boundary and only the session's chapter changes.
///
/// Two rules keep the text under the reader's eyes from ever moving:
///
/// 1. **nothing above the viewport top is measured here.** The heights come from
///    [ReaderPageTable], measured before the first build, so a page that arrives or a chapter that
///    joins the window does not need a "wait one frame, then jump back" fix;
/// 2. **the anchor is a character offset.** When the table changes, the reader's sentence is put
///    back at the viewport top by giving the scrollable a fresh position — in the same frame it is
///    painted, which is exactly what an after-the-frame `jumpTo` cannot do (ADR-0085's revision).
class ReaderScrollFlow extends StatefulWidget {
  /// Creates the flow; [table] is measured by the page from the session chapter's window.
  const ReaderScrollFlow({
    required this.table,
    required this.restore,
    required this.highlight,
    required this.style,
    required this.highlightStyle,
    required this.titleStyle,
    required this.padding,
    required this.onProgress,
    required this.onSettled,
    required this.onNeedChapter,
    super.key,
  });

  /// The pages to render, in reading order.
  final ReaderPageTable table;

  /// An explicit jump the flow must apply, or `null` while the reader scrolls on its own.
  final ReaderFlowRestore? restore;

  /// The sentence being read aloud, when it belongs to one of the rendered chapters.
  final ReaderFlowHighlight? highlight;

  /// The body text style (measured and painted with the very same value).
  final TextStyle style;

  /// The style of the sentence being read aloud (ADR-0062 §决策 5).
  final TextStyle highlightStyle;

  /// The chapter heading's style.
  final TextStyle titleStyle;

  /// The page margin, already taken off the box the pages were measured in.
  final double padding;

  /// Called while the reader scrolls, with the chapter at the top of the viewport.
  final void Function(int chapterIndex, int charOffset) onProgress;

  /// Called when a scroll settles, so the page can write the position out.
  final void Function(int chapterIndex, int charOffset) onSettled;

  /// Called with a chapter index whose body the flow needs (a loading page, or a retry).
  final void Function(int chapterIndex) onNeedChapter;

  @override
  State<ReaderScrollFlow> createState() => _ReaderScrollFlowState();
}

/// State of the scroll flow: the scroll position, the anchor and the pending requests.
class _ReaderScrollFlowState extends State<ReaderScrollFlow> {
  /// The live controller. It is **replaced** whenever the reader's sentence has to be put back:
  /// a new controller plus a new key for the scrollable makes the new position apply in the frame
  /// that paints it, instead of one frame late.
  ScrollController _scroll = ScrollController();

  /// Controllers replaced during this frame; disposed once the frame is done with them.
  final List<ScrollController> _retired = <ScrollController>[];

  /// The table the flow is currently laid out against.
  ReaderPageTable? _table;

  /// Bumped whenever [_scroll] is replaced; it is the scrollable's key.
  int _revision = 0;

  /// The viewport top in content coordinates (the table's own space, page margins excluded).
  double _offset = 0;

  /// The chapter and character offset at the viewport top — the reader's anchor.
  ({int chapterIndex, int charOffset})? _anchor;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last notification of this frame ended a scroll (a settle).
  bool _settlePending = false;

  /// The chapters this flow already asked a body for.
  final Set<int> _requested = <int>{};

  @override
  void dispose() {
    _scroll.dispose();
    for (final ScrollController controller in _retired) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync(widget.table);
    final ReaderPageTable table = _table ?? widget.table;
    final M3ETheme tokens = context.m3e;
    // 书末那一句的高度也是量好的：`itemExtentBuilder` 要求每一项都有确定高度。
    final double endExtent = tokens.spacing.xxl;
    final int itemCount = table.length + (table.hasNextChapter ? 0 : 1);

    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: ListView.builder(
        key: ValueKey<int>(_revision),
        controller: _scroll,
        // 尾部留白：末页也要能滚到视口顶。少了它，最后那一页（往往不满一屏）永远上不去，
        // 于是「跳到最后一章」会被最大滚动范围截住、锚点仍落在上一章（读者看到的是回弹）。
        padding: EdgeInsets.only(
          top: widget.padding,
          bottom: _tailOf(table, endExtent, itemCount),
        ),
        itemCount: itemCount,
        itemExtentBuilder: (int index, SliverLayoutDimensions dimensions) =>
            index < table.length ? table.pages[index].extent : endExtent,
        itemBuilder: (BuildContext context, int index) => index < table.length
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.padding),
                child: _pageOf(table.pages[index]),
              )
            : _bookEnd(context, endExtent),
      ),
    );
  }

  /// The blank that has to follow the last page for it to be scrollable to the viewport top.
  ///
  /// A page is at most one screen tall, so the last one leaves `viewport - itsHeight` of scroll range
  /// missing; adding exactly that much makes the last page's top reachable (and no more, so the extra
  /// blank is never larger than it has to be).
  double _tailOf(ReaderPageTable table, double endExtent, int itemCount) {
    if (itemCount <= 0) {
      return widget.padding;
    }
    final bool endsWithBookEnd = itemCount > table.length;
    final double lastExtent = endsWithBookEnd
        ? endExtent
        : table.pages.last.extent;
    final double viewport = table.box.height + 2 * widget.padding;
    final double needed = viewport - lastExtent;

    return needed > widget.padding ? needed : widget.padding;
  }

  /// Puts the flow back on the reader's sentence when the page table changed.
  ///
  /// This runs inside `build`, before the scrollable is laid out, so the corrected position is the
  /// one painted (ADR-0087 §决策 2). Two of the branches do **nothing**, on purpose: appending a
  /// chapter below the reader and a body arriving below the viewport both leave the text above
  /// untouched — which is why crossing a chapter boundary no longer interrupts a fling.
  void _sync(ReaderPageTable table) {
    final ReaderPageTable? previous = _table;
    _table = table;

    // 显式跳转优先于一切：它按字符偏移落位（章内跳转、目录、书签、书内搜索都走这条）。
    final ReaderFlowRestore? restore = widget.restore;
    if (restore != null && restore.nonce != _appliedRestoreNonce) {
      final double? target = table.offsetOf(
        restore.chapterIndex,
        restore.charOffset,
      );
      if (target != null) {
        _appliedRestoreNonce = restore.nonce;
        _land(target);

        return;
      }
      // 目标章的正文还没到：它现在是一页「正在加载」，先落在它的顶上；正文到达后这次 build
      // 会再走一遍，那时按同一个字符偏移落位。
    }

    if (previous == null) {
      // 首帧：不换控制器，只把锚点收下来，并把位置报给页面。
      _anchor = table.positionAt(_offset);
      _scheduleFrame();

      return;
    }
    if (previous.signature == table.signature) {
      return;
    }

    final ({int chapterIndex, int charOffset})? anchor = _anchor;
    if (anchor == null) {
      return;
    }
    final double? target = table.offsetOf(
      anchor.chapterIndex,
      anchor.charOffset,
    );
    // 半像素以内不动：那一帧其实什么都没变，换控制器只会让滚动抖一下。
    if (target != null && (target - _offset).abs() > 0.5) {
      _land(target);
    }
  }

  /// Moves the scrollable to [contentOffset] in the frame that is being built.
  ///
  /// A `jumpTo` would have to wait for the frame to end — and the frame it waits for is already
  /// painted at the wrong offset, which is the jump the reader used to see. A fresh controller and a
  /// fresh key give the scrollable a position created at the right offset instead.
  void _land(double contentOffset) {
    final ReaderPageTable? table = _table;
    final double total = table?.totalExtent ?? 0;
    final double clamped = contentOffset.clamp(0.0, total <= 0 ? 0.0 : total);
    final ScrollController next = ScrollController(
      initialScrollOffset: clamped + widget.padding,
    );
    _retired.add(_scroll);
    _scroll = next;
    _offset = clamped;
    _anchor = table?.positionAt(clamped);
    _revision++;
    _scheduleFrame();
    _disposeRetiredAfterFrame();
  }

  /// Disposes the replaced controllers once the frame that still references them is over.
  void _disposeRetiredAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final ScrollController controller in _retired) {
        controller.dispose();
      }
      _retired.clear();
    });
  }

  /// One page: the chapter heading (first page only) and the body slice.
  Widget _pageOf(ReaderPageEntry page) => ReaderPageView(
    page: page,
    style: widget.style,
    highlightStyle: widget.highlightStyle,
    titleStyle: widget.titleStyle,
    highlight: widget.highlight,
    onNeedChapter: widget.onNeedChapter,
  );

  /// The end of the book, shown once the last page of the last chapter is behind the reader.
  Widget _bookEnd(BuildContext context, double extent) {
    final M3ETheme tokens = context.m3e;

    return SizedBox(
      height: extent,
      child: Center(
        child: Text(
          AppLocalizations.of(context).readerLastChapter,
          style: tokens.typography.base.bodyLarge?.copyWith(
            color: widget.style.color,
          ),
        ),
      ),
    );
  }

  /// Collects the metrics and schedules the frame's bookkeeping.
  ///
  /// Nothing is mutated here that would rebuild: a notification can be dispatched *during* layout,
  /// and marking the page dirty from that point is an assertion. The offset and the anchor are plain
  /// fields, so they are safe to update; the report to the page waits for the frame to end.
  bool _onNotification(ScrollNotification notification) {
    final ReaderPageTable? table = _table;
    if (table == null) {
      return false;
    }
    final double content = (notification.metrics.pixels - widget.padding).clamp(
      0.0,
      table.totalExtent,
    );
    _offset = content;
    _anchor = table.positionAt(content);
    if (notification is ScrollEndNotification) {
      _settlePending = true;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _scheduleFrame();
    }

    return false;
  }

  /// Schedules this frame's report, once.
  void _scheduleFrame() {
    if (_frameScheduled) {
      return;
    }
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) {
        return;
      }
      _requestMissingBodies();
      final ({int chapterIndex, int charOffset})? anchor = _anchor;
      if (anchor == null) {
        return;
      }
      widget.onProgress(anchor.chapterIndex, anchor.charOffset);
      if (_settlePending) {
        _settlePending = false;
        widget.onSettled(anchor.chapterIndex, anchor.charOffset);
      }
    });
  }

  /// Asks for the body of every page that has none, once per chapter.
  void _requestMissingBodies() {
    final ReaderPageTable? table = _table;
    if (table == null) {
      return;
    }
    final Set<int> rendered = <int>{};
    for (final ReaderPageEntry page in table.pages) {
      rendered.add(page.id.chapterIndex);
      if (!page.isPlaceholder || !_requested.add(page.id.chapterIndex)) {
        continue;
      }
      widget.onNeedChapter(page.id.chapterIndex);
    }
    // 离开窗口的章要允许下次再问一次（读者可能往回翻），保留已问过的标记只对仍在窗口里的章有效。
    _requested.removeWhere((int index) => !rendered.contains(index));
  }
}
