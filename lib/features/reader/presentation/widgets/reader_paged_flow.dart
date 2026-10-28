/// The paged body: pages of the chapters in hand, turned across chapter boundaries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// One page of the continuous flow: the window `[start, end)` of a chapter's body.
typedef _FlowPage = ({int index, String url, String text, int start, int end});

/// Renders the chapters in hand as pages that keep turning across chapter boundaries
/// (`docs/dev/adr/0085-continuous-chapter-reading.md`).
///
/// The pages of the previous chapter's tail, the current chapter and the next chapter's head are
/// one list, so turning past the last page of a chapter lands on the next chapter's first page
/// instead of on a "next chapter" button. A neighbour whose body is not in hand yet gets a
/// [ReaderChapterPendingStrip] page in its place: that page is what fetches it, and because the
/// fetch only ever *appends* pages, the page the reader is looking at turns into the real first
/// page of that chapter as soon as it arrives — no jump, no tap.
class ReaderPagedFlow extends StatefulWidget {
  /// Creates the flow; every chapter in [bodies] must be keyed by its TOC URL.
  const ReaderPagedFlow({
    required this.chapters,
    required this.anchorIndex,
    required this.bodies,
    required this.failed,
    required this.restore,
    required this.highlight,
    required this.style,
    required this.highlightStyle,
    required this.padding,
    required this.onProgress,
    required this.onSettled,
    required this.onNeedChapter,
    super.key,
  });

  /// The whole table of contents, in reading order.
  final List<ReadingChapter> chapters;

  /// The chapter the session is on.
  final int anchorIndex;

  /// Laid-out bodies in hand, keyed by chapter URL (the page's prefetch window).
  final Map<String, String> bodies;

  /// Chapters whose body could not be read, by chapter URL.
  final Set<String> failed;

  /// The page the flow must open at, tagged with a nonce so a repeated jump is honoured.
  final ReaderFlowRestore? restore;

  /// The sentence being read aloud, when it belongs to one of the rendered chapters.
  final ReaderFlowHighlight? highlight;

  /// The body text style (pages are measured with this very value).
  final TextStyle style;

  /// The style of the sentence being read aloud (ADR-0062 §决策 5).
  final TextStyle highlightStyle;

  /// The page margin, applied around the pages.
  final double padding;

  /// Called when the page changes, with the chapter and character offset of the new page.
  final void Function(int index, int charOffset) onProgress;

  /// Called when a page turn settles, so the page can write the position out.
  final void Function(int index, int charOffset) onSettled;

  /// Called with a chapter index whose body the flow needs (a boundary page, or a retry).
  final void Function(int index) onNeedChapter;

  @override
  State<ReaderPagedFlow> createState() => _ReaderPagedFlowState();
}

/// State of the paged flow: the rendered chapters, their measured pages and the controller.
class _ReaderPagedFlowState extends State<ReaderPagedFlow> {
  final ReaderChapterWindow _window = ReaderChapterWindow();

  /// Measured page starts, keyed by chapter URL.
  final Map<String, ({int signature, List<int> starts})> _starts =
      <String, ({int signature, List<int> starts})>{};

  /// Chapters currently rendered, contiguous and in TOC order.
  List<ReaderFlowChapter> _visible = const <ReaderFlowChapter>[];

  /// The rendered chapters frozen while a drag is in progress, or `null` when there is none.
  List<ReaderFlowChapter>? _frozen;

  /// Every page of [_visible], in reading order.
  List<_FlowPage> _pages = const <_FlowPage>[];

  /// The measuring box of the last build.
  Size _size = Size.zero;

  /// The text scale of the last build, kept so pages can also be measured outside `build`.
  TextScaler _textScaler = TextScaler.noScaling;

  /// How many pages sit before the anchor chapter's first page (the leading placeholder included).
  ///
  /// This is what keeps the reader on the same text when pages are added or dropped above it.
  int _leadingPages = 0;

  /// Whether a neighbour without a body has a placeholder page at the start / at the end.
  bool _leadingPending = false;
  bool _trailingPending = false;

  /// The chapter each placeholder page already asked for, so one fetch is one request.
  int? _requestedBefore;
  int? _requestedAfter;

  PageController? _controller;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether a restore is waiting for the frame that can carry it.
  bool _restoreScheduled = false;

  /// Guards the flow's own page jumps: their notifications are not reader turns.
  bool _compensating = false;

  /// The pages the rendered window still owes the reader, applied after the frame.
  ///
  /// `jumpToPage` cannot run while the tree builds or lays out: it dispatches a scroll notification
  /// the app bar listens to, and marking a widget dirty there is an assertion.
  int _pendingPageJump = 0;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last notification of this frame ended a drag.
  bool _settlePending = false;

