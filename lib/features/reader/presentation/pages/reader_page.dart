import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reading_progress_store.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_pagination.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
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
          sourceUrl: widget.book.sourceUrl,
          bookUrl: widget.book.bookUrl,
          position: ReadingPosition(
            chapterUrl: chapter.url,
            chapterName: chapter.title.isEmpty ? null : chapter.title,
            charOffset: _lastOffset,
          ),
        ),
      );
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final ReaderSettings settings =
        ref.watch(readerSettingsProvider).value ?? ReaderSettings.defaults;
    final ({Color background, Color foreground}) palette = readerPalette(
      tokens,
      settings.background,
    );
    final AsyncValue<ParseResult<List<ReadingChapter>>> chapters = ref.watch(
      readerChaptersProvider(widget.book),
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: Text(_title(chapters, l10n)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: l10n.readerTocAction,
            onPressed: () => _openToc(_chaptersOf(chapters)),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: l10n.readerSettingsAction,
            onPressed: () => _openSettings(settings),
          ),
        ],
      ),
      body: switch (chapters) {
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
            ParseFailure<List<ReadingChapter>>(:final ParseFailureKind kind) =>
              FailureMessage(
                kind: kind,
                onRetry: () =>
                    ref.invalidate(readerChaptersProvider(widget.book)),
              ),
          },
        AsyncError<ParseResult<List<ReadingChapter>>>() => FailureMessage(
          kind: ParseFailureKind.parseFailed,
          onRetry: () => ref.invalidate(readerChaptersProvider(widget.book)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: _navBar(chapters, palette),
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
      readerSessionProvider(widget.book),
    );
    _applyStartChapter(chapters, session.value);

    return switch (session) {
      AsyncData<ReaderSessionState>(:final ReaderSessionState value) =>
        _chapterBody(chapters, value, settings, palette),
      AsyncError<ReaderSessionState>() => FailureMessage(
        kind: ParseFailureKind.parseFailed,
        onRetry: () => ref.invalidate(readerSessionProvider(widget.book)),
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
        ref
            .read(readerSessionProvider(widget.book).notifier)
            .selectChapter(index),
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
    final M3ETheme tokens = context.m3e;
    final TextStyle style = readerTextStyle(
      tokens: tokens,
      fontScale: settings.fontScale * MediaQuery.textScalerOf(context).scale(1),
      lineHeight: settings.lineHeight,
      foreground: palette.foreground,
    );

    final AsyncValue<ParseResult<String>> content = ref.watch(
      readerContentProvider((widget.book, chapter.url)),
    );

    return switch (content) {
      AsyncData<ParseResult<String>>(:final ParseResult<String> value) =>
        switch (value) {
          ParseSuccess<String>(:final String data) =>
            settings.pageMode == ReaderPageMode.scroll
                ? _scrollBody(chapter, data, style, session.charOffset, palette)
                : _pagedBody(
                    chapter,
                    data,
                    style,
                    session.charOffset,
                    chapters.length,
                    session.chapterIndex,
                    palette,
                  ),
          ParseFailure<String>(:final ParseFailureKind kind) => FailureMessage(
            kind: kind,
            onRetry: () => ref.invalidate(
              readerContentProvider((widget.book, chapter.url)),
            ),
          ),
        },
      AsyncError<ParseResult<String>>() => FailureMessage(
        kind: ParseFailureKind.parseFailed,
        onRetry: () =>
            ref.invalidate(readerContentProvider((widget.book, chapter.url))),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// The scrolling body: one `Text`, restored once per chapter, saved when a scroll settles.
  Widget _scrollBody(
    ReadingChapter chapter,
    String body,
    TextStyle style,
    int initialOffset,
    ({Color background, Color foreground}) palette,
  ) {
    final M3ETheme tokens = context.m3e;

    return NotificationListener<ScrollEndNotification>(
      onNotification: (ScrollEndNotification notification) {
        // 滚动停下时记一次：按比例换算成字符偏移（ADR-0044 §决策 4）。
        final double max = _scroll.hasClients
            ? _scroll.position.maxScrollExtent
            : 0;
        final int offset = max <= 0
            ? 0
            : (_scroll.offset / max * body.length).round();
        _rememberOffset(offset);
        unawaited(
          ref.read(readerSessionProvider(widget.book).notifier).saveProgress(),
        );

        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: _restoredScrollText(chapter, body, style, initialOffset),
      ),
    );
  }

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
  ) {
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
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
          ref.read(readerSessionProvider(widget.book).notifier).nextChapter(),
        ),
      ),
    );
  }

  /// Remembers [offset] in the session; the next chapter switch or exit writes it.
  void _rememberOffset(int offset) {
    _lastOffset = offset;
    ref.read(readerSessionProvider(widget.book).notifier).updateOffset(offset);
  }

  /// The previous / next chapter bar with the position in the middle.
  Widget _navBar(
    AsyncValue<ParseResult<List<ReadingChapter>>> chapters,
    ({Color background, Color foreground}) palette,
  ) {
    final List<ReadingChapter> known = _chaptersOf(chapters);
    final AsyncValue<ReaderSessionState> session = ref.watch(
      readerSessionProvider(widget.book),
    );
    final int index = session.value?.chapterIndex ?? 0;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.readerPreviousChapter,
            color: palette.foreground,
            onPressed: index <= 0
                ? null
                : () => unawaited(
                    ref
                        .read(readerSessionProvider(widget.book).notifier)
                        .previousChapter(),
                  ),
          ),
          Text(
            known.isEmpty ? '' : '${index + 1} / ${known.length}',
            style: context.m3e.typography.base.labelLarge?.copyWith(
              color: palette.foreground,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.readerNextChapter,
            color: palette.foreground,
            onPressed: known.isEmpty || index >= known.length - 1
                ? null
                : () => unawaited(
                    ref
                        .read(readerSessionProvider(widget.book).notifier)
                        .nextChapter(),
                  ),
          ),
        ],
      ),
    );
  }

  /// The chapter list of the current provider state, empty while it loads or fails.
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
    final int index =
        ref.watch(readerSessionProvider(widget.book)).value?.chapterIndex ?? 0;
    if (index < known.length && known[index].title.isNotEmpty) {
      return known[index].title;
    }

    return widget.book.name.isEmpty
        ? l10n.bookSourceReaderTitle
        : widget.book.name;
  }

  /// Opens the chapter list and jumps to the chosen chapter.
  void _openToc(List<ReadingChapter> chapters) {
    if (chapters.isEmpty) {
      return;
    }
    final int current =
        ref.read(readerSessionProvider(widget.book)).value?.chapterIndex ?? 0;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) => SafeArea(
          child: ListView.builder(
            itemCount: chapters.length,
            itemBuilder: (BuildContext context, int index) => ListTile(
              selected: index == current,
              title: Text(chapters[index].title),
              onTap: () {
                unawaited(
                  ref
                      .read(readerSessionProvider(widget.book).notifier)
                      .selectChapter(index),
                );
                Navigator.of(context).pop();
              },
            ),
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
