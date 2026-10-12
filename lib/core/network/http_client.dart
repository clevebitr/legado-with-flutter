import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/network/charset_decoder.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/http_response.dart';

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
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
  });
}

/// [HttpClient] backed by `dio` (C-NET-1).
final class DioHttpClient implements HttpClient {
  /// Creates a client that shares the cookie store and applies the policy.
  ///
  /// `dio` is injectable so tests can attach a fake adapter instead of touching
  /// the network (`docs/dev/testing.md` §4).
  DioHttpClient({
    required this._cookies,
    required this._logger,
    this._policy = const HttpPolicy(),
    Dio? dio,
  }) : _dio = dio ?? Dio() {
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
  final Dio _dio;

  @override
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
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
    while (true) {
      final ParseResult<HttpResponse> result = await _send(
        url,
        rulePath: rulePath,
        headers: headers,
        keyword: keyword,
        sourceId: sourceId,
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
  Future<ParseResult<HttpResponse>> _send(
    String url, {
    required String rulePath,
    required Map<String, String>? headers,
    required String? keyword,
    required String? sourceId,
  }) async {
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        url,
        options: Options(headers: headers),
      );
    } on DioException catch (error, stackTrace) {
      // 只有 dio 自己的异常到这里：URL 已在 get() 里校验，解码在 _decode 里单独处理。
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
    final ParseFailureKind? statusKind = _failureKindForStatus(status);

    if (statusKind != null) {
      _logger.warning(
        'HTTP $status for rule=$rulePath url=${redactUrl(url, keyword: keyword)}',
      );

      return ParseFailure<HttpResponse>(kind: statusKind, rulePath: rulePath);
    }

    return _decode(
      response,
      status: status,
      rulePath: rulePath,
      keyword: keyword,
      url: url,
      sourceId: sourceId,
    );
  }

  /// Decodes a 2xx body; the only place a [FormatException] is expected.
  ParseResult<HttpResponse> _decode(
    Response<List<int>> response, {
    required int status,
    required String rulePath,
    required String? keyword,
    required String url,
    required String? sourceId,
  }) {
    try {
      final DecodedBody decoded = decodeBody(
        response.data ?? const <int>[],
        contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      );
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
          headers: response.headers.map,
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