  /// The position to re-land on after the pages were re-measured (a rotated screen), if any.
  ({int index, int charOffset})? _pendingReland;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderPagedFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_frozen == null) {
      _applyStructure(
        _window.sync(
          chapters: widget.chapters,
          anchorIndex: widget.anchorIndex,
          bodies: widget.bodies,
        ),
      );
    }
  }

  /// The measuring signature: a change here invalidates every measured page list.
  int get _signature => Object.hash(
    _size.width,
    _size.height,
    widget.style,
    _textScaler.scale(1),
  );

  /// The page starts of [chapter], measured once per size, style and text scale.
  List<int> _startsOf(ReaderFlowChapter chapter) {
    final int signature = _signature;
    final ({int signature, List<int> starts})? cached = _starts[chapter.url];
    if (cached != null && cached.signature == signature) {
      return cached.starts;
    }
    final List<int> starts = readerPageStarts(
      text: chapter.text,
      style: widget.style,
      size: _size,
      textScaler: _textScaler,
    );
    _starts[chapter.url] = (signature: signature, starts: starts);

    return starts;
  }

  /// Replaces the rendered chapters, keeping the page the reader is on.
  void _applyStructure(List<ReaderFlowChapter> next) {
    // 锚点章的正文可能还没到（刚跳章）：空窗口会把正文抹掉，宁可先什么都不换。
    if (next.isEmpty || _sameChapters(_visible, next)) {
      if (next.isNotEmpty) {
        _visible = next;
      }

      return;
    }
    _visible = next;
    _measurePages();
  }

  /// Whether [a] and [b] name the same chapters in the same order.
  bool _sameChapters(List<ReaderFlowChapter> a, List<ReaderFlowChapter> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index].index != b[index].index || a[index].url != b[index].url) {
        return false;
      }
    }

    return true;
  }

  /// Lays the rendered chapters out into pages and compensates pages added above the anchor.
  ///
  /// [compensate] is off while a new viewport size is being measured: the page count then changes
  /// because every page changed, not because a chapter appeared above the reader.
  void _measurePages({bool compensate = true}) {
    final bool leadingPending = _beforeIndex != null;
    final bool trailingPending = _afterIndex != null;
    final List<_FlowPage> pages = <_FlowPage>[];
    var anchorLeading = leadingPending ? 1 : 0;
    for (final ReaderFlowChapter chapter in _visible) {
      final List<int> starts = _startsOf(chapter);
      for (var page = 0; page < starts.length; page++) {
        pages.add((
          index: chapter.index,
          url: chapter.url,
          text: chapter.text,
          start: starts[page],
          end: page + 1 < starts.length
              ? starts[page + 1]
              : chapter.text.length,
        ));
      }
      if (chapter.index < widget.anchorIndex) {
        anchorLeading += starts.length;
      }
    }
    final int added = anchorLeading - _leadingPages;
    _pages = pages;
    _leadingPending = leadingPending;
    _trailingPending = trailingPending;
    _leadingPages = anchorLeading;
    if (compensate && added != 0) {
      // 上方多了 / 少了 added 页：页码跟着挪同样多，手指下的那段字不动。
      _pendingPageJump += added;
      _scheduleFrame();
    }
  }

  /// Moves the controller by the pending pages, after the frame.
  void _applyPendingJump() {
    final int pages = _pendingPageJump;
    _pendingPageJump = 0;
    final PageController? controller = _controller;
    if (pages == 0 || controller == null || !controller.hasClients) {
      return;
    }
    final double extent = controller.position.viewportDimension;
    if (extent <= 0) {
      return;
    }
    final ScrollPosition position = controller.position;
    final double target = (position.pixels + pages * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) {
      return;
    }
    _compensating = true;
    position.jumpTo(target);
    _compensating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.padding),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          if (_visible.isEmpty) {
            _visible = _window.sync(
              chapters: widget.chapters,
              anchorIndex: widget.anchorIndex,
              bodies: widget.bodies,
            );
            _size = size;
            _textScaler = MediaQuery.textScalerOf(context);
            _measurePages(compensate: false);
          }
          if (size != _size) {
            // 视口变了（旋屏 / 改窗口）：页要重排，页码没有意义了，位置按字符偏移重找。
            final _FlowPage? current = _currentPage();
            _size = size;
            _textScaler = MediaQuery.textScalerOf(context);
            _starts.clear();
            _measurePages(compensate: false);
            if (current != null) {
              _pendingReland = (
                index: current.index,
                charOffset: current.start,
              );
            }
          }
          _scheduleFrame();

          final int pageCount = _visible.isEmpty
              ? 0
              : _pages.length +
                    (_leadingPending ? 1 : 0) +
                    (_trailingPending ? 1 : 0) +
                    (_afterIndex == null ? 1 : 0);
          final PageController controller = _controller ??= PageController(
            initialPage: _pageKey(_leadingPages),
          );
          _scheduleRestore();

          return NotificationListener<ScrollNotification>(
            onNotification: _onNotification,
            child: PageView.builder(
              controller: controller,
              itemCount: pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: _page,
            ),
          );
        },
      ),
    );
  }

  /// The page the flow opens at for the pending restore.
  int _pageKey(int fallback) {
    final ReaderFlowRestore? restore = widget.restore;
    if (restore == null) {
      return fallback;
    }

    return _pageOf(restore.index, restore.charOffset) ?? fallback;
  }

  /// The flattened page index that holds [charOffset] of chapter [index].
  int? _pageOf(int index, int charOffset) {
    var found = -1;
    for (var page = 0; page < _pages.length; page++) {
      final _FlowPage candidate = _pages[page];
      if (candidate.index != index) {
        continue;
      }
      if (found < 0) {
        found = page;
      }
      if (candidate.start <= charOffset) {
        found = page;
      } else {
        break;
      }
    }
    if (found < 0) {
      return null;
    }

    return found + (_leadingPending ? 1 : 0);
  }

  /// Jumps to the page of the pending restore once the frame that can measure it is laid out.
  void _scheduleRestore() {
    final ReaderFlowRestore? restore = widget.restore;
    if (restore == null ||
        restore.nonce == _appliedRestoreNonce ||
        _restoreScheduled) {
      return;
    }
    final int? target = _pageOf(restore.index, restore.charOffset);
    final PageController? controller = _controller;
    if (target == null) {
      return;
    }
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted) {
        return;
      }
      _appliedRestoreNonce = restore.nonce;
      if (controller == null || !controller.hasClients) {
        return;
      }
      _compensating = true;
      controller.jumpToPage(target);
      _compensating = false;
      _reportCurrentPage();
    });
  }

  /// Schedules this frame's bookkeeping, once.
  ///
  /// The page jumps, the requests and the report all run here rather than in `build` or inside a
  /// scroll notification, where the tree may be laying out another widget.
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
      _applyPendingJump();
      final PageController? controller = _controller;
      if (controller == null || !controller.hasClients) {
        return;
      }
      _reland(controller);
      final int position =
          (controller.page ?? 0).round() - (_leadingPending ? 1 : 0);
      // 提前一页接力：等翻到占位页再抓，读者看到的仍是一次「正在加载」。
      if (position <= 0) {
        if (_beforeIndex case final int before) {
          _request(before, isBefore: true);
        }
      }
      if (position >= _pages.length - 1) {
        if (_afterIndex case final int after) {
          _request(after, isBefore: false);
        }
      }
      _reportCurrentPage();
      final bool settle = _settlePending;
      _settlePending = false;
      if (settle) {
        final _FlowPage? page = _currentPage();
        if (page != null) {
          widget.onSettled(page.index, page.start);
        }
        _frozen = null;
        _reconcile();
      }
    });
  }

  /// The page the viewport shows, or `null` on a placeholder page.
  _FlowPage? _currentPage() {
    final PageController? controller = _controller;
    if (controller == null || !controller.hasClients) {
      return null;
    }
    final int position =
        (controller.page ?? 0).round() - (_leadingPending ? 1 : 0);
    if (position < 0 || position >= _pages.length) {
      return null;
    }

    return _pages[position];
  }

  /// Puts the same text back under the viewport after the pages were re-measured.
  void _reland(PageController controller) {
    final ({int index, int charOffset})? pending = _pendingReland;
    if (pending == null || !controller.hasClients) {
      return;
    }
    _pendingReland = null;
    final int? target = _pageOf(pending.index, pending.charOffset);
    if (target == null) {
      return;
    }
    _compensating = true;
    controller.jumpToPage(target);
    _compensating = false;
  }

  /// The page under the viewport, reported to the page unless it is a placeholder or a jump is
  /// still to be applied.
  void _reportCurrentPage() {
    final PageController? controller = _controller;
    if (controller == null ||
        !controller.hasClients ||
        _restorePending ||
        // 页码还没补上时，此刻的页号指向的是「挪动前」的那一页：报出去会把会话带到别处。
        _pendingPageJump != 0) {
      return;
    }
    final int page = (controller.page ?? 0).round();
    final int position = page - (_leadingPending ? 1 : 0);
    if (position < 0 || position >= _pages.length) {
      return;
    }
    final _FlowPage flowPage = _pages[position];
    widget.onProgress(flowPage.index, flowPage.start);
  }

  /// Whether an explicit jump was asked for and has not been applied yet.
  bool get _restorePending {
    final ReaderFlowRestore? restore = widget.restore;

    return restore != null && restore.nonce != _appliedRestoreNonce;
  }

  /// Handles the page turning: the report and the write-out run after the frame.
  ///
  /// `PageView` reports the new page from a scroll notification, which can be dispatched while a
  /// viewport corrects its own pixels — a provider write there is a `markNeedsBuild during build`.
  void _onPageChanged(int page) {
    _settlePending = true;
    _scheduleFrame();
  }

  /// Freezes the window while the reader drags; the settle itself runs after the frame.
  bool _onNotification(ScrollNotification notification) {
    if (_compensating) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _frozen = _visible;
    }
    if (notification is ScrollEndNotification) {
      _settlePending = true;
      _scheduleFrame();
    }

    return false;
  }

  /// Rebuilds the rendered window around the anchor chapter and drops the far ones.
  void _reconcile() {
    final int anchorIndex = widget.anchorIndex;
    _window.retain(anchorIndex: anchorIndex);
    final List<ReaderFlowChapter> next = _window.sync(
      chapters: widget.chapters,
      anchorIndex: anchorIndex,
      bodies: widget.bodies,
    );
    if (next.isEmpty) {
      return;
    }
    setState(() {
      _applyStructure(next);
    });
  }

  /// Asks the page for [index]'s body, once per chapter.
  void _request(int index, {required bool isBefore}) {
    if (isBefore ? _requestedBefore == index : _requestedAfter == index) {
      return;
    }
    if (isBefore) {
      _requestedBefore = index;
    } else {
      _requestedAfter = index;
    }
    widget.onNeedChapter(index);
  }

  /// The chapter before the anchor that the window does not have yet, or `null`.
  int? get _beforeIndex => _missingNeighbour(-1);

  /// The chapter after the anchor that the window does not have yet, or `null`.
  int? get _afterIndex => _missingNeighbour(1);

  /// The anchor's neighbour [step] chapters away, when the window does not have it yet.
  ///
  /// 相邻章已经在窗口里时不该再要一章更远的：那一次抓取会在页面的预取窗口里立刻被裁掉，
  /// 纯属每帧重试的浪费。
  int? _missingNeighbour(int step) {
    if (_visible.isEmpty) {
      return null;
    }
    final int index = widget.anchorIndex + step;
    if (index < 0 || index >= widget.chapters.length) {
      return null;
    }
    final bool loaded = _visible.any(
      (ReaderFlowChapter chapter) => chapter.index == index,
    );

    return loaded ? null : index;
  }

  /// Whether the body of chapter [index] failed to load.
  bool _isFailed(int index) {
    if (index < 0 || index >= widget.chapters.length) {
      return false;
    }

    return widget.failed.contains(widget.chapters[index].url);
  }

  /// The highlight range of the chapter at [url], when the read-aloud sentence belongs to it.
  ({int start, int end})? _highlightOf(String url) {
    final ReaderFlowHighlight? highlight = widget.highlight;
    if (highlight == null || highlight.url != url) {
      return null;
    }

    return (start: highlight.start, end: highlight.end);
  }

  /// The widget of one page of the flow.
  Widget _page(BuildContext context, int page) {
    final int position = page - (_leadingPending ? 1 : 0);
    if (position < 0) {
      if (_beforeIndex case final int before) {
        return _pendingPage(before);
      }
    } else if (position < _pages.length) {
      final _FlowPage flowPage = _pages[position];

      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: readingText(
          body: flowPage.text,
          start: flowPage.start,
          end: flowPage.end,
          style: widget.style,
          highlightStyle: widget.highlightStyle,
          highlight: _highlightOf(flowPage.url),
        ),
      );
    } else if (position == _pages.length) {
      if (_afterIndex case final int after) {
        return _pendingPage(after);
      }
    }

    return _bookEnd(context);
  }

  /// A page that stands in for a chapter whose body is still on its way.
  Widget _pendingPage(int index) {
    return Center(
      child: ReaderChapterPendingStrip(
        isFailed: _isFailed(index),
        // 重试是读者主动要求：不再受「这一露面已经问过」的闸门限制。
        onRetry: () => widget.onNeedChapter(index),
      ),
    );
  }

  /// The last page of the book: there is nothing after it, and it says so.
  Widget _bookEnd(BuildContext context) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Text(
          AppLocalizations.of(context).readerLastChapter,
          style: tokens.typography.base.bodyLarge?.copyWith(
            color: widget.style.color,
          ),
        ),
      ),
    );
  }
}
