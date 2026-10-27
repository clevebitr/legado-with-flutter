import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_position.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_session_notifier.freezed.dart';
part 'reader_session_notifier.g.dart';

/// Where the reading session stands: which chapter, and how far into it.
///
/// [charOffset] is the **estimate** ADR-0044 §决策 4 describes — the fraction read times the body
/// length — so it survives a font size change instead of pointing at a stale character.
@freezed
abstract class ReaderSessionState with _$ReaderSessionState {
  /// Creates a session state.
  const factory ReaderSessionState({
    /// Index into the book's chapter list.
    required int chapterIndex,

    /// Estimated character offset inside the current chapter.
    @Default(0) int charOffset,
  }) = _ReaderSessionState;
}

/// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
///
/// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
/// retryable failure message for the failure branch, which is what
/// `docs/dev/architecture.md` §5 asks of every consumer.
@riverpod
Future<ParseResult<List<ReadingChapter>>> readerChapters(
  Ref ref,
  ReaderBook book,
) => ref
    .watch(readerChapterListProvider)
    .fetch(
      sourceUrl: book.sourceUrl,
      tocUrl: book.tocUrl,
      // 书名 / 书籍地址是规则可见的上下文（`java.get('bookName')` / `book.*`，ADR-0049/0055）。
      bookName: book.name,
      bookUrl: book.bookUrl,
    );

/// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
///
/// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
/// instead of letting a detached continuation write into a dead state. The body goes through the
/// same `FetchContent` adapter, so the 5.2 cache still applies.
@riverpod
Future<ParseResult<String>> readerContent(
  Ref ref,
  (ReaderBook, String) request,
) {
  // 目录里这一章与下一章：`java.get('title')`、`chapter` 与 `nextChapterUrl` 三个绑定都从这里来
  // （M25/S3b），目录还没加载时全部按「不知道」传（上游在列表到达前也是这个状态）。
  final _ChapterPosition? position = _positionOf(ref, request.$1, request.$2);

  return ref
      .watch(readerChapterContentProvider)
      .fetch(
        sourceUrl: request.$1.sourceUrl,
        chapterUrl: request.$2,
        bookName: request.$1.name,
        chapterTitle: position?.chapter.title ?? '',
        bookUrl: request.$1.bookUrl,
        tocUrl: request.$1.tocUrl,
        nextChapterUrl: position?.nextUrl ?? '',
        isVip: position?.chapter.isVip ?? false,
        isPay: position?.chapter.isPay ?? false,
        isVolume: position?.chapter.isVolume ?? false,
        updateTime: position?.chapter.updateTime,
      );
}

/// One chapter's place in the table of contents: the chapter itself plus the next chapter's URL.
typedef _ChapterPosition = ({ReadingChapter chapter, String nextUrl});

/// Where [chapterUrl] sits in [book]'s chapter list, or `null` while the list has not loaded.
_ChapterPosition? _positionOf(Ref ref, ReaderBook book, String chapterUrl) {
  final ParseResult<List<ReadingChapter>>? loaded = ref
      .read(readerChaptersProvider(book))
      .value;
  if (loaded is! ParseSuccess<List<ReadingChapter>>) {
    return null;
  }
  final List<ReadingChapter> chapters = loaded.data;
  for (var index = 0; index < chapters.length; index++) {
    if (chapters[index].url == chapterUrl) {
      // 卷标题不是可读章节，但它后面的那一章就是「下一章」——按列表顺序取紧邻的下一条。
      final String nextUrl = index + 1 < chapters.length
          ? chapters[index + 1].url
          : '';

      return (chapter: chapters[index], nextUrl: nextUrl);
    }
  }

  return null;
}

/// The chapter index the session is on, or `null` while it is loading.
///
/// It exists so a listener can depend on the **index only**: the session's state also carries the
/// character offset (the audio player writes it every few seconds), and watching the whole session
/// from the player would reload the track on every progress write. A derived provider recomputes,
/// but its value is `==` to the previous one, so its listeners are not notified.
@riverpod
int? readerChapterIndex(Ref ref, ReaderBook book) =>
    ref.watch(readerSessionProvider(book)).value?.chapterIndex;

/// The reading session: which chapter is open and where the user is inside it
/// (`docs/dev/roadmap.md` 5.3).
///
/// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
/// names, and falls back to the first chapter when the position names one the list no longer has
/// (a source that re-numbered its chapters must not lock the reader out).
///
/// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
/// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
/// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.
@riverpod
class ReaderSession extends _$ReaderSession {
  /// The book this session was built for; `build` may run more than once, so it is re-assigned.
  late ReaderBook _book;

