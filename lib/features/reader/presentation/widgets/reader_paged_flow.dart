/// The paged body: pages of the chapters in hand, turned across chapter boundaries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// One page of the flow: a window `[start, end)` of the entry's body, or its loading page.
typedef _FlowPage = ({
  int index,
  String url,
  String? text,
  String title,
  int start,
  int end,
});

/// Renders the chapters in hand as pages that keep turning across chapter boundaries
/// (`docs/dev/adr/0085-continuous-chapter-reading.md`).
///
/// The slots are derived from the session chapter (`anchor - 1`, `anchor`, `anchor + 1`) by
/// [ReaderChapterSlots], so a chapter is never rendered twice; a slot without a body becomes a
/// single titled loading page instead of vanishing, which is what keeps "the next chapter" a page
/// away rather than a fetch away.
class ReaderPagedFlow extends StatefulWidget {
  /// Creates the flow; [bodies] is keyed by chapter **index**.
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

  /// Laid-out bodies in hand, keyed by chapter index.
  final Map<int, String> bodies;

  /// Chapter indexes whose body could not be read.
  final Set<int> failed;

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

  /// Called with a chapter index whose body the flow needs (a loading page, or a retry).
  final void Function(int index) onNeedChapter;

  @override
  State<ReaderPagedFlow> createState() => _ReaderPagedFlowState();
}

/// State of the paged flow: the measured entries, the flattened pages and the controller.
class _ReaderPagedFlowState extends State<ReaderPagedFlow> {
  /// Measured page starts, keyed by chapter index.
  final Map<int, ({int signature, List<int> starts})> _starts =
      <int, ({int signature, List<int> starts})>{};

  /// The rendered chapters, in reading order.
  List<ReaderFlowChapter> _visible = const <ReaderFlowChapter>[];

  /// Every page of [_visible], in reading order (a loading chapter takes one page).
  List<_FlowPage> _pages = const <_FlowPage>[];

  /// The measuring box of the last build.
  Size _size = Size.zero;

  /// The text scale of the last build, kept so pages can also be measured outside `build`.
  TextScaler _textScaler = TextScaler.noScaling;

  /// How many pages sit before the anchor chapter.
  ///
  /// This is what keeps the reader on the same text when pages are added or dropped above it.
  int _leadingPages = 0;

  /// The pages the rendered window still owes the reader, applied after the frame.
  int _pendingPageJump = 0;

  PageController? _controller;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether a restore is waiting for the frame that can carry it.
  bool _restoreScheduled = false;

  /// Guards the flow's own page jumps: their notifications are not reader turns.
  bool _compensating = false;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last notification of this frame ended a drag.
  bool _settlePending = false;

  /// Whether the slots were rebuilt during the current drag.
  bool _frozen = false;

  /// The chapters this flow already asked a body for.
  final Set<int> _requested = <int>{};

