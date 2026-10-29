import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/battery_level.dart';
import 'package:flutter_reader/core/platform/screen_awake.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/bookmark_excerpt.dart';
import 'package:flutter_reader/features/reader/domain/entities/book_search.dart';
import 'package:flutter_reader/features/reader/domain/entities/bookmark.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_source_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_record_repository.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/manga_queries.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_bookmarks_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_highlight.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/pages/manga_reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/audio_reader_view.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_book_scope.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_chapter_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_page_table.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_paged_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_scroll_flow.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_search_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_source_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_status_bar.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_toc_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_tts_sheet.dart';
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
  /// Creates the page for [book], optionally starting at [chapterUrl] and [charOffset].
  const ReaderPage({
    required this.book,
    this.chapterUrl,
    this.charOffset = 0,
    super.key,
  });

  /// The book being read.
  final ReaderBook book;

  /// The chapter to open, or `null` to resume where the reader stopped.
  ///
  /// A concrete URL wins over the stored position: tapping a chapter row in the detail page must
  /// open **that** chapter, not the last one read (ADR-0044 §决策 2).
  final String? chapterUrl;

  /// Where to land inside [chapterUrl], which is what a bookmark jump needs
  /// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 7).
  final int charOffset;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

/// State of the reader page: the scroll controller, the save bookkeeping and the last position.
class _ReaderPageState extends ConsumerState<ReaderPage> {
  /// The book currently open. It starts as the route's book and **changes** on a source switch:
  /// every provider below is keyed by it, so a new value naturally re-reads the new source
  /// (ADR-0051 §决策 3) — no navigation, no flash, and the reader stays where it was.
  late ReaderBook _book = widget.book;

  /// The progress port, captured in `initState` so `dispose` may still write.
  ReadingProgressStore? _store;

  /// The reading-record port, the clock and the session's start instant, captured for the same
  /// reason as [_store]: `dispose` may not read a provider.
  ReadingRecordRepository? _records;
  Clock? _clock;
  DateTime? _sessionStartedAt;

  /// The “keep the display on” port and the charge reader, captured for `dispose` and for the
  /// status line (ADR-0086 §决策 1/6).
  ScreenAwake? _screenAwake;
  BatteryLevel? _battery;

  /// Bumped when the flows must restore to an explicit position (ADR-0087 §决策 2).
  int _restoreNonce = 0;

  /// The explicit jump the flows have not applied yet, or `null`.
  ///
  /// It is also what the flows are told to restore to — **not** the session: the session is only
  /// moved a frame later (it is an async notifier), so building the restore from it would restore to
  /// the chapter the reader is *leaving*, and the position the flow reports back would then undo the
  /// jump. While a jump is pending, a report naming another chapter is stale by definition and is
  /// dropped (see [_followFlow]).
  ({int chapterIndex, int charOffset})? _pendingJump;

  /// Whether the chapter the route asked for was already opened.
  bool _appliedStartChapter = false;

  /// The read-aloud notifier, captured when its sheet is opened.
  ///
  /// The sheet disposes when it closes, but speech may continue; keeping the notifier here lets
  /// `dispose` apply the “stop when leaving the reader” rule (ADR-0054 §决策 5).
  ReaderTts? _tts;

  /// Watches the reader's settings so the display's awake state follows them (ADR-0086 §决策 1).
  ///
  /// `listenManual` rather than `ref.listen` because the initial value has to be applied too, and
  /// the widget-level listen has no `fireImmediately` (flutter_riverpod 3).
  ProviderSubscription<AsyncValue<ReaderSettings>>? _settingsWatch;

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

  /// The dimming overlay's opacity while the slider is being dragged, or `null` to follow the
  /// stored [ReaderSettings.brightness]. App-level, not system brightness.
  double? _brightnessOverride;

  /// Whether the last slider release is still being written; the sheet's close must not clear the
  /// override before that write lands.
  bool _brightnessSaving = false;

  /// Chapter bodies in hand, keyed by chapter URL — both the ones fetched ahead and the one the
  /// open chapter's own provider returned.
  ///
  /// Pruned to the ±[_prefetchRadius] window on every build (see [_retainBodies]), so reading a
  /// thousand chapters does not keep a thousand bodies alive. Keyed by URL and not by index because
  /// the body text itself is the same document for two chapters that share an address; the
  /// *laid-out* text is keyed by index (see [_laidOut]), which is where the two chapters differ.
  final Map<String, String> _prefetchedBodies = <String, String>{};

  /// Bodies already laid out, keyed by chapter **index**: two chapters may share an address, and
  /// they still get their own heading and their own duplicate-title strip (ADR-0087 §决策 1/4).
  final Map<int, ({int signature, String text})> _laidOut =
      <int, ({int signature, String text})>{};

  /// Page heights already measured, shared by both reading modes.
  final ReaderPageMeasureCache _measures = ReaderPageMeasureCache();

  /// The first chapter the page table renders; `-1` means "not placed yet".
  ///
  /// It only ever moves backwards while the reader reads (see [_applyWindow]).
  int _windowFirst = -1;

  /// Chapters whose body is being fetched right now.
  ///
  /// A rebuild must not queue the same chapter twice, and the runs are **serialised**
  /// (ADR-0088 §决策 2): one chapter in flight, nearest first, so the reader's own next chapter is
  /// never behind twenty others in the source's rate queue.
  final Set<String> _prefetching = <String>{};

  /// Chapters whose prefetch failed; not retried while they remain in the window.
  final Set<String> _prefetchFailed = <String>{};

