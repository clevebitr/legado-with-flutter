import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/entities/manga_pages.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_reader/features/book_source/domain/source_login.dart';
import 'package:flutter_reader/features/book_source/domain/url_rule.dart';
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
    // `imageDecode` 是「图片字节二次解密」的脚本（上游 `ContentRule.kt:21`）。本仓沙箱没有
    // 字节数组，执行不了；**显式拒绝**，否则用户只会看到一堆解密前的乱码图片（ADR-0069 G5）。
    final String? decode = source.contentRule.imageDecode;
    if (decode != null && decode.trim().isNotEmpty) {
      _logger.warning(
        'Image decoding is not supported: source=${source.url} '
        'field=contentRule.imageDecode',
      );

      return failureAt<MangaPages>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'contentRule.imageDecode',
      );
    }

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
      login: source.loginGuard,
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
    // 图片地址是 URL 规则：`img@src##$##,{"headers":{"Referer":…}}` 的选项要落到请求头上，
    // 不能跟着地址一起发出去（ADR-0069 G4）。一章节的图片通常同一套头，所以合并成一张表。
    final Map<String, String> pageHeaders = <String, String>{...?headers};

    for (var index = 0; index < walk.pages.length; index++) {
      final FetchedPage page = walk.pages[index];
      // 上游把 `ruleContent.content` 当**一个字符串**读（`getString`，无论书是文本还是图片），
      // 所以多匹配要用换行拼起来再交给 `@js:`，脚本的 `result.split("\n")` 才成立
      // （ADR-0069 G9）。
      final ParseResult<String> content = await _pages.joined(
        source.contentRule.content ?? '',
        page.scope,
        'contentRule.content',
      );

      switch (content) {
        case ParseFailure<String>(
          :final ParseFailureKind kind,
          rulePath: final String failedAt,
        ):
          return failureAt<MangaPages>(kind: kind, rulePath: failedAt);
        case ParseSuccess<String>(:final String data):
          for (final String value in _linesOf(data)) {
            for (final String rawAddress in _addressesOf(value)) {
              final String address = _withoutOptions(
                rawAddress,
                source: source,
                into: pageHeaders,
              );
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

    return ParseSuccess<MangaPages>(
      MangaPages(
        urls: urls,
        headers: pageHeaders.isEmpty ? null : pageHeaders,
        imageStyle: source.contentRule.imageStyle,
      ),
    );
  }

  /// The non-blank lines of a joined content value.
  ///
  /// One image source writes its addresses one per line (`$.data[*].image` joined with a
  /// newline), another hands over an `<img>` HTML block; both go through [_addressesOf].
  Iterable<String> _linesOf(String content) => content
      .split(RegExp(r'\r?\n'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty);

  /// [address] without its `,{…}` options, whose headers are merged into [into].
  ///
  /// An unreadable suffix is dropped as well: sending it as part of the address is what used to
  /// break hotlink-protected galleries (`book-source.md` §4.3, ADR-0069 G4).
  String _withoutOptions(
    String address, {
    required BookSource source,
    required Map<String, String> into,
  }) {
    final ParseResult<UrlRule> parsed = parseUrlRule(
      address,
      rulePath: mangaPagesRulePath,
    );
    switch (parsed) {
      case ParseSuccess<UrlRule>(:final UrlRule data):
        final Map<String, String>? options = data.options?.headers;
        if (options != null && options.isNotEmpty) {
          into.addAll(options);
        }

        return data.template;
      case ParseFailure<UrlRule>():
        _logger.warning(
          'Unreadable image URL options dropped: source=${source.url}',
        );

        return stripUrlOptions(address);
    }
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
