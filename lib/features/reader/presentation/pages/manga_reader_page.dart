import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_page.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/manga_queries.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_style.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The largest zoom the manga reader offers (a gesture parameter, not a layout token).
const double _maxMangaZoom = 4;

/// Reads one image source: a vertical strip or one image per screen
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053).
///
/// It shares the **session** with the text reader — same chapter list, same `reading_progress`
/// row — but stores the **page index** in `charOffset`: a fraction of the body length is meaningless
/// for images, while "page 7 of 20" is what resumes a chapter (ADR-0053 §决策 3).
///
/// Three things are worth knowing:
///
/// * the page is restored once per chapter from the session, and written back through the same
///   progress port the text reader uses, so the shelf's "读到第几章" keeps working;
/// * images are requested with the source's headers (`ReadingPage.headers`): a site that checks the
///   `Referer` shows broken tiles otherwise (ADR-0053 §决策 2);
/// * a failed tile is its own retry, not a chapter failure: one dead image must not cost the page.
class MangaReaderPage extends ConsumerStatefulWidget {
  /// Creates the page for [book], optionally starting at [chapterUrl].
  const MangaReaderPage({
    required this.book,
    this.chapterUrl,
    this.imageProvider,
    super.key,
  });

  /// The book being read.
  final ReaderBook book;

  /// The chapter to open, or `null` to resume where the reader stopped.
  final String? chapterUrl;

  /// The image loader, or `null` for the real cached network provider.
  ///
  /// It is an **injection seam** for widget tests, the same shape `CoverImage` uses: the test
  /// supplies a `MemoryImage`, so the page's layout, paging, retry and progress paths are testable
  /// without an HTTP client or `path_provider` (C-PERF-3 stays the production implementation).
  final ImageProvider Function(ReadingPage page)? imageProvider;

