import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_explore_categories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// A source that declares [exploreUrl].
BookSource _source({String? exploreUrl}) => BookSource(
  name: '示例源',
  url: 'https://example-novel.test',
  exploreUrl: exploreUrl,
  searchRule: const SearchRule(bookList: 'li'),
  tocRule: const TocRule(chapterList: 'dd'),
  contentRule: const ContentRule(content: 'div'),
);

/// The use case plus the doubles it talks to.
({FetchExploreCategories useCase, FakeJsBridge bridge, FakeLogPrinter printer})
_service() {
  final FakeLogPrinter printer = FakeLogPrinter();
  final AppLogger logger = AppLogger(level: LogLevel.debug, printer: printer);
  final FakeJsBridge bridge = FakeJsBridge();

  return (
    useCase: FetchExploreCategories(
      engine: RuleEngine(
        logger: logger,
        jsBridge: bridge,
        variables: JsVariableStore(),
      ),
      pages: PageFetchService(
        engine: RuleEngine(
          logger: logger,
          jsBridge: bridge,
          variables: JsVariableStore(),
        ),
        http: FakeHttpClient(),
        logger: logger,
      ),
    ),
    bridge: bridge,
    printer: printer,
  );
}

/// Returns the data of [result], failing the test when it failed.
List<ExploreCategory> _data(ParseResult<List<ExploreCategory>> result) =>
    switch (result) {
      ParseSuccess<List<ExploreCategory>>(:final List<ExploreCategory> data) =>
        data,
      ParseFailure<List<ExploreCategory>>(:final ParseFailureKind kind) => fail(
        'Expected a success but got $kind.',
      ),
    };

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure(ParseResult<List<ExploreCategory>> result) =>
    switch (result) {
      ParseFailure<List<ExploreCategory>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        ParseFailure<Never>(kind: kind, rulePath: rulePath),
      ParseSuccess<List<ExploreCategory>>() => fail('Expected a failure.'),
    };

