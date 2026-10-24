import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';

/// Hand-written [HttpClient] double: serves bodies per URL and records every
/// request, so no test touches the network (`docs/dev/testing.md` §4).
///
/// Only the public [HttpClient] contract is faked — no `dio` internals are mocked —
/// and the recorded URLs let a test assert what the production chain actually
/// requested (template rendering, keyword encoding, relative-URL resolution).
final class FakeHttpClient implements HttpClient {
  /// Requested URLs, in order.
  final List<String> requestedUrls = <String>[];

  /// The `rulePath` of every request, in order.
  final List<String> requestedRulePaths = <String>[];

  /// The request-level `headers` of every request, in order.
  ///
  /// Kept so a test can assert that the book source's own `header` field really
  /// reaches the client (`book-source.md` §2) instead of being dropped on the way.
  final List<Map<String, String>?> requestedHeaders = <Map<String, String>?>[];

  /// The `sourceId` of every request, in order.
  ///
  /// The HTTP layer only uses it to name the book source in the logs it owns
  /// (C-ERR-8, ADR-0031 §决策 2), so a test asserts it arrives rather than keeping it
  /// in the page service.
  final List<String?> requestedSourceIds = <String?>[];

  /// The caller's `maxBytes` cap of every request, in order (`null` when the caller set none).
  ///
  /// It exists so a test can assert that the import path really asks for a bounded download
  /// (`docs/dev/roadmap.md` 5.1, ADR-0040 §决策 5) instead of trusting the client.
  final List<int?> requestedMaxBytes = <int?>[];

  /// The HTTP method of every request, in order (`GET` / `POST`).
  ///
  /// `http.post` of `docs/dev/book-source.md` §6 goes through the same seam, so a test
  /// has to be able to tell which verb a rule really sent.
  final List<String> requestedMethods = <String>[];

  /// The request body of every request, in order (`null` for a GET).
  final List<String?> requestedBodies = <String?>[];

  /// The `maxRetries` a URL rule asked for, in order (`null` = policy default).
  final List<int?> requestedMaxRetries = <int?>[];

  /// The `receiveTimeout` a URL rule asked for, in order.
  final List<Duration?> requestedReceiveTimeouts = <Duration?>[];

  /// The `charset` a URL rule declared for every request, in order
  /// (`book-source.md` §4.3): `url,{“charset”:“gbk”}` has to reach the decoder.
  final List<String?> requestedCharsets = <String?>[];

  /// Awaited after a request is recorded and before it answers, when set.
  ///
  /// The hook lets a test hold a request open and decide when it may answer — needed to
  /// observe a `http.*` call whose job ends while the request is still in flight — without a
  /// wall-clock wait (`docs/dev/testing.md` §8 forbids sleeping).
  Future<void> Function()? onRequest;

  /// The `concurrentRate` declarations this client was told about, keyed by source id.
  ///
  /// The real client turns them into a rate gate (`book-source.md` §8); a double only has to
  /// prove the production chain **handed the source's declaration over**, which is what
  /// `page_fetch_service` and the use cases are responsible for.
  final Map<String, String?> sourceRates = <String, String?>{};

  @override
  void applySourceRate(String sourceId, String? concurrentRate) {
    sourceRates[sourceId] = concurrentRate;
  }

  final Map<String, String> _bodies = <String, String>{};
  final Map<String, ParseFailureKind> _failures = <String, ParseFailureKind>{};
  final Map<String, Object?> _causes = <String, Object?>{};
  final Map<String, Exception> _throws = <String, Exception>{};

  /// Serves [body] for [url].
  void serve(String url, String body) => _bodies[url] = body;

  /// Makes [url] fail with [kind] instead of being served.
  ///
  /// [cause] lets a test reproduce a **typed** refusal — the request layer marks an oversized
  /// body with a `BodyTooLargeException` cause, and the import path has to recognise it.
  void failWith(String url, ParseFailureKind kind, {Object? cause}) {
    _failures[url] = kind;
    if (cause != null) {
      _causes[url] = cause;
    }
  }

  /// Makes [url] **throw** [error] instead of answering with a [ParseResult].
  ///
  /// Deliberately out of contract: `HttpClient` answers with a [ParseResult]
  /// (C-ERR-1), and the pages must still show a message rather than a blank screen
  /// when a collaborator breaks that contract. This is how that branch is covered.
  void throwOn(String url, Exception error) => _throws[url] = error;

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
  }) => _serve(
    method: 'GET',
    url: url,
    rulePath: rulePath,
    headers: headers,
    sourceId: sourceId,
    maxBytes: maxBytes,
    declaredCharset: declaredCharset,
    maxRetries: maxRetries,
    receiveTimeout: receiveTimeout,
  );

  /// Answers the **bytes** of the served body.
  ///
  /// The double re-encodes the text it was given: what it has to prove is that the caller went
  /// through the request layer's byte door at all (C-NET-1), not how a real binary body survives
  /// transport — that is `http_client_test`'s job with a Dio adapter.
  @override
  Future<ParseResult<Uint8List>> getBytes(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
  }) async {
    final ParseResult<HttpResponse> result = await get(
      url,
      rulePath: rulePath,
      headers: headers,
      keyword: keyword,
      sourceId: sourceId,
      maxBytes: maxBytes,
    );

    return switch (result) {
      ParseSuccess<HttpResponse>(:final HttpResponse data) =>
        ParseSuccess<Uint8List>(Uint8List.fromList(utf8.encode(data.body))),
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        ParseFailure<Uint8List>(kind: kind, rulePath: rulePath),
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
  }) => _serve(
    method: 'POST',
    url: url,
    rulePath: rulePath,
    body: body,
    headers: headers,
    sourceId: sourceId,
    declaredCharset: declaredCharset,
    maxRetries: maxRetries,
    receiveTimeout: receiveTimeout,
  );

  /// Records one request and answers from the registered bodies / failures.
  Future<ParseResult<HttpResponse>> _serve({
    required String method,
    required String url,
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? sourceId,
    int? maxBytes,
    String? declaredCharset,
    int? maxRetries,
    Duration? receiveTimeout,
  }) async {
    requestedMaxRetries.add(maxRetries);
    requestedReceiveTimeouts.add(receiveTimeout);
    requestedUrls.add(url);
    requestedRulePaths.add(rulePath);
    requestedHeaders.add(headers);
    requestedSourceIds.add(sourceId);
    requestedMethods.add(method);
    requestedBodies.add(body);
    requestedMaxBytes.add(maxBytes);
    requestedCharsets.add(declaredCharset);

    final Future<void> Function()? hook = onRequest;
    if (hook != null) {
      await hook();
    }

    final Exception? thrown = _throws[url];
    if (thrown != null) {
      throw thrown;
    }

    final ParseFailureKind? kind = _failures[url];
    if (kind != null) {
      return ParseFailure<HttpResponse>(
        kind: kind,
        rulePath: rulePath,
        cause: _causes[url],
      );
    }

    final String? served = _bodies[url];
    if (served == null) {
      // 未登记的 URL 视为 404：测试必须显式声明它期望被请求的每一个地址。
      return ParseFailure<HttpResponse>(
        kind: ParseFailureKind.notFound,
        rulePath: rulePath,
      );
    }

    return ParseSuccess<HttpResponse>(
      HttpResponse(
        statusCode: 200,
        headers: const <String, List<String>>{},
        body: served,
      ),
    );
  }
}