  /// Bumped on a source switch so an in-flight prefetch of the old source is dropped.
  int _prefetchGeneration = 0;

  /// How many chapters on **each** side the reader keeps ahead of itself (ADR-0088 §决策 2).
  ///
  /// A fixed 15 — the number the user asked for. The setting surface upstream has
  /// (`preDownloadNum` / `preDownloadNumPrev`) is still registered in `docs/dev/roadmap.md` §3.7.
  static const int _prefetchRadius = 15;

  /// Chapters still to fetch, nearest first; rebuilt when the anchor chapter changes.
  final List<int> _prefetchQueue = <int>[];

  /// The anchor chapter the queue was built for, so a rebuild does not reshuffle it per frame.
  int _prefetchAnchor = -1;

  /// The chapter count the queue was built for: a book that gained chapters needs a new queue.
  int _prefetchCount = -1;

  /// The session the last build saw, so the tool bar can show the chapter position.
  ReaderSessionState? _lastSession;

  /// The body of the chapter the last build showed, for the percent estimate.
  String? _lastBody;

  /// The chapter the last build showed, kept for the session record written in `dispose`.
  String? _lastChapterUrl;
  String? _lastChapterName;

  /// Whether the user is dragging the progress slider right now.
  ///
  /// While dragging, the label follows the finger but the chapter does **not** change: changing it
  /// per frame would start a fetch per frame (§决策 1).
  double? _scrubbing;

  @override
  void initState() {
    super.initState();
    _store = ref.read(readerProgressStoreProvider);
    _records = ref.read(readingRecordRepositoryProvider);
    _clock = ref.read(clockProvider);
    _screenAwake = ref.read(screenAwakeProvider);
    _battery = ref.read(batteryLevelProvider);
    _sessionStartedAt = _clock?.now();
    _settingsWatch = ref.listenManual<AsyncValue<ReaderSettings>>(
      readerSettingsProvider,
      (AsyncValue<ReaderSettings>? previous, AsyncValue<ReaderSettings> next) {
        final ReaderSettings? current = next.value;
        if (current == null) {
          return;
        }
        unawaited(
          _screenAwake?.setAwake(awake: current.keepScreenAwake) ??
              Future<void>.value(),
        );
      },
      fireImmediately: true,
    );
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
    _recordSession();
    _tts?.onReaderClosed();
    _settingsWatch?.close();
    _chromeTimer?.cancel();
    // 离开阅读器就把常亮交还系统（ADR-0086 §决策 1）；幂等，重复释放无害。
    unawaited(_screenAwake?.setAwake(awake: false) ?? Future<void>.value());
    super.dispose();
  }

