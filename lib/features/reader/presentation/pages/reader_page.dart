import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/manga_queries.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/pages/manga_reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_source_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_toc_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Reads one book: the chapter body in the middle, the chapter list and the reading settings
/// around it (`docs/dev/roadmap.md` 5.3)。
///
/// Three things are worth knowing before reading the code:
///
/// * **the session owns the position** (`ReaderSession`): this page only turns scroll / page
///   positions into the estimated character offset of ADR-0044 §决策 4 and asks the session to
///   remember it;
/// * **the store is captured in `initState`**: the last write happens in `dispose`, where reading a
///   provider would be unsafe, so the port is taken once while the widget is alive;
/// * **the two page modes share everything but the body widget**: the same chapter, the same
///   restore offset, the same save path — so switching modes mid-chapter does not lose the place.
class ReaderPage extends ConsumerStatefulWidget {
  /// Creates the page for [book], optionally starting at [chapterUrl].
  const ReaderPage({required this.book, this.chapterUrl, super.key});

  /// The book being read.
  final ReaderBook book;

  /// The chapter to open, or `null` to resume where the reader stopped.
  ///
  /// A concrete URL wins over the stored position: tapping a chapter row in the detail page must
  /// open **that** chapter, not the last one read (ADR-0044 §决策 2).
  final String? chapterUrl;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

/// State of the reader page: the scroll controller, the save bookkeeping and the last position.
class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ScrollController _scroll = ScrollController();

  /// The book currently open. It starts as the route's book and **changes** on a source switch:
  /// every provider below is keyed by it, so a new value naturally re-reads the new source
  /// (ADR-0051 §决策 3) — no navigation, no flash, and the reader stays where it was.
  late ReaderBook _book = widget.book;

  /// The progress port, captured in `initState` so `dispose` may still write.
  ReadingProgressStore? _store;

  /// The chapter whose restore offset was already applied (the page restores once per chapter).
  String? _restoredChapterUrl;

  /// Whether the chapter the route asked for was already opened.
  bool _appliedStartChapter = false;

  /// The last position the page saw, used by the `dispose` write.
  int _lastIndex = 0;
  int _lastOffset = 0;
  List<ReadingChapter> _chapters = const <ReadingChapter>[];

  /// Whether the chrome (app bar + tool bar) is shown (ADR-0051 §决策 1).
  ///
  /// It starts **hidden**: a reader that opens with a toolbar is a reader that never gets out of
  /// the way. A tap in the middle third brings it back.
  bool _chromeVisible = false;

  /// Counts down while the chrome is shown; every interaction restarts it (4 s, §决策 1).
  Timer? _chromeTimer;

  /// The dimming overlay's opacity, 0..1 (1 = no dimming). App-level, not system brightness.
  double _brightness = 1;

  /// The session the last build saw, so the tool bar can show the chapter position.
  ReaderSessionState? _lastSession;

  /// The body of the chapter the last build showed, for the percent estimate.
  String? _lastBody;

  /// Whether the user is dragging the progress slider right now.
  ///
  /// While dragging, the label follows the finger but the chapter does **not** change: changing it
  /// per frame would start a fetch per frame (§决策 1).
  double? _scrubbing;

  @override
  void initState() {
    super.initState();
    _store = ref.read(readerProgressStoreProvider);
  }

