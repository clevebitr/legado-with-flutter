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

  final Map<String, String> _bodies = <String, String>{};
  final Map<String, ParseFailureKind> _failures = <String, ParseFailureKind>{};

  /// Serves [body] for [url].
  void serve(String url, String body) => _bodies[url] = body;

  /// Makes [url] fail with [kind] instead of being served.
  void failWith(String url, ParseFailureKind kind) => _failures[url] = kind;

  @override
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
  }) async {
    requestedUrls.add(url);
    requestedRulePaths.add(rulePath);

    final ParseFailureKind? kind = _failures[url];
    if (kind != null) {
      return ParseFailure<HttpResponse>(kind: kind, rulePath: rulePath);
    }

    final String? body = _bodies[url];
    if (body == null) {
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
        body: body,
      ),
    );
  }
}