void main() {
  group('FetchExploreCategories', () {
    test('execute_givenNoExploreUrl_returnsAnEmptyList', () async {
      // 没有发现页的书源是正常书源：空列表（UI 显示空态），不是失败。
      expect(_data(await _service().useCase.execute(_source())), isEmpty);
      expect(
        _data(await _service().useCase.execute(_source(exploreUrl: '   '))),
        isEmpty,
      );
    });

    test('execute_givenASeparatedString_readsTheCategories', () async {
      final List<ExploreCategory> categories = _data(
        await _service().useCase.execute(
          _source(exploreUrl: '玄幻::https://a.test/x&&都市::https://b.test/y'),
        ),
      );

      expect(categories, hasLength(2));
      expect(
        categories.first,
        const ExploreCategory(title: '玄幻', url: 'https://a.test/x'),
      );
    });

    test(
      'execute_givenAWholeFieldScriptReturningAnArray_readsItAsJson',
      () async {
        final ({
          FetchExploreCategories useCase,
          FakeJsBridge bridge,
          FakeLogPrinter printer,
        })
        fixture = _service();
        fixture.bridge.result = <Object?>[
          <String, Object?>{'title': '玄幻', 'url': 'https://a.test/x'},
          <String, Object?>{'title': '搜索', 'type': 'text'},
        ];

        final List<ExploreCategory> categories = _data(
          await fixture.useCase.execute(_source(exploreUrl: '@js:kinds()')),
        );

        // 脚本结果里的 JSON 数组走 JSON 形态（ADR-0035 §决策 4），表单型元素被拒并记录。
        expect(categories.single.title, '玄幻');
        expect(fixture.bridge.jobs.single.script, 'kinds()');
        expect(
          fixture.printer.events.map(
            (LogEvent event) => event.message.toString(),
          ),
          contains(contains('reason=form category (type=text)')),
        );
      },
    );

    test(
      'execute_givenAWholeFieldScriptReturningAString_readsTheString',
      () async {
        final ({
          FetchExploreCategories useCase,
          FakeJsBridge bridge,
          FakeLogPrinter printer,
        })
        fixture = _service();
        fixture.bridge.result = '玄幻::https://a.test/x';

        final List<ExploreCategory> categories = _data(
          await fixture.useCase.execute(_source(exploreUrl: '@js:kinds()')),
        );

        expect(categories.single.url, 'https://a.test/x');
      },
    );

    test(
      'execute_givenAWholeFieldScriptReturningSomethingElse_fails',
      () async {
        final ({
          FetchExploreCategories useCase,
          FakeJsBridge bridge,
          FakeLogPrinter printer,
        })
        fixture = _service();
        fixture.bridge.result = 42;

        final ParseFailure<Never> failure = _failure(
          await fixture.useCase.execute(_source(exploreUrl: '@js:kinds()')),
        );

        // 登记差异 ④：脚本返回值不是两种形态之一 → 该字段 parseFailed（不造 ERROR 分类）。
        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'exploreUrl');
      },
    );

    test('execute_givenAClosedJsWrapper_runsOnlyTheScript', () async {
      final ({
        FetchExploreCategories useCase,
        FakeJsBridge bridge,
        FakeLogPrinter printer,
      })
      fixture = _service();
      fixture.bridge.result = '玄幻::https://a.test/x';

      // `<js>` 形态大小写不敏感，且必须 `</js>` 收尾（登记差异 ①）。
      await fixture.useCase.execute(
        _source(exploreUrl: '<JS>  kinds()  </JS>'),
      );

      expect(fixture.bridge.jobs.single.script, '  kinds()  ');
    });

    test('execute_givenAnUnclosedJsWrapper_failsWithoutRunningIt', () async {
      final ({
        FetchExploreCategories useCase,
        FakeJsBridge bridge,
        FakeLogPrinter printer,
      })
      fixture = _service();

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(_source(exploreUrl: '<js>kinds()')),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'exploreUrl:js-not-closed');
      // 上游会用 `lastIndexOf("<")` 截断、把尾巴上的垃圾吞掉；本仓拒绝并不跑脚本。
      expect(fixture.bridge.jobs, isEmpty);
    });

    test('execute_givenAWholeFieldScript_bindsTheDocumentedSurface', () async {
      final ({
        FetchExploreCategories useCase,
        FakeJsBridge bridge,
        FakeLogPrinter printer,
      })
      fixture = _service();
      fixture.bridge.result = '玄幻::https://a.test/x';

      await fixture.useCase.execute(_source(exploreUrl: '@js:kinds()'));

      // ADR-0035 §决策 4：`baseUrl` = 书源 URL、`page` = 1、不绑 `key`、无 `result`、
      // 也没有 `parse.*` 的页级 scope（该字段没有页面）。
      expect(fixture.bridge.jobs.single.baseUrl, 'https://example-novel.test');
      expect(fixture.bridge.jobs.single.page, 1);
      expect(fixture.bridge.jobs.single.key, isNull);
      expect(fixture.bridge.jobs.single.result, isNull);
      expect(fixture.bridge.jobs.single.parseEvaluator, isNull);
    });

    test('execute_givenAFailingScript_returnsTheBridgeFailure', () async {
      final ({
        FetchExploreCategories useCase,
        FakeJsBridge bridge,
        FakeLogPrinter printer,
      })
      fixture = _service();
      fixture.bridge.failure = failureAt<Never>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'exploreUrl:js:error',
      );

      final ParseFailure<Never> failure = _failure(
        await fixture.useCase.execute(_source(exploreUrl: '@js:boom()')),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'exploreUrl:js:error');
    });

    test('execute_givenARejectedCategory_logsItAndKeepsTheRest', () async {
      final ({
        FetchExploreCategories useCase,
        FakeJsBridge bridge,
        FakeLogPrinter printer,
      })
      fixture = _service();

      final List<ExploreCategory> categories = _data(
        await fixture.useCase.execute(
          _source(exploreUrl: '::https://a.test/x&&玄幻::https://a.test/y'),
        ),
      );

      // C-SRC-4：被拒的条目必须记录，其余条目照常。
      expect(categories.single.title, '玄幻');
      final String warning = fixture.printer.events
          .map((LogEvent event) => event.message.toString())
          .firstWhere((String message) => message.contains('rejected'));
      expect(warning, contains('source=https://example-novel.test'));
      expect(warning, contains('field=exploreUrl'));
      expect(warning, contains('kind=unsupportedRule'));
      expect(warning, contains('reason=blank title'));
    });
  });
}
