import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';

/// Reads one manga chapter's image list (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 2).
///
/// It walks the chapter exactly like `FetchContent` does — same `nextContentUrl` paging, same
/// `concurrentRate` budget, same `header` evaluation — and then asks `contentRule.content` for
/// **every** value instead of the first one. That one difference is the whole point: an image rule
/// matches many nodes, and taking the first value would show a one-page chapter.
///
/// Three rules are worth naming:
///
/// * a value that cannot be turned into an absolute `http(s)` address is **dropped with a
///   warning** naming the page, because one bad attribute must not cost the chapter; a chapter
///   that ends up with no images at all is [ParseFailureKind.parseFailed], never an empty gallery;
/// * duplicates are dropped while keeping rule order: paged content repeats the first image on
///   every continuation page on some sites;
/// * the images are **not** cached by `ContentCache`: that cache stores text bodies keyed by
///   chapter URL, and a list of addresses is cheap to re-read compared to the images themselves
///   (which `cached_network_image` already caches).
final class FetchMangaPages {
  /// Creates the use case.
  const FetchMangaPages({required this._pages, required this._logger});

  final PageFetchService _pages;
  final AppLogger _logger;

  /// Reads the images of the chapter [request] names.
  Future<ParseResult<MangaPages>> execute(
    BookSource source,
    ChapterRequest request,
  ) async {
    final String url = request.url;
    // 书源自己的限速要在第一个请求之前进预算（book-source.md §8、ADR-0036）。
    _pages.applySourceRate(source);
    // `header` 写成规则时要在**第一个请求之前**求值，图片请求也带同一份表。
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
      ),
      headers: headers,
      sourceId: source.url,
      source: source.jsSourceInfo,
    );

    switch (walk) {
      case ParseFailure<PageWalk>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ):
        return failureAt<MangaPages>(kind: kind, rulePath: failedAt);
      case ParseSuccess<PageWalk>(:final PageWalk data):
        final ParseFailure<Never>? stopped = data.stoppedBy;
        if (stopped != null) {
          return failureAt<MangaPages>(
            kind: stopped.kind,
            rulePath: stopped.rulePath,
          );
        }

        return _read(source, data, headers);
    }
  }

  /// Turns every walked page into absolute image addresses.
  Future<ParseResult<MangaPages>> _read(
    BookSource source,
    PageWalk walk,
    Map<String, String>? headers,
  ) async {
    final List<String> urls = <String>[];
    final Set<String> seen = <String>{};

    for (var index = 0; index < walk.pages.length; index++) {
      final FetchedPage page = walk.pages[index];
      final ParseResult<List<String>> values = await _pages.extractAll(
        source.contentRule.content ?? '',
        page.scope,
        'contentRule.content',
      );

      switch (values) {
        case ParseFailure<List<String>>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return failureAt<MangaPages>(kind: kind, rulePath: failedAt);
        case ParseSuccess<List<String>>(:final List<String> data):
          for (final String value in data) {
            final String trimmed = value.trim();
            if (trimmed.isEmpty) {
              continue;
            }
            final String absolute = resolveAbsoluteUrl(trimmed, page.url);
            if (!_isHttpUrl(absolute)) {
              // 相对地址在无 base 时仍是相对；非 http(s)（data: / javascript:）也不是图片源。
              _logger.warning(
                'Manga page ${index + 1} of ${source.url} has an unusable image '
                'address; the page is dropped: $trimmed',
              );

              continue;
            }
            if (seen.add(absolute)) {
              urls.add(absolute);
            }
          }
      }
    }

    if (urls.isEmpty) {
      // 一条规则没匹配到图 = 规则失效，不是「这一章没图」（book-source.md §7）。
      return failureAt<MangaPages>(
        kind: ParseFailureKind.parseFailed,
        rulePath: mangaPagesRulePath,
      );
    }

    return ParseSuccess<MangaPages>(MangaPages(urls: urls, headers: headers));
  }

  /// Whether [value] is an absolute `http(s)` address, i.e. something a network image can load.
  bool _isHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);

    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
