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

/// Fetches pages over HTTP for the rest of the app.
///
/// Expected failures come back as a [ParseFailure]; implementations never throw for them.
abstract interface class HttpClient {
  /// Sends a GET for [url]; expected failures come back as a [ParseFailure].
  ///
  /// [rulePath] locates the failure, [headers] override the policy, and [maxBytes] bounds the body (over it: a [BodyTooLargeException] cause).
  /// [maxRetries] overrides the policy's bound for this request: a URL rule's `retry` option
  /// (`docs/dev/roadmap.md` M21a) is capped by the caller at 3, so C-NET-2's 「显式次数上限」 still
  /// holds. [receiveTimeout] is the rule's `readTimeout`, again capped by the caller.
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
    String? declaredCharset,
    int? maxRetries,
    Duration? receiveTimeout,
  });

  /// Sends a GET and answers the raw bytes of a 2xx response.
  ///
  /// Used for non-text bodies (images, fonts); every other rule of [get] still applies.
  Future<ParseResult<Uint8List>> getBytes(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
  });

  /// Sends a POST to [url], carrying [body] as-is.
  ///
  /// [headers] must supply `Content-Type`; the other parameters and failures match [get].
  Future<ParseResult<HttpResponse>> post(
    String url, {
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    String? declaredCharset,
    int? maxRetries,
    Duration? receiveTimeout,
  });

  /// Sends a HEAD to [url]: the response without its body.
  ///
  /// Used by the sandbox's synchronous `java.head(url)` (ADR-0076 §决策 1), which upstream answers
  /// with a whole `StrResponse` so a rule can read `header('Location')`. Every other rule of [get]
  /// still applies — the address, the budget, the retry bound and the header policy are the same.
  Future<ParseResult<HttpResponse>> head(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxRetries,
    Duration? receiveTimeout,
  });

  /// Applies the `concurrentRate` [sourceId] declares to that source's budget.
  ///
  /// [concurrentRate] is raw text; `null`, blank and `"0"` mean no gate, and illegal text warns.
  void applySourceRate(String sourceId, String? concurrentRate);
}

/// Marks a response body that passed the caller's `maxBytes` cap.
///
/// It never escapes: the client turns it into a [ParseFailure] whose `cause` is this object.
final class BodyTooLargeException implements Exception {
  /// Creates the marker for a body that passed [limitBytes].
  const BodyTooLargeException(this.limitBytes);

  /// The cap the caller asked for, in bytes.
  final int limitBytes;

  @override
  String toString() => 'Response body exceeded $limitBytes bytes';
}

// 未解码的 2xx 响应，文本与字节两条路径共用。
final class _RawResponse {
  const _RawResponse({
    required this.status,
    required this.headers,
    required this.bytes,
    required this.url,
  });

  final int status;
  final Headers headers;
  final List<int> bytes;

  /// 读过重定向之后的地址（没有重定向时就是请求的地址）。
  final Uri url;
}

/// The address a response finally came from: [requested] with every redirect applied.
///
/// dio exposes the chain (`Response.redirects`) rather than the final address, so a relative
/// `Location` (`?9bdb14…`, which is how an ASP session hands a search off) has to be resolved
/// against the address it was served from, in order, to land where a browser would.
Uri _finalUri(Uri requested, List<RedirectRecord> redirects) {
  var current = requested;
  for (final RedirectRecord record in redirects) {
    // dio 5.11 起 `RedirectRecord.location` 是 `Uri`（更早是 `String?`）；转回字符串再 resolve，
    // 相对引用（`?token`）的语义才与浏览器一致。
    final String location = record.location.toString();
    if (location.isEmpty) {
      continue;
    }
    current = current.resolve(location);
  }

  return current;
}

/// [HttpClient] backed by `dio`.
///
/// Every wire request also spends one slot of its source's concurrency budget.
final class DioHttpClient implements HttpClient {
  /// Creates a client that shares the cookie jar and applies the given policy.
  ///
  /// [dio] is injectable for tests; without a charset cache every response is sniffed.
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
      // 4xx/5xx 自己映射成 ParseFailureKind，不让 dio 抛异常。
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

