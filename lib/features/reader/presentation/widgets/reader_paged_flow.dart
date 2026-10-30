/// The paged body: the same page table the scroll mode uses, one page at a time.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_turn.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Renders the page table as pages that keep turning across chapter boundaries
/// (`docs/dev/adr/0087-reader-page-table-and-chapter-heading.md` §决策 5).
///
/// It is the **same** table the scroll mode renders — same pages, same heights, same headings — so
/// switching modes mid-chapter cannot lose the place and the two modes cannot disagree about where a
/// chapter begins. A chapter whose body has not arrived takes one loading page, which becomes that
/// chapter's first page in place once the text is in hand: the reader's page does not move.
class ReaderPagedFlow extends StatefulWidget {
  /// Creates the flow; [table] is measured by the page from the session chapter's window.
  const ReaderPagedFlow({
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
    this.turn,
    super.key,
  });

  /// The pages to render, in reading order.
  final ReaderPageTable table;

  /// The page the flow must open at, tagged with a nonce so a repeated jump is honoured.
  final ReaderFlowRestore? restore;

  /// The sentence being read aloud, when it belongs to one of the rendered chapters.
  final ReaderFlowHighlight? highlight;

  /// The body text style (pages were measured with this very value).
  final TextStyle style;

  /// The style of the sentence being read aloud (ADR-0062 §决策 5).
  final TextStyle highlightStyle;

  /// The chapter heading's style.
  final TextStyle titleStyle;

  /// The page margin, already taken off the box the pages were measured in.
  final double padding;

  /// Called when the page changes, with the chapter and character offset of the new page.
  final void Function(int chapterIndex, int charOffset) onProgress;

  /// Called when a page turn settles, so the page can write the position out.
  final void Function(int chapterIndex, int charOffset) onSettled;

  /// Called with a chapter index whose body the flow needs (a loading page, or a retry).
  final void Function(int chapterIndex, {bool explicit}) onNeedChapter;

  /// The page's "turn one page" command (ADR-0093 §决策 2), or `null` when it is not used.
  final ReaderPageTurn? turn;

  @override
  State<ReaderPagedFlow> createState() => _ReaderPagedFlowState();
}

/// State of the paged flow: the page controller, the page the reader is on and the requests.
class _ReaderPagedFlowState extends State<ReaderPagedFlow> {
  late PageController _controller = PageController();

  /// Controllers replaced during this frame; disposed once the frame is done with them.
  final List<PageController> _retired = <PageController>[];

  /// The table the flow is currently laid out against.
  ReaderPageTable? _table;

  /// Bumped whenever [_controller] is replaced; it is the pager's key.
  int _revision = 0;

  /// The page the reader is on, as an index into the table.
  int _page = 0;

  /// The chapter and character offset the current page starts at.
  ({int chapterIndex, int charOffset})? _anchor;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last turn still has to be written out.
  bool _settlePending = false;

  /// The chapters this flow already asked a body for.
  final Set<int> _requested = <int>{};

  @override
  void initState() {
    super.initState();
    widget.turn?.addListener(_onTurn);
  }

