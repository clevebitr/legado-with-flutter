import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/fake_log_printer.dart';

/// Client under test plus its doubles.
typedef _Fixture = ({
  HttpClient client,
  FakeHttpAdapter adapter,
  FakeLogPrinter printer,
});

/// Builds a client whose dio talks to [FakeHttpAdapter] instead of the network.
_Fixture _buildClient({HttpPolicy policy = const HttpPolicy()}) {
  final FakeHttpAdapter adapter = FakeHttpAdapter();
  final FakeLogPrinter printer = FakeLogPrinter();
  final Dio dio = Dio()..httpClientAdapter = adapter;

  return (
    client: DioHttpClient(
      cookies: InMemoryCookieManager(),
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      policy: policy,
      dio: dio,
    ),
    adapter: adapter,
    printer: printer,
  );
}

/// Returns the response of a successful [result], failing the test otherwise.
HttpResponse _expectSuccess(ParseResult<HttpResponse> result) =>
    switch (result) {
      ParseSuccess<HttpResponse>(:final HttpResponse data) => data,
      ParseFailure<HttpResponse>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the kind of a failed [result], failing the test otherwise.
ParseFailureKind _expectFailure(ParseResult<HttpResponse> result) =>
    switch (result) {
      ParseSuccess<HttpResponse>() => fail('Expected a failure.'),
      ParseFailure<HttpResponse>(:final ParseFailureKind kind) => kind,
    };

/// Pumps the event queue until [condition] holds, failing when it never does.
///
/// A bounded loop instead of a wall-clock wait, so the concurrency tests below cannot
/// flake (`docs/dev/testing.md` §8 forbids sleeping).
Future<void> _pumpUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await pumpEventQueue(times: 1);
  }

  expect(condition(), isTrue);
}

