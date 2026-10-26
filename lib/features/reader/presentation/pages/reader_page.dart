import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
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
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_search_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_source_sheet.dart';
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
  final ScrollController _scroll = ScrollController();

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

  /// The chapter whose restore offset was already applied (the page restores once per chapter).
  String? _restoredChapterUrl;

  /// Bumped when a jump must restore again inside the **same** chapter.
  ///
  /// The paged body restores once per widget instance, so a bookmark jump that stays in the same
  /// chapter would otherwise be ignored; a new key gives it a fresh body that restores at the
  /// requested offset (ADR-0066 §决策 7).
  int _restoreNonce = 0;

  /// Whether the chapter the route asked for was already opened.
  bool _appliedStartChapter = false;

  /// The read-aloud notifier, captured when its sheet is opened.
  ///
  /// The sheet disposes when it closes, but speech may continue; keeping the notifier here lets
  /// `dispose` apply the “stop when leaving the reader” rule (ADR-0054 §决策 5).
  ReaderTts? _tts;

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
    _sessionStartedAt = _clock?.now();
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
    _chromeTimer?.cancel();
    _scroll.dispose();
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
          if (brightness < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  // 亮度遮罩用主题的 scrim：它本来就是「压暗内容」的角色，避免硬编码黑色。
                  color: tokens.colors.scrim.withValues(alpha: 1 - brightness),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _chromeVisible
          ? _toolBar(context, l10n, chapters, palette, marks)
          : null,
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
  void _jumpToChapter(int index, {int charOffset = 0}) {
    if (_chapters.isEmpty) {
      return;
    }
    final int target = index.clamp(0, _chapters.length - 1);
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
          _restoredChapterUrl = null;
          _lastBody = null;
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
      // 同一章内的跳转必须让正文重新恢复一次：滚动正文按章缓存恢复目标，分页正文每个实例只恢复
      // 一次，所以这里清掉章标记并换一个实例（见 [_restoreNonce]）。
      _restoredChapterUrl = null;
      _restoreNonce++;
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

    // L1 预取：进入本章时把下一章正文读进正文缓存，翻章时直接命中而不等网络。
    // 监听（而不是 `read`）让 autoDispose 的 provider 活到内容到达；回调本身不重建页面。
    if (session.chapterIndex + 1 < chapters.length) {
      final ReadingChapter nextChapter = chapters[session.chapterIndex + 1];
      ref.listen(
        readerContentProvider((_book, nextChapter.url)),
        (
          AsyncValue<ParseResult<String>>? previous,
          AsyncValue<ParseResult<String>> next,
        ) {},
      );
    }

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
    // ADR-0062 §决策 5：读出声时把那句话画出来。这个 provider 只在读声时才有值，
    // 所以没开 TTS 的读者只多一次空读，不会因此拉起语音引擎。
    final ReaderTtsHighlight? spoken = ref.watch(readerTtsHighlighterProvider);
    final ({int start, int end})? spokenRange =
        spoken != null && spoken.chapterUrl == chapter.url
        ? (start: spoken.start, end: spoken.end)
        : null;

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
                      spokenRange,
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
                      spokenRange,
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
    ({int start, int end})? spokenRange,
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
      child: _restoredScrollText(
        chapter,
        body,
        style,
        initialOffset,
        spokenRange,
      ),
    ),
  );

  /// The body text, jumped to [initialOffset] the first time this chapter is shown.
  Widget _restoredScrollText(
    ReadingChapter chapter,
    String body,
    TextStyle style,
    int initialOffset,
    ({int start, int end})? spokenRange,
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

    return readingText(
      body: body,
      style: style,
      highlightStyle: spokenSentenceStyle(context, style),
      highlight: spokenRange,
    );
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
    ({int start, int end})? spokenRange,
  ) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: _PagedBody(
        key: ValueKey<String>(
          '${chapter.url}|${style.fontSize}|${style.height}|$_restoreNonce',
        ),
        text: body,
        style: style,
        initialOffset: initialOffset,
        foreground: palette.foreground,
        isLastChapter: chapterIndex == chapterCount - 1,
        spokenRange: spokenRange,
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
    required this.spokenRange,
    required this.onOffsetChanged,
    required this.onNextChapter,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int initialOffset;
  final Color foreground;
  final bool isLastChapter;

  /// The sentence being read aloud, as an offset range of [text] (ADR-0062 §决策 5).
  final ({int start, int end})? spokenRange;

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
              child: readingText(
                body: widget.text,
                start: start,
                end: end,
                style: widget.style,
                highlightStyle: spokenSentenceStyle(context, widget.style),
                highlight: widget.spokenRange,
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
