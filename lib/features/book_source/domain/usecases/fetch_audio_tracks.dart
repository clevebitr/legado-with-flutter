import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/features/book_source/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Reads the audio addresses of one chapter (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).
///
/// Legado stores audio addresses in the **content** rule: `BookContent.kt` skips HTML formatting
/// for audio books and hands the rule's text straight to the player. This use case keeps that
/// route but reads the rule's **list** form, so a chapter that names several parts keeps every
/// part instead of joining them into one unusable string.
///
/// The chapter URL goes through the same [PageFetchService] walk as a text body: the source's
/// rate declaration, its rule-based `header`, and `nextContentUrl` paging all apply, and a paging
/// page that cannot be read fails the chapter rather than silently truncating the playlist — a
/// chapter that plays only its first part is not a usable chapter (`book-source.md` §9).
final class FetchAudioTracks {
  /// Creates the use case.
  const FetchAudioTracks({required this._pages});

  final PageFetchService _pages;

  /// Reads the track list of [request]'s chapter.
  ///
  /// A rule that matched nothing, or whose values are not `http(s)` addresses, is
  /// [ParseFailureKind.parseFailed]: showing an empty player is worse than showing the failure,
  /// because the user cannot tell a silent chapter from a broken rule (C-SRC-4).
  Future<ParseResult<List<AudioTrack>>> execute(
    BookSource source,
    ChapterRequest request,
  ) async {
    final String url = request.url;
    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);
    // `header` 写成规则时要在**第一个请求之前**求值（book-source.md §2、M12-A2）。
    final Map<String, String>? headers = await _pages.headersOf(source);
    final ParseResult<PageWalk> walk = await _pages.walk(
      rule: url,
      rulePath: 'ruleContent',
      nextRule: source.contentRule.nextContentUrl,
      nextRulePath: 'contentRule.nextContentUrl',
      context: JsPageContext(
        baseUrl: url,
        source: source.jsSourceInfo,
        headers: headers,
        bookName: request.bookName,
        chapterTitle: request.title,
        book: JsBookInfo(
          name: request.bookName,
          author: request.author,
          bookUrl: request.bookUrl,
          tocUrl: request.tocUrl,
          intro: request.intro,
          kind: request.kind,
        ),
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    return switch (walk) {
      ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<List<AudioTrack>>(kind: kind, rulePath: failedAt),
      ParseSuccess<PageWalk>(:final PageWalk data) => await _read(
        source,
        data,
        headers ?? const <String, String>{},
      ),
    };
  }

  /// Reads every walked page into one de-duplicated track list.
  Future<ParseResult<List<AudioTrack>>> _read(
    BookSource source,
    PageWalk walk,
    Map<String, String> sourceHeaders,
  ) async {
    final ParseFailure<Never>? stopped = walk.stoppedBy;
    if (stopped != null) {
      // 与正文同一条口径：缺页的章节不可用，不做「能播多少算多少」。
      return failureAt<List<AudioTrack>>(
        kind: stopped.kind,
        rulePath: stopped.rulePath,
      );
    }

    final Map<String, String> headers = Map<String, String>.unmodifiable(
      sourceHeaders,
    );
    final List<AudioTrack> tracks = <AudioTrack>[];
    final Set<String> seen = <String>{};

    for (final FetchedPage page in walk.pages) {
      final ParseResult<List<String>> values = await _pages.valueList(
        source.contentRule.content,
        page.scope,
        'contentRule.content',
      );

      switch (values) {
        case ParseFailure<List<String>>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return failureAt<List<AudioTrack>>(kind: kind, rulePath: failedAt);
        case ParseSuccess<List<String>>(:final List<String> data):
          for (final String raw in data) {
            final String value = raw.trim();
            if (!_looksLikeAddress(value)) {
              // 真实源里 content 规则可能返回整页 HTML（`<js>result</js>` + webView 源）：
              // 那不是地址，交给播放器只会得到一条假 URL，甚至在 Windows 上崩掉原生插件。
              _pages.warn(
                'Audio value skipped (not a URL): source=${source.url} '
                'field=contentRule.content',
              );
              continue;
            }
            // 相对地址按**读到它的那一页**解析（与封面、目录同一条规则，book-source.md §2）。
            final String absolute = resolveAbsoluteUrl(value, page.url);
            if (!_isMediaUrl(absolute) || !seen.add(absolute)) {
              continue;
            }
            tracks.add(AudioTrack(url: absolute, headers: headers));
          }
      }
    }

    if (tracks.isEmpty) {
      return failureAt<List<AudioTrack>>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'contentRule.content',
      );
    }

    return ParseSuccess<List<AudioTrack>>(tracks);
  }
}

/// The longest single audio address accepted, in characters.
///
/// A real media URL (including a signed CDN query) is far shorter; a longer value is a page or
/// an error document that the source's `content` rule returned by mistake.
const int _maxMediaUrlLength = 4096;

/// Whether [value] is shaped like an address at all, before relative resolution.
///
/// The check runs **before** `resolveAbsoluteUrl`: a page body such as `<!DOCTYPE html>…` would
/// otherwise resolve into a syntactically valid `https://…` URL and pass the scheme check, and the
/// player would receive a page instead of media.
bool _looksLikeAddress(String value) =>
    value.isNotEmpty &&
    value.length <= _maxMediaUrlLength &&
    !value.contains(RegExp(r'[\s<>]')) &&
    !value.toLowerCase().startsWith('data:');

/// Whether [url] can be handed to the player.
///
/// Only `http(s)` addresses are accepted; **no shape filter beyond that**. An `.m3u8` playlist is a
/// player capability, not a parsing one: Android/iOS decode it, while Windows' bundled libmpv has no
/// HLS demuxer and answers with a retryable playback failure (ADR-0062 §决策 3). Refusing the
/// address here would make the source look broken on the platforms that can play it.
bool _isMediaUrl(String url) {
  final Uri? uri = Uri.tryParse(url);

  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}
