/// The continuous scroll body: the chapters in hand stacked in one vertical flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The measured height of one rendered slot: its title, then its body (or loading block).
typedef _Measure = ({double title, double body});

/// Renders the chapters in hand as **one** scrolling document
/// (`docs/dev/adr/0085-continuous-chapter-reading.md`).
///
/// Upstream Legado never stops at a chapter boundary: the current chapter and the next one are one
/// flow, so scrolling continues across the boundary and only the session's chapter changes. This
/// widget is that flow for the vertically scrolling mode:
///
/// * **the slots are derived** from the session chapter (`anchor - 1`, `anchor`, `anchor + 1`) by
///   [ReaderChapterSlots] — never accumulated — so a chapter cannot be rendered twice;
/// * every slot prints its **title**, and a slot whose body has not arrived shows a
///   [ReaderChapterPendingStrip] under that title instead of text (ADR-0087 §决策 1);
/// * the top of the viewport is the **anchor**: it names the chapter the session is on and the
///   character offset it is at, and it is what a structural change has to keep still.
///
/// Three rules keep it from fighting the reader:
///
/// 1. structure changes are compensated by the height that moved above the anchor, applied in the
///    frame's post-frame pass (never during build or layout, where `jumpTo` would trip the app
///    bar's scroll listener);
/// 2. no structure changes at all while a drag is in progress (a jump cancels the gesture);
/// 3. the chapter above the anchor is included only when the anchor chapter fills a viewport — a
///    property of the chapter, not of the scroll offset, so the above-region never appears and
///    disappears while scrolling.
class ReaderScrollFlow extends StatefulWidget {
  /// Creates the flow; [bodies] is keyed by chapter **index** (see [ReaderChapterSlots]).
  const ReaderScrollFlow({
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

  /// An explicit jump the flow must apply, or `null` while the reader scrolls on its own.
  final ReaderFlowRestore? restore;

  /// The sentence being read aloud, when it belongs to one of the rendered chapters.
  final ReaderFlowHighlight? highlight;

  /// The body text style (measured and painted with the very same value).
  final TextStyle style;

  /// The style of the sentence being read aloud (ADR-0062 §决策 5).
  final TextStyle highlightStyle;

  /// The page margin, applied around the whole flow.
  final double padding;

  /// Called while the reader scrolls, with the chapter at the top of the viewport.
  final void Function(int index, int charOffset) onProgress;

  /// Called when a scroll settles, so the page can write the position out.
  final void Function(int index, int charOffset) onSettled;

  /// Called with a chapter index whose body the flow needs (a loading slot, or a retry).
  final void Function(int index) onNeedChapter;

  @override
  State<ReaderScrollFlow> createState() => _ReaderScrollFlowState();
}

/// State of the scroll flow: the rendered slots, their measured heights and the anchor.
class _ReaderScrollFlowState extends State<ReaderScrollFlow> {
  final ScrollController _scroll = ScrollController();

  /// Measured heights of a slot's title and body, keyed by chapter index.
  ///
  /// Cached because the flow rebuilds on every progress write: re-measuring three chapters per
  /// frame would be the most expensive thing in the reader (C-PERF-1).
  final Map<
    int,
    ({int signature, int length, int titleLength, _Measure measure})
  >
  _heights = <int, ({int signature, int length, int titleLength, _Measure measure})>{};

  /// The slots currently rendered, in reading order.
  List<ReaderFlowChapter> _slots = const <ReaderFlowChapter>[];

  /// The top of each slot in content coordinates, from the last build.
  List<double> _tops = const <double>[];

  /// The measuring box of the last build: width and text scale.
  double _width = 0;
  TextScaler _textScaler = TextScaler.noScaling;

  /// The chapter-title style and the space it takes above its body (ADR-0086 §决策 7).
  TextStyle _titleStyle = const TextStyle();
  double _titleSpacing = 0;

  /// The height of a loading block, measured once per build from the theme's spacing.
  double _loadingHeight = 0;

  /// The position the flow has to keep: the chapter at the top of the viewport, how far into it,
  /// and whether that chapter's body is on screen at all.
  ({int index, double fraction})? _anchor;

  /// The last scroll metrics handed over by a notification or a post-layout read.
  double _offset = 0;
  double _viewportHeight = 0;

  /// Whether the slots still have to be rebuilt when the drag ends.
  bool _rebuildPending = false;

  /// The offset the rendered window change still owes the reader, applied after the frame.
  ///
  /// It cannot be applied while the tree is building or laying out: `jumpTo` dispatches a
  /// [ScrollNotification] that the app bar listens to, and marking a widget dirty there is illegal
  /// (it threw `_RenderLayoutBuilder was mutated in _RenderSingleChildViewport.performLayout`).
  double _pendingJump = 0;

  /// The anchor to re-land on after the measuring box changed (a rotated screen), if any.
  ({int index, int charOffset})? _pendingReland;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether a restore is waiting for the frame that can carry it.
  bool _restoreScheduled = false;

  /// Guards the flow's own offset jumps: their notifications are not reader scrolls.
  bool _compensating = false;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last notification of this frame ended a scroll (a settle).
  bool _settlePending = false;

  /// The chapters this frame's slots should not repeat a request for.
  final Set<int> _requested = <int>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderScrollFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 手指按着的时候不换结构：换结构要挪偏移，而挪偏移会取消这次手势。
    if (!_frozen) {
      _rebuildSlots();
    }
  }

  /// Whether a drag is in progress (structure changes wait for it to end).
  bool _frozen = false;

  /// The measuring signature: a change here invalidates every measured height.
  int get _signature => Object.hash(
    _width,
    widget.style,
    _textScaler.scale(1),
    _titleStyle,
    _titleSpacing,
    _loadingHeight,
  );

  /// The measured height of [chapter]'s title and body.
  _Measure _measureOf(ReaderFlowChapter chapter) {
    final int signature = _signature;
    final int length = chapter.text?.length ?? 0;
    final int titleLength = chapter.title.length;
    final ({int signature, int length, int titleLength, _Measure measure})? cached =
        _heights[chapter.index];
    if (cached != null &&
        cached.signature == signature &&
        cached.length == length &&
        cached.titleLength == titleLength) {
      return cached.measure;
    }
    final double body = switch (chapter.text) {
      final String text => readerTextHeight(
        text: text,
        style: widget.style,
        width: _width,
        textScaler: _textScaler,
      ),
      // 正文还没到：这段就是一个「正在加载」方块，高度按方块量。
      null => _loadingHeight,
    };
    final double title = titleLength == 0
        ? 0
        : readerTextHeight(
                text: chapter.title,
                style: _titleStyle,
                width: _width,
                textScaler: _textScaler,
              ) +
              _titleSpacing;
    final _Measure measure = (title: title, body: body);
    _heights[chapter.index] = (
      signature: signature,
      length: length,
      titleLength: titleLength,
      measure: measure,
    );

    return measure;
  }

  /// The content-space top of every slot, the page margin included.
  List<double> _topsOf(List<ReaderFlowChapter> slots) {
    final List<double> tops = <double>[];
    var top = widget.padding;
    for (final ReaderFlowChapter slot in slots) {
      tops.add(top);
      final _Measure measure = _measureOf(slot);
      top += measure.title + measure.body;
    }

    return tops;
  }

  /// Renews the rendered slots from the session chapter, keeping the anchor where the reader sees it.
  void _rebuildSlots() {
    final List<ReaderFlowChapter> next = ReaderChapterSlots.of(
      chapters: widget.chapters,
      anchorIndex: widget.anchorIndex,
      bodies: widget.bodies,
      includePrevious: _anchorFillsViewport(widget.anchorIndex),
    );
    if (next.isEmpty) {
      return;
    }
    final List<double> nextTops = _topsOf(next);
    if (_sameSlots(_slots, next) && _sameTops(_tops, nextTops)) {
      // 批次与高度都没变：什么都不用做（这条路径每帧都会走）。
      return;
    }
    // 锚点上方的高度变了多少，偏移就跟着挪多少：手指下的那行字一动不动。
    final double? delta = _deltaOf(next, nextTops);
    _slots = next;
    _tops = nextTops;
    if (delta == null || delta == 0) {
      return;
    }
    _pendingJump += delta;
    _scheduleFrame();
  }

  /// The height change of everything above the anchor, when the anchor is in both slot lists.
  double? _deltaOf(List<ReaderFlowChapter> next, List<double> nextTops) {
    final ({int index, double fraction})? anchor = _anchor;
    if (anchor == null || _tops.length != _slots.length) {
      return null;
    }
    final int before = _indexOfSlot(_slots, anchor.index);
    final int after = _indexOfSlot(next, anchor.index);
    if (before < 0 || after < 0) {
      return null;
    }

    return nextTops[after] - _tops[before];
  }

  /// Where [index] sits in [slots], or `-1`.
  int _indexOfSlot(List<ReaderFlowChapter> slots, int index) {
    for (var position = 0; position < slots.length; position++) {
      if (slots[position].index == index) {
        return position;
      }
    }

    return -1;
  }

  /// Whether [a] and [b] are the same chapters with the same bodies.
  bool _sameSlots(List<ReaderFlowChapter> a, List<ReaderFlowChapter> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var position = 0; position < a.length; position++) {
      if (a[position].index != b[position].index ||
          a[position].title != b[position].title ||
          a[position].text?.length != b[position].text?.length) {
        return false;
      }
    }

    return true;
  }