void main() {
  group('DioHttpClient', () {
    test('get_whenServerReturns200_decodesTheBody', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: utf8.encode('<html>hi</html>'),
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=utf-8'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'searchUrl',
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, '<html>hi</html>');
      expect(response.headers['content-type'], <String>[
        'text/html; charset=utf-8',
      ]);
    });

    test('get_whenContentTypeDeclaresGbk_decodesGbkBytes', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: <int>[0xCC, 0xEC],
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=gbk'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'contentRule.content',
        ),
      );

      expect(response.body, '天');
    });

    test('get_whenStatusIsForbidden_returnsNetworkForbidden', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(statusCode: 403);

      expect(
        _expectFailure(
          await fixture.client.get(
            'https://example.com/a',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.networkForbidden,
      );
      expect(
        fixture.adapter.requests,
        hasLength(1),
        reason: 'A 403 is not retryable.',
      );
    });

    test('get_whenStatusIsNotFound_returnsNotFound', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(statusCode: 404);

      expect(
        _expectFailure(
          await fixture.client.get(
            'https://example.com/a',
            rulePath: 'tocRule.chapterUrl',
          ),
        ),
        ParseFailureKind.notFound,
      );
    });

    test(
      'get_whenStatusIsServerError_returnsNetworkFailedAfterRetrying',
      () async {
        final _Fixture fixture = _buildClient();
        fixture.adapter.enqueueResponse(statusCode: 500);
        fixture.adapter.enqueueResponse(statusCode: 500);

        expect(
          _expectFailure(
            await fixture.client.get(
              'https://example.com/a',
              rulePath: 'searchUrl',
            ),
          ),
          ParseFailureKind.networkFailed,
        );
        expect(fixture.adapter.requests, hasLength(2));
      },
    );

    test(
      'get_whenFirstAttemptFailsAndTheNextSucceeds_returnsSuccess',
      () async {
        final _Fixture fixture = _buildClient();
        fixture.adapter.enqueueFailure(DioExceptionType.connectionError);
        fixture.adapter.enqueueResponse(bytes: utf8.encode('ok'));

        final HttpResponse response = _expectSuccess(
          await fixture.client.get(
            'https://example.com/a',
            rulePath: 'searchUrl',
          ),
        );

        expect(response.body, 'ok');
        expect(fixture.adapter.requests, hasLength(2));
        expect(
          fixture.printer.events.map((LogEvent event) => event.message),
          contains(contains('Retrying request')),
        );
      },
    );

    test('get_whenRetriesAreDisabled_doesNotRetry', () async {
      final _Fixture fixture = _buildClient(
        policy: const HttpPolicy(maxRetries: 0),
      );
      fixture.adapter.enqueueResponse(statusCode: 500);

      expect(
        _expectFailure(
          await fixture.client.get(
            'https://example.com/a',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.networkFailed,
      );
      expect(fixture.adapter.requests, hasLength(1));
    });

    test('get_whenDioFails_mapsEveryExceptionTypeOntoAKind', () async {
      const Map<DioExceptionType, ParseFailureKind> expected =
          <DioExceptionType, ParseFailureKind>{
            DioExceptionType.connectionTimeout: ParseFailureKind.networkTimeout,
            DioExceptionType.sendTimeout: ParseFailureKind.networkTimeout,
            DioExceptionType.receiveTimeout: ParseFailureKind.networkTimeout,
            DioExceptionType.transformTimeout: ParseFailureKind.networkTimeout,
            DioExceptionType.connectionError: ParseFailureKind.networkFailed,
            DioExceptionType.badCertificate: ParseFailureKind.networkFailed,
            DioExceptionType.unknown: ParseFailureKind.networkFailed,
            DioExceptionType.cancel: ParseFailureKind.cancelled,
            DioExceptionType.badResponse: ParseFailureKind.networkForbidden,
          };

      for (final MapEntry<DioExceptionType, ParseFailureKind> entry
          in expected.entries) {
        final _Fixture fixture = _buildClient(
          policy: const HttpPolicy(maxRetries: 0),
        );
        fixture.adapter.enqueueFailure(
          entry.key,
          statusCode: entry.key == DioExceptionType.badResponse ? 403 : null,
        );

        expect(
          _expectFailure(
            await fixture.client.get(
              'https://example.com/a',
              rulePath: 'searchUrl',
            ),
          ),
          entry.value,
          reason: 'DioExceptionType.${entry.key.name}',
        );
      }
    });

    test('get_whenUrlIsMalformed_returnsNetworkFailedWithoutSending', () async {
      final _Fixture fixture = _buildClient();

      // dio 内部还会再 Uri.parse 一次，这里必须提前拒绝，否则它的 FormatException
      // 会被当成解码失败（encodingFailed），桶就错了。
      expect(
        _expectFailure(
          await fixture.client.get('http://[bad', rulePath: 'searchUrl'),
        ),
        ParseFailureKind.networkFailed,
      );
      expect(fixture.adapter.requests, isEmpty);
      expect(
        fixture.printer.events.single.message,
        contains('<unparsable-url>'),
      );
    });

    test('get_whenUrlHasNoSupportedScheme_returnsNetworkFailed', () async {
      final _Fixture fixture = _buildClient();

      expect(
        _expectFailure(
          await fixture.client.get('example.com/a', rulePath: 'searchUrl'),
        ),
        ParseFailureKind.networkFailed,
      );
      expect(fixture.adapter.requests, isEmpty);
    });

    test('get_whenUrlIsPlainHttp_rejectsItWithoutSending', () async {
      final _Fixture fixture = _buildClient();

      expect(
        _expectFailure(
          await fixture.client.get(
            'http://example.com/a?token=abc123',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.networkFailed,
      );
      expect(fixture.adapter.requests, isEmpty);
      expect(fixture.printer.events.single.message, contains('token=***'));
    });

    test('get_whenPlainHttpIsAllowed_sendsTheRequest', () async {
      final _Fixture fixture = _buildClient(
        policy: const HttpPolicy(allowPlainHttp: true),
      );
      fixture.adapter.enqueueResponse(bytes: utf8.encode('ok'));

      final HttpResponse response = _expectSuccess(
        await fixture.client.get('http://example.com/a', rulePath: 'searchUrl'),
      );

      expect(response.body, 'ok');
      expect(fixture.adapter.requests, hasLength(1));
    });

    test('get_whenNoHeadersAreGiven_sendsThePolicyUserAgent', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse();

      await fixture.client.get('https://example.com/a', rulePath: 'searchUrl');

      expect(
        fixture.adapter.requests.single.headers['user-agent'],
        'flutter_reader',
      );
    });

    test('get_whenHeadersAreGiven_overridesTheDefaults', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse();

      await fixture.client.get(
        'https://example.com/a',
        rulePath: 'searchUrl',
        headers: <String, String>{'user-agent': 'BookSource/1.0'},
      );

      expect(
        fixture.adapter.requests.single.headers['user-agent'],
        'BookSource/1.0',
      );
    });

    test('get_whenAResponseSetsACookie_sendsItOnTheNextRequest', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: utf8.encode('first'),
        headers: <String, List<String>>{
          'set-cookie': <String>['session=abc; Path=/'],
        },
      );
      fixture.adapter.enqueueResponse(bytes: utf8.encode('second'));

      await fixture.client.get('https://example.com/a', rulePath: 'searchUrl');
      await fixture.client.get('https://example.com/b', rulePath: 'searchUrl');

      expect(fixture.adapter.requests.last.headers['cookie'], 'session=abc');
    });

    test('get_whenBodyFallsBackToUtf8AndFails_returnsEncodingFailed', () async {
      final _Fixture fixture = _buildClient();
      // 未知标签会回退 UTF-8，而回退 / 嗅探车道的解码失败必须显式失败
      // （C-NET-3、ADR-0031 §决策 2）。
      fixture.adapter.enqueueResponse(
        bytes: <int>[0xFF, 0xFE, 0xFD],
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=x-unknown'],
        },
      );

      expect(
        _expectFailure(
          await fixture.client.get(
            'https://example.com/a',
            rulePath: 'contentRule.content',
          ),
        ),
        ParseFailureKind.encodingFailed,
      );
    });

    test('get_whenDeclaredCharsetHasAStrayByte_decodesItAndLogsIt', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: <int>[0xE5, 0x89, 0x91, 0x8B],
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=utf-8'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'contentRule.content',
          sourceId: 'https://example-novel.test',
        ),
      );

      final Object? message = fixture.printer.events.single.message;
      // ADR-0031 §决策 1/2：声明是权威，坏字节用替换字符顶上（整页仍然可用）——但必须留痕，
      // 且措辞要能解释发生了什么：声明的编码 + 替换数量；同时不得含正文（C-SEC-4）。
      expect(response.body, contains('\uFFFD'));
      expect(message, contains('utf-8'));
      expect(message, contains('1 malformed byte'));
      expect(message, contains('contentRule.content'));
      // C-ERR-8：warning 必须能定位到书源。
      expect(message, contains('https://example-novel.test'));
    });

    test('get_whenAnExceptionIsLogged_writesADigestAndARedactedUrl', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueFailure(DioExceptionType.cancel);

      expect(
        _expectFailure(
          await fixture.client.get(
            'https://example.com/a?token=abc123',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.cancelled,
      );

      final Object? loggedError = fixture.printer.events.single.error;

      expect(loggedError, isA<String>());
      expect(loggedError, isNot(contains('example.com')));
      expect(fixture.printer.events.single.message, contains('token=***'));
    });

    test('get_whenSearchUrlFails_keepsTheKeywordOutOfTheLog', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueFailure(DioExceptionType.cancel);

      await fixture.client.get(
        'https://example.com/search/hello?page=1',
        rulePath: 'searchUrl',
        keyword: 'hello',
      );

      expect(fixture.printer.events.single.message, isNot(contains('hello')));
    });

    test('get_givenMoreRequestsThanTheSourcesBudget_queuesTheExcess', () async {
      const String sourceId = 'https://example-novel.test';
      final _Fixture fixture = _buildClient(
        policy: const HttpPolicy(maxConcurrentRequestsPerSource: 1),
      );
      final List<Completer<void>> gates = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
      ];
      var fetchIndex = 0;
      fixture.adapter.onFetch = () => gates[fetchIndex++].future;
      fixture.adapter.enqueueResponse(bytes: utf8.encode('first'));
      fixture.adapter.enqueueResponse(bytes: utf8.encode('second'));

      final Future<ParseResult<HttpResponse>> first = fixture.client.get(
        'https://example-novel.test/a',
        rulePath: 'ruleContent',
        sourceId: sourceId,
      );
      final Future<ParseResult<HttpResponse>> second = fixture.client.get(
        'https://example-novel.test/b',
        rulePath: 'ruleContent',
        sourceId: sourceId,
      );

      await _pumpUntil(() => fixture.adapter.requests.isNotEmpty);
      // §8：同一书源的预算为 1，第二个请求必须排到第一个结束之后。
      expect(fixture.adapter.requests, hasLength(1));

      gates[0].complete();
      await _pumpUntil(() => fixture.adapter.requests.length == 2);
      gates[1].complete();
      await Future.wait(<Future<ParseResult<HttpResponse>>>[first, second]);

      expect(_expectSuccess(await first).body, 'first');
      expect(_expectSuccess(await second).body, 'second');
    });

    test('get_givenNoSourceId_keysTheBudgetByHost', () async {
      final _Fixture fixture = _buildClient(
        policy: const HttpPolicy(maxConcurrentRequestsPerSource: 1),
      );
      final Completer<void> gate = Completer<void>();
      fixture.adapter.onFetch = () => gate.future;
      fixture.adapter.enqueueResponse(bytes: utf8.encode('a'));
      fixture.adapter.enqueueResponse(bytes: utf8.encode('b'));
      fixture.adapter.enqueueResponse(bytes: utf8.encode('c'));

      final Future<ParseResult<HttpResponse>> held = fixture.client.get(
        'https://one.test/a',
        rulePath: 'searchUrl',
      );
      await _pumpUntil(() => fixture.adapter.requests.isNotEmpty);

      // 另一台主机有它自己的预算，不必等第一个结束。
      final Future<ParseResult<HttpResponse>> other = fixture.client.get(
        'https://two.test/b',
        rulePath: 'searchUrl',
      );
      await _pumpUntil(() => fixture.adapter.requests.length == 2);

      // 同一主机仍在同一份预算里排队（无书源上下文时按主机分桶）。
      final Future<ParseResult<HttpResponse>> sameHost = fixture.client.get(
        'https://one.test/c',
        rulePath: 'searchUrl',
      );
      await pumpEventQueue();
      expect(fixture.adapter.requests, hasLength(2));

      gate.complete();
      await Future.wait(<Future<ParseResult<HttpResponse>>>[
        held,
        other,
        sameHost,
      ]);
      expect(fixture.adapter.requests, hasLength(3));
    });

    test('post_whenServerReturns200_sendsTheBodyAndTheMethod', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: utf8.encode('{"ok":true}'),
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.post(
          'https://example.com/api',
          rulePath: 'searchUrl',
          body: 'q=1',
          headers: <String, String>{'content-type': 'text/plain'},
        ),
      );

      expect(response.body, '{"ok":true}');
      expect(fixture.adapter.requests.single.method, 'POST');
      expect(fixture.adapter.requests.single.data, 'q=1');
      expect(
        fixture.adapter.requests.single.headers['content-type'],
        'text/plain',
      );
    });

    test('post_whenTheBodyIsAbsent_sendsAnEmptyPayload', () async {
      // `http.post` 的 options 里没有 body 时不能凭空造一个：POST 与 GET 共用同一条
      // 决策路径，唯一差别就是 method 与 data。
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(bytes: utf8.encode('ok'));

      expect(
        _expectSuccess(
          await fixture.client.post(
            'https://example.com/api',
            rulePath: 'searchUrl',
          ),
        ).body,
        'ok',
      );
      expect(fixture.adapter.requests.single.data, isNull);
    });

    test('post_sharesTheGetRetryAndRejectionPolicy', () async {
      final _Fixture fixture = _buildClient(
        policy: const HttpPolicy(maxRetries: 0),
      );
      fixture.adapter.enqueueResponse(statusCode: 403);

      expect(
        _expectFailure(
          await fixture.client.post(
            'https://example.com/api',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.networkForbidden,
      );

      // 明文 HTTP 与畸形 URL 的拒绝也走同一条 `_request` 守卫。
      final _Fixture plain = _buildClient();
      expect(
        _expectFailure(
          await plain.client.post(
            'http://example.com/a',
            rulePath: 'searchUrl',
          ),
        ),
        ParseFailureKind.networkFailed,
      );
      expect(plain.adapter.requests, isEmpty);
    });
  });
}