  @override
  void dispose() {
    // 离开阅读器一定要落盘：只在「换章」时保存的话，读到一半按返回就丢了（ADR-0044 §决策 2）。
    final ReadingProgressStore? store = _store;
    if (store != null &&
        _chapters.isNotEmpty &&
        _lastIndex < _chapters.length) {
      final ReadingChapter chapter = _chapters[_lastIndex];
      unawaited(
        store.write(
          sourceUrl: _book.sourceUrl,
          bookUrl: _book.bookUrl,
          position: ReadingPosition(
            chapterUrl: chapter.url,
            chapterName: chapter.title.isEmpty ? null : chapter.title,
            charOffset: _lastOffset,
          ),
        ),
      );
    }
    _chromeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Shows the chrome and restarts its auto-hide countdown (ADR-0051 §决策 1).
  void _showChrome() {
    _chromeTimer?.cancel();
    setState(() => _chromeVisible = true);
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _chromeVisible = false);
      }
    });
  }

  /// Hides the chrome immediately.
  void _hideChrome() {
    _chromeTimer?.cancel();
    setState(() => _chromeVisible = false);
  }

  /// Runs [action] and keeps the chrome alive a little longer.
  void _keepAlive(VoidCallback action) {
    _chromeTimer?.cancel();
    action();
    if (_chromeVisible) {
      _chromeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _chromeVisible = false);
        }
      });
    }
  }

  /// Decides which body the book needs and builds it
  /// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 1).
  ///
  /// The kind is awaited before either body is built: guessing "text" while the port loads would
  /// fetch a chapter body nobody shows, and an image source would pay for it on every open.
  @override
  Widget build(BuildContext context) {
    final AsyncValue<ParseResult<ReaderSourceKind>> kind = ref.watch(
      readerSourceKindProvider(widget.book.sourceUrl),
    );

    return switch (kind) {
      AsyncData<ParseResult<ReaderSourceKind>>(
        :final ParseResult<ReaderSourceKind> value,
      ) =>
        switch (value) {
          ParseSuccess<ReaderSourceKind>(data: ReaderSourceKind.image) =>
            MangaReaderPage(book: widget.book, chapterUrl: widget.chapterUrl),
          _ => _textReader(context),
        },
      // 端口不该失败（失败在适配器里被吸收成 text），真抛了也不能把书挡住。
      AsyncError<ParseResult<ReaderSourceKind>>() => _textReader(context),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  /// The text reader this page has always been (`docs/dev/roadmap.md` 5.3).
  Widget _textReader(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final ReaderSettings settings =
        ref.watch(readerSettingsProvider).value ?? ReaderSettings.defaults;
    final ({Color background, Color foreground}) palette = readerPalette(
      tokens,
      settings.background,
    );
    final AsyncValue<ParseResult<List<ReadingChapter>>> chapters = ref.watch(
      readerChaptersProvider(_book),
    );

    return Scaffold(
      backgroundColor: palette.background,
      // 沉浸式（ADR-0051 §决策 1）：AppBar 与工具条默认都不在，点正文中间 ⅓ 才出现。
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: palette.background,
              foregroundColor: palette.foreground,
              title: Text(_title(chapters, l10n)),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.text_fields),
                  tooltip: l10n.readerSettingsAction,
                  onPressed: () => _keepAlive(() => _openSettings(settings)),
                ),
              ],
            )
          : null,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: switch (chapters) {
              AsyncData<ParseResult<List<ReadingChapter>>>(
                :final ParseResult<List<ReadingChapter>> value,
              ) =>
                switch (value) {
                  ParseSuccess<List<ReadingChapter>>(
                    :final List<ReadingChapter> data,
                  ) =>
                    data.isEmpty
                        ? StateMessage(message: l10n.readerNoChapter)
                        : _sessionBody(data, settings, palette),
                  ParseFailure<List<ReadingChapter>>(
                    :final ParseFailureKind kind,
                  ) =>
                    FailureMessage(
                      kind: kind,
                      onRetry: () =>
                          ref.invalidate(readerChaptersProvider(_book)),
                    ),
                },
              AsyncError<ParseResult<List<ReadingChapter>>>() => FailureMessage(
                kind: ParseFailureKind.parseFailed,
                onRetry: () => ref.invalidate(readerChaptersProvider(_book)),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          // 亮度是**应用级遮罩**（ADR-0051 §决策 1）：不碰系统亮度，三端行为一致。
          if (_brightness < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 1 - _brightness),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _chromeVisible
          ? _toolBar(context, l10n, chapters, palette)
          : null,
    );
  }

  /// The bottom tool bar of the immersive chrome (ADR-0051 §决策 1).
  Widget _toolBar(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
    ({Color background, Color foreground}) palette,
  ) {
    final M3ETheme tokens = context.m3e;
    final List<ReadingChapter> known = _chaptersOf(chapters);
    final int index = _currentIndex;
    final int total = known.length;
    final double? scrubbing = _scrubbing;

    return SafeArea(
      child: Container(
        color: palette.background,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (total > 0)
              Row(
                children: <Widget>[
                  Text(
                    l10n.readerChapterProgress(index + 1, total),
                    style: tokens.typography.base.labelSmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: (scrubbing ?? index.toDouble()).clamp(
                        0,
                        (total - 1).toDouble(),
                      ),
                      max: (total - 1).toDouble(),
                      divisions: total > 1 ? total - 1 : null,
                      label: l10n.readerChapterProgress(
                        (scrubbing ?? index).round() + 1,
                        total,
                      ),
                      // 拖动只动标签（§决策 1）：每帧换章会引发每帧一次抓取。
                      onChanged: total > 1
                          ? (double value) => setState(() => _scrubbing = value)
                          : null,
                      onChangeEnd: (double value) {
                        setState(() => _scrubbing = null);
                        _jumpToChapter(value.round());
                      },
                    ),
                  ),
                  Text(
                    l10n.readerChapterPercent(_chapterPercent),
                    style: tokens.typography.base.labelSmall,
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  tooltip: l10n.readerPreviousChapter,
                  onPressed: index > 0 ? () => _jumpToChapter(index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.list),
                  tooltip: l10n.readerTocAction,
                  onPressed: () => _keepAlive(() => _openToc(known)),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l10n.readerChangeSource,
                  onPressed: () => _keepAlive(_openChangeSource),
                ),
                IconButton(
                  icon: const Icon(Icons.brightness_6_outlined),
                  tooltip: l10n.readerBrightness,
                  onPressed: () => _keepAlive(() => _openBrightness(tokens)),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  tooltip: l10n.readerNextChapter,
                  onPressed: index + 1 < total
                      ? () => _jumpToChapter(index + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The chapter the session shows, or 0 when there is none yet.
  int get _currentIndex {
    final ReaderSessionState? state = _lastSession;
    if (state == null || _chapters.isEmpty) {
      return 0;
    }

    return state.chapterIndex.clamp(0, _chapters.length - 1);
  }

  /// The reading fraction inside the current chapter, 0–100 (the estimate of ADR-0044 §决策 4).
  int get _chapterPercent {
    final ReaderSessionState? state = _lastSession;
    final String? body = _lastBody;
    if (state == null || body == null || body.isEmpty) {
      return 0;
    }

    return (state.charOffset / body.length * 100).clamp(0, 100).round();
  }

  /// Jumps to chapter [index] and keeps the chrome alive.
  void _jumpToChapter(int index) {
    if (_chapters.isEmpty) {
      return;
    }
    final int target = index.clamp(0, _chapters.length - 1);
    unawaited(
      ref.read(readerSessionProvider(_book).notifier).selectChapter(target),
    );
    _keepAlive(() {});
  }

  /// Opens the “change source” sheet and switches when the user picks one (ADR-0051 §决策 3).
  ///
  /// The switch happens **in place**: `_book` changes, every provider keyed by it re-reads the new
  /// source, and the session is told which chapter to open. No navigation, so the reader keeps its
  /// scroll position for the frame and the user never sees a page flash.
  Future<void> _openChangeSource() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Object? picked = await showModalBottomSheet<Object?>(
      context: context,
      builder: (BuildContext context) => ReaderSourceSheet(book: _book),
    );
    if (!mounted || picked is! ReaderSourceCandidate) {
      return;
    }

    final String chapterName =
        _chaptersOf(ref.read(readerChaptersProvider(_book)))
            .elementAtOrNull(_currentIndex)
            ?.title ??
        '';
    final ParseResult<ReaderSourceSwitch> switched = await ref
        .read(bookSourceSwitcherProvider)
        .switchTo(
          book: _book,
          candidate: picked,
          currentChapterName: chapterName,
          currentChapterIndex: _currentIndex,
        );
    if (!mounted) {
      return;
    }

    switch (switched) {
      case ParseSuccess<ReaderSourceSwitch>(:final ReaderSourceSwitch data):
        setState(() {
          _book = data.book;
          _restoredChapterUrl = null;
          _lastBody = null;
        });
        // 新身份上的会话从零开始：直接告诉它对齐到哪一章（进度也由它在新身份下落盘）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(
            ref
                .read(readerSessionProvider(_book).notifier)
                .selectChapter(data.chapterIndex),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.readerSourceAligned(data.chapterName))),
        );
      case ParseFailure<ReaderSourceSwitch>():
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.readerSourceFailed)));
    }
  }

  /// Opens the brightness slider (an app-level overlay, ADR-0051 §决策 1).
  void _openBrightness(M3ETheme tokens) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) =>
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.lg),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.brightness_low),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.2,
                          max: 1,
                          divisions: 16,
                          label: '${(_brightness * 100).round()}%',
                          onChanged: (double value) {
                            setSheetState(() {});
                            setState(() => _brightness = value);
                          },
                        ),
                      ),
                      const Icon(Icons.brightness_high),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  /// The session-dependent half: chapter body or session failure.
  Widget _sessionBody(
    List<ReadingChapter> chapters,
    ReaderSettings settings,
    ({Color background, Color foreground}) palette,
  ) {
    _chapters = chapters;

    final AsyncValue<ReaderSessionState> session = ref.watch(
      readerSessionProvider(_book),
    );
    _applyStartChapter(chapters, session.value);

    return switch (session) {
      AsyncData<ReaderSessionState>(:final ReaderSessionState value) =>
        _chapterBody(chapters, value, settings, palette),
      AsyncError<ReaderSessionState>() => FailureMessage(
        kind: ParseFailureKind.parseFailed,
        onRetry: () => ref.invalidate(readerSessionProvider(_book)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// Opens the chapter the route named, once, when it differs from the restored one.
  void _applyStartChapter(
    List<ReadingChapter> chapters,
    ReaderSessionState? session,
  ) {
    final String? requested = widget.chapterUrl;
    if (_appliedStartChapter || requested == null || session == null) {
      return;
    }
    final int index = chapters.indexWhere(
      (ReadingChapter chapter) => chapter.url == requested,
    );
    if (index < 0) {
      // 路由给的章节不在目录里（源改过地址）：保持在恢复出来的位置，不要让页面卡住。
      _appliedStartChapter = true;

      return;
    }
    _appliedStartChapter = true;
    if (index == session.chapterIndex) {
      return;
    }
    // 换章会改 provider 状态，而这里还在 build 里：放到帧后执行（否则 Riverpod 会报
    // 「Tried to modify a provider while the widget tree was building」）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(readerSessionProvider(_book).notifier).selectChapter(index),
      );
    });
  }

  /// The body of the open chapter, in the mode the reader chose.
  Widget _chapterBody(
    List<ReadingChapter> chapters,
    ReaderSessionState session,
    ReaderSettings settings,
    ({Color background, Color foreground}) palette,
  ) {
    if (chapters.isEmpty || session.chapterIndex >= chapters.length) {
      return StateMessage(
        message: AppLocalizations.of(context).readerNoChapter,
      );
    }
    final ReadingChapter chapter = chapters[session.chapterIndex];
    _lastIndex = session.chapterIndex;
    _lastOffset = session.charOffset;
    _lastSession = session;
    final M3ETheme tokens = context.m3e;
    final TextStyle style = readerTextStyle(
      tokens: tokens,
      fontScale: settings.fontScale * MediaQuery.textScalerOf(context).scale(1),
      lineHeight: settings.lineHeight,
      foreground: palette.foreground,
      family: settings.fontFamily,
    );

    final AsyncValue<ParseResult<String>> content = ref.watch(
      readerContentProvider((_book, chapter.url)),
    );

    // 三区点击（ADR-0051 §决策 1）：中间 ⅓ 唤出菜单，左右各 ⅓ 唤出菜单前先收起它。
    return _tapZones(
      child: switch (content) {
        AsyncData<ParseResult<String>>(:final ParseResult<String> value) =>
          switch (value) {
            // 段距与首行缩进是**排版**（ADR-0051 §决策 4）：在渲染前套一次，正文数据不动。
            ParseSuccess<String>(:final String data) =>
              _remembered(data) && settings.pageMode == ReaderPageMode.scroll
                  ? _scrollBody(
                      chapter,
                      readerBodyText(data, settings),
                      style,
                      session.charOffset,
                      palette,
                      _paddingOf(settings),
                    )
                  : _pagedBody(
                      chapter,
                      readerBodyText(data, settings),
                      style,
                      session.charOffset,
                      chapters.length,
                      session.chapterIndex,
                      palette,
                      _paddingOf(settings),
                    ),
            ParseFailure<String>(:final ParseFailureKind kind) =>
              FailureMessage(
                kind: kind,
                onRetry: () =>
                    ref.invalidate(readerContentProvider((_book, chapter.url))),
              ),
          },
        AsyncError<ParseResult<String>>() => FailureMessage(
          kind: ParseFailureKind.parseFailed,
          onRetry: () =>
              ref.invalidate(readerContentProvider((_book, chapter.url))),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Wraps [child] in the three tap zones of §决策 1.
  ///
  /// Only the **middle** one is wired here; the left/right thirds keep the platform's own scroll
  /// and page gestures (a tap there hides the chrome instead of fighting the gesture recognizer).
  Widget _tapZones({required Widget child}) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double width = constraints.maxWidth;
      final double third = width / 3;

      return Stack(
        children: <Widget>[
          Positioned.fill(child: child),
          Positioned(
            left: third,
            width: third,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _chromeVisible ? _hideChrome : _showChrome,
            ),
          ),
        ],
      );
    },
  );

  /// The scrolling body: one `Text`, restored once per chapter, saved when a scroll settles.
  Widget _scrollBody(
    ReadingChapter chapter,
    String body,
    TextStyle style,
    int initialOffset,
    ({Color background, Color foreground}) palette,
    double padding,
  ) => NotificationListener<ScrollEndNotification>(
    onNotification: (ScrollEndNotification notification) {
      // 滚动停下时记一次：按比例换算成字符偏移（ADR-0044 §决策 4）。
      final double max = _scroll.hasClients
          ? _scroll.position.maxScrollExtent
          : 0;
      final int offset = max <= 0
          ? 0
          : (_scroll.offset / max * body.length).round();
      _rememberOffset(offset);
      unawaited(ref.read(readerSessionProvider(_book).notifier).saveProgress());

      return false;
    },
    child: SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.all(padding),
      child: _restoredScrollText(chapter, body, style, initialOffset),
    ),
  );

  /// The body text, jumped to [initialOffset] the first time this chapter is shown.
  Widget _restoredScrollText(
    ReadingChapter chapter,
    String body,
    TextStyle style,
    int initialOffset,
  ) {
    if (_restoredChapterUrl != chapter.url) {
      _restoredChapterUrl = chapter.url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) {
          return;
        }
        final double max = _scroll.position.maxScrollExtent;
        if (max <= 0 || initialOffset <= 0 || body.isEmpty) {
          return;
        }
        _scroll.jumpTo((initialOffset / body.length * max).clamp(0, max));
      });
    }

    return Text(body, style: style);
  }

  /// The paged body: pages measured by [readerPageStarts], turned horizontally.
  Widget _pagedBody(
    ReadingChapter chapter,
    String body,
    TextStyle style,
    int initialOffset,
    int chapterCount,
    int chapterIndex,
    ({Color background, Color foreground}) palette,
    double padding,
  ) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: _PagedBody(
        key: ValueKey<String>(
          '${chapter.url}|${style.fontSize}|${style.height}',
        ),
        text: body,
        style: style,
        initialOffset: initialOffset,
        foreground: palette.foreground,
        isLastChapter: chapterIndex == chapterCount - 1,
        onOffsetChanged: _rememberOffset,
        onNextChapter: () => unawaited(
          ref.read(readerSessionProvider(_book).notifier).nextChapter(),
        ),
      ),
    );
  }

  /// Remembers [offset] in the session; the next chapter switch or exit writes it.
  void _rememberOffset(int offset) {
    _lastOffset = offset;
    ref.read(readerSessionProvider(_book).notifier).updateOffset(offset);
  }

  /// The chapters of [chapters], or none while they load.
  List<ReadingChapter> _chaptersOf(
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
  ) => switch (chapters.value) {
    ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
      data,
    _ => const <ReadingChapter>[],
  };

  /// The app bar title: the chapter, else the book.
  String _title(
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
    AppLocalizations l10n,
  ) {
    final List<ReadingChapter> known = _chaptersOf(chapters);
    final int index = _currentIndex;
    if (index < known.length && known[index].title.isNotEmpty) {
      return known[index].title;
    }

    return _book.name.isEmpty ? l10n.bookSourceReaderTitle : _book.name;
  }

  /// Remembers the loaded body for the percent label and answers `true` (so it reads as a
  /// condition in the layout switch).
  bool _remembered(String body) {
    _lastBody = body;

    return true;
  }

  /// The padding the body uses, from the page-margin preset (ADR-0051 §决策 4).
  double _paddingOf(ReaderSettings settings) =>
      readerPagePaddingOf(settings.pagePadding);

  /// Opens the chapter list and jumps to the chosen chapter (ADR-0051 §决策 2).
  void _openToc(List<ReadingChapter> chapters) {
    if (chapters.isEmpty) {
      return;
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: ReaderTocSheet(
            chapters: chapters,
            currentIndex: _currentIndex,
            onSelected: (int index) {
              Navigator.of(context).pop();
              _jumpToChapter(index);
            },
          ),
        ),
      ),
    );
  }

  /// Opens the reading settings and applies every change immediately.
  void _openSettings(ReaderSettings settings) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final ReaderSettings current =
                ref.watch(readerSettingsProvider).value ?? settings;

            return ReaderSettingsSheet(
              settings: current,
              onChanged: (ReaderSettings next) => unawaited(
                ref.read(readerSettingsProvider.notifier).apply(next),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The horizontally paged body (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 4).
///
/// The page boundaries are measured per layout, because a page is "what fits at this font size in
/// this box" and nothing else. The last item is the end of the chapter: it offers the next chapter
/// instead of pretending the body continues (cross-chapter paging is registered as open).
class _PagedBody extends StatefulWidget {
  const _PagedBody({
    required this.text,
    required this.style,
    required this.initialOffset,
    required this.foreground,
    required this.isLastChapter,
    required this.onOffsetChanged,
    required this.onNextChapter,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int initialOffset;
  final Color foreground;
  final bool isLastChapter;
  final ValueChanged<int> onOffsetChanged;
  final VoidCallback onNextChapter;

  @override
  State<_PagedBody> createState() => _PagedBodyState();
}

/// State of the paged body: the page list, the controller and the restore jump.
class _PagedBodyState extends State<_PagedBody> {
  PageController? _controller;
  List<int> _starts = const <int>[0];
  bool _restored = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _starts = readerPageStarts(
          text: widget.text,
          style: widget.style,
          size: constraints.biggest,
          textScaler: MediaQuery.textScalerOf(context),
        );
        final PageController controller = _controller ??= PageController();
        _restoreOnce(controller);

        return PageView.builder(
          controller: controller,
          itemCount: _starts.length + 1,
          onPageChanged: (int page) {
            if (page < _starts.length) {
              widget.onOffsetChanged(_starts[page]);
            }
          },
          itemBuilder: (BuildContext context, int page) {
            if (page >= _starts.length) {
              return _chapterEnd(l10n, tokens);
            }
            final int start = _starts[page];
            final int end = page + 1 < _starts.length
                ? _starts[page + 1]
                : widget.text.length;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                widget.text.substring(start, end),
                style: widget.style,
              ),
            );
          },
        );
      },
    );
  }

  /// Jumps to the page that holds the restored offset, once.
  void _restoreOnce(PageController controller) {
    if (_restored || widget.initialOffset <= 0) {
      return;
    }
    _restored = true;
    final int page = readerPageOf(_starts, widget.initialOffset);
    if (page == 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) {
        controller.jumpToPage(page);
      }
    });
  }

  /// The last page: the chapter is over, the next one is one tap away.
  Widget _chapterEnd(AppLocalizations l10n, M3ETheme tokens) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.isLastChapter
                  ? l10n.readerLastChapter
                  : l10n.readerChapterEnd,
              style: tokens.typography.base.bodyLarge?.copyWith(
                color: widget.foreground,
              ),
            ),
            if (!widget.isLastChapter) ...<Widget>[
              SizedBox(height: tokens.spacing.lg),
              FilledButton(
                onPressed: widget.onNextChapter,
                child: Text(l10n.readerNextChapter),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