  @override
  ConsumerState<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends ConsumerState<MangaReaderPage> {
  final ScrollController _scroll = ScrollController();

  /// The current page of the open chapter (0-based).
  int _page = 0;

  /// How many times each page index was asked to retry, so the image cache entry is bypassed.
  final Map<int, int> _retries = <int, int>{};

  /// The chapter whose restored page was already applied.
  String? _restoredChapterUrl;

  /// Whether the chapter the route asked for was already opened.
  bool _appliedStartChapter = false;

  /// The last page index handed to the session, to avoid a write per scroll pixel.
  int _reportedPage = -1;

  @override
  void dispose() {
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
    final AsyncValue<ReaderSessionState> session = ref.watch(
      readerSessionProvider(widget.book),
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: Text(widget.book.name),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              settings.pageMode == ReaderPageMode.scroll
                  ? Icons.swap_horiz
                  : Icons.swap_vert,
            ),
            tooltip: settings.pageMode == ReaderPageMode.scroll
                ? l10n.readerPageModePaged
                : l10n.readerPageModeScroll,
            onPressed: () => unawaited(
              ref
                  .read(readerSettingsProvider.notifier)
                  .apply(
                    settings.copyWith(
                      pageMode: settings.pageMode == ReaderPageMode.scroll
                          ? ReaderPageMode.paged
                          : ReaderPageMode.scroll,
                    ),
                  ),
            ),
          ),
        ],
      ),
      body: switch ((chapters, session)) {
        (AsyncData<ParseResult<List<ReadingChapter>>>(:final value), _) =>
          switch (value) {
            ParseFailure<List<ReadingChapter>>(:final ParseFailureKind kind) =>
              FailureMessage(
                kind: kind,
                onRetry: () =>
                    ref.invalidate(readerChaptersProvider(widget.book)),
              ),
            ParseSuccess<List<ReadingChapter>>(
              :final List<ReadingChapter> data,
            ) =>
              data.isEmpty
                  ? StateMessage(message: l10n.readerNoChapter)
                  : _withSession(l10n, data, session, palette, settings),
          },
        (AsyncError<ParseResult<List<ReadingChapter>>>(), _) => FailureMessage(
          kind: ParseFailureKind.parseFailed,
          onRetry: () => ref.invalidate(readerChaptersProvider(widget.book)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Renders the open chapter once the session (chapter index + page) is known.
  Widget _withSession(
    AppLocalizations l10n,
    List<ReadingChapter> chapters,
    AsyncValue<ReaderSessionState> session,
    ({Color background, Color foreground}) palette,
    ReaderSettings settings,
  ) {
    final ReaderSessionState? state = session.value;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _applyStartChapter(chapters, state);
    final int index = state.chapterIndex.clamp(0, chapters.length - 1);
    final ReadingChapter chapter = chapters[index];
    final AsyncValue<ParseResult<List<ReadingPage>>> pages = ref.watch(
      mangaPagesProvider((widget.book, chapter.url)),
    );

    return Column(
      children: <Widget>[
        Expanded(
          child: switch (pages) {
            AsyncData<ParseResult<List<ReadingPage>>>(:final value) =>
              switch (value) {
                ParseFailure<List<ReadingPage>>(:final ParseFailureKind kind) =>
                  FailureMessage(
                    kind: kind,
                    onRetry: () => ref.invalidate(
                      mangaPagesProvider((widget.book, chapter.url)),
                    ),
                  ),
                ParseSuccess<List<ReadingPage>>(
                  :final List<ReadingPage> data,
                ) =>
                  _pages(l10n, chapter, data, state, settings),
              },
            AsyncError<ParseResult<List<ReadingPage>>>() => FailureMessage(
              kind: ParseFailureKind.parseFailed,
              onRetry: () => ref.invalidate(
                mangaPagesProvider((widget.book, chapter.url)),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        _bottomBar(l10n, chapters, index, palette, _page + 1, _pageTotal),
      ],
    );
  }

  /// The page count of the open chapter, taken from the last successful load.
  int _pageTotal = 0;

  /// The page strip / pager of one chapter.
  Widget _pages(
    AppLocalizations l10n,
    ReadingChapter chapter,
    List<ReadingPage> pages,
    ReaderSessionState session,
    ReaderSettings settings,
  ) {
    _pageTotal = pages.length;
    _restorePage(chapter, pages.length, session.charOffset, settings.pageMode);

    // 「一张图占一屏」的图片高度要用**列表视口**的高度：整块屏幕还要扣掉 AppBar、底栏与
    // 系统栏，按屏幕高度画会让每一页都比视口高一点，滑动时出现半个页面的跳动。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewport = constraints.maxHeight;
        if (settings.pageMode == ReaderPageMode.paged) {
          return _PagedManga(
            // 换章就是一个新的 PageView 状态：initialPage 只在该章首次构建时读一次。
            key: ValueKey<String>('${chapter.url}|${pages.length}'),
            pages: pages,
            initialPage: _page,
            onPageChanged: (int index) => _onPageChanged(index, pages),
            builder: (BuildContext context, int index) =>
                _pageTile(context, index, pages[index], viewport),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification) {
              _trackScroll(
                pages.length,
                settled: notification is ScrollEndNotification,
              );
            }

            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            itemCount: pages.length,
            itemBuilder: (BuildContext context, int index) =>
                _pageTile(context, index, pages[index], viewport),
          ),
        );
      },
    );
  }

  /// Applies the stored page of [chapter] once, and resets the strip for it.
  void _restorePage(
    ReadingChapter chapter,
    int pageCount,
    int storedPage,
    ReaderPageMode mode,
  ) {
    if (_restoredChapterUrl == chapter.url) {
      return;
    }
    _restoredChapterUrl = chapter.url;
    _page = pageCount == 0 ? 0 : storedPage.clamp(0, pageCount - 1);
    _reportedPage = _page;
    if (mode == ReaderPageMode.scroll) {
      // 懒加载列表里第 N 页可能还没被建出来，只能按比例跳过去（ADR-0053 §决策 3 的近似）。
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted || !_scroll.hasClients || pageCount <= 1) {
          return;
        }
        final double fraction = _page / (pageCount - 1);
        _scroll.jumpTo(_scroll.position.maxScrollExtent * fraction);
      });
    }
  }

  /// One image, its own failure tile, and the header-carrying request.
  ///
  /// [viewportHeight] is the height the surrounding list/page view really has; a `SINGLE` page
  /// fills it exactly, so one image is one screenful and a swipe lands on the next page.
  Widget _pageTile(
    BuildContext context,
    int index,
    ReadingPage page,
    double viewportHeight,
  ) {
    final M3ETheme tokens = context.m3e;

    // `SINGLE` 是「一张图占一屏」：按视口高度约束、在框内等比缩放；其余（含未实现的对齐分支）
    // 仍是整宽顺排（ADR-0069 G5）。
    final bool single = page.style == MangaImageStyle.single;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: _ZoomableImage(
        child: Image(
          // 重试就是换一个 key：同一地址的失败结果不会一直留在缓存里。
          key: ValueKey<String>('${page.url}#${_retries[index] ?? 0}'),
          image: _imageOf(page),
          width: double.infinity,
          height: single ? viewportHeight - tokens.spacing.sm : null,
          fit: single ? BoxFit.contain : BoxFit.fitWidth,
          frameBuilder:
              (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) => wasSynchronouslyLoaded || frame != null
              ? child
              : Padding(
                  padding: EdgeInsets.all(tokens.spacing.xl),
                  child: const Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) => _retryTile(context, index),
        ),
      ),
    );
  }

  /// The provider for [page]: the injected one in tests, the cached network one in production.
  ImageProvider _imageOf(ReadingPage page) =>
      widget.imageProvider?.call(page) ??
      CachedNetworkImageProvider(page.url, headers: page.headers);

  /// The tile an image that failed to load shows: it names the problem and offers a retry.
  Widget _retryTile(BuildContext context, int index) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: tokens.colors.outline),
          SizedBox(height: tokens.spacing.sm),
          Text(l10n.mangaImageFailed, textAlign: TextAlign.center),
          SizedBox(height: tokens.spacing.sm),
          TextButton.icon(
            onPressed: () =>
                setState(() => _retries[index] = (_retries[index] ?? 0) + 1),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.actionRetry),
          ),
        ],
      ),
    );
  }

  /// Tracks the visible page in scroll mode from the scroll extent (an estimate, by design).
  void _trackScroll(int pageCount, {required bool settled}) {
    if (!_scroll.hasClients || pageCount <= 1) {
      return;
    }
    final double max = _scroll.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    final double fraction = (_scroll.offset / max).clamp(0, 1);
    final int page = (fraction * (pageCount - 1)).round();
    if (page != _page) {
      setState(() => _page = page);
    }
    _remember(page);
    if (settled) {
      unawaited(_save());
    }
  }

  /// Handles a settled page change in paged mode.
  void _onPageChanged(int index, List<ReadingPage> pages) {
    setState(() => _page = index);
    _remember(index);
    _prefetch(index, pages);
    unawaited(_save());
  }

  /// Tells the session where the user is, without writing yet.
  void _remember(int page) {
    if (_reportedPage == page) {
      return;
    }
    _reportedPage = page;
    ref.read(readerSessionProvider(widget.book).notifier).updateOffset(page);
  }

  /// Writes the page through the progress port (the session owns the table).
  Future<void> _save() =>
      ref.read(readerSessionProvider(widget.book).notifier).saveProgress();

  /// Warms the previous and next image so a page turn does not start from a blank tile.
  void _prefetch(int index, List<ReadingPage> pages) {
    for (final int neighbour in <int>[index - 1, index + 1]) {
      if (neighbour < 0 || neighbour >= pages.length) {
        continue;
      }
      final ReadingPage page = pages[neighbour];
      unawaited(
        precacheImage(
          _imageOf(page),
          context,
          // 预取失败不打扰读者：滑到那一页时会走正常的失败 / 重试路径。
          onError: (Object _, StackTrace? _) {},
        ),
      );
    }
  }

  /// Opens the chapter the route asked for once the chapter list and the session are ready.
  void _applyStartChapter(
    List<ReadingChapter> chapters,
    ReaderSessionState session,
  ) {
    if (_appliedStartChapter) {
      return;
    }
    _appliedStartChapter = true;
    final String? target = widget.chapterUrl;
    if (target == null) {
      return;
    }
    final int index = chapters.indexWhere(
      (ReadingChapter chapter) => chapter.url == target,
    );
    if (index < 0 || index == session.chapterIndex) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
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

  /// Chapter navigation plus the page counter.
  Widget _bottomBar(
    AppLocalizations l10n,
    List<ReadingChapter> chapters,
    int index,
    ({Color background, Color foreground}) palette,
    int page,
    int total,
  ) {
    final M3ETheme tokens = context.m3e;
    final ReaderSession session = ref.read(
      readerSessionProvider(widget.book).notifier,
    );

    return BottomAppBar(
      color: palette.background,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.skip_previous),
            tooltip: l10n.readerPreviousChapter,
            onPressed: index <= 0
                ? null
                : () => unawaited(session.previousChapter()),
          ),
          Expanded(
            child: Center(
              // 图片还没读到时 total 是 0：显示「1 / 0」比不显示更容易让人以为坏了。
              child: total <= 0
                  ? const SizedBox.shrink()
                  : Text(
                      l10n.mangaPageIndicator(page, total),
                      style: tokens.typography.base.labelLarge?.copyWith(
                        color: palette.foreground,
                      ),
                    ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: l10n.readerNextChapter,
            onPressed: index >= chapters.length - 1
                ? null
                : () => unawaited(session.nextChapter()),
          ),
        ],
      ),
    );
  }
}

