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

import '../../support/capturing_log_printer.dart';
import '../../support/fake_http_adapter.dart';

/// Client under test plus its doubles.
typedef _Fixture = ({
  HttpClient client,
  FakeHttpAdapter adapter,
  CapturingLogPrinter printer,
});

/// Builds a client whose dio talks to [FakeHttpAdapter] instead of the network.
_Fixture _buildClient({HttpPolicy policy = const HttpPolicy()}) {
  final FakeHttpAdapter adapter = FakeHttpAdapter();
  final CapturingLogPrinter printer = CapturingLogPrinter();
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

    test('get_whenBodyCannotBeDecoded_returnsEncodingFailed', () async {
      final _Fixture fixture = _buildClient();
      fixture.adapter.enqueueResponse(
        bytes: <int>[0xFF, 0xFE, 0xFD],
        headers: <String, List<String>>{
          'content-type': <String>['text/html; charset=utf-8'],
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
  });
}
