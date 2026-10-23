import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/url_template.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

/// Reads one manga chapter's image list through `contentRule.content`.
///
/// Walks the chapter like the text reader does, then keeps every matched value instead of the first
/// one.
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
    // 书源自己的限速要在第一个请求之前进预算。
    _pages.applySourceRate(source);
    // `header` 写成规则时也要在第一个请求之前求值，图片请求带同一份表。
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
            for (final String address in _addressesOf(value)) {
              final String absolute = resolveAbsoluteUrl(address, page.url);
              if (!_isHttpUrl(absolute)) {
                // 相对地址在无 base 时仍是相对；非 http(s)（data: / javascript:）也不是图片源。
                _logger.warning(
                  'Manga page ${index + 1} of ${source.url} has an unusable image '
                  'address; the page is dropped: ${_previewOf(address)}',
                );

                continue;
              }
              if (seen.add(absolute)) {
                urls.add(absolute);
              }
            }
          }
      }
    }

    if (urls.isEmpty) {
      // 一条规则没匹配到图 = 规则失效，而不是「这一章没图」。
      return failureAt<MangaPages>(
        kind: ParseFailureKind.parseFailed,
        rulePath: mangaPagesRulePath,
      );
    }

    return ParseSuccess<MangaPages>(MangaPages(urls: urls, headers: headers));
  }

  // 日志里最多保留 80 字符的单行预览。
  String _previewOf(String value) {
    final String oneLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    return oneLine.length <= 80 ? oneLine : '${oneLine.substring(0, 80)}…';
  }

  // 值可能已是地址，也可能是 HTML；懒加载属性优先于 `src`。
  Iterable<String> _addressesOf(String value) sync* {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (!trimmed.contains('<')) {
      yield trimmed;

      return;
    }

    final List<String> found = <String>[];
    for (final html_dom.Element image
        in html_parser.parseFragment(trimmed).querySelectorAll('img')) {
      final String? address =
          image.attributes['data-original'] ??
          image.attributes['data-src'] ??
          image.attributes['src'];
      if (address != null && address.trim().isNotEmpty) {
        found.add(address.trim());
      }
    }
    if (found.isEmpty) {
      // 有 `<` 但不是图片标签：交给调用方按坏地址记一条 warning，而不是静默吞掉。
      yield trimmed;

      return;
    }
    yield* found;
  }

  bool _isHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);

    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
