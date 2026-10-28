/// The continuous scroll body: the chapters in hand stacked in one vertical flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The measured height of one rendered chapter: its title and its body, separately.
typedef _Measure = ({double title, double body});

/// Renders the chapters in hand as **one** scrolling document
/// (`docs/dev/adr/0085-continuous-chapter-reading.md`).
///
/// Upstream Legado never stops at a chapter boundary: the previous chapter's tail, the current
/// chapter and the next chapter's head are one flow, so scrolling continues in either direction and
/// only the session's chapter changes. This widget is that flow for the vertically scrolling mode:
///
/// * the chapters are stacked in TOC order and the page's prefetch window fills the neighbours in;
/// * the top of the viewport is the **anchor** — it names the chapter the session is on and the
///   character offset it is at, and it is what keeps the reading position steady when a chapter is
///   added above or dropped from below;
/// * a neighbour that is not in hand yet appears as a [ReaderChapterPendingStrip] where it will
///   be, which is also what triggers the fetch (no "tap for the next chapter" dead end).
///
/// Two rules keep the flow from fighting the reader: structural changes wait while a drag is in
/// progress (a jump under the finger cancels the gesture), and the anchor is re-established after
/// every structural change by moving the offset by exactly the height that moved above it.
class ReaderScrollFlow extends StatefulWidget {
  /// Creates the flow; every chapter in [bodies] must be keyed by its TOC URL.
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

  /// Laid-out bodies in hand, keyed by chapter URL (the page's prefetch window).
  final Map<String, String> bodies;

  /// Chapters whose body could not be read, by chapter URL.
  final Set<String> failed;

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

  /// Called with a chapter index whose body the flow needs (a boundary, or a retry).
  final void Function(int index) onNeedChapter;

  @override
  State<ReaderScrollFlow> createState() => _ReaderScrollFlowState();
}

/// State of the scroll flow: the rendered chapters, their measured heights and the anchor.
class _ReaderScrollFlowState extends State<ReaderScrollFlow> {
  final ScrollController _scroll = ScrollController();
  final ReaderChapterWindow _window = ReaderChapterWindow();

  /// Measured heights of a chapter's title and body, keyed by chapter URL.
  ///
  /// Cached because the flow rebuilds on every progress write: re-measuring three chapters per
  /// frame would be the most expensive thing in the reader (C-PERF-1).
  final Map<
    String,
    ({int signature, int length, int titleLength, double title, double body})
  >
  _heights =
      <
        String,
        ({
          int signature,
          int length,
          int titleLength,
          double title,
          double body,
        })
      >{};

  /// Chapters currently rendered, contiguous and in TOC order.
  List<ReaderFlowChapter> _visible = const <ReaderFlowChapter>[];

  /// The rendered chapters frozen while a drag is in progress, or `null` when there is none.
  List<ReaderFlowChapter>? _frozen;

  /// The top of each visible chapter in content coordinates, from the last build.
  List<double> _tops = const <double>[];

  /// The measuring box of the last build: width, text scale and the box itself.
  double _width = 0;
  TextScaler _textScaler = TextScaler.noScaling;

  /// The chapter-title style and the space it takes above the body (ADR-0086 §决策 7).
  TextStyle _titleStyle = const TextStyle();
  double _titleSpacing = 0;

  /// The position the flow has to keep: the chapter at the top of the viewport and how far into it.
  ({int index, double fraction})? _anchor;

  /// The last scroll metrics handed over by a notification or a post-layout read.
  double _offset = 0;
  double _maxExtent = 0;
  double _viewportHeight = 0;

  /// The anchor to re-land on after the measuring box changed (a rotated screen), if any.
  ({int index, int charOffset})? _pendingReland;

  /// The restore nonce already applied; `-1` so a fresh flow always applies nonce 0 once.
  int _appliedRestoreNonce = -1;

  /// Whether a restore is waiting for the frame that can carry it.
  bool _restoreScheduled = false;

  /// Guards the flow's own offset jumps: their notifications are not reader scrolls.
  bool _compensating = false;

  /// The offset the rendered window change still owes the reader, applied after the frame.
  ///
  /// It cannot be applied while the tree is building or laying out: `jumpTo` dispatches a
  /// [ScrollNotification] that the app bar listens to, and marking a widget dirty there is illegal
  /// (it threw `_RenderLayoutBuilder was mutated in _RenderSingleChildViewport.performLayout`).
  double _pendingJump = 0;

  /// Whether the one post-frame pass of this frame is already scheduled.
  bool _frameScheduled = false;

