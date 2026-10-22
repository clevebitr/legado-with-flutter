import 'dart:io' show HttpHeaders;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
import 'package:flutter_reader/core/network/charset_decoder.dart';
import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';

/// Fetches pages over HTTP for the rest of the app (C-NET-1).
///
/// Implementations never throw for expected failures: timeouts, connection
/// errors, non-2xx statuses and undecodable bodies come back as a
/// [ParseFailure] so callers can `switch` exhaustively (C-ERR-1). Feature code
/// must depend on this interface and never import `dio` itself.
abstract interface class HttpClient {
  /// Sends a GET request to [url].
  ///
  /// [rulePath] names the book source field this request belongs to; it is
  /// carried into [ParseFailure.rulePath] so a failure stays locatable
  /// (C-SRC-8). [headers] override the policy defaults for this request only,
  /// while cookies come from the [CookieManager] and must never be set by hand
  /// (C-NET-5).
  ///
  /// Pass [keyword] when [url] was rendered from a search template: it is used
  /// only to keep the keyword out of failure logs (ADR-0006 §5).
  ///
  /// Pass [sourceId] (the book source URL) so a warning that belongs to a book
  /// source can name it without the client having to know the source model
  /// (C-ERR-8): the tolerant-decode warning of ADR-0031 §决策 2 needs it.
  ///
  /// Pass [maxBytes] to bound the response **while it is read** (`docs/dev/roadmap.md` 5.1,
  /// ADR-0040 §决策 5): the import path must abandon an oversized download instead of
  /// buffering it (C-PERF-5). A body over the cap is a [ParseFailure] of kind
  /// [ParseFailureKind.invalidBookSource] whose `cause` is a [BodyTooLargeException] — the
  /// request layer owns no "too large" kind, and it does not know what the caller wanted the
  /// bytes for, so the caller rewrites the failure into its own `rulePath`
  /// (`ImportBookSources` maps it to `import.sizeLimit`). `null` means “no caller cap”, which
  /// is what every rule-driven request wants.
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
    String? declaredCharset,
  });

  /// Sends a POST request to [url], carrying [body] as the request payload.
  ///
  /// The contract is [get]'s: the same [rulePath] / [headers] / [keyword] / [sourceId]
  /// meanings, the same retry, timeout and decoding policy, and the same promise to
  /// answer with a [ParseResult] instead of throwing (C-ERR-1).
  ///
  /// [body] is sent as it is, so the `Content-Type` a site expects has to come from
  /// [headers] — the client does not guess one. It exists because the JS whitelist of
  /// `docs/dev/book-source.md` §6 binds `http.post`, and the request layer must stay the
  /// single door to the network (C-NET-1).
  ///
  /// There is no `maxBytes` here: the cap exists for a caller that downloads a **file**
  /// (the import path), and a rule-driven POST is read whole by definition.
  Future<ParseResult<HttpResponse>> post(
    String url, {
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    String? declaredCharset,
  });

  /// Applies the `concurrentRate` [sourceId] declares to that source's budget
  /// (`docs/dev/book-source.md` §8).
  ///
  /// Call it when an operation starts using a source. The rate gate is keyed by [sourceId],
  /// exactly like the concurrency budget, so every later request of that source — including
  /// the `http.*` calls a `@js:` rule makes (`book-source.md` §6), which never see the
  /// declaration itself — passes it as well (ADR-0036 §决策 5).
  ///
  /// [concurrentRate] is the **raw** declaration text: the request layer owns the syntax and
  /// its warning, because that is where the budget is spent. `null`, a blank string and `"0"`
  /// mean “no rate gate”; an illegal declaration is ignored with a warning and the source keeps
  /// the default concurrency budget (ADR-0036 §决策 2). Registering the same declaration twice
  /// is harmless and never resets the window.
  void applySourceRate(String sourceId, String? concurrentRate);
}

/// Raised inside the request layer when a response body passes the caller's `maxBytes` cap.
///
/// It never escapes as an exception: [DioHttpClient] catches it, cancels the download and answers
/// with a [ParseFailure] whose `cause` is this object, so the caller can recognise *why* the
/// request was refused (`ImportBookSources` rewrites it into `import.sizeLimit`).
///
/// It carries the limit, never the bytes that were read (C-SEC-4).
final class BodyTooLargeException implements Exception {
  /// Creates the marker for a body that passed [limitBytes].
  const BodyTooLargeException(this.limitBytes);