  /// Applies [sourceId]'s rate declaration; an illegal one is ignored and warned about.
  ///
  /// The gate is keyed by the source URL, so its `@js:` requests pass it too.
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
    int? maxRetries,
    Duration? receiveTimeout,
  }) => _request(
    method: 'GET',
    url: url,
    rulePath: rulePath,
    headers: headers,
    keyword: keyword,
    sourceId: sourceId,
    maxBytes: maxBytes,
    declaredCharset: declaredCharset,
    maxRetries: maxRetries,
    receiveTimeout: receiveTimeout,
  );

  @override
  Future<ParseResult<HttpResponse>> head(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxRetries,
    Duration? receiveTimeout,
  }) => _request(
    method: 'HEAD',
    url: url,
    rulePath: rulePath,
    headers: headers,
    keyword: keyword,
    sourceId: sourceId,
    maxRetries: maxRetries,
    receiveTimeout: receiveTimeout,
  );

  @override
  Future<ParseResult<Uint8List>> getBytes(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
  }) async {
    final ParseResult<_RawResponse> raw = await _perform<_RawResponse>(
      method: 'GET',
      url: url,
      rulePath: rulePath,
      headers: headers,
      keyword: keyword,
      sourceId: sourceId,
      maxBytes: maxBytes,
      send: (Uri uri) => _sendRaw(
        url,
        method: 'GET',
        rulePath: rulePath,
        headers: headers,
        keyword: keyword,
        sourceId: sourceId,
        maxBytes: maxBytes,
      ),
      failure: (ParseFailureKind kind, Object? cause) =>
          ParseFailure<_RawResponse>(
            kind: kind,
            rulePath: rulePath,
            cause: cause,
          ),
    );

    return switch (raw) {
      ParseSuccess<_RawResponse>(:final _RawResponse data) =>
        ParseSuccess<Uint8List>(Uint8List.fromList(data.bytes)),
      ParseFailure<_RawResponse>(
        :final ParseFailureKind kind,
        :final Object? cause,
      ) =>
        ParseFailure<Uint8List>(kind: kind, rulePath: rulePath, cause: cause),
    };
  }

  @override
  Future<ParseResult<HttpResponse>> post(
    String url, {
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    String? declaredCharset,
    int? maxRetries,
    Duration? receiveTimeout,
  }) => _request(
    method: 'POST',
    url: url,
    body: body,
    rulePath: rulePath,
    headers: headers,
    keyword: keyword,
    sourceId: sourceId,
    declaredCharset: declaredCharset,
    maxRetries: maxRetries,
    receiveTimeout: receiveTimeout,
  );

  // 发送一次 method 请求并把正文解码成文本。
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
    int? maxRetries,
    Duration? receiveTimeout,
  }) async {
    final ParseResult<_RawResponse> raw = await _perform<_RawResponse>(
      method: method,
      url: url,
      rulePath: rulePath,
      headers: headers,
      keyword: keyword,
      sourceId: sourceId,
      maxBytes: maxBytes,
      maxRetries: maxRetries,
      send: (Uri uri) => _sendRaw(
        url,
        method: method,
        body: body,
        rulePath: rulePath,
        headers: headers,
        keyword: keyword,
        sourceId: sourceId,
        maxBytes: maxBytes,
        receiveTimeout: receiveTimeout,
      ),
      failure: (ParseFailureKind kind, Object? cause) =>
          ParseFailure<_RawResponse>(
            kind: kind,
            rulePath: rulePath,
            cause: cause,
          ),
    );

    return switch (raw) {
      ParseSuccess<_RawResponse>(:final _RawResponse data) => _decode(
        status: data.status,
        headers: data.headers,
        bytes: data.bytes,
        rulePath: rulePath,
        keyword: keyword,
        url: url,
        responseUrl: data.url,
        sourceId: sourceId,
        declaredCharset: declaredCharset,
      ),
      ParseFailure<_RawResponse>(
        :final ParseFailureKind kind,
        :final Object? cause,
      ) =>
        ParseFailure<HttpResponse>(
          kind: kind,
          rulePath: rulePath,
          cause: cause,
        ),
    };
  }

  // URL 校验、并发预算与重试都在这里统一处理。
  Future<ParseResult<T>> _perform<T>({
    required String method,
    required String url,
    required String rulePath,
    required Future<ParseResult<T>> Function(Uri uri) send,
    required ParseFailure<T> Function(ParseFailureKind kind, Object? cause)
    failure,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
    int? maxRetries,
  }) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      // 畸形 URL 与不支持的 scheme 在这里拒绝，免得 dio 的异常落到解码分支。
      _logger.warning(
        'Unsupported request URL rejected: rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );

      return failure(ParseFailureKind.networkFailed, null);
    }
    if (uri.scheme == 'http' && !_policy.allowPlainHttp) {
      // 明文 HTTP 需用户显式开启；失败分类里没有策略桶，用 networkFailed 承载。
      _logger.warning(
        'Plaintext HTTP rejected by policy: rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );

      return failure(ParseFailureKind.networkFailed, null);
    }

    // 规则自己的 `retry` 覆盖策略默认值；两者都不允许无限重试（C-NET-2）。
    final int retryBound = maxRetries ?? _policy.maxRetries;
    var attempt = 0;
    // 同一书源的请求共用一份并发预算；没有书源时按主机分桶。
    final String limitKey = sourceId ?? uri.host;
    while (true) {
      final ParseResult<T> result = await _limiter.run(
        limitKey,
        () => send(uri),
      );

      switch (result) {
        case ParseSuccess<T>():
          return result;
        case ParseFailure<T>(:final ParseFailureKind kind):
          // 只有可重试的 kind 才继续，上限来自策略。
          if (!kind.isRetryable || attempt >= retryBound) {
            return result;
          }
      }

      attempt++;
      _logger.warning(
        'Retrying request: rule=$rulePath attempt=${attempt + 1}/${retryBound + 1}',
      );
    }
  }

  // 返回未解码的字节，maxBytes 在下载途中生效。
  Future<ParseResult<_RawResponse>> _sendRaw(
    String url, {
    required String method,
    required String rulePath,
    required Map<String, String>? headers,
    required String? keyword,
    required String? sourceId,
    String? body,
    int? maxBytes,
    Duration? receiveTimeout,
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
          // 规则声明的 `readTimeout` 只影响这一条请求（上限由解析侧钳到 120 s）。
          receiveTimeout: receiveTimeout,
          sendTimeout: receiveTimeout,
        ),
      );
    } on DioException catch (error, stackTrace) {
      // 只有 dio 自己的异常到这里；URL 已在 _perform 校验。
      // 日志里要能看出**为什么**失败：dio 的异常对象会被脱敏成 `sha256`，403 与超时长得一样。
      _logger.warning(
        'Request failed for rule=$rulePath '
        'type=${error.type.name} status=${error.response?.statusCode} '
        'url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<_RawResponse>(
        kind: _failureKindForDioError(error),
        rulePath: rulePath,
      );
    }

    final int status = response.statusCode ?? 0;
    // dio 用 null 表示没有正文，这里补一个空流以便后续统一处理。
    final ResponseBody responseBody =
        response.data ?? ResponseBody.fromBytes(const <int>[], status);
    final ParseFailureKind? statusKind = _failureKindForStatus(status);

    if (statusKind != null) {
      _logger.warning(
        'HTTP $status for rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );
      await _discard(responseBody);

      return ParseFailure<_RawResponse>(kind: statusKind, rulePath: rulePath);
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

      return ParseFailure<_RawResponse>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: rulePath,
        cause: error,
      );
    } on Exception catch (error, stackTrace) {
      // 正文是流式读取的，读超时以 DioException 抛出，必须接住以免穿透 HttpClient 契约。
      final ParseFailureKind kind = error is DioException
          ? _failureKindForDioError(error)
          : ParseFailureKind.networkFailed;
      _logger.warning(
        'Response body could not be read: rule=$rulePath kind=${kind.name} '
        'url=${redactUrl(url, keyword: keyword)}',
        describeError(error),
        stackTrace,
      );

      return ParseFailure<_RawResponse>(kind: kind, rulePath: rulePath);
    }

    return ParseSuccess<_RawResponse>(
      _RawResponse(
        status: status,
        headers: response.headers,
        bytes: bytes,
        url: _finalUri(response.requestOptions.uri, response.redirects),
      ),
    );
  }

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

  // 取消订阅才会把连接还给连接池。
  Future<void> _discard(ResponseBody body) async {
    await body.stream.listen(null).cancel();
  }

  // 解码异常在这里转成 encodingFailed。
  Future<ParseResult<HttpResponse>> _decode({
    required int status,
    required Headers headers,
    required List<int> bytes,
    required String rulePath,
    required String? keyword,
    required String url,
    required Uri responseUrl,
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
        // 只有本次刚嗅探出的标签才写缓存。
        await _writeCachedCharset(sourceId, url, decoded.charset);
      }
      if (decoded.toleratedMalformedBytes) {
        // 宽容解码必须留痕：记录编码与替换数量，正文、Cookie、Token 不入日志。
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
          url: responseUrl.toString(),
        ),
      );
    } on FormatException catch (error, stackTrace) {
      // 嗅探车道解码失败必须显式报错，不能静默替换成乱码。
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

// 唯一生成 Cookie 头、记录响应 Cookie 的地方。
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

// 缓存键的 ruleField 固定：同一页面会被不同阶段重复读取，带上阶段就会反复嗅探。
const String _charsetCacheField = 'charset';

// `page` 同样固定：字符集与页码无关。
const int _charsetCachePage = 1;

// 只区分 403、404 与其余非 2xx。
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

String _excerpt(String? declaration) {
  final String text = declaration ?? '';
  if (text.length <= _maxExcerptLength) {
    return text;
  }

  return '${text.substring(0, _maxExcerptLength)}…';
}

// 日志里保留的声明文本长度上限。
const int _maxExcerptLength = 32;

// 穷举所有 DioExceptionType，dio 新增枚举值时能直接编译报错。
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
