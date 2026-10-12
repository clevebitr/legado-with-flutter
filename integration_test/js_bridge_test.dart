import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:integration_test/integration_test.dart';
import 'package:logger/logger.dart';

/// 设备级验证：真实 QuickJS 引擎 + 真实 worker isolate 上跑通 `JsBridge` 的 3.3 契约。
///
/// `lib/core/js/quickjs_worker.dart` 依赖 `flutter_qjs_next` 的原生库，`flutter test`
/// 的宿主 VM 里根本加载不了它（只能由设备构建提供），因此按 ADR-0019 第二类登记在
/// `tool/coverage_allowlist.txt` 中豁免覆盖率。**本文件是它唯一的自动化验证入口**，
/// 也是 ADR-0029 §后果 要求的集成探针（`PLAN.md` §6 陷阱 #1：「构建成功」对 JS 路径
/// 毫无证明力）。运行方式见 `docs/dev/test-environment.md` §4。
///
/// 与 `tool/spike/` 的分工：那里验证**引擎架构可行性**（9 项探针），这里验证**产品代码**
/// ——`QuickJsWorkerBridge` 的排队、超时、`log.*` 转发与 `crypto.*` 绑定确实在真机上成立。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _CollectingPrinter printer;
  late QuickJsWorkerBridge bridge;
  late _ProbeHttpClient http;

  setUp(() {
    printer = _CollectingPrinter();
    http = _ProbeHttpClient();
    bridge = QuickJsWorkerBridge(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      launch: launchQuickJsWorker,
      http: http,
    );
  });

  tearDown(() => bridge.dispose());

  testWidgets('jsBridge_whenEvaluatedOnADevice_exposesTheSandboxVariables', (
    WidgetTester tester,
  ) async {
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            "String(result) + '|' + page + '|' + source.name + '|' "
            "+ source.url + '|' + baseUrl",
      ),
    );

    expect(
      _value(result),
      'raw|2|示例书源|https://example-novel.test|'
      'https://example-novel.test/search',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenTheRuleReturnsAnArray_reportsAList', (
    WidgetTester tester,
  ) async {
    // nextTocUrl 这类规则允许 JS 返回 URL 数组（book-source.md §4.1），所以结果必须
    // 是 JSON 值而不是 `String(...)` 拼出来的字符串。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(script: "['toc_2.html', 'toc_3.html']"),
    );

    expect(_value(result), <String>['toc_2.html', 'toc_3.html']);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenTheRuleUsesCrypto_answersSynchronously', (
    WidgetTester tester,
  ) async {
    // `crypto.*` 是同步绑定（ADR-0029 §决策 3）：不需要 await 就能拿到值。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(script: "crypto.md5('abc') + '|' + crypto.base64Encode('a')"),
    );

    expect(_value(result), '900150983cd24fb0d6963f7d28e17f72|YQ==');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenTheRuleLogs_forwardsItWithTheField', (
    WidgetTester tester,
  ) async {
    await bridge.evaluate(
      _job(script: "log.warn('hello from the rule'); 'done'"),
    );

    expect(printer.lines, contains('[js:searchRule.name] hello from the rule'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenAScriptRunsAway_timesOutAndKeepsTheWorkerUsable', (
    WidgetTester tester,
  ) async {
    // 探针 07 口径搬到产品代码上：引擎中断 runaway 脚本，worker 不被杀，随后仍可用。
    final ParseResult<Object?> runaway = await bridge.evaluate(
      _job(script: 'while (true) {}'),
    );

    expect(switch (runaway) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        '$kind $rulePath',
      ParseSuccess<Object?>() => 'unexpected success',
    }, 'ParseFailureKind.parseFailed searchRule.name:js:timeout');

    final ParseResult<Object?> after = await bridge.evaluate(
      _job(script: "'still alive'"),
    );

    expect(_value(after), 'still alive');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenRunningARule_hidesEverythingOutsideTheWhitelist', (
    WidgetTester tester,
  ) async {
    // F1：§6 的禁令必须是可实测的——引擎自带的定时器 / console / 编码函数 / 模块
    // 加载器全部不在沙箱里（`JsWebApis.none()`），白名单外的名字全部是 undefined。
    const List<String> forbidden = <String>[
      'setTimeout',
      'setInterval',
      'clearTimeout',
      'clearInterval',
      'queueMicrotask',
      'console',
      'atob',
      'btoa',
      'structuredClone',
      'performance',
      'require',
      'process',
      'XMLHttpRequest',
      'fetch',
    ];
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            '${jsonEncode(forbidden)}.map(function (name) {'
            " return name + '=' + typeof globalThis[name]; }).join(',')",
      ),
    );

    expect(
      _value(result),
      forbidden.map((String name) => '$name=undefined').join(','),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleRebindsTheWhitelist_theNextJobIsRepaired', (
    WidgetTester tester,
  ) async {
    // F1：Object.freeze 冻的是对象，不是 globalThis 上的属性名，所以每个 job 前重跑沙箱。
    await bridge.evaluate(
      _job(
        script: "delete globalThis.crypto; globalThis.log = null; 'tampered'",
      ),
    );

    final ParseResult<Object?> after = await bridge.evaluate(
      _job(script: "crypto.md5('abc') + '|' + typeof log"),
    );

    expect(_value(after), '900150983cd24fb0d6963f7d28e17f72|object');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'jsBridge_whenAScriptSchedulesAPromiseJob_theEngineStillDrainsIt',
    (WidgetTester tester) async {
      // F1 的收尾检查：硬化沙箱（`JsWebApis.none()` + 删掉定时器/microtask 名字）不能把引擎
      // 自己的 Promise 作业队列一起打掉——3.4 的 `http.*` / `parse.*` 靠它才能返回 Promise。
      // 观察方式是跨两个 job 的全局量：同一个运行时被复用，所以第一个 job 排下的作业在第二个
      // job 读取时已经跑完（`enableHandlePromises` + `executePendingJobs`）。
      await bridge.evaluate(
        _job(
          script:
              "globalThis.__promiseJob = 'pending';"
              'Promise.resolve(1).then(function () {'
              " globalThis.__promiseJob = 'ran'; }); 'scheduled'",
        ),
      );

      final ParseResult<Object?> after = await bridge.evaluate(
        _job(script: 'globalThis.__promiseJob'),
      );

      expect(_value(after), 'ran');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'jsBridge_whenTheEngineRunsAJsRule_bindsResultAndThePageContext',
    (WidgetTester tester) async {
      // 3.4 的接入点：引擎把选择器算出的值当 `result` 交给沙箱，并把页面的
      // baseUrl / page / source 一起带上（book-source.md §6）。
      final RuleEngine engine = RuleEngine(
        logger: AppLogger(level: LogLevel.debug, printer: printer),
        jsBridge: bridge,
      );
      const String pageHtml = '<div id="c">正文</div>';
      final RuleScope scope = RuleScope.dom(
        parser.parse(pageHtml),
        body: pageHtml,
        jsContext: const JsPageContext(
          baseUrl: 'https://example-novel.test/book/1/',
          page: 3,
          source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
        ),
      );

      final ParseResult<String?> result = await engine.extractFirst(
        "id.c@text@js:result + '|' + baseUrl + '|' + page + '|' + source.name",
        scope,
        rulePath: 'contentRule.content',
      );

      expect(_value(result), '正文|https://example-novel.test/book/1/|3|示例书源');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('jsBridge_whenTheScriptThrows_reportsJsError', (
    WidgetTester tester,
  ) async {
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(script: "throw new Error('boom')"),
    );

    expect(switch (result) {
      ParseFailure<Object?>(:final String rulePath) => rulePath,
      ParseSuccess<Object?>() => 'unexpected success',
    }, 'searchRule.name:js:error');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleAwaitsAnHttpGet_resolvesThePromise', (
    WidgetTester tester,
  ) async {
    // §6 的 `http.*` 是 Promise（ADR-0029 §决策 3）：脚本必须 await，而这次等待要真的跨过
    // worker → 桥 → 请求层再回来。这也是 3.4 里唯一无法用假 worker 证明的一段。
    http.body = '{"name":"One"}';
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            '(async function () {'
            " var body = await http.get('https://mirror.test/api');"
            " return body + '|' + source.name; })()",
        sourceHeaders: const <String, String>{'Referer': 'https://book.test/'},
      ),
    );

    expect(_value(result), '{"name":"One"}|示例书源');
    expect(http.requestedUrls, <String>['https://mirror.test/api']);
    // 书源自带的 header 在下面（C-NET-4），书源 URL 作为并发预算键（§8）。
    expect(http.lastHeaders?['Referer'], 'https://book.test/');
    expect(http.lastSourceId, 'https://example-novel.test');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleAwaitsAnHttpPost_sendsTheBody', (
    WidgetTester tester,
  ) async {
    http.body = 'posted';
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            '(async function () {'
            " return await http.post('https://mirror.test/api', {body: 'q=1'}); })()",
      ),
    );

    expect(_value(result), 'posted');
    expect(http.requestedMethods, <String>['POST']);
    expect(http.lastBody, 'q=1');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleAwaitsAParseCall_evaluatesTheNestedRule', (
    WidgetTester tester,
  ) async {
    // `parse.*` 也是 Promise，且它的实现落在**引擎**那边：嵌套规则在宿主 isolate 上求值，
    // 所以这里要的是「真引擎 + 真 worker」两段同时成立。
    const String pageHtml =
        '<ul class="list"><li class="odd"><a href="/book/1">One</a></li></ul>';
    final RuleEngine engine = RuleEngine(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      jsBridge: bridge,
    );
    final RuleScope scope = RuleScope.dom(
      parser.parse(pageHtml),
      body: pageHtml,
      jsContext: const JsPageContext(
        baseUrl: 'https://example-novel.test/search',
      ),
    );

    final ParseResult<String?> result = await engine.extractFirst(
      '@js:(async function () {'
      " return await parse.getString('class.odd.0@tag.a.0@text', result); })()",
      scope,
      rulePath: 'searchRule.name',
    );

    expect(_value(result), 'One');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenAParseCallHasNoPageScope_failsWithTheMarker', (
    WidgetTester tester,
  ) async {
    // ADR-0029 §决策 5：元素级 scope 必须显式失败（`js:parse-scope`），不得静默给空值。
    const String pageHtml = '<li class="odd"><a href="/book/1">One</a></li>';
    final RuleEngine engine = RuleEngine(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      jsBridge: bridge,
    );
    final RuleScope element = RuleScope.dom(parser.parse(pageHtml));

    final ParseResult<String?> result = await engine.extractFirst(
      '@js:(async function () {'
      " return await parse.getString('tag.a@href', result); })()",
      element,
      rulePath: 'tocRule.chapterUrl',
    );

    expect(switch (result) {
      ParseFailure<String?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        '$kind $rulePath',
      ParseSuccess<String?>() => 'unexpected success',
    }, 'ParseFailureKind.unsupportedRule tocRule.chapterUrl:js:parse-scope');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleExceedsTheCallQuota_failsTheJob', (
    WidgetTester tester,
  ) async {
    // §6 的额度含 log.*：超限不是拒绝一次调用，而是这个 job 已经不可信；worker 随之重建。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            'for (var index = 0; index < 25; index++) { log.info(index); }'
            " 'done'",
      ),
    );

    expect(switch (result) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        '$kind $rulePath',
      ParseSuccess<Object?>() => 'unexpected success',
    }, 'ParseFailureKind.parseFailed searchRule.name:js:quota');

    // 重建后的 worker 必须照常可用。
    expect(
      _value(await bridge.evaluate(_job(script: "'still alive'"))),
      'still alive',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleLooksAtTheWhitelist_findsOnlyIt', (
    WidgetTester tester,
  ) async {
    // C-SRC-3：白名单外的能力不存在（`java` 仍属 M1，未实现），而本阶段的两个宿主绑定存在。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            '[typeof http, typeof http.get, typeof http.post, '
            'typeof parse, typeof parse.getString, typeof parse.getElements, '
            "typeof java].join(',')",
      ),
    );

    expect(
      _value(result),
      'object,function,function,object,function,function,undefined',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// A job whose script decides the behaviour; the variables are the §6 bindings.
JsJob _job({required String script, Map<String, String>? sourceHeaders}) =>
    JsJob(
      script: script,
      rulePath: 'searchRule.name',
      baseUrl: 'https://example-novel.test/search',
      page: 2,
      source: const JsSourceInfo(
        name: '示例书源',
        url: 'https://example-novel.test',
      ),
      result: 'raw',
      sourceHeaders: sourceHeaders,
    );

/// The value of a successful evaluation, failing the test otherwise.
Object? _value(ParseResult<Object?> result) => switch (result) {
  ParseSuccess<Object?>(:final Object? data) => data,
  ParseFailure<Object?>(:final ParseFailureKind kind, :final String rulePath) =>
    fail('Expected a success but got $kind at $rulePath.'),
};

/// Collects the log lines the bridge writes, without a test-support dependency.
///
/// `integration_test/` does not import `test/support/`, so the printer is local: the
/// probe must stay runnable on a device exactly as the app would log.
final class _CollectingPrinter extends LogPrinter {
  /// Lines written, in order.
  final List<String> lines = <String>[];

  @override
  List<String> log(LogEvent event) {
    lines.add('${event.message}');

    return const <String>[];
  }
}

/// Serves canned bodies for the probe's `http.*` calls, so the device run never touches
/// the network (`docs/dev/testing.md` §1).
///
/// It is local on purpose, for the same reason [_CollectingPrinter] is: the probe has no
/// dependency on `test/support/`. The request layer's own behaviour (timeouts, retries,
/// decoding, the per-source budget) belongs to its unit tests; what this double has to make
/// observable is what the **worker** sent and what it got back.
final class _ProbeHttpClient implements HttpClient {
  /// URLs requested, in order.
  final List<String> requestedUrls = <String>[];

  /// HTTP methods requested, in order.
  final List<String> requestedMethods = <String>[];

  /// The body served for every request.
  String body = '';

  /// The headers of the last request.
  Map<String, String>? lastHeaders;

  /// The `sourceId` of the last request.
  String? lastSourceId;

  /// The request body of the last request.
  String? lastBody;

  @override
  Future<ParseResult<HttpResponse>> get(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
  }) async {
    requestedUrls.add(url);
    requestedMethods.add('GET');
    lastHeaders = headers;
    lastSourceId = sourceId;

    return _answer();
  }

  @override
  Future<ParseResult<HttpResponse>> post(
    String url, {
    required String rulePath,
    String? body,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
  }) async {
    requestedUrls.add(url);
    requestedMethods.add('POST');
    lastHeaders = headers;
    lastSourceId = sourceId;
    lastBody = body;

    return _answer();
  }

  /// The canned 200 with [body].
  ParseResult<HttpResponse> _answer() => ParseSuccess<HttpResponse>(
    HttpResponse(
      statusCode: 200,
      headers: const <String, List<String>>{},
      body: body,
    ),
  );
}