/// A pager that owns its controller, so a chapter change simply replaces the widget state.
class _PagedManga extends StatefulWidget {
  const _PagedManga({
    required this.pages,
    required this.initialPage,
    required this.onPageChanged,
    required this.builder,
    super.key,
  });

  final List<ReadingPage> pages;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext context, int index) builder;

  @override
  State<_PagedManga> createState() => _PagedMangaState();
}

class _PagedMangaState extends State<_PagedManga> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    itemCount: widget.pages.length,
    onPageChanged: widget.onPageChanged,
    itemBuilder: widget.builder,
  );
}

/// An image that zooms on a double tap.
///
/// A always-present [InteractiveViewer] would claim horizontal drags away from the [PageView]
/// (`ScaleGestureRecognizer` wins the arena even with `panEnabled: false`), so at normal scale the
/// tile is a plain image with a double-tap handler and **the pager keeps the swipe**. Zooming wraps
/// it in an [InteractiveViewer] (pinch + pan), and a second double tap resets.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.child});

  final Widget child;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomed = true;
      _controller.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
    });
  }

  void _reset() {
    setState(() {
      _zoomed = false;
      _controller.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_zoomed) {
      return GestureDetector(onDoubleTap: _zoomIn, child: widget.child);
    }

    return GestureDetector(
      onDoubleTap: _reset,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: _maxMangaZoom,
        child: widget.child,
      ),
    );
  }
}
