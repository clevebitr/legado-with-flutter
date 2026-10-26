// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';

/// One search hit of a book source (matrix #8, `docs/dev/book-source.md` §2).
///
/// These are plain domain entities: unlike the book source models they carry **no**
/// JSON annotations, because their JSON form is not part of the domain language
/// (ADR-0021 §决策 3 — the exception does not spread).
///
/// [updateTime] (and [BookInfo.updateTime] / [Chapter.updateTime]) is carried as the source
/// spelled it: a display string, never a parsed date (`book-source.md` §2). The UI that shows
/// it arrives with Phase 5, which is where its consumption is registered (`docs/dev/roadmap.md` §3.7).
@freezed
abstract class Book with _$Book {
  /// Creates a search hit.
  ///
  /// [name] and [url] are required on the entity, but only [url] decides whether a
  /// hit survives: a hit without a usable URL is dropped with a warning instead of
  /// failing the whole search (`book-source.md` §9), while a `name` rule that matched
  /// nothing falls back to an **empty string**.
  const factory Book({
    required String name,
    required String url,
    String? author,
    String? kind,
    String? coverUrl,
    String? intro,
    String? lastChapter,
    String? wordCount,
    String? updateTime,
  }) = _Book;
}

/// The detail page of one book (`ruleBookInfo`).
@freezed
abstract class BookInfo with _$BookInfo {
  /// Creates a book detail.
  ///
  /// [name] falls back to an empty string when the `name` rule matched nothing;
  /// every other field stays `null` in that case, because an absent cover or intro is
  /// not fatal (`book-source.md` §7).
  ///
  /// [tocUrl] is already resolved to an absolute URL; when the source declares no
  /// `tocUrl` rule it is the book URL itself, which is where upstream expects the
  /// chapter list to live.
  ///
  /// [canReName] does **not** come from the page: it reports whether the source declares a
  /// `canReName` rule at all, which is what upstream checks before it lets a caller overwrite a
  /// book's name and author (`BookInfo.kt:65-84`; `book-source.md` §2). The rule text itself is
  /// never evaluated, and the consumer that acts on it arrives with Phase 5.
  const factory BookInfo({
    required String name,
    required String url,
    required String tocUrl,
    String? author,
    String? kind,
    String? coverUrl,
    String? intro,
    String? lastChapter,
    String? wordCount,
    String? updateTime,
    @Default(false) bool canReName,
  }) = _BookInfo;
}

/// One entry of a table of contents (`ruleToc`).
@freezed
abstract class Chapter with _$Chapter {
  /// Creates a chapter entry.
  ///
  /// [name] falls back to an empty string when the `chapterName` rule matched nothing;
  /// a chapter without a usable URL is dropped with a warning instead of failing the
  /// whole table of contents (`book-source.md` §9).
  ///
  /// [url] is already resolved to an absolute URL.
  ///
  /// [isVip] is `false` unless the source's `isVip` rule produced a value upstream
  /// reads as true: `null`, an empty string, `false` and `0` all stay non-VIP
  /// (`book-source.md` §4.1).
  ///
  /// [updateTime] is the chapter's update time as the source spelled it — `null` when the
  /// rule matched nothing. It is a **display** string: the engine does not parse it, and a
  /// source that wants a formatted date asks `java.timeFormat` for one (§6).
  ///
  /// [isPay] is the source's「已购买」mark and only means something together with [isVip]
  /// (upstream `BookChapterList.kt:229-268`); [isVolume] marks a **volume heading** rather than a
  /// readable chapter, which keeps it in the list without offering it as a page to read.
  ///
  /// [wordCount] is display text, like [updateTime]. [variable] is the chapter's own variable map
  /// (`chapter.putVariable`, upstream): the audio pipeline stores the lyrics a `subContent` rule
  /// produced under `lyric` (§4.1). [reviewImg] is the image a `contentRule.title` rule carried.
  const factory Chapter({
    required String name,
    required String url,
    @Default(false) bool isVip,
    @Default(false) bool isPay,
    @Default(false) bool isVolume,
    String? updateTime,
    String? wordCount,
    @Default(<String, String>{}) Map<String, String> variable,
    String? reviewImg,
  }) = _Chapter;
}
