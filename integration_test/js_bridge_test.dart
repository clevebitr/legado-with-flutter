import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
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
/// 也是 ADR-0029 §后果 要求的集成探针（`docs/dev/roadmap.md` §6 陷阱 #1：「构建成功」对 JS 路径
/// 毫无证明力）。运行方式见 `docs/dev/test-environment.md` §4。
///
/// 与 `tool/spike/` 的分工：那里验证**引擎架构可行性**（9 项探针），这里验证**产品代码**
/// ——`QuickJsWorkerBridge` 的排队、超时、`log.*` 转发与 `crypto.*` 绑定确实在真机上成立。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _CollectingPrinter printer;
  late QuickJsWorkerBridge bridge;
  late _ProbeHttpClient http;
  // 变量表由桥与引擎共用：脚本 `java.put` 写进去的，`@get:` 与 `{{…}}` 要能读到（ADR-0034）。
  final JsVariableStore variables = JsVariableStore();

  setUp(() {
    printer = _CollectingPrinter();
    http = _ProbeHttpClient();
    bridge = QuickJsWorkerBridge(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      launch: launchQuickJsWorker,
      http: http,
      variables: variables,
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
        variables: variables,
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
      variables: variables,
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
      variables: variables,
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
    // C-SRC-3：白名单外的能力不存在，而 §6 里的绑定都在（`java.*` 是 M1，矩阵 #17）。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(
        script:
            '[typeof http, typeof http.get, typeof http.post, '
            'typeof parse, typeof parse.getString, typeof parse.getElements, '
            'typeof java, typeof java.put, typeof java.get, '
            "typeof setTimeout, typeof console].join(',')",
      ),
    );

    expect(
      _value(result),
      'object,function,function,object,function,function,'
      'object,function,function,undefined,undefined',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenAScriptWritesAJavaVariable_keepsItPerSource', (
    WidgetTester tester,
  ) async {
    // 矩阵 #17：`java.*` 在 worker 内同步拿到值（§6），而变量按**书源**键控
    // （ADR-0030 §决策 4、ADR-0034 §决策 1）。
    const String sourceUrl = 'https://example-novel.test';
    const String otherUrl = 'https://other.test';
    expect(
      _value(
        await bridge.evaluate(
          _job(script: "java.put('token', 'a'); java.get('token')"),
        ),
      ),
      'a',
    );
    // 写入的整份表随结果回到宿主，由桥 merge 进它自己的那份表（ADR-0034 §决策 1）。
    expect(variables.read(sourceUrl, 'token'), 'a');

    // 同一书源的下一个 job：调用方把该源的**快照**装进 job（这就是引擎的做法），
    // 所以它看得到上一个 job 写入的值。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script: "java.get('token')",
            variables: variables.snapshot(sourceUrl),
          ),
        ),
      ),
      'a',
    );

    // 另一个书源看到的是自己的空表，不是前一个书源的。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script: "java.get('token')",
            variables: variables.snapshot(otherUrl),
            source: const JsSourceInfo(name: '另一个书源', url: otherUrl),
          ),
        ),
      ),
      '',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenJavaAndTheEngineShareAStore_seesEachOther', (
    WidgetTester tester,
  ) async {
    // 矩阵 #16 / #17 是**同一份**变量：脚本 `java.put` 写下的，引擎的 `@get:` 要读得到
    // （ADR-0034 §决策 1）。这也是真引擎才能证明的一段。
    final RuleEngine engine = RuleEngine(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      jsBridge: bridge,
      variables: variables,
    );
    const String pageHtml = '<p>x</p>';
    final RuleScope scope = RuleScope.dom(
      parser.parse(pageHtml),
      body: pageHtml,
      jsContext: const JsPageContext(
        baseUrl: 'https://example-novel.test/book/1/',
        source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
      ),
    );

    await engine.extractFirst(
      "@js:java.put('token', 'a')",
      scope,
      rulePath: 'searchRule.name',
    );

    expect(
      _value(
        await engine.extractFirst(
          '@get:{token}',
          scope,
          rulePath: 'searchRule.name',
        ),
      ),
      'a',
    );

    // 反过来也一样：`@put:` 写下的，脚本里的 `java.get` 要读得到。
    await engine.extractFirst(
      '@put:{token2:tag.p@text}',
      scope,
      rulePath: 'searchRule.name',
    );
    expect(
      _value(
        await engine.extractFirst(
          "@js:java.get('token2')",
          scope,
          rulePath: 'searchRule.name',
        ),
      ),
      'x',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'jsBridge_whenAScriptFormatsATimestamp_usesMillisecondsAndItsZone',
    (WidgetTester tester) async {
      // M1-b1：`java.timeFormat` 是 §6 表里的同族同步绑定（入参**毫秒**、输出固定 pattern、
      // 设备本地时区）。pattern 与时区判定在 Dart 侧单测里钉住，这里证明真引擎 + 真 worker
      // 上这条链路确实存在（`java` 对象上有它，且能拿到格式化的值）。
      final ParseResult<Object?> result = await bridge.evaluate(
        _job(
          script:
              '[typeof java.timeFormat, java.timeFormat(0), '
              "java.timeFormat('1700000000000')].join('|')",
        ),
      );

      // 期望值用同一套 Dart 本地换算算出来，所以探针在哪个时区的设备上跑都成立。
      final String expected =
          '${formatTimestamp(DateTime.fromMillisecondsSinceEpoch(0))}|'
          '${formatTimestamp(DateTime.fromMillisecondsSinceEpoch(1700000000000))}';
      expect(_value(result), 'function|$expected');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('jsBridge_whenAScriptPassesAnUnusableTimestamp_reportsJsError', (
    WidgetTester tester,
  ) async {
    // 读不成时间戳的入参是那次调用的失败（`ok:false`），前奏把它变成 JS `Error`，
    // 于是整个 job 按 §7 报 `js:error` —— 不得静默给一个错的时间。
    final ParseResult<Object?> result = await bridge.evaluate(
      _job(script: "java.timeFormat('not-a-time')"),
    );

    expect(switch (result) {
      ParseFailure<Object?>(:final String rulePath) => rulePath,
      ParseSuccess<Object?>() => 'unexpected success',
    }, 'searchRule.name:js:error');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenAJobCarriesABook_exposesItsFields', (
    WidgetTester tester,
  ) async {
    // ADR-0060 P2：`book` 对象由 worker 绑定（上游 AnalyzeUrl.kt:373 的同一形状）。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script: "book.name + '|' + book.author + '|' + book.tocUrl",
            book: const JsBookInfo(
              name: '剑来',
              author: '烽火戏诸侯',
              bookUrl: 'https://example-novel.test/book/1',
              tocUrl: 'https://example-novel.test/book/1/toc',
            ),
          ),
        ),
      ),
      '剑来|烽火戏诸侯|https://example-novel.test/book/1/toc',
    );
  });

  testWidgets('jsBridge_whenAScriptUsesBookMethods_readsAndWritesVariables', (
    WidgetTester tester,
  ) async {
    // ADR-0062 §决策 2：`book.putVariable` / `getVariable` 就是 `java.put` / `java.get` 那张表
    // （上游 AnalyzeUrl.javaPut 先写 book 的 variableMap，AnalyzeUrl.kt:390-406）。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script:
                "book.putVariable('token', 'abc'); "
                "book.getVariable('token') + '|' + java.get('token')",
            book: const JsBookInfo(name: '剑来'),
          ),
        ),
      ),
      'abc|abc',
    );
  });

  testWidgets('jsBridge_whenAScriptCallsTheBookStateSetters_readsThemBack', (
    WidgetTester tester,
  ) async {
    // `setType` / `setReverseToc` 在本 job 内可读回；它们**不改**宿主的章节顺序或书籍类型，
    // 这条差异登记在 ADR-0062 §决策 2，所以这里只验「可调用、不静默崩」。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script:
                'book.setType(1); book.setReverseToc(true); '
                "book.getType() + '|' + book.getReverseToc() + '|' + book.type",
            book: const JsBookInfo(name: '剑来'),
          ),
        ),
      ),
      '1|true|1',
    );
  });

  testWidgets('jsBridge_whenAJobCarriesBookNames_javaGetAnswersThemFirst', (
    WidgetTester tester,
  ) async {
    // M12-A5 / ADR-0049：`bookName` / `title` 是**内置键**，先于变量表；`java.put` 不能劫持它们。
    // 这一条只能在设备上验：解码与赋值都发生在 worker 隔离区里。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script: "java.put('bookName', '变量里的书名'); java.get('bookName') + '|' + java.get('title')",
            bookName: '剑来',
            chapterTitle: '第一章',
          ),
        ),
      ),
      '剑来|第一章',
    );
    // 没有上下文的阶段（搜索 / 目录）回落到变量表。
    expect(
      _value(
        await bridge.evaluate(
          _job(
            script: "java.get('title')",
            variables: const <String, String>{'title': '变量章节'},
          ),
        ),
      ),
      '变量章节',
    );
  });

  testWidgets('jsBridge_whenAUrlRuleUsesKey_bindsItOnlyThere', (
    WidgetTester tester,
  ) async {
    // §4 / 矩阵 #18：搜索 URL 里的 `{{…}}` 是 JS，且只有那里绑 `key`
    // （上游 `AnalyzeUrl.evalJS`，AnalyzeUrl.kt:377）。
    final RuleEngine engine = RuleEngine(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      jsBridge: bridge,
      variables: variables,
    );
    const JsPageContext context = JsPageContext(
      baseUrl: 'https://example-novel.test',
      source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
    );

    final ParseResult<String> url = await engine.renderUrl(
      'https://example-novel.test/search?q={{key.toUpperCase()}}',
      rulePath: 'searchUrl',
      params: const <String, String>{'key': 'abc', 'page': '1'},
      context: context,
    );
    expect(switch (url) {
      ParseSuccess<String>(:final String data) => data,
      ParseFailure<String>() => 'unexpected failure',
    }, 'https://example-novel.test/search?q=ABC');

    // 字段规则里没有 `key`：上一条 job 设过的全局名必须被清掉（沙箱每 job 重装）。
    const String pageHtml = '<p>x</p>';
    final ParseResult<String?> field = await engine.extractFirst(
      '{{key}}',
      RuleScope.dom(
        parser.parse(pageHtml),
        body: pageHtml,
        jsContext: const JsPageContext(
          baseUrl: 'https://example-novel.test',
          source: JsSourceInfo(name: '示例书源', url: 'https://example-novel.test'),
        ),
      ),
      rulePath: 'searchRule.name',
    );
    expect(switch (field) {
      ParseFailure<String?>(:final String rulePath) => rulePath,
      ParseSuccess<String?>() => 'unexpected success',
    }, 'searchRule.name:js:error');
  }, timeout: const Timeout(Duration(minutes: 2)));
  testWidgets(
    'jsBridge_whenAScriptUsesTheJavaCompatSurface_answersLikeUpstream',
    (WidgetTester tester) async {
      // M1-b1b（ADR-0037 §决策 2）：别名族在 worker 内同步完成，语义按上游照抄。
      final ParseResult<Object?> result = await bridge.evaluate(
        _job(
          script:
              "[java.md5Encode('abc'), java.base64Decode(java.base64Encode('剑来')), "
              "java.encodeURI('a b'), typeof java.log('x')].join('|')",
        ),
      );

      // md5('abc') 是 RFC 1321 的公开向量；base64 往返、空格 → `+`、log 无返回值。
      expect(
        _value(result),
        '900150983cd24fb0d6963f7d28e17f72|剑来|a+b|undefined',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('jsBridge_whenAScriptCallsARejectedJavaMember_failsReadably', (
    WidgetTester tester,
  ) async {
    // ADR-0037 §决策 5：M2 的成员命中即给可读错误，不是 `undefined is not a function`。
    // `Packages.*` 是 Rhino 的另一条互操作入口（`Packages.java.lang.…`），同样具名拒绝——
    // 不然它是 `Packages is not defined` 这种更难懂的错误。
    for (final String script in <String>[
      "java.ajax('https://a.test')",
      "Packages.java.lang.String('x')",
    ]) {
      final ParseResult<Object?> result = await bridge.evaluate(
        _job(script: script),
      );

      expect(
        switch (result) {
          ParseFailure<Object?>(:final String rulePath) => rulePath,
          ParseSuccess<Object?>() => 'unexpected success',
        },
        'searchRule.name:js:error',
        reason: script,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('jsBridge_whenARuleUsesTheJavaGetStringFastPath_getsSyncValues', (
    WidgetTester tester,
  ) async {
    // ADR-0037 §决策 3①：字面量首参在构造 job 之前由宿主内联，所以表达式里的用法拿到同步值，
    // 上游 `List.toArray()` 的写法（§决策 4 的垫片）也随之成立。
    final RuleEngine engine = RuleEngine(
      logger: AppLogger(level: LogLevel.debug, printer: printer),
      jsBridge: bridge,
      variables: variables,
    );
    const String pageHtml =
        '<ul class="list"><li class="odd"><a href="/book/1">One</a></li></ul>';
    final RuleScope scope = RuleScope.dom(
      parser.parse(pageHtml),
      body: pageHtml,
      jsContext: const JsPageContext(
        baseUrl: 'https://example-novel.test/search',
      ),
    );

    final ParseResult<String?> result = await engine.extractFirst(
      "@js:java.getString('class.odd.0@tag.a.0@text') + '|' + "
      "java.getStringList('class.odd@tag.a').toArray().length",
      scope,
      rulePath: 'contentRule.content',
    );

    expect(_value(result), 'One|1');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// A job whose script decides the behaviour; the variables are the §6 bindings.
///
/// [variables] is the source's **snapshot** as the engine takes it (`JsJob.variables`): a
/// probe that expects a `java.put` of an earlier job to be readable has to carry it, because
/// the bridge merges the reported table into the store and never injects a snapshot itself
/// (ADR-0034 §决策 1).
JsJob _job({
  required String script,
  Map<String, String>? sourceHeaders,
  Map<String, String> variables = const <String, String>{},
  JsSourceInfo source = const JsSourceInfo(
    name: '示例书源',
    url: 'https://example-novel.test',
  ),
  String? bookName,
  String? chapterTitle,
  JsBookInfo? book,
}) => JsJob(
  script: script,
  rulePath: 'searchRule.name',
  baseUrl: 'https://example-novel.test/search',
  page: 2,
  source: source,
  result: 'raw',
  sourceHeaders: sourceHeaders,
  variables: variables,
  bookName: bookName,
  chapterTitle: chapterTitle,
  book: book,
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

  /// The `concurrentRate` declarations this double was told about, keyed by source id.
  ///
  /// The probe does not exercise the rate gate (that is the request layer's own unit test);
  /// it only has to accept the call the production chain makes (ADR-0036 §决策 5).
  final Map<String, String?> sourceRates = <String, String?>{};

  @override
  void applySourceRate(String sourceId, String? concurrentRate) {
    sourceRates[sourceId] = concurrentRate;
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
  }) async {
    requestedUrls.add(url);
    requestedMethods.add('GET');
    lastHeaders = headers;
    lastSourceId = sourceId;

    return _answer();
  }

  @override
  Future<ParseResult<Uint8List>> getBytes(
    String url, {
    required String rulePath,
    Map<String, String>? headers,
    String? keyword,
    String? sourceId,
    int? maxBytes,
  }) async {
    // 探针不取二进制体：它只验证 worker 发出的调用；真字节走 `http_client_test`。
    requestedUrls.add(url);
    requestedMethods.add('GET');
    lastHeaders = headers;
    lastSourceId = sourceId;

    return ParseSuccess<Uint8List>(Uint8List.fromList(utf8.encode(body)));
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