  /// Appends this session to the reading history (ADR-0066 §决策 4).
  ///
  /// The store drops sessions below `minimumRecordedSeconds`, so this always hands the frame over
  /// and never has to decide: a glance at the chapter title is not a reading record. Both ports
  /// were captured in `initState` because reading a provider inside `dispose` is unsafe.
  void _recordSession() {
    final ReadingRecordRepository? records = _records;
    final Clock? clock = _clock;
    final DateTime? startedAt = _sessionStartedAt;
    if (records == null || clock == null || startedAt == null) {
      return;
    }
    final ReadingSession session = ReadingSession(
      sourceUrl: _book.sourceUrl,
      bookUrl: _book.bookUrl,
      bookName: _book.name,
      chapterUrl: _lastChapterUrl,
      chapterName: _lastChapterName,
      startedAt: startedAt,
      endedAt: clock.now(),
    );
    if (!session.shouldRecord) {
      return;
    }
    unawaited(records.record(session));
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

  /// Decides which body the book needs and builds it: text, manga or audio
  /// (`docs/dev/roadmap.md` §3.10 M16/M17, ADR-0053 §决策 1, ADR-0054 §决策 1).
  ///
  /// The kind is awaited before either body is built: guessing "text" while the port loads would
  /// fetch a chapter body nobody shows, and an image source would pay for it on every open.
  @override
  Widget build(BuildContext context) {
    final AsyncValue<ParseResult<ReaderSourceKind>> kind = ref.watch(
      readerSourceKindProvider(_book.sourceUrl),
    );

    return switch (kind) {
      AsyncData<ParseResult<ReaderSourceKind>>(
        :final ParseResult<ReaderSourceKind> value,
      ) =>
        switch (value) {
          ParseSuccess<ReaderSourceKind>(data: ReaderSourceKind.image) =>
            MangaReaderPage(book: _book, chapterUrl: widget.chapterUrl),
          ParseSuccess<ReaderSourceKind>(data: ReaderSourceKind.audio) =>
            AudioReaderView(book: _book),
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
    // 拖动时用本地预览，松手后跟随已存的值（ADR-0075 §决策 2）。
    final double brightness = _brightnessOverride ?? settings.brightness;
    final AsyncValue<ParseResult<List<ReadingChapter>>> chapters = ref.watch(
      readerChaptersProvider(_book),
    );
    // 书签也在工具条出现**之前**就读：工具条只在唤出时才构建，第一帧还停在 loading 的话，
    // 按钮会先画成「未标记」再跳成「已标记」（ADR-0066 §决策 3 的 toggle 语义要求状态稳定）。
    final AsyncValue<List<Bookmark>> marks = ref.watch(
      readerBookmarksProvider(_book),
    );
    final ColorFilter? eyeFilter = readerEyeProtectionFilter(
      settings.eyeProtection,
    );
    final List<ReadingChapter> knownChapters = _chaptersOf(chapters);

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
                  icon: const Icon(Icons.search),
                  tooltip: l10n.readerSearchAction,
                  onPressed: () => _keepAlive(
                    () => _openSearch(switch (chapters.value) {
                      ParseSuccess<List<ReadingChapter>>(
                        :final List<ReadingChapter> data,
                      ) =>
                        data,
                      _ => const <ReadingChapter>[],
                    }),
                  ),
                ),
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
            // 护眼滤镜只作用在正文上（ADR-0086 §决策 2）：状态栏与亮度遮罩自己就是「看得清」
            // 的手段，不该再被压暖。
            child: _filtered(
              eyeFilter,
              _bodyOf(chapters, settings, palette, l10n),
            ),
          ),
          // 亮度是**应用级遮罩**（ADR-0051 §决策 1）：不碰系统亮度，三端行为一致。
          if (brightness < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  // 亮度遮罩用主题的 scrim：它本来就是「压暗内容」的角色，避免硬编码黑色。
                  color: tokens.colors.scrim.withValues(alpha: 1 - brightness),
                ),
              ),
            ),
          // 状态栏（ADR-0086 §决策 6）：沉浸式把时间与电量都藏起来了，这一行把它们放回来。
          if (settings.showReaderStatus)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _statusLine(knownChapters, settings, palette, l10n),
            ),
        ],
      ),
      bottomNavigationBar: _chromeVisible
          ? _toolBar(context, l10n, chapters, palette, marks)
          : null,
    );
  }

  /// [child] behind the warm filter, or untouched when the reader has it off.
  Widget _filtered(ColorFilter? filter, Widget child) =>
      filter == null ? child : ColorFiltered(colorFilter: filter, child: child);

  /// The body of the open chapter, dispatched by the chapter list's state.
  Widget _bodyOf(
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
    ReaderSettings settings,
    ({Color background, Color foreground}) palette,
    AppLocalizations l10n,
  ) {
    // 目录被刷新（书更了新章节）时 `AsyncValue` 是 loading，但它带着上一次的值：读者眼前的东西
    // **不能**因此换成转圈——那就是「闪屏」，而且正文流程会被销毁重建，滚动位置跟着丢
    // （ADR-0089）。只有从来没有拿到过目录时才画转圈。
    final ParseResult<List<ReadingChapter>>? loaded = chapters.value;
    if (loaded == null) {
      if (chapters.hasError) {
        return FailureMessage(
          kind: ParseFailureKind.parseFailed,
          onRetry: () => ref.invalidate(readerChaptersProvider(_book)),
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    return switch (loaded) {
      ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
        data.isEmpty
            ? StateMessage(message: l10n.readerNoChapter)
            : _sessionBody(data, settings, palette),
      ParseFailure<List<ReadingChapter>>(:final ParseFailureKind kind) =>
        FailureMessage(
          kind: kind,
          onRetry: () => ref.invalidate(readerChaptersProvider(_book)),
        ),
    };
  }

  /// The reader's status line, or nothing when the reader turned it off.
  Widget _statusLine(
    List<ReadingChapter> chapters,
    ReaderSettings settings,
    ({Color background, Color foreground}) palette,
    AppLocalizations l10n,
  ) {
    final Clock? clock = _clock;
    final BatteryLevel? battery = _battery;
    if (!settings.showReaderStatus || clock == null || battery == null) {
      return const SizedBox.shrink();
    }
    final int index = _currentIndex;
    final String progress = chapters.isEmpty
        ? l10n.readerChapterPercent(_chapterPercent)
        : '${l10n.readerChapterProgress(index + 1, chapters.length)} · '
              '${l10n.readerChapterPercent(_chapterPercent)}';

    return ReaderStatusBar(
      progressText: progress,
      clock: clock,
      battery: battery,
      foreground: palette.foreground,
    );
  }

  /// The bottom tool bar of the immersive chrome (ADR-0051 §决策 1).
  Widget _toolBar(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
    ({Color background, Color foreground}) palette,
    AsyncValue<List<Bookmark>> marks,
  ) {
    final M3ETheme tokens = context.m3e;
    final List<ReadingChapter> known = _chaptersOf(chapters);
    final int index = _currentIndex;
    final int total = known.length;
    final bool marked = _isBookmarkedAtCurrentPosition(known, index, marks);
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
                    // 只有一章时没有可拖动的范围：`max == min` 会让 Slider 的归一化位置变成
                    // NaN（调试包里就是一条画不出来的进度条）。空位取代它。
                    child: total > 1
                        ? Slider(
                            value: (scrubbing ?? index.toDouble()).clamp(
                              0,
                              (total - 1).toDouble(),
                            ),
                            max: (total - 1).toDouble(),
                            divisions: total - 1,
                            label: l10n.readerChapterProgress(
                              (scrubbing ?? index).round() + 1,
                              total,
                            ),
                            // 拖动只动标签（§决策 1）：每帧换章会引发每帧一次抓取。
                            onChanged: (double value) =>
                                setState(() => _scrubbing = value),
                            onChangeEnd: (double value) {
                              setState(() => _scrubbing = null);
                              _jumpToChapter(value.round());
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    l10n.readerChapterPercent(_chapterPercent),
                    style: tokens.typography.base.labelSmall,
                  ),
                ],
              ),
            // 七个按钮在 320dp 的窄屏上放不下一整行：宽度够时均匀分布，不够时横向滚动，
            // 不会把「下一章」挤出屏幕（M14 起就是最容易出问题的一行）。
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            tooltip: l10n.readerPreviousChapter,
                            onPressed: index > 0
                                ? () => _jumpToChapter(index - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.list),
                            tooltip: l10n.readerTocAction,
                            onPressed: () => _keepAlive(() => _openToc(known)),
                          ),
                          // 书签按钮是一个 toggle：同一位置再按一次就取消（ADR-0066 §决策 3）。
                          IconButton(
                            icon: Icon(
                              marked ? Icons.bookmark : Icons.bookmark_border,
                            ),
                            tooltip: marked
                                ? l10n.bookmarkRemove
                                : l10n.bookmarkAdd,
                            onPressed: known.isEmpty
                                ? null
                                : () => _keepAlive(
                                    () => _toggleBookmark(known, index, l10n),
                                  ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: l10n.readerChangeSource,
                            onPressed: () => _keepAlive(_openChangeSource),
                          ),
                          IconButton(
                            icon: const Icon(Icons.brightness_6_outlined),
                            tooltip: l10n.readerBrightness,
                            onPressed: () =>
                                _keepAlive(() => _openBrightness(tokens)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            tooltip: l10n.readerTtsAction,
                            onPressed: _openTts,
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
                    ),
                  ),
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

  /// Whether the current position of chapter [index] already carries a bookmark.
  ///
  /// The list is the same provider the toggle reloads, so the icon and the next write always agree
  /// on what 「marked here」 means (ADR-0066 §决策 3).
  bool _isBookmarkedAtCurrentPosition(
    List<ReadingChapter> chapters,
    int index,
    AsyncValue<List<Bookmark>> marks,
  ) {
    if (chapters.isEmpty || index >= chapters.length) {
      return false;
    }

    return isBookmarkedAt(
      marks.value ?? const <Bookmark>[],
      chapterUrl: chapters[index].url,
      charOffset: _lastOffset,
    );
  }

  /// Adds or removes the bookmark at the current position and reports which way it went.
  Future<void> _toggleBookmark(
    List<ReadingChapter> chapters,
    int index,
    AppLocalizations l10n,
  ) async {
    if (index >= chapters.length) {
      return;
    }
    final ReadingChapter chapter = chapters[index];
    final String body = _lastBody ?? '';
    final bool? marked = await ref
        .read(readerBookmarksProvider(_book).notifier)
        .toggle(
          BookmarkDraft(
            sourceUrl: _book.sourceUrl,
            bookUrl: _book.bookUrl,
            bookName: _book.name,
            tocUrl: _book.tocUrl,
            chapterUrl: chapter.url,
            chapterName: chapter.title.isEmpty ? null : chapter.title,
            chapterIndex: index,
            charOffset: _lastOffset,
            // 摘录来自已经渲染过的正文：加书签不发第二请求（ADR-0066 §决策 3）。
            excerpt: body.isEmpty ? null : bookmarkExcerpt(body, _lastOffset),
          ),
        );
    if (!mounted) {
      return;
    }
    final String message = switch (marked) {
      true => l10n.bookmarkAdded,
      false => l10n.bookmarkRemoved,
      null => l10n.bookmarkFailed,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Jumps to chapter [index] and keeps the chrome alive.
  /// Jumps to chapter [index] and keeps the chrome alive.
  ///
  /// A jump is **explicit**: the flows are rebuilt at the new position ([_restoreNonce]) instead of
  /// continuing from where the reader was, which is what makes a table-of-contents tap, a bookmark
  /// or a slider drag land exactly where it says (ADR-0085 §决策 4).
  void _jumpToChapter(int index, {int charOffset = 0}) {
    if (_chapters.isEmpty) {
      return;
    }
    final int target = index.clamp(0, _chapters.length - 1);
    // 显式跳转重置窗口：跳过去以后，锚点上方的章不再是读者刚读过的那些（ADR-0087 §决策 2）。
    setState(() {
      _restoreNonce++;
      _windowFirst = -1;
      _pendingJump = (chapterIndex: target, charOffset: charOffset);
    });
    unawaited(
      ref
          .read(readerSessionProvider(_book).notifier)
          .selectChapter(target, charOffset: charOffset),
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
      isScrollControlled: true,
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
          // 换源就是换一份目录：正文流程必须按新身份的章节重新定位（ADR-0085 §决策 4）。
          _restoreNonce++;
          _pendingJump = (chapterIndex: data.chapterIndex, charOffset: 0);
          _lastBody = null;
          // 旧源的正文不能带到新源：换源后重新预取相邻章。
          _prefetchedBodies.clear();
          _prefetching.clear();
          _prefetchFailed.clear();
          _laidOut.clear();
          _measures.clear();
          _windowFirst = -1;
          _prefetchGeneration++;
        });
        // 退出守护要按换源后的身份判断「在不在书架」，否则会拿旧 URL 再问一次。
        ReaderBookScope.maybeOf(context)?.value = data.book;
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

  /// Opens the brightness slider (an app-level overlay, ADR-0051 §决策 1 / ADR-0075 §决策 2).
  ///
  /// 拖动只改本地遮罩，松手才写设置：每一帧写 `shared_preferences` 会让滑动卡顿。
  void _openBrightness(M3ETheme tokens) {
    final ReaderSettings initial =
        ref.read(readerSettingsProvider).value ?? ReaderSettings.defaults;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final ReaderSettings current =
                ref.read(readerSettingsProvider).value ?? initial;
            final double value = _brightnessOverride ?? current.brightness;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.lg),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.brightness_low),
                    Expanded(
                      child: Slider(
                        value: value,
                        min: minReaderBrightness,
                        max: maxReaderBrightness,
                        divisions: 12,
                        label: '${(value * 100).round()}%',
                        onChanged: (double next) {
                          setSheetState(() {});
                          setState(() => _brightnessOverride = next);
                        },
                        onChangeEnd: (double next) {
                          _brightnessSaving = true;
                          unawaited(
                            ref
                                .read(readerSettingsProvider.notifier)
                                .apply(current.copyWith(brightness: next))
                                .whenComplete(() {
                                  _brightnessSaving = false;
                                  if (mounted) {
                                    setState(() => _brightnessOverride = null);
                                  }
                                }),
                          );
                        },
                      ),
                    ),
                    const Icon(Icons.brightness_high),
                  ],
                ),
              ),
            );
          },
        ),
      ).whenComplete(() {
        // 没松手就被关掉时，不在页面上留下一个没存盘的遮罩；正在落盘的写入交给它自己清理。
        if (!_brightnessSaving && mounted) {
          setState(() => _brightnessOverride = null);
        }
      }),
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
    // 与 [_bodyOf] 同一条规矩：会话重建（目录更新会让它重建）期间继续画上一次的位置。
    final ReaderSessionState? state = session.value;
    if (state == null) {
      if (session.hasError) {
        return FailureMessage(
          kind: ParseFailureKind.parseFailed,
          onRetry: () => ref.invalidate(readerSessionProvider(_book)),
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    return _chapterBody(chapters, state, settings, palette);
  }

  /// Opens the chapter the route named, once, when it differs from the restored one.
  ///
  /// The route may also name an offset inside that chapter (a bookmark jump); the session then
  /// starts there instead of at the top, and the body restores against it once
  /// (ADR-0066 §决策 7).
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
    final int offset = widget.charOffset < 0 ? 0 : widget.charOffset;
    final bool samePosition =
        index == session.chapterIndex && offset == session.charOffset;
    if (samePosition) {
      return;
    }
    // 换章 / 换位置会改 provider 状态，而这里还在 build 里：放到帧后执行（否则 Riverpod 会报
    // 「Tried to modify a provider while the widget tree was building」）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // 同一章内的跳转必须让正文重新恢复一次：流程每个实例只应用一次显式跳转，所以这里换一个
      // 编号（见 [_restoreNonce]）。
      _restoreNonce++;
      _windowFirst = -1;
      _pendingJump = (chapterIndex: index, charOffset: offset);
      unawaited(
        ref
            .read(readerSessionProvider(_book).notifier)
            .selectChapter(index, charOffset: offset),
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
    _lastChapterUrl = chapter.url;
    _lastChapterName = chapter.title.isEmpty ? null : chapter.title;

    // 本章的正文也走同一条读路径：正文还没到手时页表给出一页「章头 + 正在加载」，
    // 页面自己不再另画一个转圈（那会让正文在加载前后各画一次）。
    final ParseResult<String>? content = ref
        .watch(readerContentProvider((_book, chapter.url)))
        .value;
    final String? currentData = switch (content) {
      ParseSuccess<String>(:final String data) => data,
      ParseFailure<String>() => null,
      null => null,
    };

    // 阅读位置最多跨进**一章**未加载的章（ADR-0088 §决策 1）：锚点章的正文没到手，页表就只排到它
    // 自己，快速滑动会在这一页加载页上停住；正文到手才允许再往下接一章。这样「一次滑动跨过好几章
    // 空白、把它们同时拉起来」不会发生——能被跨过去的章一律是已经抓好的章。
    final bool anchorReady = currentData != null && currentData.isNotEmpty;
    // 窗口只向前长（ADR-0087 §决策 2）：锚点前进时只往下补章，不回收上方的章，
    // 于是「视口顶以上的高度」在阅读过程中不会变——这是滚动不跳的前提。
    _applyWindow(session.chapterIndex, chapters.length);
    final int last = anchorReady
        ? (session.chapterIndex + 1).clamp(0, chapters.length - 1)
        : session.chapterIndex;
    final Set<int> window = <int>{
      for (var index = _windowFirst; index <= last; index++) index,
    };
    // 正文原文留 ±15 章（提前缓存），排版结果与测量只留渲染窗口（ADR-0088 §决策 3）。
    _retainBodies(session.chapterIndex, window);
    _queuePrefetches(session.chapterIndex, chapters.length);

    final M3ETheme tokens = context.m3e;
    final TextStyle style = readerTextStyle(
      tokens: tokens,
      fontScale: settings.fontScale * MediaQuery.textScalerOf(context).scale(1),
      lineHeight: settings.lineHeight,
      foreground: palette.foreground,
      family: settings.fontFamily,
    );
    final TextStyle titleStyle = readerChapterTitleStyle(
      tokens: tokens,
      foreground: palette.foreground,
      bodyFontSize: style.fontSize ?? 16,
    );

    // ADR-0062 §决策 5：读出声时把那句话画出来。这个 provider 只在读声时才有值，
    // 所以没开 TTS 的读者只多一次空读，不会因此拉起语音引擎。
    final ReaderTtsHighlight? spoken = ref.watch(readerTtsHighlighterProvider);
    final ReaderFlowHighlight? highlight = spoken == null
        ? null
        : (url: spoken.chapterUrl, start: spoken.start, end: spoken.end);

    // 段距、首行缩进与「删掉正文首行重复的章节名」都是**排版**（ADR-0087 §决策 4）：
    // 在渲染前套一次，正文数据与缓存都不动。
    //
    // 正文按**章节下标**交给页表（不是按 URL）：目录里两章指向同一个地址是抓取站点的常见形状，
    // 按 URL 归并会把它们压成一份正文，看起来就是同一章被打印了两遍（ADR-0087 §决策 1）。
    // 锚点章的正文是从 provider 拿的，预取表里没有它；记下来，否则读者换到下一章后
    // 这一章就退回占位页（上一章整章变矮 = 正是会跳字的那种结构变化）。
    if (currentData != null && currentData.isNotEmpty) {
      _prefetchedBodies[chapter.url] = currentData;
    }
    final Map<int, String> bodies = <int, String>{};
    final Set<int> failed = <int>{};
    for (final int index in window) {
      final ReadingChapter candidate = chapters[index];
      if (_prefetchFailed.contains(candidate.url) ||
          (candidate.url == chapter.url && content is ParseFailure<String>)) {
        failed.add(index);
      }
      final String? raw = candidate.url == chapter.url
          ? currentData
          : _prefetchedBodies[candidate.url];
      if (raw != null && raw.isNotEmpty) {
        bodies[index] = _laidOutBody(index, candidate, raw, settings);
      }
    }
    _remembered(bodies[session.chapterIndex] ?? '');
    final ({int chapterIndex, int charOffset}) target =
        _pendingJump ??
        (chapterIndex: session.chapterIndex, charOffset: session.charOffset);
    final ReaderFlowRestore restore = (
      chapterIndex: target.chapterIndex,
      charOffset: target.charOffset,
      nonce: _restoreNonce,
    );
    final double padding = _paddingOf(settings);
    final TextStyle highlightStyle = spokenSentenceStyle(context, style);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    // 页表在 build 里算好再交给流程：流程只画、不度量，所以任何结构变化都能在同一帧里补偿
    // （ADR-0087 §决策 1/2）。尺寸取正文盒子——扣掉两侧与上下的页边距。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size box = Size(
          (constraints.maxWidth - 2 * padding).clamp(0.0, double.infinity),
          (constraints.maxHeight - 2 * padding).clamp(0.0, double.infinity),
        );
        final ReaderPageTable table = buildReaderPageTable(
          chapters: chapters,
          firstChapter: _windowFirst,
          lastChapter: last,
          bodies: bodies,
          failed: failed,
          size: box,
          bodyStyle: style,
          titleStyle: titleStyle,
          titleGap: readerChapterTitleGap(tokens),
          loadingExtent: tokens.spacing.xxl + tokens.spacing.lg,
          textScaler: textScaler,
          cache: _measures,
        );

        // 三区点击（ADR-0051 §决策 1）：中间 ⅓ 唤出菜单，左右各 ⅓ 收起它。
        return _tapZones(
          child: switch (settings.pageMode) {
            ReaderPageMode.scroll => ReaderScrollFlow(
              key: const ValueKey<String>('reader-scroll'),
              table: table,
              restore: restore,
              highlight: highlight,
              style: style,
              highlightStyle: highlightStyle,
              titleStyle: titleStyle,
              padding: padding,
              onProgress: _followFlow,
              onSettled: _settleFlow,
              onNeedChapter: _needChapter,
            ),
            ReaderPageMode.paged => ReaderPagedFlow(
              key: const ValueKey<String>('reader-paged'),
              table: table,
              restore: restore,
              highlight: highlight,
              style: style,
              highlightStyle: highlightStyle,
              titleStyle: titleStyle,
              padding: padding,
              onProgress: _followFlow,
              onSettled: _settleFlow,
              onNeedChapter: _needChapter,
            ),
          },
        );
      },
    );
  }

  /// Follows the flow: a new chapter switches the session, a new offset inside it is progress.
  ///
  /// Crossing a chapter boundary is **not** a jump: the flows keep their scroll position and the
  /// page only moves the session, which is what the tool bar, the read-aloud engine and the saved
  /// position follow (ADR-0085 §决策 2).
  void _followFlow(int index, int charOffset) {
    final ({int chapterIndex, int charOffset})? pending = _pendingJump;
    if (pending != null) {
      if (index != pending.chapterIndex) {
        // 显式跳转还没落地：这一刻流程报上来的是读者原来那一章，写回会话就把跳转撤销了。
        return;
      }
      _pendingJump = null;
    }
    final ReaderSession session = ref.read(
      readerSessionProvider(_book).notifier,
    );
    final int? current = ref
        .read(readerSessionProvider(_book))
        .value
        ?.chapterIndex;
    _lastIndex = index;
    _lastOffset = charOffset;
    if (current == index) {
      session.updateOffset(charOffset);

      return;
    }
    unawaited(session.selectChapter(index, charOffset: charOffset));
  }

  /// Writes the position out when a scroll or a page turn settles (ADR-0044 §决策 2).
  void _settleFlow(int index, int charOffset) {
    _followFlow(index, charOffset);
    unawaited(ref.read(readerSessionProvider(_book).notifier).saveProgress());
    _trimWindow(index);
  }

  /// Drops the chapters the reader has left far behind, once the scroll has come to rest.
  ///
  /// The window only grows while the reader moves forward (ADR-0087 §决策 2), so without this a
  /// long read would keep every chapter's body alive. Trimming is exact — the pages above the
  /// viewport come off, and the flow puts the reader's own sentence back — so it is only done when
  /// nothing is in motion, and only when at least three chapters are behind.
  void _trimWindow(int index) {
    final int wanted = (index - 1).clamp(0, _chapters.length - 1);
    if (_windowFirst < 0 || wanted - _windowFirst < 3 || !mounted) {
      return;
    }
    setState(() => _windowFirst = wanted);
  }

  /// Reads the body of chapter [index] on the flow's behalf.
  ///
  /// [explicit] separates the two callers ADR-0085 §决策 5 merged: a page that is merely waiting
  /// (relay) and the reader pressing «reload» (retry). Only the retry may clear the "already failed"
  /// mark and only the retry may re-ask for the anchor chapter — a relay that did either would let the
  /// screen and the prefetch queue take turns asking for the same chapter, one request per frame
  /// (`docs/dev/adr/0088-crossing-limit-and-prefetch-window.md`).
  void _needChapter(int index, {bool explicit = false}) {
    if (index < 0 || index >= _chapters.length) {
      return;
    }
    final ReadingChapter chapter = _chapters[index];
    if (index == _lastSession?.chapterIndex) {
      // 锚点章由页面自己 watch 的 provider 负责：接力加载什么都不用做（**不要** read 它，
      // `ref.read` 会把一个没人看的 provider 现造出来，等于凭空多发一个请求）。
      _prefetchFailed.remove(chapter.url);
      if (explicit) {
        ref.invalidate(readerContentProvider((_book, chapter.url)));
      }

      return;
    }
    if (!explicit &&
        (_prefetchFailed.contains(chapter.url) ||
            _prefetching.contains(chapter.url))) {
      // 已经失败过、或正在取：接力加载不再另发一个请求。
      return;
    }
    if (explicit) {
      _prefetchFailed.remove(chapter.url);
      ref.invalidate(readerContentProvider((_book, chapter.url)));
    }
    // 队列里本来就有它（半径内最近的那些）时不动顺序——顺序就是「最近优先」；
    // 只有它不在队列里（失败后掉队、或超出半径）才插到队首。
    if (!_prefetchQueue.contains(index)) {
      _prefetchQueue.insert(0, index);
    }
    _pumpPrefetch();
  }

  /// [body] as the page table wants it: the duplicate title removed, then the paragraph transform.
  ///
  /// Keyed by **chapter index** and cached, because the reader rebuilds on every progress write: the
  /// transform has to run once per body, not once per frame (C-PERF-1). The signature carries the
  /// chapter's title and the book's name because the duplicate-title strip compares against them
  /// (ADR-0087 §决策 4) — a renamed source would otherwise keep the stale text.
  String _laidOutBody(
    int index,
    ReadingChapter chapter,
    String body,
    ReaderSettings settings,
  ) {
    final int signature = Object.hash(
      settings.paragraphSpacing,
      settings.firstLineIndent,
      body.length,
      chapter.title,
      _book.name,
    );
    final ({int signature, String text})? cached = _laidOut[index];
    if (cached != null && cached.signature == signature) {
      return cached.text;
    }
    final String text = readerBodyText(
      readerStripDuplicateTitle(
        body,
        title: chapter.title,
        bookName: _book.name,
      ),
      settings,
    );
    _laidOut[index] = (signature: signature, text: text);

    return text;
  }

  /// Drops what the reader no longer needs, in two layers (ADR-0088 §决策 3).
  ///
  /// The raw bodies stay for the whole ±[_prefetchRadius] window — that is the point of fetching them
  /// ahead. The laid-out text and the measurements only stay for the **rendered** window: they are
  /// derived (a font-size change throws them away anyway), and keeping thirty chapters of typeset
  /// text around buys nothing.
  void _retainBodies(int anchorIndex, Set<int> window) {
    final Set<String> urls = <String>{
      for (
        var index = anchorIndex - _prefetchRadius;
        index <= anchorIndex + _prefetchRadius;
        index++
      )
        if (index >= 0 && index < _chapters.length) _chapters[index].url,
    };
    _prefetchedBodies.removeWhere(
      (String url, String _) => !urls.contains(url),
    );
    _prefetchFailed.removeWhere((String url) => !urls.contains(url));
    _laidOut.removeWhere(
      (int index, ({int signature, String text}) _) => !window.contains(index),
    );
    _measures.retain(window);
  }

  /// Places the window's first chapter, which may only ever move **back** while reading.
  ///
  /// A chapter is kept once it has been rendered: letting it go while the reader is below it would
  /// change the height above the viewport top, which is exactly what makes text jump
  /// (ADR-0087 §决策 2). An explicit jump resets the window to the anchor's neighbours.
  void _applyWindow(int anchorIndex, int chapterCount) {
    final int wanted = (anchorIndex - 1).clamp(0, chapterCount - 1);
    if (_windowFirst < 0 || wanted < _windowFirst) {
      _windowFirst = wanted;
    }
  }

  /// Runs [action] once the frame that is being built has been laid out.
  ///
  /// The serial prefetch chain hops from one frame to the next, and `addPostFrameCallback` does **not**
  /// schedule a frame: without the explicit `scheduleFrame` the chain stalls the first time nothing
  /// else asks for a repaint (a reader sitting still would stop prefetching).
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => action())
      ..scheduleFrame();
  }

  /// Rebuilds the prefetch queue around [anchorIndex] and starts the first fetch.
  ///
  /// Nearest first (`+1, -1, +2, -2, …`) inside the ±[_prefetchRadius] window, skipping what is
  /// already in hand, already failed, or already in flight. The queue is only rebuilt when the
  /// anchor chapter actually changed: the page rebuilds on every progress write, and reshuffling
  /// thirty entries per frame would restart the reader's own next chapter for no reason.
  void _queuePrefetches(int anchorIndex, int chapterCount) {
    if (_prefetchAnchor == anchorIndex && _prefetchCount == chapterCount) {
      return;
    }
    _prefetchAnchor = anchorIndex;
    _prefetchCount = chapterCount;
    _prefetchQueue.clear();
    for (var distance = 1; distance <= _prefetchRadius; distance++) {
      final int after = anchorIndex + distance;
      final int before = anchorIndex - distance;
      if (after < chapterCount) {
        _prefetchQueue.add(after);
      }
      if (before >= 0) {
        _prefetchQueue.add(before);
      }
    }
    _pumpPrefetch();
  }

  /// Starts the next queued fetch, once the previous one has finished.
  void _pumpPrefetch() {
    if (_prefetching.isNotEmpty ||
        _prefetchQueue.isEmpty ||
        _chapters.isEmpty) {
      return;
    }
    // 队列里的下标可能已经过期（目录变了、换源了）：跳过不可用的那些。
    while (_prefetchQueue.isNotEmpty) {
      final int index = _prefetchQueue.removeAt(0);
      if (index < 0 || index >= _chapters.length) {
        continue;
      }
      final ReadingChapter chapter = _chapters[index];
      if (_prefetchedBodies.containsKey(chapter.url) ||
          _prefetchFailed.contains(chapter.url) ||
          _prefetching.contains(chapter.url)) {
        continue;
      }
      _prefetching.add(chapter.url);
      final int generation = _prefetchGeneration;
      _afterFrame(() {
        if (!mounted || generation != _prefetchGeneration) {
          // 换源已经把旧 generation 的预取全部作废；新 generation 的标记不能在这里删。
          if (generation == _prefetchGeneration) {
            _prefetching.remove(chapter.url);
          }

          return;
        }
        unawaited(_prefetch(chapter, generation));
      });

      return;
    }
  }

  /// Fetches [chapter] through the production content port and keeps the body for the next turn.
  ///
  /// It deliberately does **not** listen to `readerContentProvider`: that would only keep a
  /// provider alive, not guarantee the body is in hand before the turn. The port writes the same
  /// content cache the normal read uses, and the map below is what the flows render from.
  ///
  /// The request carries the very same chapter context as [readerContentProvider] — its place in
  /// the TOC, the chapter after it, VIP/pay flags — because a prefetched body is now the **usual**
  /// one: a rule that reads `nextChapterUrl` must not see a different value just because the
  /// reader got there by scrolling (M25/S3b).
  Future<void> _prefetch(ReadingChapter chapter, int generation) async {
    try {
      final int index = _chapters.indexWhere(
        (ReadingChapter candidate) => candidate.url == chapter.url,
      );
      final String nextUrl = index >= 0 && index + 1 < _chapters.length
          ? _chapters[index + 1].url
          : '';
      final ParseResult<String> result = await ref
          .read(readerChapterContentProvider)
          .fetch(
            sourceUrl: _book.sourceUrl,
            chapterUrl: chapter.url,
            bookName: _book.name,
            chapterTitle: chapter.title,
            bookUrl: _book.bookUrl,
            tocUrl: _book.tocUrl,
            nextChapterUrl: nextUrl,
            isVip: chapter.isVip,
            isPay: chapter.isPay,
            isVolume: chapter.isVolume,
            updateTime: chapter.updateTime,
          );
      if (!mounted || generation != _prefetchGeneration) {
        return;
      }
      if (result case ParseSuccess<String>(:final String data)
          when data.isNotEmpty) {
        setState(() => _prefetchedBodies[chapter.url] = data);
      } else {
        // 失败或空正文：记下来避免每个 build 重试，并让占位条换成「重新加载」。
        setState(() => _prefetchFailed.add(chapter.url));
      }
    } on Exception {
      if (mounted && generation == _prefetchGeneration) {
        setState(() => _prefetchFailed.add(chapter.url));
      }
    } finally {
      if (generation == _prefetchGeneration) {
        _prefetching.remove(chapter.url);
        // 串行的下一章；帧后调用，免得在 paint/build 期间 setState（C-ERR / C-STATE）。
        if (mounted) {
          _afterFrame(() {
            if (mounted) {
              _pumpPrefetch();
            }
          });
        }
      }
    }
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

  /// Remembers the loaded body for the percent label and the bookmark excerpt.
  void _remembered(String body) {
    _lastBody = body;
  }

  /// The padding the body uses, from the page-margin preset (ADR-0051 §决策 4).
  double _paddingOf(ReaderSettings settings) =>
      readerPagePaddingOf(settings.pagePadding);

  /// Opens the read-aloud sheet and remembers its notifier for the exit rule.
  ///
  /// 用 [_book] 而不是路由里的 `widget.book`：换源之后朗读必须跟着新源走，否则它会用旧源的
  /// 章节地址去读正文。
  void _openTts() {
    _tts = ref.read(readerTtsProvider(_book).notifier);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => ReaderTtsSheet(book: _book),
      ),
    );
  }

  /// Opens the in-book search and jumps to the hit the user picks
  /// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
  ///
  /// The hit's `offsetInText` is the reader's own text offset, so it travels as the session's
  /// `charOffset` — exactly how a bookmark lands on its sentence (ADR-0066 §决策 7).
  void _openSearch(List<ReadingChapter> chapters) {
    if (chapters.isEmpty) {
      return;
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: ReaderSearchSheet(
            book: _book,
            chapters: chapters,
            fromIndex: _currentIndex,
            onSelected: (BookSearchHit hit) {
              Navigator.of(context).pop();
              _jumpToChapter(hit.chapterIndex, charOffset: hit.offsetInText);
            },
          ),
        ),
      ),
    );
  }

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
        isScrollControlled: true,
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
