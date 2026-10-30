import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_lib.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_http_client.dart';
import '../../support/fake_log_printer.dart';

void main() {
  group('JsLibStore', () {
    test('resolve_givenNoLibrary_answersNull', () async {
      final JsLibStore store = JsLibStore();

      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: null,
            rulePath: 'searchRule.name',
          ),
        ),
        isNull,
      );
      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: '   ',
            rulePath: 'searchRule.name',
          ),
        ),
        isNull,
      );
    });

    test('resolve_givenPlainJavaScript_answersItUnchanged', () async {
      // 上游 `isJsonObject()` 为假：整个字段就是一段 JS，原样跑。
      const String lib = 'function sign(url) { return url + md5("x"); }';
      final JsLibStore store = JsLibStore();

      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: lib,
            rulePath: 'searchRule.name',
          ),
        ),
        lib,
      );
    });

    test(
      'resolve_givenAJsonObjectOfUrls_downloadsAndConcatenatesThem',
      () async {
        final FakeHttpClient http = FakeHttpClient()
          ..serve('https://cdn.test/a.js', 'function a() { return 1; }')
          ..serve('https://cdn.test/b.js', 'function b() { return 2; }');
        final JsLibStore store = JsLibStore(http: http);

        final ParseResult<String?> resolved = await store.resolve(
          sourceUrl: 'https://a.test',
          jsLib:
              '{"lib1":"https://cdn.test/a.js","lib2":"https://cdn.test/b.js"}',
          rulePath: 'searchRule.name',
        );

        expect(_value(resolved), contains('function a()'));
        expect(_value(resolved), contains('function b()'));
        // 两条脚本之间要有一行分隔：上一条的尾注释不吞掉下一条。
        expect(_value(resolved), contains('}\n;\n'));
        expect(http.requestedUrls, <String>[
          'https://cdn.test/a.js',
          'https://cdn.test/b.js',
        ]);
        expect(http.requestedSourceIds, <String?>[
          'https://a.test',
          'https://a.test',
        ]);
      },
    );

    test('resolve_givenAJsonObjectWithoutUrls_answersNoLibrary', () async {
      // 上游的循环只下载 `isAbsUrl()` 的值；一个没有 URL 的对象等于没有库。
      final FakeHttpClient http = FakeHttpClient();
      final JsLibStore store = JsLibStore(http: http);

      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: '{"note":"not a url"}',
            rulePath: 'searchRule.name',
          ),
        ),
        isNull,
      );
      expect(http.requestedUrls, isEmpty);
    });

    test('resolve_givenJsonThatIsNotAnObject_fallsBackToPlainJs', () async {
      final JsLibStore store = JsLibStore();

      // 数组与坏 JSON 都不是「对象形态的库」，按上游判定当普通 JS。
      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: '["https://cdn.test/a.js"]',
            rulePath: 'r',
          ),
        ),
        '["https://cdn.test/a.js"]',
      );
      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: '{"broken": ',
            rulePath: 'r',
          ),
        ),
        '{"broken": ',
      );
    });

    test('resolve_givenADownloadFailure_failsWithTheLibMarker', () async {
      // 库拿不到就是这条规则的失败，而且错误要能看出不是规则自己的错（C-SRC-4）。
      final FakeHttpClient http = FakeHttpClient()
        ..failWith('https://cdn.test/a.js', ParseFailureKind.networkFailed);
      final FakeLogPrinter printer = FakeLogPrinter();
      final JsLibStore store = JsLibStore(
        http: http,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      final ParseResult<String?> resolved = await store.resolve(
        sourceUrl: 'https://a.test',
        jsLib: '{"lib":"https://cdn.test/a.js"}',
        rulePath: 'searchRule.name',
      );

      expect(
        switch (resolved) {
          ParseFailure<String?>(
            :final ParseFailureKind kind,
            :final String rulePath,
          ) =>
            (kind, rulePath),
          ParseSuccess<String?>() => fail('Expected a failure.'),
        },
        (ParseFailureKind.networkFailed, 'searchRule.name:js:lib'),
      );
      expect(printer.events.single.level, Level.warning);
    });

    test('resolve_givenNoHttpClient_reportsAUrlLibraryAsUnsupported', () async {
      // 没有网络端口的装配（单测 / 未接线）不能静默当「没有库」：规则会因此全错。
      final JsLibStore store = JsLibStore();

      expect(switch (await store.resolve(
        sourceUrl: 'https://a.test',
        jsLib: '{"lib":"https://cdn.test/a.js"}',
        rulePath: 'r',
      )) {
        ParseFailure<String?>(:final ParseFailureKind kind) => kind,
        ParseSuccess<String?>() => fail('Expected a failure.'),
      }, ParseFailureKind.unsupportedRule);
    });

    test('resolve_givenTheSameLibraryTwice_downloadsOnce', () async {
      // 一页二十个 `@js:` 字段会问二十次；库只该下载一次。
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://cdn.test/a.js', 'var a = 1;');
      final JsLibStore store = JsLibStore(http: http);
      const String jsLib = '{"lib":"https://cdn.test/a.js"}';

      await Future.wait(<Future<ParseResult<String?>>>[
        store.resolve(sourceUrl: 'https://a.test', jsLib: jsLib, rulePath: 'r'),
        store.resolve(sourceUrl: 'https://a.test', jsLib: jsLib, rulePath: 'r'),
        store.resolve(sourceUrl: 'https://a.test', jsLib: jsLib, rulePath: 'r'),
      ]);

      expect(http.requestedUrls, <String>['https://cdn.test/a.js']);
    });

    test('resolve_givenMoreLibrariesThanItRemembers_dropsTheOldest', () async {
      // 上限与上游 `LruCache(16)` 同数；超出的库下次重新解析。
      final JsLibStore store = JsLibStore(maxEntries: 2);
      for (final String lib in <String>['a', 'b', 'c']) {
        await store.resolve(
          sourceUrl: 'https://a.test',
          jsLib: lib,
          rulePath: 'r',
        );
      }

      expect(store.cachedTextOf('a'), isNull);
      expect(store.cachedTextOf('b'), 'b');
      expect(store.cachedTextOf('c'), 'c');
    });

    test('resolve_givenACachedLibrary_doesNotAskTheNetworkAgain', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve('https://cdn.test/a.js', 'var a = 1;');
      final JsLibStore store = JsLibStore(http: http);
      const String jsLib = '{"lib":"https://cdn.test/a.js"}';

      await store.resolve(
        sourceUrl: 'https://a.test',
        jsLib: jsLib,
        rulePath: 'r',
      );
      await store.resolve(
        sourceUrl: 'https://a.test',
        jsLib: jsLib,
        rulePath: 'r',
      );

      expect(http.requestedUrls, hasLength(1));
      expect(store.cachedTextOf(jsLib), contains('var a = 1;'));
    });

    test('resolve_givenAFailureThenASuccess_retriesTheDownload', () async {
      // 失败不进缓存：站点瞬断之后，下一条规则应该能重新拿到库。
      final FakeHttpClient http = FakeHttpClient()
        ..failWith('https://cdn.test/a.js', ParseFailureKind.networkTimeout);
      final JsLibStore store = JsLibStore(http: http);
      const String jsLib = '{"lib":"https://cdn.test/a.js"}';

      expect(
        await store.resolve(
          sourceUrl: 'https://a.test',
          jsLib: jsLib,
          rulePath: 'r',
        ),
        isA<ParseFailure<String?>>(),
      );

      http
        ..clearFailures()
        ..serve('https://cdn.test/a.js', 'var a = 1;');
      expect(
        _value(
          await store.resolve(
            sourceUrl: 'https://a.test',
            jsLib: jsLib,
            rulePath: 'r',
          ),
        ),
        contains('var a = 1;'),
      );
    });
  });
}

/// The value of a successful resolution, failing the test otherwise.
String? _value(ParseResult<String?> result) => switch (result) {
  ParseSuccess<String?>(:final String? data) => data,
  ParseFailure<String?>(:final ParseFailureKind kind, :final String rulePath) =>
    fail('Expected a success but got $kind at $rulePath.'),
};