  /// The cap the caller asked for, in bytes.
  final int limitBytes;

  @override
  String toString() => 'Response body exceeded $limitBytes bytes';
}

/// [HttpClient] backed by `dio` (C-NET-1).
///
/// Every wire request also spends one slot of the book source's concurrency budget
/// (`book-source.md` §8): the budget is the request layer's policy (ADR-0030 §决策 2),
/// so enforcing it here is what lets a batch of chapter downloads stay bounded without
/// any caller having to know about it.
final class DioHttpClient implements HttpClient {
  /// Creates a client that shares the cookie store and applies the policy.
  ///
  /// `dio` is injectable so tests can attach a fake adapter instead of touching
  /// the network (`docs/dev/testing.md` §4). [policy] also carries the per-source
  /// concurrency budget, so the limiter is built from it and needs no separate
  /// injection point. `charsetCache` is optional: `null` means “sniff every response”,
  /// which is what a caller that has no cache to offer (and every test that does not
  /// care) gets; the app wires the `CacheDao`-backed one in `http_client_provider.dart`.
  DioHttpClient({
    required this._cookies,
    required this._logger,
    HttpPolicy policy = const HttpPolicy(),
    Dio? dio,
    this._charsetCache,
  }) : _policy = policy,
       _limiter = RequestLimiter(
         maxConcurrent: policy.maxConcurrentRequestsPerSource,
       ),
       _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: _policy.timeout,
      receiveTimeout: _policy.timeout,
      sendTimeout: _policy.timeout,
      headers: <String, String>{HttpHeaders.userAgentHeader: _policy.userAgent},
      // 4xx/5xx 不交给 dio 抛异常：状态码要自己映射成 ParseFailureKind
      // （book-source.md §7），否则 403/404 会混进同一个 badResponse 桶。
      validateStatus: (int? _) => true,
      responseType: ResponseType.bytes,
    );
    _dio.interceptors.add(_CookieInterceptor(_cookies));
  }

  final CookieManager _cookies;
  final AppLogger _logger;
  final HttpPolicy _policy;
  final RequestLimiter _limiter;
  final Dio _dio;
  final CharsetCache? _charsetCache;

  /// Reads [sourceId]'s own rate declaration into its budget (`book-source.md` §8).
  ///
  /// The rate gate lives in the same [RequestLimiter] as the concurrency budget and is keyed
  /// by the source URL, so a `@js:` rule's `http.*` call (which only knows the source URL,
  /// `book-source.md` §6) passes the same gate without carrying the declaration
  /// (ADR-0036 §决策 5).
  ///
  /// An illegal declaration is **ignored and reported** (ADR-0036 §决策 2): the source keeps
  /// the default concurrency budget and is not rate limited, instead of being silently limited
  /// by a number nobody can see. The warning names the source, the field and a bounded excerpt
  /// of the text, never a page body (C-ERR-8, C-SEC-4).
  @override
  void applySourceRate(String sourceId, String? concurrentRate) {
    final ConcurrentRateDeclaration declaration = parseConcurrentRate(
      concurrentRate,
    );
    if (declaration.isInvalid) {
      _logger.warning(
        'Ignoring an invalid concurrentRate: source=$sourceId '
        'field=concurrentRate reason=${declaration.invalidReason} '
        'value=${_excerpt(concurrentRate)}',
      );
    }

    _limiter.applyRate(sourceId, declaration.rate);
  }

  @override
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
    String? declaredCharset,
  }) => _request(
    method: 'GET',
    url: url,
    rulePath: rulePath,
    headers: headers,
    keyword: keyword,
    sourceId: sourceId,
    maxBytes: maxBytes,
    declaredCharset: declaredCharset,
  );

  @override
  Future<ParseResult<HttpResponse>> post(
    String url, {
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    String? declaredCharset,
  }) => _request(
    method: 'POST',
    url: url,
    body: body,
    rulePath: rulePath,
    headers: headers,
    keyword: keyword,
    sourceId: sourceId,
    declaredCharset: declaredCharset,
  );

  /// Sends one request of [method] with the shared policy, budget and retry loop.
  ///
  /// Both verbs go through here so a later policy change (a new retryable kind, a
  /// stricter URL check) cannot land on one of them only.
  Future<ParseResult<HttpResponse>> _request({
    required String method,
    required String url,
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
    String? declaredCharset,
  }) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      // 畸形 URL 与不支持的 scheme 在这里就拒绝：dio 内部还会再 Uri.parse 一次，
      // 它抛出的 FormatException 若落到解码分支就会被误报成 encodingFailed（桶错了）。
      _logger.warning(
        'Unsupported request URL rejected: rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );

      return ParseFailure<HttpResponse>(
        kind: ParseFailureKind.networkFailed,
        rulePath: rulePath,
      );
    }
    if (uri.scheme == 'http' && !_policy.allowPlainHttp) {
      // C-SEC-2：明文 HTTP 必须由用户显式开启。9 个 ParseFailureKind 里没有
      // 「策略拒绝」桶，故用 networkFailed 承载，原因写进日志。
      _logger.warning(
        'Plaintext HTTP rejected by policy: rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );

      return ParseFailure<HttpResponse>(
        kind: ParseFailureKind.networkFailed,
        rulePath: rulePath,
      );
    }

    var attempt = 0;
    // 同一书源的请求共用一份并发预算（book-source.md §8）。没有书源时按主机分桶，
    // 这样「章节正文批量下载」这类无书源上下文的调用也不会对单一域名无限并发。
    final String limitKey = sourceId ?? uri.host;
    while (true) {
      final ParseResult<HttpResponse> result = await _limiter.run(
        limitKey,
        () => _send(
          url,
          method: method,
          body: body,
          rulePath: rulePath,
          headers: headers,
          keyword: keyword,
          sourceId: sourceId,
          maxBytes: maxBytes,
          declaredCharset: declaredCharset,
        ),
      );

      switch (result) {
        case ParseSuccess<HttpResponse>():
          return result;
        case ParseFailure<HttpResponse>(:final ParseFailureKind kind):
          // 只有可重试的 kind 才继续；上限来自策略，禁止无限重试（C-NET-2）。
          if (!kind.isRetryable || attempt >= _policy.maxRetries) {
            return result;
          }
      }

      attempt++;
      _logger.warning(
        'Retrying request: rule=$rulePath attempt=${attempt + 1}/${_policy.maxRetries + 1}',
      );
    }
  }

  /// Performs one request and maps every outcome onto a [ParseResult].
  ///
  /// The body always arrives as a stream and is read by [_readBytes], so the `maxBytes` cap
  /// applies to the *download* rather than to the decoded text: an oversized body is abandoned
  /// mid-flight (C-PERF-5). Without a cap the accumulated bytes are exactly what the previous
  /// `bytes` response type produced.
  Future<ParseResult<HttpResponse>> _send(
    String url, {
    required String method,
    required String rulePath,
    required Map<String, String>? headers,
    required String? keyword,
    required String? sourceId,
    String? body,
    int? maxBytes,
    String? declaredCharset,
  }) async {
    final Response<ResponseBody> response;
    try {
      response = await _dio.request<ResponseBody>(
        url,
        data: body,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );
    } on DioException catch (error, stackTrace) {
      // 只有 dio 自己的异常到这里：URL 已在 [_request] 里校验，解码在 _decode 里单独处理。
      _logger.warning(
        'Request failed for rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<HttpResponse>(
        kind: _failureKindForDioError(error),
        rulePath: rulePath,
      );
    }

    final int status = response.statusCode ?? 0;
    // dio 把「没有正文可给」表达成 null；对调用方那就是空正文，所以这里补一个空流，
    // 后面的读取与丢弃两条路径都不必再判空。
    final ResponseBody responseBody =
        response.data ?? ResponseBody.fromBytes(const <int>[], status);
    final ParseFailureKind? statusKind = _failureKindForStatus(status);

    if (statusKind != null) {
      _logger.warning(
        'HTTP $status for rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );
      await _discard(responseBody);

      return ParseFailure<HttpResponse>(kind: statusKind, rulePath: rulePath);
    }

    final List<int> bytes;
    try {
      bytes = await _readBytes(responseBody, maxBytes: maxBytes);
    } on BodyTooLargeException catch (error, stackTrace) {
      _logger.warning(
        'Response body passed the caller limit: rule=$rulePath '
        'limit=${error.limitBytes} url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<HttpResponse>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: rulePath,
        cause: error,
      );
    } on Exception catch (error, stackTrace) {
      // 正文是**流式**读的（C-PERF-5），所以读的过程中也会超时 / 断连，而 dio 的
      // `receiveTimeout` 在那里表现为一个 `DioException`。它在 `_dio.request` 的
      // try 之外抛出，不接住就会穿过 `HttpClient` 契约（C-ERR-1），把一个「读超时」
      // 变成上一层的整批失败（真实案例：一个源把整次聚合搜索打成了失败）。
      final ParseFailureKind kind = error is DioException
          ? _failureKindForDioError(error)
          : ParseFailureKind.networkFailed;
      _logger.warning(
        'Response body could not be read: rule=$rulePath kind=${kind.name} '
        'url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<HttpResponse>(kind: kind, rulePath: rulePath);
    }

    return _decode(
      status: status,
      headers: response.headers,
      bytes: bytes,
      rulePath: rulePath,
      keyword: keyword,
      url: url,
      sourceId: sourceId,
      declaredCharset: declaredCharset,
    );
  }

  /// Reads the whole [body], or abandons it the moment it passes `maxBytes`.
  ///
  /// Throwing inside the `await for` cancels the subscription, which is what stops the download
  /// instead of letting it finish in the background (C-PERF-5).
  Future<List<int>> _readBytes(
    ResponseBody body, {
    required int? maxBytes,
  }) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final Uint8List chunk in body.stream) {
      builder.add(chunk);
      if (maxBytes != null && builder.length > maxBytes) {
        throw BodyTooLargeException(maxBytes);
      }
    }

    return builder.takeBytes();
  }

  /// Releases a response body this client deliberately does not read.
  ///
  /// A 4xx/5xx body stays held by dio until its subscription is consumed or cancelled; cancelling
  /// returns the connection to the pool instead of leaving it dangling.
  Future<void> _discard(ResponseBody body) async {
    await body.stream.listen(null).cancel();
  }

  /// Decodes a 2xx body; the only place a [FormatException] is expected.
  ///
  /// The sniffing step of `book-source.md` §5 runs once per `(书源, URL)`: the label it
  /// chose is read from [CharsetCache] on the next request and passed to [decodeBody], so
  /// the detector never runs twice for the same page. Only a **detected** label is stored
  /// (a declared one is read from the response itself every time and always wins); a cache
  /// that cannot answer is a miss, because the port is total (C-ERR-2).
  Future<ParseResult<HttpResponse>> _decode({
    required int status,
    required Headers headers,
    required List<int> bytes,
    required String rulePath,
    required String? keyword,
    required String url,
    required String? sourceId,
    String? declaredCharset,
  }) async {
    final String? sniffedCharset = await _readCachedCharset(sourceId, url);

    try {
      final DecodedBody decoded = decodeBody(
        bytes,
        contentType: headers.value(HttpHeaders.contentTypeHeader),
        sniffedCharset: sniffedCharset,
        declaredCharset: declaredCharset,
      );
      if (decoded.isDetected && sniffedCharset == null) {
        // 命中的标签不需要重写（DAO 已把它当成未过期才会返回）；只有**这次刚嗅探出来**的才写。
        await _writeCachedCharset(sourceId, url, decoded.charset);
      }
      if (decoded.toleratedMalformedBytes) {
        // ADR-0031 §决策 1/2：声明车道允许宽容解码，但必须留痕——携带**声明的编码**、
        // 替换数量与书源 ID；正文、Cookie、Token 一律不入日志（C-ERR-8 / C-SEC-4）。
        _logger.warning(
          'Declared charset ${decoded.charset} carried illegal bytes; '
          '${decoded.malformedByteCount} malformed byte replacement(s) inserted: '
          'rule=$rulePath source=${sourceId ?? 'unknown'} '
          'url=${redactUrl(url, keyword: keyword)}',
        );
      }

      return ParseSuccess<HttpResponse>(
        HttpResponse(
          statusCode: status,
          headers: headers.map,
          body: decoded.text,
        ),
      );
    } on FormatException catch (error, stackTrace) {
      // 嗅探 / 回退车道的解码失败必须显式失败，禁止用 allowMalformed 静默吞掉，
      // 否则「猜错的编码」会变成乱码正文（C-NET-3、ADR-0031 §决策 3）。
      _logger.warning(
        'Body decoding failed for rule=$rulePath source=${sourceId ?? 'unknown'} '
        'url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<HttpResponse>(
        kind: ParseFailureKind.encodingFailed,
        rulePath: rulePath,
      );
    }
  }

  /// The charset a previous response for ([sourceId], [url]) was decoded with, if any.
  ///
  /// A page without a book source has no cache key (C-NET-6 starts one with the source id),
  /// so it sniffs every time. Nothing here catches: [CharsetCache] is total — a cache
  /// failure comes back as `null`, which is why the request path needs no exception
  /// boundary of its own (C-ERR-2).
  Future<String?> _readCachedCharset(String? sourceId, String url) async {
    final CharsetCache? cache = _charsetCache;
    if (cache == null || sourceId == null) {
      return null;
    }

    return cache.read(
      sourceId: sourceId,
      ruleField: _charsetCacheField,
      url: url,
      page: _charsetCachePage,
    );
  }

  /// Stores the detected charset for ([sourceId], [url]); a failed write is not the page's.
  Future<void> _writeCachedCharset(
    String? sourceId,
    String url,
    String charset,
  ) async {
    final CharsetCache? cache = _charsetCache;
    if (cache == null || sourceId == null) {
      return;
    }

    await cache.write(
      sourceId: sourceId,
      ruleField: _charsetCacheField,
      url: url,
      page: _charsetCachePage,
      charset: charset,
    );
  }
}