  @override
  void didUpdateWidget(ReaderPagedFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turn != widget.turn) {
      oldWidget.turn?.removeListener(_onTurn);
      widget.turn?.addListener(_onTurn);
    }
  }

  /// Turns one page in the commanded direction (ADR-0093 §决策 3, ADR-0096).
  ///
  /// It goes through the pager's own animation, so progress, the page-table correction and crossing
  /// a chapter boundary all keep working exactly as a manual swipe (ADR-0087 §决策 5).
  void _onTurn() {
    if (!_controller.hasClients) {
      return;
    }
    final bool forward = widget.turn?.direction == ReaderPageTurnDirection.next;
    final Future<void> turn = forward
        ? _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
        : _controller.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
    unawaited(turn);
  }

  @override
  void dispose() {
    widget.turn?.removeListener(_onTurn);
    _controller.dispose();
    for (final PageController controller in _retired) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync(widget.table);
    final ReaderPageTable table = _table ?? widget.table;
    final int count = table.length + (table.hasNextChapter ? 0 : 1);
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    if (_page >= count) {
      _page = count - 1;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Padding(
        padding: EdgeInsets.all(widget.padding),
        child: PageView.builder(
          key: ValueKey<int>(_revision),
          controller: _controller,
          itemCount: count,
          onPageChanged: _onPageChanged,
          itemBuilder: (BuildContext context, int index) => index < table.length
              // 页高就是量出来的高度：内容放不下时下层滚动视图吸收，而不是溢出报错。
              ? SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ReaderPageView(
                    page: table.pages[index],
                    style: widget.style,
                    highlightStyle: widget.highlightStyle,
                    titleStyle: widget.titleStyle,
                    highlight: widget.highlight,
                    onNeedChapter: widget.onNeedChapter,
                  ),
                )
              : _bookEnd(context),
        ),
      ),
    );
  }

  /// Puts the reader back on the same text when the page table changed.
  ///
  /// The pages after the reader are what a body arriving creates, so the common case re-lands on the
  /// very page it was on — by page identity, never by index, because an inserted page above shifts
  /// every index below it (ADR-0087 §决策 5).
  void _sync(ReaderPageTable table) {
    final ReaderPageTable? previous = _table;
    _table = table;

    final ReaderFlowRestore? restore = widget.restore;
    if (restore != null && restore.nonce != _appliedRestoreNonce) {
      final int index = table.indexOfChapter(
        restore.chapterIndex,
        restore.charOffset,
      );
      if (index >= 0) {
        _appliedRestoreNonce = restore.nonce;
        _land(index);

        return;
      }
      // 目标章正文未到：它现在是一页加载页，先落在这一页；正文到手后这次 build 会再走一遍。
    }

    if (previous == null) {
      _page = 0;
      _anchor = _anchorOf(0);
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
    final int index = table.indexOfChapter(
      anchor.chapterIndex,
      anchor.charOffset,
    );
    if (index >= 0 && index != _page) {
      _land(index);
    }
  }

  /// Moves the pager to [page] in the frame that is being built.
  ///
  /// `jumpToPage` would land a frame late — the reader would see the old page once more. A fresh
  /// controller and key create the page position at the right index instead.
  void _land(int page) {
    final ReaderPageTable? table = _table;
    final int count =
        (table?.length ?? 0) + ((table?.hasNextChapter ?? true) ? 0 : 1);
    final int target = page.clamp(0, count <= 0 ? 0 : count - 1);
    final PageController next = PageController(initialPage: target);
    _retired.add(_controller);
    _controller = next;
    _page = target;
    _anchor = _anchorOf(target);
    _revision++;
    _settlePending = true;
    _scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final PageController controller in _retired) {
        controller.dispose();
      }
      _retired.clear();
    });
  }

  /// The chapter and character offset page [index] starts at, or `null` on the end page.
  ({int chapterIndex, int charOffset})? _anchorOf(int index) {
    final ReaderPageEntry? page = _table?.pageAt(index);
    if (page == null) {
      return null;
    }

    return (chapterIndex: page.id.chapterIndex, charOffset: page.start);
  }

  /// Handles a page turn: the report and the write-out run after the frame.
  ///
  /// `PageView` reports the new page from a scroll notification, which can be dispatched while a
  /// viewport corrects its own pixels — a provider write there is a `markNeedsBuild during build`.
  void _onPageChanged(int page) {
    _page = page;
    _anchor = _anchorOf(page);
    _settlePending = true;
    _scheduleFrame();
  }

  /// Remembers that the reader stopped turning; the write-out waits for the frame to end.
  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _settlePending = true;
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
      widget.onNeedChapter(page.id.chapterIndex, explicit: false);
    }
    _requested.removeWhere((int index) => !rendered.contains(index));
  }

  /// The last page of the book: there is nothing after it, and it says so.
  Widget _bookEnd(BuildContext context) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Text(
        AppLocalizations.of(context).readerLastChapter,
        style: tokens.typography.base.bodyLarge?.copyWith(
          color: widget.style.color,
        ),
      ),
    );
  }
}
