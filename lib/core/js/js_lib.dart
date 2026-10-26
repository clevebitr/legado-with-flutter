import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';

// 私有字段不能做具名初始化形参（Dart 限制），手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

/// The `rulePath` marker of a failure that came from a source's `jsLib`, not from a rule.
///
/// Upstream throws a `NoStackTraceException("下载jsLib-…失败")` from inside `SharedJsScope`, which a
/// user only sees as「这条规则为什么全错」。Keeping the marker apart lets the log and the debug page
/// say「库脚本坏了」without reading the stack (`book-source.md` §6).
const String jsLibMarker = 'js:lib';

/// Resolves a book source's `jsLib` into the JavaScript the sandbox can run (ADR-0078 S1).
///
/// Upstream (`SharedJsScope.kt:23-60`) accepts two shapes in one field:
///
/// * **plain JavaScript** — evaluated as-is into the source's shared scope;
/// * **a JSON object whose values are absolute URLs** — each script is downloaded (and disk-cached
///   there) and evaluated in map order.
///
/// This store answers the **concatenated text** of those scripts, so the worker only has to run one
/// string per job. The reasons for the shape:
///
/// * the worker is an isolate and cannot fetch; the store is the only side that may use
///   [HttpClient] (C-NET-1);
/// * the text is cached by the **raw `jsLib` string** and bounded like upstream's 16-entry
///   `LruCache`, so a page with twenty `@js:` fields resolves the library once;
/// * a download failure is a [ParseFailure] with [jsLibMarker] — never a silently library-less run
///   (C-SRC-4), because a rule that needs its helper would then fail twenty times for the wrong
///   reason.
final class JsLibStore {
  /// Creates the store.
  ///
  /// A `null` [http] keeps the store to plain-JavaScript libraries (and reports a URL-shaped
  /// library as unsupported); that is what a unit test of the rule engine wants by default.
  JsLibStore({
    HttpClient? http,
    AppLogger? logger,
    this.maxEntries = defaultMaxEntries,
  }) : _http = http,
       _logger = logger;

  /// The default bound, the same number upstream's `LruCache` uses.
  static const int defaultMaxEntries = 16;

  /// How many distinct `jsLib` texts the store remembers.
  final int maxEntries;

  final HttpClient? _http;
  final AppLogger? _logger;

  // 插入序即 LRU 序：命中时删后重插，满了就丢最旧的一条。
  final LinkedHashMap<String, String> _resolved =
      LinkedHashMap<String, String>();

  // 同一个库被一页里的二十个字段同时要时，只解析一次。
  final Map<String, Future<ParseResult<String?>>> _pending =
      <String, Future<ParseResult<String?>>>{};

  /// The runnable JavaScript of [jsLib], or `null` when the source declares no library.
  ///
  /// [sourceUrl] only names the requests the library may trigger (it is the per-source budget key,
  /// C-NET-5); [rulePath] locates a failure.
  Future<ParseResult<String?>> resolve({
    required String sourceUrl,
    required String? jsLib,
    required String rulePath,
  }) {
    if (jsLib == null || jsLib.trim().isEmpty) {
      return Future<ParseResult<String?>>.value(
        const ParseSuccess<String?>(null),
      );
    }

    final String? cached = _resolved.remove(jsLib);
    if (cached != null) {
      _resolved[jsLib] = cached;

      return Future<ParseResult<String?>>.value(ParseSuccess<String?>(cached));
    }

    final Future<ParseResult<String?>>? inFlight = _pending[jsLib];
    if (inFlight != null) {
      return inFlight;
    }
    final Future<ParseResult<String?>> created = _resolve(
      jsLib: jsLib,
      sourceUrl: sourceUrl,
      rulePath: rulePath,
    );
    _pending[jsLib] = created;

    // 失败不进缓存，也不留在 _pending：下一次规则应该重试一次下载（站点可能是瞬断）。
    return created.whenComplete(() => _pending.remove(jsLib));
  }

  /// The text [jsLib] resolved to, when it is already known; `null` otherwise.
  ///
  /// A diagnostic door: the debug page shows what the sandbox actually runs.
  String? cachedTextOf(String? jsLib) =>
      jsLib == null ? null : _resolved[jsLib];

  Future<ParseResult<String?>> _resolve({
    required String jsLib,
    required String sourceUrl,
    required String rulePath,
  }) async {
    final List<String>? urls = _absoluteUrlsOf(jsLib);
    if (urls == null) {
      // 纯 JS：原样跑（上游 `isJsonObject()` 为假就走这一支）。
      return _remember(jsLib, jsLib);
    }
    if (urls.isEmpty) {
      // JSON 对象里没有 URL 值的库：上游的循环什么都不做，等于「没有库」。
      return _remember(jsLib, '');
    }

    final HttpClient? http = _http;
    if (http == null) {
      return ParseFailure<String?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$rulePath:$jsLibMarker',
      );
    }

    final StringBuffer script = StringBuffer();
    for (final String url in urls) {
      final ParseResult<HttpResponse> response = await http.get(
        url,
        rulePath: '$rulePath:$jsLibMarker',
        sourceId: sourceUrl.isEmpty ? null : sourceUrl,
      );
      switch (response) {
        case ParseFailure<HttpResponse>(
          :final ParseFailureKind kind,
          :final String rulePath,
        ):
          _logger?.warning(
            'Could not download the source jsLib: url=${redactUrl(url)} '
            'kind=${kind.name}',
          );

          return ParseFailure<String?>(kind: kind, rulePath: rulePath);
        case ParseSuccess<HttpResponse>(:final HttpResponse data):
          // 多个脚本按 JSON 的对象序拼接；中间的空行避免上一条的尾注释吞掉下一条。
          if (script.isNotEmpty) {
            script.write('\n;\n');
          }
          script.write(data.body);
      }
    }

    return _remember(jsLib, script.toString());
  }

  ParseResult<String?> _remember(String jsLib, String script) {
    _resolved[jsLib] = script;
    while (_resolved.length > maxEntries) {
      _resolved.remove(_resolved.keys.first);
    }

    return ParseSuccess<String?>(script.isEmpty ? null : script);
  }

  /// The absolute URLs a JSON-object `jsLib` carries, or `null` when [jsLib] is not such an object.
  ///
  /// Non-URL values are ignored on purpose: upstream's loop only downloads `value.isAbsUrl()`.
  static List<String>? _absoluteUrlsOf(String jsLib) {
    final String text = jsLib.trim();
    if (!text.startsWith('{')) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      // 不是合法 JSON：按上游 `isJsonObject()` 的判定，它算普通 JS。
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    return <String>[
      for (final Object? value in decoded.values)
        if (value is String && _isAbsoluteUrl(value)) value,
    ];
  }

  static bool _isAbsoluteUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');
}