/// Adds stored cookies to requests and records the cookies of responses.
///
/// The only place a `Cookie` header is produced (C-NET-5).
final class _CookieInterceptor extends Interceptor {
  _CookieInterceptor(this._cookies);

  final CookieManager _cookies;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? cookieHeader = _cookies.cookieHeaderFor(options.uri);
    if (cookieHeader != null) {
      options.headers[HttpHeaders.cookieHeader] = cookieHeader;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _cookies.storeFromResponse(
      response.requestOptions.uri,
      response.headers[HttpHeaders.setCookieHeader] ?? const <String>[],
    );
    handler.next(response);
  }
}

/// The `ruleField` the charset cache uses in the TTL cache's key (`book-source.md` §5).
///
/// It is a constant on purpose: §5 caches by 「书源 ID + URL」, and one book page is often
/// read by two stages (the G2b source reads it for `ruleBookInfo` and again for `ruleToc`),
/// so a key that carried the stage would miss on the second read and sniff again. The
/// `page` part of the shared key is fixed for the same reason — a charset does not depend
/// on it.
const String _charsetCacheField = 'charset';

/// The `page` the charset cache uses in the TTL cache's key; see [_charsetCacheField].
const int _charsetCachePage = 1;

/// Maps a non-2xx [status] onto the kinds `book-source.md` §7 names.
///
/// 403, 404 and 5xx are spelled out there; any other status falls back to
/// [ParseFailureKind.networkFailed] because the taxonomy has no closer bucket.
ParseFailureKind? _failureKindForStatus(int status) {
  if (status >= 200 && status < 300) {
    return null;
  }
  if (status == 403) {
    return ParseFailureKind.networkForbidden;
  }
  if (status == 404) {
    return ParseFailureKind.notFound;
  }

  return ParseFailureKind.networkFailed;
}

/// Maps a dio failure onto the failure taxonomy.
///
/// Returns a bounded excerpt of a declaration for a warning (C-ERR-8, C-SEC-4).
///
/// An invalid `concurrentRate` is arbitrary text from an imported file, so the log line keeps
/// only its first characters: enough to recognise what the source wrote, never unbounded.
String _excerpt(String? declaration) {
  final String text = declaration ?? '';
  if (text.length <= _maxExcerptLength) {
    return text;
  }

  return '${text.substring(0, _maxExcerptLength)}…';
}

/// Longest declaration excerpt a warning carries.
const int _maxExcerptLength = 32;

/// Every `DioExceptionType` is listed so a dio upgrade that adds a value becomes
/// a compile error instead of a silent fallback.
ParseFailureKind _failureKindForDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ParseFailureKind.networkTimeout;
    case DioExceptionType.cancel:
      return ParseFailureKind.cancelled;
    case DioExceptionType.badResponse:
      return _failureKindForStatus(error.response?.statusCode ?? 0) ??
          ParseFailureKind.networkFailed;
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return ParseFailureKind.networkFailed;
  }
}