  @override
  Future<ReaderSessionState> build(ReaderBook book) async {
    _book = book;
    final ParseResult<List<ReadingChapter>> chapters = await ref.watch(
      readerChaptersProvider(book).future,
    );
    if (chapters case ParseFailure<List<ReadingChapter>>()) {
      // 目录读不出来时没有「章节」可言：状态停在第一章，页面显示失败态。
      return const ReaderSessionState(chapterIndex: 0);
    }
    final List<ReadingChapter> loaded = switch (chapters) {
      ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
        data,
      ParseFailure<List<ReadingChapter>>() => const <ReadingChapter>[],
    };
    final ReadingPosition? stored = await ref
        .read(readerProgressStoreProvider)
        .read(sourceUrl: book.sourceUrl, bookUrl: book.bookUrl);
    final int restored = _indexOf(loaded, stored?.chapterUrl);
    if (restored < 0) {
      // 存的章节已经不在目录里（源重排了章节）：从第一章开始，而不是把读者挡在门外。
      return const ReaderSessionState(chapterIndex: 0);
    }

    return ReaderSessionState(
      chapterIndex: restored,
      charOffset: stored?.charOffset ?? 0,
    );
  }

  /// Finds the index of [chapterUrl] in [chapters], or `-1` when it is gone.
  int _indexOf(List<ReadingChapter> chapters, String? chapterUrl) {
    if (chapterUrl == null) {
      return -1;
    }
    for (var index = 0; index < chapters.length; index++) {
      if (chapters[index].url == chapterUrl) {
        return index;
      }
    }

    return -1;
  }

  /// Opens chapter [index] at [charOffset] and remembers it.
  ///
  /// [charOffset] is what a bookmark jump needs: the position is already known, so the session
  /// starts there instead of at the top of the chapter (ADR-0066 §决策 7). A chapter switch
  /// passes `0`.
  Future<void> selectChapter(int index, {int charOffset = 0}) async {
    final List<ReadingChapter> chapters = _chapters;
    if (index < 0 || index >= chapters.length) {
      return;
    }
    state = AsyncData<ReaderSessionState>(
      ReaderSessionState(
        chapterIndex: index,
        charOffset: charOffset < 0 ? 0 : charOffset,
      ),
    );
    await saveProgress();
  }

  /// Opens the next chapter, if any.
  Future<void> nextChapter() => selectChapter(_currentIndex + 1);

  /// Opens the previous chapter, if any.
  Future<void> previousChapter() => selectChapter(_currentIndex - 1);

  /// Remembers how far into the current chapter the user is, without writing yet.
  ///
  /// The page calls this while scrolling / page-turning and [saveProgress] when the movement
  /// settles, so a long scroll does not write once per pixel.
  void updateOffset(int charOffset) {
    final ReaderSessionState? current = state.value;
    final int offset = charOffset < 0 ? 0 : charOffset;
    if (current == null || current.charOffset == offset) {
      return;
    }
    state = AsyncData<ReaderSessionState>(current.copyWith(charOffset: offset));
  }

  /// Writes the current position through the progress port.
  Future<void> saveProgress() async {
    final ReaderBook book = _book;
    final List<ReadingChapter> chapters = _chapters;
    final ReaderSessionState? current = state.value;
    if (chapters.isEmpty ||
        current == null ||
        current.chapterIndex >= chapters.length) {
      return;
    }
    final ReadingChapter chapter = chapters[current.chapterIndex];

    try {
      await ref
          .read(readerProgressStoreProvider)
          .write(
            sourceUrl: book.sourceUrl,
            bookUrl: book.bookUrl,
            position: ReadingPosition(
              chapterUrl: chapter.url,
              chapterName: chapter.title.isEmpty ? null : chapter.title,
              charOffset: current.charOffset,
            ),
          );
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Saving the reading position failed: book=${book.bookUrl}',
            error,
            stackTrace,
          );
    }
  }

  /// The chapter list of the current book, empty when it could not be read.
  List<ReadingChapter> get _chapters =>
      switch (ref.read(readerChaptersProvider(_book)).value) {
        ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
          data,
        _ => const <ReadingChapter>[],
      };

  /// The chapter index the session is on.
  int get _currentIndex => state.value?.chapterIndex ?? 0;
}

/// The reader's own settings, and the only place that writes them (`docs/dev/roadmap.md` 5.3).
///
/// `keepAlive` because the reader rebuilds its body on every scroll frame and re-reading
/// `shared_preferences` for each of those would be a platform call per frame (the same reason
/// `Settings` is `keepAlive`).
@Riverpod(keepAlive: true)
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  @override
  Future<ReaderSettings> build() async =>
      (await ref.watch(readerSettingsRepositoryProvider.future)).load();

  /// Stores [settings]; the values are clamped by [ReaderSettings] itself.
  ///
  /// Named `apply` rather than `update` because the generated async notifier already has an
  /// `update` that takes a transformer, and shadowing it would be a trap for the next reader.
  Future<void> apply(ReaderSettings settings) async {
    await (await ref.read(readerSettingsRepositoryProvider.future))
        .save(settings);
    state = AsyncData<ReaderSettings>(settings);
  }
}