  /// Whether two measured top lists agree.
  bool _sameTops(List<double> a, List<double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var position = 0; position < a.length; position++) {
      if (a[position] != b[position]) {
        return false;
      }
    }

    return true;
  }

  /// Whether the anchor chapter alone fills a viewport, so chapters may sit above it.
  ///
  /// A property of the chapter, never of the scroll offset: that is what keeps the above-region
  /// from appearing and disappearing while the reader scrolls.
  bool _anchorFillsViewport(int anchorIndex) {
    if (anchorIndex < 0 || anchorIndex >= widget.chapters.length) {
      return false;
    }
    final String? body = widget.bodies[anchorIndex];
    if (body == null || _width <= 0 || _viewportHeight <= 0) {
      // 正文或视口还没量出来时不画上一章：等它到了再按真实高度判断。
      return false;
    }
    final double bodyHeight = readerTextHeight(
      text: body,
      style: widget.style,
      width: _width,
      textScaler: _textScaler,
    );

    return bodyHeight >= _viewportHeight;
  }

  /// Applies the offset the window change owes the reader, after the frame.
  void _applyPendingJump() {
    final double delta = _pendingJump;
    _pendingJump = 0;
    if (delta == 0 || !_scroll.hasClients) {
      return;
    }
    final double max = _scroll.position.maxScrollExtent;
    final double target = (_scroll.offset + delta).clamp(0, max <= 0 ? 0 : max);
    if (target == _scroll.offset) {
      return;
    }
    _compensating = true;
    _scroll.jumpTo(target);
    _compensating = false;
  }

  /// The slot at the top of the viewport for [offset], with the offset inside its body.
  ({int index, int charOffset, double fraction})? _anchorAt(double offset) {
    if (_slots.isEmpty || _tops.length != _slots.length) {
      return null;
    }
    var position = _slots.length - 1;
    for (var candidate = 0; candidate < _slots.length; candidate++) {
      final _Measure measure = _measureOf(_slots[candidate]);
      if (offset < _tops[candidate] + measure.title + measure.body) {
        position = candidate;
        break;
      }
    }
    final ReaderFlowChapter slot = _slots[position];
    final _Measure measure = _measureOf(slot);
    final String? body = slot.text;
    if (body == null || body.isEmpty || measure.body <= 0) {
      return (index: slot.index, charOffset: 0, fraction: 0);
    }
    final double fraction =
        ((offset - _tops[position] - measure.title) / measure.body).clamp(
          0.0,
          1.0,
        );

    return (
      index: slot.index,
      charOffset: (fraction * body.length).round(),
      fraction: fraction,
    );
  }

  /// The content offset that puts character [charOffset] of chapter [index] at the viewport top.
  double? _offsetOf(int index, int charOffset) {
    final int position = _indexOfSlot(_slots, index);
    if (position < 0 || _tops.length != _slots.length) {
      return null;
    }
    final ReaderFlowChapter slot = _slots[position];
    final _Measure measure = _measureOf(slot);
    final String? body = slot.text;
    final double fraction = body == null || body.isEmpty
        ? 0
        : (charOffset / body.length).clamp(0.0, 1.0);

    return _tops[position] + measure.title + fraction * measure.body;
  }

  /// Remembers and reports the anchor for the current offset.
  void _report({bool notify = true}) {
    // 定位还没落地时不报也不收锚点：那时视口停在上章的尾巴上，收下来会把窗口往回拽，
    // 报出去会把会话往回顶。
    if (_restorePending) {
      return;
    }
    final ({int index, int charOffset, double fraction})? anchor = _anchorAt(
      _offset,
    );
    if (anchor == null) {
      return;
    }
    _anchor = (index: anchor.index, fraction: anchor.fraction);
    if (notify) {
      widget.onProgress(anchor.index, anchor.charOffset);
    }
  }

  /// Whether an explicit jump was asked for and has not been applied yet.
  bool get _restorePending {
    final ReaderFlowRestore? restore = widget.restore;

    return restore != null && restore.nonce != _appliedRestoreNonce;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final M3ETheme tokens = context.m3e;
        final double width = constraints.maxWidth - 2 * widget.padding;
        final TextScaler textScaler = MediaQuery.textScalerOf(context);
        // 视口宽 / 字号变了：行高全变，偏移必须按锚点重算，否则旋转屏幕就跳到别处。
        final bool remeasured =
            width != _width || textScaler.scale(1) != _textScaler.scale(1);
        _width = width < 0 ? 0 : width;
        _textScaler = textScaler;
        _viewportHeight = constraints.maxHeight;
        _titleStyle =
            tokens.typography.base.titleMedium?.copyWith(
              color: widget.style.color,
            ) ??
            widget.style;
        _titleSpacing = tokens.spacing.xl;
        // 一行式加载块的最小合手高度：16dp 指示器 + 文案，留一点上下气口。
        _loadingHeight = tokens.spacing.xxl + tokens.spacing.lg;
        if (_slots.isEmpty) {
          _rebuildSlots();
        }
        if (remeasured) {
          _pendingReland = _anchorCharOf(_anchor);
        }
        _scheduleRestore();
        _scheduleFrame();

        return NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.all(widget.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final ReaderFlowChapter slot in _slots)
                  _slotOf(context, slot, tokens),
                if (_isLastChapter) _bookEnd(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Whether the last slot is the last chapter of the book.
  bool get _isLastChapter =>
      _slots.isNotEmpty && _slots.last.index == widget.chapters.length - 1;

  /// One slot: the chapter title, then its body or the block that stands in for it.
  Widget _slotOf(
    BuildContext context,
    ReaderFlowChapter slot,
    M3ETheme tokens,
  ) {
    final String? body = slot.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (slot.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: _titleSpacing),
            child: Text(
              slot.title,
              style: _titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (body == null)
          SizedBox(
            height: _loadingHeight,
            child: Center(
              child: ReaderChapterPendingStrip(
                isFailed: widget.failed.contains(slot.index),
                // 重试是读者主动要求：绕开「这一刻已经问过」的闸门。
                onRetry: () => widget.onNeedChapter(slot.index),
              ),
            ),
          )
        else
          readingText(
            body: body,
            style: widget.style,
            highlightStyle: widget.highlightStyle,
            highlight: _highlightOf(slot),
          ),
      ],
    );
  }

  /// Schedules the explicit jump once the frame that can measure it has been laid out.
  void _scheduleRestore() {
    final ReaderFlowRestore? restore = widget.restore;
    if (restore == null ||
        restore.nonce == _appliedRestoreNonce ||
        _restoreScheduled) {
      return;
    }
    final double? target = _offsetOf(restore.index, restore.charOffset);
    if (target == null) {
      // 目标章的正文还在路上：等它到手后这次 build 会再排一次。
      return;
    }
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      _appliedRestoreNonce = restore.nonce;
      final double max = _scroll.position.maxScrollExtent;
      final double clamped = target.clamp(0, max <= 0 ? 0 : max);
      _compensating = true;
      _scroll.jumpTo(clamped);
      _compensating = false;
      _offset = clamped;
      _report();
    });
  }

  /// Schedules this frame's bookkeeping, once.
  ///
  /// Everything that touches the scroll position or a provider runs here rather than in `build`,
  /// `didUpdateWidget` or a scroll notification: those can run inside another widget's layout, and
  /// both `jumpTo` and a provider write mark widgets dirty.
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
      if (!_scroll.hasClients) {
        return;
      }
      _viewportHeight = _scroll.position.viewportDimension;
      if (_rebuildPending) {
        // 拖动手势结束时才走到这里：窗口按当前锚点重新取一次。
        _rebuildPending = false;
        _rebuildSlots();
        _applyPendingJump();
      }
      _offset = _scroll.position.pixels;
      _reland();
      _report();
      _requestMissingBodies();
      final bool settle = _settlePending;
      _settlePending = false;
      if (settle) {
        final ({int index, int charOffset, double fraction})? anchor = _anchorAt(
          _offset,
        );
        if (anchor != null) {
          widget.onSettled(anchor.index, anchor.charOffset);
        }
      }
    });
  }

  /// Asks for the body of every slot that has none, once per chapter.
  void _requestMissingBodies() {
    for (final ReaderFlowChapter slot in _slots) {
      if (slot.text != null || !_requested.add(slot.index)) {
        continue;
      }
      widget.onNeedChapter(slot.index);
    }
  }

  /// Puts the anchor back at the viewport top after the text was re-measured.
  void _reland() {
    final ({int index, int charOffset})? pending = _pendingReland;
    if (pending == null) {
      return;
    }
    _pendingReland = null;
    final double? target = _offsetOf(pending.index, pending.charOffset);
    if (target == null || !_scroll.hasClients) {
      return;
    }
    final double max = _scroll.position.maxScrollExtent;
    final double clamped = target.clamp(0, max <= 0 ? 0 : max);
    _compensating = true;
    _scroll.jumpTo(clamped);
    _compensating = false;
    _offset = clamped;
  }

  /// The character offset the anchor stands for, when the chapter is still rendered.
  ({int index, int charOffset})? _anchorCharOf(
    ({int index, double fraction})? anchor,
  ) {
    if (anchor == null) {
      return null;
    }
    final int position = _indexOfSlot(_slots, anchor.index);
    if (position < 0) {
      return null;
    }
    final String? body = _slots[position].text;
    if (body == null) {
      return null;
    }

    return (index: anchor.index, charOffset: (anchor.fraction * body.length).round());
  }

  /// Collects the scroll metrics and schedules the frame's bookkeeping.
  ///
  /// Nothing is mutated here: a notification can be dispatched *during* layout (a viewport that
  /// corrects its own pixels), and a rebuild from that point on is an assertion.
  bool _onNotification(ScrollNotification notification) {
    if (_compensating) {
      return false;
    }
    _offset = notification.metrics.pixels;
    _viewportHeight = notification.metrics.viewportDimension;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _frozen = true;
    }
    if (notification is ScrollEndNotification) {
      _settlePending = true;
      _rebuildPending = true;
      _frozen = false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _scheduleFrame();
    }

    return false;
  }

  /// The highlight range of [slot], when the read-aloud sentence belongs to it.
  ({int start, int end})? _highlightOf(ReaderFlowChapter slot) {
    final ReaderFlowHighlight? highlight = widget.highlight;
    if (highlight == null || highlight.url != slot.url || slot.text == null) {
      return null;
    }

    return (start: highlight.start, end: highlight.end);
  }

  /// The end of the book, shown once the last chapter is exhausted.
  Widget _bookEnd(BuildContext context) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.xl),
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
}