  /// Whether the slots still have to be rebuilt when the drag ends.
  bool _rebuildPending = false;

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
    if (!_frozen) {
      _applySlots(_slots());
    }
  }

  /// The slots this frame renders: the anchor and its neighbours.
  List<ReaderFlowChapter> _slots() => ReaderChapterSlots.of(
    chapters: widget.chapters,
    anchorIndex: widget.anchorIndex,
    bodies: widget.bodies,
    includePrevious: true,
  );

  /// The measuring signature: a change here invalidates every measured page list.
  int get _signature =>
      Object.hash(_size.width, _size.height, widget.style, _textScaler.scale(1));

  /// The page starts of [chapter], measured once per size, style and text scale.
  List<int> _startsOf(ReaderFlowChapter chapter) {
    final String text = chapter.text ?? '';
    final int signature = _signature;
    final ({int signature, List<int> starts})? cached = _starts[chapter.index];
    if (cached != null && cached.signature == signature) {
      return cached.starts;
    }
    final List<int> starts = text.isEmpty
        ? const <int>[0]
        : readerPageStarts(
            text: text,
            style: widget.style,
            size: _size,
            textScaler: _textScaler,
          );
    _starts[chapter.index] = (signature: signature, starts: starts);

    return starts;
  }

  /// Replaces the rendered chapters, keeping the page the reader is on.
  void _applySlots(List<ReaderFlowChapter> next) {
    if (next.isEmpty) {
      return;
    }
    if (_sameSlots(_visible, next)) {
      _visible = next;
      // 同一批章，只是正文到了：页表要按新正文重排（页码仍按上面的补法处理）。
      _measurePages();

      return;
    }
    _visible = next;
    _measurePages();
  }

  /// Whether [a] and [b] are the same chapters with the same bodies.
  bool _sameSlots(List<ReaderFlowChapter> a, List<ReaderFlowChapter> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var position = 0; position < a.length; position++) {
      if (a[position].index != b[position].index ||
          a[position].text?.length != b[position].text?.length) {
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
    final List<_FlowPage> pages = <_FlowPage>[];
    var anchorLeading = 0;
    for (final ReaderFlowChapter chapter in _visible) {
      final String? text = chapter.text;
      if (text == null) {
        // 正文还没到：这一章占一页（标题 + 正在加载），读者能翻进来看到它在路上。
        if (chapter.index < widget.anchorIndex) {
          anchorLeading++;
        }
        pages.add((
          index: chapter.index,
          url: chapter.url,
          text: null,
          title: chapter.title,
          start: 0,
          end: 0,
        ));

        continue;
      }
      final List<int> starts = _startsOf(chapter);
      if (chapter.index < widget.anchorIndex) {
        anchorLeading += starts.length;
      }
      for (var page = 0; page < starts.length; page++) {
        pages.add((
          index: chapter.index,
          url: chapter.url,
          text: text,
          title: chapter.title,
          start: starts[page],
          end: page + 1 < starts.length ? starts[page + 1] : text.length,
        ));
      }
    }
    final int added = anchorLeading - _leadingPages;
    _pages = pages;
    _leadingPages = anchorLeading;
    if (compensate && added != 0) {
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
            _visible = _slots();
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
              : _pages.length + (_isLastChapter ? 1 : 0);
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

  /// Whether the last rendered chapter is the book's last chapter.
  bool get _isLastChapter =>
      _visible.isNotEmpty &&
      _visible.last.index == widget.chapters.length - 1;

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

    return found < 0 ? null : found;
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
      if (_rebuildPending) {
        _rebuildPending = false;
        _applySlots(_slots());
      }
      _applyPendingJump();
      final PageController? controller = _controller;
      if (controller == null || !controller.hasClients) {
        return;
      }
      _reland(controller);
      _requestMissingBodies();
      _reportCurrentPage();
      final bool settle = _settlePending;
      _settlePending = false;
      if (settle) {
        final _FlowPage? page = _currentPage();
        if (page != null) {
          widget.onSettled(page.index, page.start);
        }
      }
    });
  }

  /// Asks for the body of every rendered chapter that has none, once per chapter.
  void _requestMissingBodies() {
    for (final ReaderFlowChapter chapter in _visible) {
      if (chapter.text != null || !_requested.add(chapter.index)) {
        continue;
      }
      widget.onNeedChapter(chapter.index);
    }
  }

  /// The page the viewport shows, or `null` on the end page.
  _FlowPage? _currentPage() {
    final PageController? controller = _controller;
    if (controller == null || !controller.hasClients) {
      return null;
    }
    final int position = (controller.page ?? 0).round();
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

  /// The page under the viewport, reported to the page unless a jump is still to be applied.
  void _reportCurrentPage() {
    if (_restorePending || _pendingPageJump != 0) {
      return;
    }
    final _FlowPage? page = _currentPage();
    if (page == null) {
      return;
    }
    widget.onProgress(page.index, page.start);
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
      _frozen = true;
    }
    if (notification is ScrollEndNotification) {
      _settlePending = true;
      _rebuildPending = true;
      _frozen = false;
      _scheduleFrame();
    }

    return false;
  }

  /// The widget of one page of the flow.
  Widget _page(BuildContext context, int page) {
    if (page < 0 || page >= _pages.length) {
      return _bookEnd(context);
    }
    final _FlowPage flowPage = _pages[page];
    final String? text = flowPage.text;
    if (text == null) {
      return _pendingPage(context, flowPage);
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: readingText(
        body: text,
        start: flowPage.start,
        end: flowPage.end,
        style: widget.style,
        highlightStyle: widget.highlightStyle,
        highlight: _highlightOf(flowPage.url),
      ),
    );
  }

  /// A page that stands in for a chapter whose body is still on its way.
  ///
  /// It carries the chapter's own title, so the reader knows which chapter is loading.
  Widget _pendingPage(BuildContext context, _FlowPage page) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (page.title.isNotEmpty)
            Text(
              page.title,
              style: tokens.typography.base.titleMedium?.copyWith(
                color: widget.style.color,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          ReaderChapterPendingStrip(
            isFailed: widget.failed.contains(page.index),
            // 重试是读者主动要求：不再受「这一面已经问过」的闸门限制。
            onRetry: () => widget.onNeedChapter(page.index),
          ),
        ],
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

  /// The highlight range of the chapter at [url], when the read-aloud sentence belongs to it.
  ({int start, int end})? _highlightOf(String url) {
    final ReaderFlowHighlight? highlight = widget.highlight;
    if (highlight == null || highlight.url != url) {
      return null;
    }

    return (start: highlight.start, end: highlight.end);
  }
}
