import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
import 'package:flutter_reader/core/network/charset_decoder.dart';
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
  _FakeCharsetCache cache,
});

/// In-memory [CharsetCache] double: records what the client asked and answers from a map
/// (`docs/dev/testing.md` §4).
final class _FakeCharsetCache implements CharsetCache {
  /// Labels the client is told about, keyed by `sourceId|url`.
  final Map<String, String> entries = <String, String>{};

  /// URLs the client read.
  final List<String> reads = <String>[];

  /// `url=charset` pairs the client wrote.
  final List<String> writes = <String>[];

  /// When true, [read] throws so a test can pin the “cache failure is a miss” path.
  bool failReads = false;

  /// When true, [write] throws so a test can pin “a failed write is not the page's”.
  bool failWrites = false;

  @override
  Future<String?> read({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
  }) async {
    if (failReads) {
      throw Exception('cache read failed');
    }
    reads.add(url);

    return entries['$sourceId|$url'];
  }

  @override
  Future<void> write({
    required String sourceId,
    required String ruleField,
    required String url,
    required int page,
    required String charset,
  }) async {
    if (failWrites) {
      throw Exception('cache write failed');
    }
    writes.add('$url=$charset');
    entries['$sourceId|$url'] = charset;
  }
}

/// Builds a client whose dio talks to [FakeHttpAdapter] instead of the network.
_Fixture _buildClient({
  HttpPolicy policy = const HttpPolicy(),
  bool withCharsetCache = false,
}) {
  final FakeHttpAdapter adapter = FakeHttpAdapter();
  final FakeLogPrinter printer = FakeLogPrinter();
  final Dio dio = Dio()..httpClientAdapter = adapter;
  final _FakeCharsetCache cache = _FakeCharsetCache();

  return (
    client: DioHttpClient(
      cookies: InMemoryCookieManager(),
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      policy: policy,
      dio: dio,
      charsetCache: withCharsetCache ? cache : null,
    ),
    adapter: adapter,
    printer: printer,
    cache: cache,
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

/// Returns the `cause` of a failed [result], failing the test otherwise.
Object? _failureCause(ParseResult<HttpResponse> result) => switch (result) {
  ParseSuccess<HttpResponse>() => fail('Expected a failure.'),
  ParseFailure<HttpResponse>(:final Object? cause) => cause,
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
    test(
      'get_givenABodyLargerThanTheCallersCap_abandonsItWithATypedCause',
      () async {
        // docs/dev/roadmap.md 5.1 / ADR-0040 §决策 5：上限在**读**的时候生效（C-PERF-5），
        // 并带一个可识别的 cause，让导入层把它改写成自己的 rulePath。
        final _Fixture fixture = _buildClient();
        fixture.adapter.enqueueResponse(bytes: utf8.encode('0123456789'));

        final ParseResult<HttpResponse> result = await fixture.client.get(
          'https://example.test/sources.json',
          rulePath: 'import.url',
          maxBytes: 4,
        );

        expect(_expectFailure(result), ParseFailureKind.invalidBookSource);
        expect(_failureCause(result), isA<BodyTooLargeException>());
        expect(
          _failureCause(result).toString(),
          'Response body exceeded 4 bytes',
        );
        expect(
          fixture.printer.events.last.message.toString(),
          contains('limit=4'),
        );
      },
    );

    test('get_givenABodyWithinTheCallersCap_decodesIt', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: utf8.encode('{}'),
        headers: <String, List<String>>{
          'content-type': <String>['application/json; charset=utf-8'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.test/sources.json',
          rulePath: 'import.url',
          maxBytes: 4,
        ),
      );

      expect(response.body, '{}');
    });

    test('get_givenANonSuccessStatusWithACap_releasesTheBody', () async {
      // 流模式下 4xx/5xx 的正文还握在 dio 手里；不取消订阅就把连接留着（[_discard]）。
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        statusCode: 404,
        bytes: utf8.encode('nope'),
      );

      final ParseResult<HttpResponse> result = await fixture.client.get(
        'https://example.test/sources.json',
        rulePath: 'import.url',
        maxBytes: 4,
      );

      expect(_expectFailure(result), ParseFailureKind.notFound);
    });

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

    test('get_givenNoDeclaration_writesTheDetectedCharsetToTheCache', () async {
      final _Fixture fixture = _buildClient(withCharsetCache: true);
      // 无声明的 GBK 页：嗅探车道，结果应记入缓存（book-source.md §5）。
      // 期望值取自解码器自己：断言的是「嗅探出什么就缓存什么」，
      // 而不是钉某个检测器版本对这两个字节的选择。
      const List<int> bytes = <int>[0xCC, 0xEC];
      final DecodedBody sniffed = decodeBody(bytes);
      fixture.adapter.enqueueResponse(bytes: bytes);

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'ruleBookInfo',
          sourceId: 'https://example.com',
        ),
      );

      expect(response.body, sniffed.text);
      expect(fixture.cache.writes, <String>[
        'https://example.com/a=${sniffed.charset}',
      ]);
    });

    test('get_givenACachedLabel_sniffsNoMore', () async {
      final _Fixture fixture = _buildClient(withCharsetCache: true);
      fixture.cache.entries['https://example.com|https://example.com/a'] =
          'gbk';
      // UTF-8 字节 + 缓存标签 gbk：解出来是 GBK 读法（不是嗅探会选的 utf-8），
      // 即第二次请求确实没有再嗅探（PLAN 3.9 的验收口径）。
      fixture.adapter.enqueueResponse(bytes: utf8.encode('剑来'));

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'ruleBookInfo',
          sourceId: 'https://example.com',
        ),
      );

      expect(fixture.cache.reads, <String>['https://example.com/a']);
      expect(response.body, isNot('剑来'));
      expect(fixture.cache.writes, isEmpty, reason: '命中的标签不需要重写');
    });

    test('get_givenADeclaredCharset_doesNotWriteToTheCache', () async {
      final _Fixture fixture = _buildClient(withCharsetCache: true);
      fixture.adapter.enqueueResponse(
        bytes: <int>[0xCC, 0xEC],
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=gbk'],
        },
      );

      final HttpResponse response = _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'ruleBookInfo',
          sourceId: 'https://example.com',
        ),
      );

      // 声明车道每次都能自己读出标签，不值得缓存；而且声明优先于缓存标签（ADR-0031）。
      expect(response.body, '天');
      expect(fixture.cache.writes, isEmpty);
    });

    test('get_givenACacheThatBreaksItsContract_theFailurePropagates', () async {
      // `CharsetCache` 的契约是 total（读返回 null / 写 no-op / 绝不抛），失败面在适配器里
      // 被吸收，所以客户端**故意**没有异常边界：C-ERR-2 的 `on Exception` 只允许出现在
      // presentation 的 Notifier 里（ADR-0002 的修订注记）。这条用例把边界的位置钉住——
      // 契约被违反时异常不会被就地吞掉。
      final _Fixture fixture = _buildClient(withCharsetCache: true);
      fixture.cache.failReads = true;
      fixture.adapter.enqueueResponse(bytes: <int>[0xCC, 0xEC]);

      await expectLater(
        fixture.client.get(
          'https://example.com/a',
          rulePath: 'ruleBookInfo',
          sourceId: 'https://example.com',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('get_givenNoSourceId_doesNotTouchTheCache', () async {
      final _Fixture fixture = _buildClient(withCharsetCache: true);
      fixture.adapter.enqueueResponse(bytes: <int>[0xCC, 0xEC]);

      _expectSuccess(
        await fixture.client.get(
          'https://example.com/a',
          rulePath: 'searchUrl',
        ),
      );

      // C-NET-6 的键以书源 ID 开头：没有书源上下文的页没有可缓存的身份。
      expect(fixture.cache.reads, isEmpty);
      expect(fixture.cache.writes, isEmpty);
    });
  });

  group('DioHttpClient applySourceRate', () {
    test('applySourceRate_givenALegalDeclaration_doesNotWarn', () {
      final _Fixture fixture = _buildClient();

      fixture.client.applySourceRate('https://example.com', '5/1000');

      // 合法声明、`"0"` 与空白都是安静路径：日志里不应该出现 `concurrentRate`。
      fixture.client.applySourceRate('https://example.com', '0');
      fixture.client.applySourceRate('https://example.com', '');

      expect(
        fixture.printer.events.map(
          (LogEvent event) => event.message.toString(),
        ),
        isNot(contains(contains('concurrentRate'))),
      );
    });

    test('applySourceRate_givenAnIllegalDeclaration_warnsOnce', () {
      final _Fixture fixture = _buildClient();

      fixture.client.applySourceRate('https://example.com', 'abc');

      // ADR-0036 §决策 2：非法声明要**可观测**——一条 warning，含书源 ID、字段名与原文。
      final List<String> messages = fixture.printer.events
          .map((LogEvent event) => event.message.toString())
          .toList();
      expect(messages, hasLength(1));
      expect(messages.single, contains('source=https://example.com'));
      expect(messages.single, contains('field=concurrentRate'));
      expect(messages.single, contains('reason=not an integer'));
      expect(messages.single, contains('value=abc'));
    });

    test(
      'applySourceRate_givenALongIllegalDeclaration_truncatesTheExcerpt',
      () {
        final _Fixture fixture = _buildClient();
        final String long = 'x' * 64;

        fixture.client.applySourceRate('https://example.com', long);

        // 日志里只留前 32 个字符 + 截断标记（C-ERR-8 / C-SEC-4 的「摘要」口径）。
        final String message = fixture.printer.events.single.message.toString();
        expect(message, contains('value=${'x' * 32}…'));
        expect(message, isNot(contains(long)));
      },
    );
  });
}