  /// Whether the last notification of this frame ended a scroll (a settle).
  bool _settlePending = false;

  /// Whether the chapters below the anchor fill a viewport, so a chapter may sit above it.
  ///
  /// A shorter body cannot hold the anchor at the top of the screen: the content above would push
  /// it off and no scroll offset could compensate (there is nowhere to scroll to).
  bool _canHoldAbove = false;

  /// Whether the pending strip above / below the flow is on screen.
  bool _showBefore = false;
  bool _showAfter = false;

  /// The chapter each pending strip already asked for, so one fetch is one request.
  int? _requestedBefore;
  int? _requestedAfter;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderScrollFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 手指按着的时候不换结构：换结构要挪偏移，而挪偏移会取消这次手势。
    if (_frozen == null) {
      _applyStructure(
        _window.sync(
          chapters: widget.chapters,
          anchorIndex: _anchor?.index ?? widget.anchorIndex,
          bodies: widget.bodies,
        ),
      );
    }
  }

  /// The measuring signature: a change here invalidates every measured height.
  int get _signature => Object.hash(
    _width,
    widget.style,
    _textScaler.scale(1),
    _titleStyle,
    _titleSpacing,
  );

  /// The measured height of [chapter], title and padding included.
  double _heightOf(ReaderFlowChapter chapter) {
    final _Measure measure = _measureOf(chapter);

    return measure.title + measure.body;
  }

  /// Measures [chapter] once per style, width and text, and caches the result.
  _Measure _measureOf(ReaderFlowChapter chapter) {
    final int signature = _signature;
    final ({
      int signature,
      int length,
      int titleLength,
      double title,
      double body,
    })?
    cached = _heights[chapter.url];
    if (cached != null &&
        cached.signature == signature &&
        cached.length == chapter.text.length &&
        cached.titleLength == chapter.title.length) {
      return (title: cached.title, body: cached.body);
    }
    final double body = readerTextHeight(
      text: chapter.text,
      style: widget.style,
      width: _width,
      textScaler: _textScaler,
    );
    final double title = chapter.title.isEmpty
        ? 0
        : readerTextHeight(
                text: chapter.title,
                style: _titleStyle,
                width: _width,
                textScaler: _textScaler,
              ) +
              _titleSpacing;
    _heights[chapter.url] = (
      signature: signature,
      length: chapter.text.length,
      titleLength: chapter.title.length,
      title: title,
      body: body,
    );

    return (title: title, body: body);
  }

  /// The content-space top of every chapter in [chapters], the page margin included.
  List<double> _topsOf(List<ReaderFlowChapter> chapters) {
    final List<double> tops = <double>[];
    var top = widget.padding;
    for (final ReaderFlowChapter chapter in chapters) {
      tops.add(top);
      top += _heightOf(chapter);
    }

    return tops;
  }

  /// Replaces the rendered chapters, keeping the anchor where the reader sees it.
  void _applyStructure(List<ReaderFlowChapter> next) {
    // 锚点章的正文可能还没到（刚跳章）：空窗口会把正文抹掉，宁可先什么都不换。
    if (next.isEmpty) {
      return;
    }
    final int anchorIndex = _anchor?.index ?? widget.anchorIndex;
    final int anchorPosition = next.indexWhere(
      (ReaderFlowChapter chapter) => chapter.index == anchorIndex,
    );
    if (anchorPosition < 0) {
      // 锚点章不在新窗口里（换书 / 换源）：位置交给 restore 处理。
      _visible = next;
      _tops = _topsOf(next);

      return;
    }
    // 上一章只在「锚点章自己撑得满一屏」或「它已经在屏上」时才画。两条判据都只看章节与
    // 窗口，不看当前滚动位置：一旦把偏移也纳入条件，读者一边滑，上一章就会一会儿加进来、
    // 一会儿撤掉——正文看起来重复、位置也在跳。撑不满一屏的章节则根本不画上面（会把正文
    // 顶出屏幕，而可滚动范围不够补偿）。
    final bool holds =
        _fillsViewport(next, anchorPosition) || _alreadyAbove(anchorIndex);
    final List<ReaderFlowChapter> rendered = holds
        ? next
        : next.sublist(anchorPosition);
    if (_sameChapters(_visible, rendered)) {
      _visible = rendered;

      return;
    }
    final List<double> tops = _topsOf(rendered);
    final int before = _visible.indexWhere(
      (ReaderFlowChapter chapter) => chapter.index == anchorIndex,
    );
    final int after = rendered.indexWhere(
      (ReaderFlowChapter chapter) => chapter.index == anchorIndex,
    );
    final bool firstFill = _visible.isEmpty || _tops.length != _visible.length;
    final double oldTop = firstFill ? tops[after] : _tops[before];
    _visible = rendered;
    _tops = tops;
    if (firstFill || before < 0) {
      return;
    }
    // 锚点上方的内容高度变了多少，偏移就跟着挪多少：手指下的那行字一动不动。
    _pendingJump += tops[after] - oldTop;
    _scheduleFrame();
  }

  /// Whether the rendered window already starts before [anchorIndex].
  ///
  /// 已经在屏上的上一章不会因为换到下一章就被撤掉：撤掉要挪偏移，那是可见的一下跳。
  bool _alreadyAbove(int anchorIndex) =>
      _visible.isNotEmpty && _visible.first.index < anchorIndex;

  /// Whether the anchor chapter alone fills a viewport, so chapters may sit above it.
  ///
  /// A property of the chapter, never of the scroll offset: that is what keeps the above-region
  /// from appearing and disappearing while the reader scrolls.
  bool _fillsViewport(List<ReaderFlowChapter> chapters, int position) {
    if (position < 0 || position >= chapters.length) {
      return false;
    }

    return _heightOf(chapters[position]) >= _viewportHeight;
  }

  /// Whether the previous chapter is in hand but not on screen yet, while the reader is at the top.
  ///
  /// The previous chapter is only painted once the reader is close to the top: painting it earlier
  /// would shift the text under a reader who is deep inside the chapter, and there is nothing to
  /// gain from it.
  bool get _shouldPrepend {
    final ({int index, double fraction})? anchor = _anchor;
    if (_visible.isEmpty ||
        _offset > _viewportHeight ||
        !_canHoldAbove ||
        anchor == null) {
      return false;
    }
    final int index = anchor.index - 1;
    if (index < 0 || index >= widget.chapters.length) {
      return false;
    }
    if (_visible.first.index <= index) {
      return false;
    }

    return widget.bodies.containsKey(widget.chapters[index].url);
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

  /// The chapter at the top of the viewport for [offset], with the offset inside it.
  ({int index, int charOffset, double fraction})? _anchorAt(double offset) {
    if (_visible.isEmpty || _tops.length != _visible.length) {
      return null;
    }
    var position = _visible.length - 1;
    for (var index = 0; index < _visible.length; index++) {
      if (offset < _tops[index] + _heightOf(_visible[index])) {
        position = index;
        break;
      }
    }
    final ReaderFlowChapter chapter = _visible[position];
    final _Measure measure = _measureOf(chapter);
    final double body = measure.body;
    final double fraction = body <= 0
        ? 0
        : ((offset - _tops[position] - measure.title) / body).clamp(0.0, 1.0);

    return (
      index: chapter.index,
      charOffset: (fraction * chapter.text.length).round(),
      fraction: fraction,
    );
  }

  /// The content offset that puts character [charOffset] of chapter [index] at the viewport top.
  double? _offsetOf(int index, int charOffset) {
    final int position = _visible.indexWhere(
      (ReaderFlowChapter chapter) => chapter.index == index,
    );
    if (position < 0 || _tops.length != _visible.length) {
      return null;
    }
    final ReaderFlowChapter chapter = _visible[position];
    final _Measure measure = _measureOf(chapter);
    final double fraction = chapter.text.isEmpty
        ? 0
        : (charOffset / chapter.text.length).clamp(0.0, 1.0);

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
        final double measured = width < 0 ? 0 : width;
        final TextScaler textScaler = MediaQuery.textScalerOf(context);
        // 视口宽 / 字号变了：行高全变，偏移必须按锚点重算，否则旋转屏幕就跳到别处。
        final bool remeasured =
            measured != _width || textScaler.scale(1) != _textScaler.scale(1);
        _width = measured;
        _textScaler = textScaler;
        _viewportHeight = constraints.maxHeight;
        if (_visible.isEmpty) {
          // 第一帧才知道视口多高：窗口在这里才第一次落地（见 [_applyStructure] 的几何门槛）。
          _applyStructure(
            _window.sync(
              chapters: widget.chapters,
              anchorIndex: widget.anchorIndex,
              bodies: widget.bodies,
            ),
          );
        }
        _titleStyle =
            tokens.typography.base.titleMedium?.copyWith(
              color: widget.style.color,
            ) ??
            widget.style;
        _titleSpacing = tokens.spacing.xl;
        _tops = _topsOf(_visible);
        _canHoldAbove = _fillsViewport(
          _visible,
          _visible.indexWhere(
            (ReaderFlowChapter chapter) =>
                chapter.index == (_anchor?.index ?? widget.anchorIndex),
          ),
        );
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
                if (_canHoldAbove && _showBefore)
                  if (_beforeIndex case final int before)
                    ReaderChapterPendingStrip(
                      isFailed: _isFailed(before),
                      // 重试是读者主动要求：绕开「这一面已经问过」的闸门。
                      onRetry: () => widget.onNeedChapter(before),
                    ),
                for (final ReaderFlowChapter chapter in _visible) ...<Widget>[
                  // 章标题（ADR-0086 §决策 7）：连续滚动里没有它就分不出章节从哪开始。
                  if (chapter.title.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: _titleSpacing),
                      child: Text(
                        chapter.title,
                        style: _titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  readingText(
                    body: chapter.text,
                    style: widget.style,
                    highlightStyle: widget.highlightStyle,
                    highlight: _highlightOf(chapter),
                  ),
                ],
                if (_showAfter)
                  if (_afterIndex case final int after)
                    ReaderChapterPendingStrip(
                      isFailed: _isFailed(after),
                      onRetry: () => widget.onNeedChapter(after),
                    ),
                if (_afterIndex == null && _visible.isNotEmpty)
                  _bookEnd(context),
              ],
            ),
          ),
        );
      },
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
      _offset = _scroll.position.pixels;
      _maxExtent = _scroll.position.maxScrollExtent;
      _viewportHeight = _scroll.position.viewportDimension;
      _reland();
      _report();
      final bool settle = _settlePending;
      _settlePending = false;
      if (settle) {
        final ({int index, int charOffset, double fraction})? anchor =
            _anchorAt(_offset);
        if (anchor != null) {
          widget.onSettled(anchor.index, anchor.charOffset);
        }
        _frozen = null;
        // 手势结束：把冻结的窗口换成当前该显示的那一份，并顺手丢掉远处已渲染的章。
        _reconcile();
      }
      if (_shouldPrepend) {
        _reconcile();
      }
      _updateStrips();
    });
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
    final int position = _visible.indexWhere(
      (ReaderFlowChapter chapter) => chapter.index == anchor.index,
    );
    if (position < 0) {
      return null;
    }

    return (
      index: anchor.index,
      charOffset: (anchor.fraction * _visible[position].text.length).round(),
    );
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
    _maxExtent = notification.metrics.maxScrollExtent;
    _viewportHeight = notification.metrics.viewportDimension;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      // 手指按着的时候不换结构：换结构要挪偏移，而挪偏移会取消这次手势。
      _frozen = _visible;
    }
    if (notification is ScrollEndNotification) {
      _settlePending = true;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _scheduleFrame();
    }

    return false;
  }

  /// Rebuilds the rendered window around the anchor and drops the chapters far from it.
  ///
  /// Runs after a settle, where a window change is cheap: the offset it owes the reader is applied
  /// in the same pass, so no drag is cancelled.
  void _reconcile() {
    final int anchorIndex = _anchor?.index ?? widget.anchorIndex;
    _window.retain(anchorIndex: anchorIndex);
    final List<ReaderFlowChapter> next = _window.sync(
      chapters: widget.chapters,
      anchorIndex: anchorIndex,
      bodies: widget.bodies,
    );
    if (next.isEmpty) {
      // 锚点章的正文不在手里（页面已把它的预取窗口挪走）：这一帧什么都不换。
      return;
    }
    setState(() {
      _applyStructure(next);
    });
  }

  /// Shows or hides the pending strips and asks for the chapters they stand for.
  void _updateStrips() {
    final int? before = _beforeIndex;
    final int? after = _afterIndex;
    // 一屏之内到边就开始接力：等真滑到尽头再抓，读者一定会看到一次空白。
    final bool showBefore =
        before != null && _canHoldAbove && _offset <= _viewportHeight;
    final bool showAfter =
        after != null && _maxExtent - _offset <= _viewportHeight;
    if (showBefore != _showBefore || showAfter != _showAfter) {
      setState(() {
        _showBefore = showBefore;
        _showAfter = showAfter;
      });
    }
    if (showBefore) {
      _request(before, isBefore: true);
    }
    if (showAfter) {
      _request(after, isBefore: false);
    }
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
    final int index = (_anchor?.index ?? widget.anchorIndex) + step;
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

  /// The highlight range of [chapter], when the read-aloud sentence belongs to it.
  ({int start, int end})? _highlightOf(ReaderFlowChapter chapter) {
    final ReaderFlowHighlight? highlight = widget.highlight;
    if (highlight == null || highlight.url != chapter.url) {
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
