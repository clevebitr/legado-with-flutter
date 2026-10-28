// P1–P3 引擎性能基准（M26，`docs/dev/adr/0078` 决策 4）。
//
// 为什么存在：M26 允许重构引擎内核，条件是「同一行为更快」，而「更快」必须是可复核的数字，
// 不是体感。`docs/dev/constraints.md` 与 `docs/dev/testing.md` §1 禁止测试联网、也不让基准
// 拖慢 CI，所以这里是 `tool/` 入口（与 `tool/spot_check/` 同一模式）：**不进 CI**，
// 也不被 `flutter test` 发现。
//
// 用法（仓库根目录）：
//
//   flutter run -d windows --release -t tool/bench/bench.dart -- --out=build/bench.json
//   flutter run -d windows --release -t tool/bench/bench.dart -- --only=p1,p2 --iterations=10
//
// 为什么是 `flutter run` 而不是 `dart run`：引擎的 `@js:` 路径与 `AppLogger` 都要 Flutter 运行时
// （`flutter/foundation`、`flutter_qjs_next` 的原生库），`dart run` 在 `dart:ui` 上直接编译失败
// ——与 `tool/spot_check/README.md` §2 记录的原因完全相同。`flutter run` 不转发命令行参数，
// 所以选项走 `BENCH_ARGS` 环境变量（与 `SPOT_CHECK_ARGS` 同一约定）。
//
// 口径、改前/改后数字与「怎么把 P4/P5/P6 接进来」都写在 `tool/bench/README.md`；本文件只负责
// 生成夹具、跑链路、打印与落盘。指标与目标值（P1–P6）的唯一出处是 `docs/dev/adr/0078` 决策 4，
// 这里只抄阈值做对照，改阈值请改 ADR。

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/features/book_source/domain/html_to_text.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';
import 'package:html/parser.dart' as html_parser;

// ---------------------------------------------------------------------------------------------
// 夹具（确定性生成，不进仓库：200 KB 的页面文件不该躺在一个基准脚本旁边）
// ---------------------------------------------------------------------------------------------

/// 单章页面的默认段数：500 段 × 5 句中文，UTF-8 下约 195 KB（P1 的「≤200KB HTML」）。
const int _chapterParagraphs = 500;

/// 千章目录的默认章数（P2）。
const int _tocChapters = 1000;

/// P2 线性度扫描的章数。
const List<int> _tocSweep = <int>[250, 500, 1000, 2000];

/// 单章正文的三段取值规则（矩阵 #2 / #1 / #8 的常见形状）：
/// `id.content` → `tag.p` → `text`。上游语料里正文规则的主流写法就是这个形状。
const String _contentRule = 'id.content@tag.p@text';

/// `ruleContent.replaceRegex`（§4.1）：语料里最常见的一类是「删掉整行广告」。
const String _replaceRule = r'##^.*?(求票|广告|本章未完).*?$###';

/// 目录列表规则（矩阵 #1 / #2）：`id.list@tag.dd` 与语料「笔趣阁系」的写法一致。
const String _tocListRule = 'id.list@tag.dd';

/// 目录条目里的章名与地址（矩阵 #8）。
const String _tocNameRule = 'tag.a.0@text';
const String _tocUrlRule = 'tag.a.0@href';

/// 矩阵 #20 的正则列表规则：同一条目录页，一条正则取 1000 条（语料里 2 源的形状）。
const String _tocRegexListRule = r':href="(/book/1/c\d+\.html)">([^<]+)</a>';

/// 正则条目的字段规则：`$N` 模板（矩阵 #20 注记）。
const String _tocRegexNameRule = r'$2';
const String _tocRegexUrlRule = r'$1';

/// 一条取值 CSS 规则 + 一条 JSONPath 规则（P3 的三种编译形态之一）。
const String _valueRule = 'class.line@text';
const String _jsonRule = r'$.data.name';

/// 一页书（`book-source.md` §10 的夹具口径：构造的页面 + 真实形状的规则）。
String _chapterHtml({int paragraphs = _chapterParagraphs}) {
  final StringBuffer buffer = StringBuffer()
    ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
    ..write('<title>第 1 章 基准</title></head><body>')
    ..write('<div id="main"><div class="bookname"><h1>第 1 章 基准</h1></div>')
    ..write('<div id="content">');
  for (var index = 0; index < paragraphs; index++) {
    buffer.write('<p class="line">');
    // 每段 5 句、每句约 28 字：段数 × 字数决定页面大小，而页内结构保持真实（每段一个 `<p>`），
    // 这样 P1 的「解析」与「提取」两段都有活干。
    for (var sentence = 0; sentence < 5; sentence++) {
      buffer.write(_sentenceOf(index * 5 + sentence));
    }
    buffer.write('</p>');
  }
  // 语料里正文页几乎都有这几块垃圾：脚本、样式、广告行与「本章未完」，它们分别考验
  // HTML 解析、`replaceRegex` 和「多段正文拼接」。
  buffer
    ..write('</div><script>var ad=1;</script><style>.ad{display:none}</style>')
    ..write('<div class="bottem">本章未完，请点击下一页继续阅读 求票</div>')
    ..write('</div></body></html>');

  return buffer.toString();
}

/// P5 用的一页 JSON（语料里 JSON-API 源的主流形状：`$.data.x`）。
const String _jsonPageBody = '{"data":{"start_time":1540458357,"name":"One"}}';

/// 一句确定性的占位正文（不联网、不随机：两次运行必须逐字节相同，否则数字不可比）。
String _sentenceOf(int index) => switch (index % 4) {
  0 => '他抬头看了看天色，心里想着这一段山路还有多远要走。',
  1 => '风从松林深处吹来，带着一点湿气，也带着远处溪水的声音。',
  2 => '“走吧。”同伴低声说了一句，脚步却没有挪动半分。',
  _ => '远处的灯火明明灭灭，像是有人在夜里替他们守着什么。',
};

/// 一页目录（P2）：`id.list` 下 1000 个 `<dd><a href>章名</a></dd>`。
String _tocHtml({int chapters = _tocChapters}) {
  final StringBuffer buffer = StringBuffer()
    ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
    ..write('<title>目录</title></head><body><div id="list"><dl>');
  for (var index = 1; index <= chapters; index++) {
    buffer.write('<dd><a href="/book/1/c$index.html">第 $index 章 ');
    buffer.write(_sentenceOf(index).substring(0, 12));
    buffer.write('</a></dd>');
  }
  buffer.write('</dl></div></body></html>');

  return buffer.toString();
}

// ---------------------------------------------------------------------------------------------
// 采集
// ---------------------------------------------------------------------------------------------

/// 引擎与页面服务：与生产同一条装配路径（`lib/features/book_source/di.dart`），只是没有网络。
///
/// P1/P2/P3 一次请求都不发，所以 `HttpClient` 用的是真实现而非替身：它只在被调用时上网，
/// 而这些指标按定义不含网络（P1「不含网络」）。真桥同理——没有 `@js:` 规则就不会起 worker
/// 隔离体，P5 接进来时它已经就位。
final class _Harness {
  _Harness()
    : _variables = JsVariableStore(),
      _logger = AppLogger(level: LogLevel.off) {
    final DioHttpClient http = DioHttpClient(
      cookies: InMemoryCookieManager(),
      logger: _logger,
    );
    _bridge = QuickJsWorkerBridge(
      logger: _logger,
      launch: launchQuickJsWorker,
      http: http,
      variables: _variables,
    );
    _engine = RuleEngine(
      logger: _logger,
      jsBridge: _bridge,
      variables: _variables,
    );
    pages = PageFetchService(engine: _engine, http: http, logger: _logger);
  }

  final JsVariableStore _variables;
  final AppLogger _logger;
  late final QuickJsWorkerBridge _bridge;
  late final RuleEngine _engine;
  late final PageFetchService pages;

  /// Stops the JS worker, when one was ever started (no `@js:` rule means none was).
  Future<void> dispose() => _bridge.dispose();

  /// 引擎的规则编译计数（P3 的观测点）。
  RuleCompileStats get compileStats => _engine.compileStats;

  /// 引擎的嵌套调用计数（P5 的内联覆盖率观测点）。
  JsInlineStats get inlineStats => _engine.inlineStats;

  /// 生产桥本身，供 P5 的分段量直接投递 job（绕开引擎）。
  QuickJsWorkerBridge get jsBridge => _bridge;

  /// 一页的规则作用域：与 `PageFetchService._pageOf` 为同一形状（DOM + 原始正文 + JS 上下文）。
  ///
  /// `body` 是**必须**的：`@json:` 与 `:正则` 都读整页正文，少了它就测的不是同一条链路。
  RuleScope pageScope(
    String html, {
    String url = 'https://example-novel.test/book/1/',
  }) => RuleScope.dom(
    html_parser.parse(html),
    body: html,
    jsContext: JsPageContext(
      baseUrl: url,
      source: const JsSourceInfo(
        name: '基准书源',
        url: 'https://example-novel.test',
      ),
    ),
  );
}

/// 一次采样的统计量（毫秒）。分位数用「排序后取位置」，不做插值：样本量小，插值只是装饰。
final class _Timing {
  _Timing(this.samplesMs) : assert(samplesMs.isNotEmpty);

  final List<double> samplesMs;

  List<double> get _sorted => <double>[...samplesMs]..sort();

  int get count => samplesMs.length;

  double get min => _sorted.first;

  double get max => _sorted.last;

  double get p50 => _quantile(0.50);

  double get p95 => _quantile(0.95);

  double get mean =>
      samplesMs.reduce((double a, double b) => a + b) / samplesMs.length;

  double _quantile(double fraction) {
    final List<double> sorted = _sorted;
    final int index = (sorted.length * fraction).ceil() - 1;

    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'n': count,
    'min': _round(min),
    'p50': _round(p50),
    'p95': _round(p95),
    'max': _round(max),
    'mean': _round(mean),
  };
}

/// 一行结果：一个指标的一项测量（P1 的「total」、P2 的「list」等）。
final class _Measurement {
  const _Measurement({
    required this.metric,
    required this.name,
    required this.timing,
    this.target,
  });

  final String metric;
  final String name;
  final _Timing timing;
  final String? target;

  Map<String, Object?> toJson() => <String, Object?>{
    'metric': metric,
    'measure': name,
    'target': target,
    ...timing.toJson(),
  };
}

/// 一次基准运行的完整结果。
final class _Report {
  _Report({
    required this.fixtureBytes,
    required this.tocChapters,
    required this.measurements,
    required this.linearity,
    required this.compileStats,
    required this.iterations,
    required this.warmup,
    this.jsRoundtrip,
    this.pingPong,
    this.inlineStats,
    this.memory = const <_MemoryRow>[],
  });

  final ({int chapter, int toc}) fixtureBytes;
  final int tocChapters;
  final List<_Measurement> measurements;
  final List<({int chapters, _Timing total})> linearity;
  final RuleCompileStats compileStats;
  final int iterations;
  final int warmup;

  /// P5 的空脚本 job 往返耗时，`--only` 不含 `p5` 时为 `null`。
  final _Timing? jsRoundtrip;

  /// 「两跳消息」的机器地板价（裸 isolate 往返），`--only` 不含 `p5` 时为 `null`。
  final _Timing? pingPong;

  /// P5 的内联覆盖率快照（主流字面量写法与带变量的写法各一次）。
  final ({JsInlineStats literal, JsInlineStats dynamic})? inlineStats;

  /// P6 的常驻增量（每项一行）。
  final List<_MemoryRow> memory;

  Map<String, Object?> toJson() => <String, Object?>{
    'generatedAt': DateTime.now().toIso8601String(),
    'platform': <String, Object?>{
      'os': Platform.operatingSystem,
      'dart': Platform.version,
      'release': !_isDebugBuild,
    },
    'options': <String, Object?>{
      'iterations': iterations,
      'warmup': warmup,
      'tocChapters': tocChapters,
    },
    'fixtures': <String, Object?>{
      'chapterBytes': fixtureBytes.chapter,
      'tocBytes': fixtureBytes.toc,
      'tocChapters': tocChapters,
    },
    'measurements': <Map<String, Object?>>[
      for (final _Measurement measurement in measurements) measurement.toJson(),
    ],
    'linearity': <Map<String, Object?>>[
      for (final ({int chapters, _Timing total}) row in linearity)
        <String, Object?>{
          'chapters': row.chapters,
          'usPerChapter': _round(row.total.p50 * 1000 / row.chapters),
          ...row.total.toJson(),
        },
    ],
    'ruleCompile': <String, Object?>{
      'lookups': compileStats.lookups,
      'compilations': compileStats.compilations,
      'hits': compileStats.hits,
      'hitRate': _round(compileStats.hitRate * 100),
    },
    'js': <String, Object?>{
      'roundtripMs': jsRoundtrip?.toJson(),
      'pingPongMs': pingPong?.toJson(),
      'inline': switch (inlineStats) {
        final ({JsInlineStats literal, JsInlineStats dynamic}) stats =>
          <String, Object?>{
            'literalCalls': stats.literal.calls,
            'literalCoverage': _round(stats.literal.inlineCoverage * 100),
            'dynamicCalls': stats.dynamic.calls,
            'dynamicCoverage': _round(stats.dynamic.inlineCoverage * 100),
          },
        null => null,
      },
    },
    'memory': <Map<String, Object?>>[
      for (final _MemoryRow row in memory) row.toJson(),
    ],
  };
}

/// P6 的一行：一项操作的常驻内存增量（MB）。
///
/// 「峰值增量」在 Dart 侧拿不到（没有 GC 钩子），所以这里记两个数：**首次**增量近似工作集
/// （分配上限），**后续中位数**是每次重复的净增长（>0 说明有保留，可能是泄漏）。
final class _MemoryRow {
  const _MemoryRow({
    required this.name,
    required this.firstMb,
    required this.medianMb,
    required this.maxMb,
  });

  final String name;
  final double firstMb;
  final double medianMb;
  final double maxMb;

  Map<String, Object?> toJson() => <String, Object?>{
    'measure': name,
    'firstMb': _round(firstMb),
    'medianMb': _round(medianMb),
    'maxMb': _round(maxMb),
  };
}

// ---------------------------------------------------------------------------------------------
// 三个指标
// ---------------------------------------------------------------------------------------------

/// P1：单章正文「解析 → 提取 → `replaceRegex`」全程，不含网络。
///
/// 分三段采，是为了让重构面（R2 共享 scope、R3 批量提取）能看出时间花在哪一段；判定只看
/// `total`（ADR-0078 决策 4 的 P1）。
Future<List<_Measurement>> _measureChapter(
  _Harness harness, {
  required int iterations,
  required int warmup,
}) async {
  final String html = _chapterHtml();
  final RuleScope scope = harness.pageScope(html);
  final JsPageContext context = _contextOf(scope);

  final List<double> parse = <double>[];
  final List<double> extract = <double>[];
  final List<double> replace = <double>[];
  final List<double> total = <double>[];

  for (var index = 0; index < warmup + iterations; index++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final RuleScope page = harness.pageScope(html);
    final double parseMs = _elapsedMs(stopwatch);

    final String body = _success(
      await harness.pages.content(_contentRule, page, 'contentRule.content'),
      'contentRule.content',
    );
    final double extractMs = _elapsedMs(stopwatch);

    final String replaced = await harness.pages.replaceContent(
      _replaceRule,
      htmlToText(body),
      'contentRule.replaceRegex',
      sourceId: 'https://example-novel.test',
      jsContext: context,
    );
    final double replaceMs = _elapsedMs(stopwatch);

    // 取值只为证明这条链路真的产出了正文（空串会被服务判成 parseFailed）。
    _verify(replaced.trim().isNotEmpty, 'P1 produced an empty chapter body');
    if (index < warmup) {
      continue;
    }
    parse.add(parseMs);
    extract.add(extractMs);
    replace.add(replaceMs);
    total.add(parseMs + extractMs + replaceMs);
  }

  return <_Measurement>[
    _Measurement(
      metric: 'P1',
      name: '解析 HTML（200KB 页）',
      timing: _Timing(parse),
    ),
    _Measurement(
      metric: 'P1',
      name: '提取（id.content@tag.p@text）',
      timing: _Timing(extract),
    ),
    _Measurement(
      metric: 'P1',
      name: 'replaceRegex + htmlToText',
      timing: _Timing(replace),
    ),
    _Measurement(
      metric: 'P1',
      name: 'total：解析→提取→replaceRegex',
      timing: _Timing(total),
      target: '≤ 40 ms',
    ),
  ];
}

/// P2：千章目录（CSS 列表 + 正则列表两种求值形态），含目录页解析。
///
/// 判定看 `total`（ADR-0078 决策 4 的 P2）；`linearity` 另行扫描章数，检查「无 O(n²)」。
Future<List<_Measurement>> _measureToc(
  _Harness harness, {
  required int chapters,
  required int iterations,
  required int warmup,
}) async {
  final String html = _tocHtml(chapters: chapters);
  final JsPageContext context = _contextOf(harness.pageScope(html));

  final List<double> parse = <double>[];
  final List<double> cssList = <double>[];
  final List<double> cssFields = <double>[];
  final List<double> cssTotal = <double>[];
  final List<double> regexList = <double>[];
  final List<double> regexFields = <double>[];
  final List<double> regexTotal = <double>[];

  for (var index = 0; index < warmup + iterations; index++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final RuleScope page = harness.pageScope(html);
    final double parseMs = _elapsedMs(stopwatch);

    final List<RuleScope> items = _success(
      await harness.pages.list(_tocListRule, page, 'tocRule.chapterList'),
      'tocRule.chapterList',
    );
    final double listMs = _elapsedMs(stopwatch);

    final ({int names, int urls}) read = await _readEntries(
      harness,
      items,
      nameRule: _tocNameRule,
      urlRule: _tocUrlRule,
    );
    final double fieldsMs = _elapsedMs(stopwatch);

    final List<RuleScope> regexItems = _success(
      await harness.pages.list(_tocRegexListRule, page, 'tocRule.chapterList'),
      'tocRule.chapterList',
    );
    final double regexListMs = _elapsedMs(stopwatch);

    final ({int names, int urls}) regexRead = await _readEntries(
      harness,
      regexItems,
      nameRule: _tocRegexNameRule,
      urlRule: _tocRegexUrlRule,
    );
    final double regexFieldsMs = _elapsedMs(stopwatch);

    // 两条列表规则都必须真的产出这一页的条目，否则「快」只说明规则没命中。
    // 用断言以外的方式校验：`--release` 会丢掉 assert，而基准数字不允许建立在「其实没命中」上。
    _verify(
      items.length == chapters,
      'CSS list rule matched ${items.length}/$chapters',
    );
    _verify(
      regexItems.length == chapters,
      'regex list rule matched ${regexItems.length}/$chapters',
    );
    _verify(
      read.names == chapters && read.urls == chapters,
      'CSS fields are incomplete',
    );
    _verify(
      regexRead.names == chapters && regexRead.urls == chapters,
      'regex fields are incomplete',
    );

    if (index < warmup) {
      continue;
    }
    parse.add(parseMs);
    cssList.add(listMs);
    cssFields.add(fieldsMs);
    cssTotal.add(parseMs + listMs + fieldsMs);
    regexList.add(regexListMs);
    regexFields.add(regexFieldsMs);
    regexTotal.add(parseMs + regexListMs + regexFieldsMs);
  }

  // `context` 只为证明这一页的作用域带 JS 上下文（`replaceRegex` 的 `@js:` 要用同一页）。
  _verify(context.page == 1, 'page scope lost its JS context');

  return <_Measurement>[
    _Measurement(
      metric: 'P2',
      name: '目录页解析（$chapters 章）',
      timing: _Timing(<double>[...parse]),
    ),
    _Measurement(
      metric: 'P2',
      name: 'CSS 列表规则（id.list@tag.dd）',
      timing: _Timing(cssList),
    ),
    _Measurement(
      metric: 'P2',
      name: 'CSS 条目字段 ×2（$chapters 条）',
      timing: _Timing(cssFields),
    ),
    _Measurement(
      metric: 'P2',
      name: 'total CSS：解析→列表→字段',
      timing: _Timing(cssTotal),
      target: '≤ 300 ms',
    ),
    _Measurement(
      metric: 'P2',
      name: '正则列表规则（:href=…）',
      timing: _Timing(regexList),
    ),
    _Measurement(
      metric: 'P2',
      name: '正则条目字段 ×2（$chapters 条）',
      timing: _Timing(regexFields),
    ),
    _Measurement(
      metric: 'P2',
      name: 'total 正则：解析→列表→字段',
      timing: _Timing(regexTotal),
    ),
  ];
}

/// 逐条读章名与地址：与 `FetchToc._entries` 同一形状（每条两次取值规则求值）。
Future<({int names, int urls})> _readEntries(
  _Harness harness,
  List<RuleScope> items, {
  required String nameRule,
  required String urlRule,
}) async {
  var names = 0;
  var urls = 0;
  for (final RuleScope item in items) {
    final String? name = _success(
      await harness.pages.field(
        nameRule,
        item,
        'tocRule.chapterName',
        sourceId: 'https://example-novel.test',
      ),
      'tocRule.chapterName',
    );
    final String? url = _success(
      await harness.pages.field(
        urlRule,
        item,
        'tocRule.chapterUrl',
        sourceId: 'https://example-novel.test',
      ),
      'tocRule.chapterUrl',
    );
    if (name != null && name.isNotEmpty) {
      names++;
    }
    if (url != null && url.isNotEmpty) {
      urls++;
    }
  }

  return (names: names, urls: urls);
}

/// P2 的线性度扫描：同一套链路在 250 / 500 / 1000 / 2000 章上的中位数总耗时。
///
/// 「近似线性」的判据是**每章耗时不随章数增长**（`usPerChapter` 在 4 个点上同量级）；O(n²) 会
/// 让最后一行是首行的数倍。这里用 `p50` 而不是 min，是因为扫描样本少，min 更容易被单次抖动骗过。
Future<List<({int chapters, _Timing total})>> _measureTocLinearity(
  _Harness harness, {
  required int iterations,
}) async {
  final List<({int chapters, _Timing total})> rows =
      <({int chapters, _Timing total})>[];
  for (final int chapters in _tocSweep) {
    final String html = _tocHtml(chapters: chapters);
    final List<double> total = <double>[];
    for (var index = 0; index < 1 + iterations; index++) {
      final Stopwatch stopwatch = Stopwatch()..start();
      final RuleScope page = harness.pageScope(html);
      final List<RuleScope> items = _success(
        await harness.pages.list(_tocListRule, page, 'tocRule.chapterList'),
        'tocRule.chapterList',
      );
      await _readEntries(
        harness,
        items,
        nameRule: _tocNameRule,
        urlRule: _tocUrlRule,
      );
      final double elapsed = _elapsedMs(stopwatch);
      if (index > 0) {
        total.add(elapsed);
      }
    }
    rows.add((chapters: chapters, total: _Timing(total)));
  }

  return rows;
}

/// P3：同一批规则文本反复求值时的「命率」——`compilations / lookups`。
///
/// 改前引擎没有任何编译缓存，所以 `lookups == compilations`、命中率 **0%**；这条数字就是 R1
/// （规则编译期/运行期分离）的「改前」基线，改后同一个脚本应当把命中率抬到 ≥95%
/// （ADR-0078 决策 4）。
///
/// 三种形态各一条，覆盖 P3 点名的三类编译：CSS 选择器、JSONPath、正则链。
Future<RuleCompileStats> _measureRuleCompile(
  _Harness harness, {
  required int iterations,
}) async {
  final RuleScope page = harness.pageScope(_chapterHtml(paragraphs: 4));
  // 正则列表规则只能在目录页上命中，所以它用一个 20 章的小目录（P3 度量的是编译次数，不是条目数）。
  final RuleScope toc = harness.pageScope(_tocHtml(chapters: 20));
  final RuleScope json = RuleScope.json(<String, Object?>{
    'data': <String, Object?>{'name': 'One'},
  });

  // P1/P2 也求值规则，所以这里取**增量**：P3 问的是「同一批规则反复求值时」的命中率，
  // 与前面两项各自编译了多少条无关。
  final RuleCompileStats before = harness.compileStats;

  for (var index = 0; index < iterations; index++) {
    _success(
      await harness.pages.content(_valueRule, page, 'contentRule.content'),
      'contentRule.content',
    );
    _success(
      await harness.pages.content(_jsonRule, json, 'contentRule.content'),
      'contentRule.content',
    );
    _success(
      await harness.pages.list(_tocRegexListRule, toc, 'tocRule.chapterList'),
      'tocRule.chapterList',
    );
  }

  final RuleCompileStats after = harness.compileStats;

  return RuleCompileStats(
    lookups: after.lookups - before.lookups,
    compilations: after.compilations - before.compilations,
  );
}

/// P5：真 worker 上一个 job 的固定开销，以及主流写法里嵌套调用的内联覆盖率。
///
/// **必须真 worker**：空脚本也要走一遍「排队 → isolate 消息 → 前奏 → 回传」，那正是 P5 说的
/// 「每个 job 的固定开销」（ADR-0078 决策 4，目标 ≤ 3 ms）。
///
/// 内联覆盖率用两种语料里的真实写法各跑一次：
/// * **字面量写法**（`java.timeFormat(java.getString('$.start_time')*1000)`，语料主流）：宿主在构造
///   job 之前就把 `java.getString` 求值并内联，因此这一轮应当 **100%** 不跨 sandbox；
/// * **带变量的写法**（`java.getString(rule)`）：首参不是字面量，只能回到 `parse.*` 通道，
///   这一轮应当是 0%。
///
/// 两个数一起看才有意义：它说明「≥90% 的嵌套调用内联」取决于**语料写法**而不是引擎选择，
/// 而语料里主流写法正好是字面量的那种。
Future<({_Timing roundtrip, JsInlineStats literal, JsInlineStats dynamic})>
_measureJs(
  _Harness harness, {
  required int iterations,
  required int warmup,
}) async {
  // 页级作用域（DOM + 正文）：嵌套的 `parse.*` 只答**页级**作用域，JSON 条目/元素作用域会被
  // 具名拒绝（`js:parse-scope`），所以这里必须是一页。正文是 JSON 文本，`$.` 规则直接读它。
  final RuleScope scope = harness.pageScope(_jsonPageBody);
  const JsPageContext context = _fallbackContext;

  final List<double> roundtrip = <double>[];
  for (var index = 0; index < warmup + iterations; index++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Object? answer = _success(
      await harness.pages.script(
        'void 0',
        rulePath: 'contentRule.content',
        context: context,
      ),
      'contentRule.content',
    );
    final double elapsed = _elapsedMs(stopwatch);
    _verify(answer == null, 'an empty script must answer null');
    if (index >= warmup) {
      roundtrip.add(elapsed);
    }
  }

  final JsInlineStats beforeLiteral = harness.inlineStats;
  _success(
    await harness.pages.content(
      r"{{java.timeFormat(java.getString('$.data.start_time')*1000)}}",
      scope,
      'tocRule.updateTime',
    ),
    'tocRule.updateTime',
  );
  final JsInlineStats afterLiteral = harness.inlineStats;

  // 首参是**表达式**而不是字面量：内联路径不成立，只能走 `parse.*` 回到宿主。
  final JsInlineStats beforeDynamic = harness.inlineStats;
  _success(
    await harness.pages.content(
      r'@js:java.getString(result.length >= 0 ? "$.data.name" : "$.data.name")',
      scope,
      'tocRule.chapterName',
    ),
    'tocRule.chapterName',
  );
  final JsInlineStats afterDynamic = harness.inlineStats;

  return (
    roundtrip: _Timing(roundtrip),
    literal: JsInlineStats(
      inlinedCalls: afterLiteral.inlinedCalls - beforeLiteral.inlinedCalls,
      bridgedCalls: afterLiteral.bridgedCalls - beforeLiteral.bridgedCalls,
    ),
    dynamic: JsInlineStats(
      inlinedCalls: afterDynamic.inlinedCalls - beforeDynamic.inlinedCalls,
      bridgedCalls: afterDynamic.bridgedCalls - beforeDynamic.bridgedCalls,
    ),
  );
}

/// P5 的分段：把「一个 job 的固定开销」拆成看得见的四段，再给一条机器底座。
///
/// 3 ms 单看没有方向，所以这里用**现成的接缝**各量一次，不靠猜：
///
/// | 段 | 怎么量 |
/// |---|---|
/// | 引擎侧 | 同一个 `RuleEngine.evaluateJs`，换成**立刻返回**的桥 → 内联扫描 + 作业构造 + `jsLib` 解析的宿主成本 |
/// | 桥 + worker | 直接调 `JsBridge.evaluate(JsJob('void 0'))`，绕开引擎 → 两跳消息 + 沙箱前奏 + 空信封 |
/// | + `jsLib` 前奏 | 同一个 job 带一段 40 字节的库 → 前奏里「先跑库」的成本 |
/// | + 结果信封 | 脚本返回 32 KB 字符串 → 结果编解码的成本 |
/// | 机器底座 | 一个裸 `Isolate` 的 echo 往返 → 「两跳消息」本身在这台机器上的地板价 |
///
/// 剩下分不开的部分（沙箱前奏本身、真实信封的序列化细节）要 worker 侧计时才看得见，
/// 那是 R5 的开工前置；本脚本只回答「钱花在哪一段的量级上」。
Future<List<_Measurement>> _measureJsSegments(
  _Harness harness, {
  required int iterations,
  required int warmup,
}) async {
  final RuleEngine hostSide = RuleEngine(
    logger: AppLogger(level: LogLevel.off),
    jsBridge: _InstantJsBridge(),
    variables: JsVariableStore(),
  );

  final List<double> engine = <double>[];
  final List<double> bridge = <double>[];
  final List<double> withLib = <double>[];
  final List<double> bigResult = <double>[];
  final List<double> bulk = <double>[];

  for (var index = 0; index < warmup + iterations; index++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    _success<Object?>(
      await hostSide.evaluateJs(
        'void 0',
        rulePath: 'contentRule.content',
        context: _fallbackContext,
      ),
      'contentRule.content',
    );
    final double engineMs = _elapsedMs(stopwatch);

    _success<Object?>(
      await harness.jsBridge.evaluate(_benchJob('void 0')),
      'contentRule.content',
    );
    final double bridgeMs = _elapsedMs(stopwatch);

    _success<Object?>(
      await harness.jsBridge.evaluate(
        _benchJob(
          "__benchLib('x')",
          jsLib: 'function __benchLib(a){return a;}',
        ),
      ),
      'contentRule.content',
    );
    final double libMs = _elapsedMs(stopwatch);

    _success<Object?>(
      await harness.jsBridge.evaluate(_benchJob("'x'.repeat(32768)")),
      'contentRule.content',
    );
    final double bigMs = _elapsedMs(stopwatch);

    _success<Object?>(
      await harness.jsBridge.evaluate(_benchJob(_bulkScript)),
      'contentRule.content',
    );
    final double bulkMs = _elapsedMs(stopwatch);

    if (index >= warmup) {
      engine.add(engineMs);
      bridge.add(bridgeMs);
      withLib.add(libMs);
      bigResult.add(bigMs);
      bulk.add(bulkMs);
    }
  }

  return <_Measurement>[
    _Measurement(metric: 'P5', name: '引擎侧（假桥，沙箱之外）', timing: _Timing(engine)),
    _Measurement(metric: 'P5', name: '桥 + worker：空脚本', timing: _Timing(bridge)),
    _Measurement(
      metric: 'P5',
      name: '桥 + worker：+ jsLib 前奏',
      timing: _Timing(withLib),
    ),
    _Measurement(
      metric: 'P5',
      name: '桥 + worker：+ 32 KB 结果信封',
      timing: _Timing(bigResult),
    ),
    // 体积灵敏度：脚本源码每多 1 KB 要多少时间。用它把「每 job 重跑整份前奏」的解析成本
    // 从常数项里估出来（前奏长度是已知常量，见打印里的 prelude=…）。
    _Measurement(
      metric: 'P5',
      name: '桥 + worker：+ ${_bulkBytes ~/ 1024} KB 脚本源码',
      timing: _Timing(bulk),
    ),
  ];
}

/// 体积灵敏度用的脚本：只堆语句，不做 I/O，让成本集中在「解析这段源码」上。
final String _bulkScript = 'var a0=0;' * (_bulkBytes ~/ 9);
const int _bulkBytes = 45 * 1024;

/// 沙箱前奏的字符数，从 `lib/core/js/quickjs_worker.dart` 的 `_prelude` 常量里读。
///
/// 它是 `quickjs_worker.dart` 的私有常量，工具不 import（那是 isolate 入口，`coverage:ignore-file`），
/// 所以这里按文本切出来；读不到（不在仓库根目录运行）就返回 `null`，只跳过那条估算。
int? _preludeChars() {
  final File file = File('lib/core/js/quickjs_worker.dart');
  if (!file.existsSync()) {
    return null;
  }
  final String source = file.readAsStringSync();
  const String open = "const String _prelude = r'''";
  final int start = source.indexOf(open);
  if (start < 0) {
    return null;
  }
  final int end = source.indexOf("''';", start + open.length);
  if (end < 0) {
    return null;
  }

  return end - (start + open.length);
}

/// 一个最小的真 job：固定的空上下文，只用来量固定开销。
JsJob _benchJob(String script, {String? jsLib}) => JsJob(
  script: script,
  rulePath: 'contentRule.content',
  baseUrl: 'https://example-novel.test/book/1/',
  page: 1,
  source: const JsSourceInfo(name: '基准书源', url: 'https://example-novel.test'),
  sourceHeaders: const <String, String>{},
  jsLib: jsLib,
);

/// 「两跳消息」的机器地板价：一个 echo isolate 的往返。
///
/// 与 worker 的区别是它什么都不做（没有沙箱、没有前奏、没有信封），所以
/// `空脚本 − 地板价` 才是「沙箱侧」的那部分成本。
Future<_Timing> _measurePingPong(int iterations, {required int warmup}) async {
  final ReceivePort replies = ReceivePort();
  await Isolate.spawn(_echoMain, replies.sendPort);
  final Completer<SendPort> ready = Completer<SendPort>();
  final Queue<Completer<void>> pending = Queue<Completer<void>>();
  replies.listen((Object? message) {
    if (message is SendPort) {
      ready.complete(message);

      return;
    }
    if (pending.isNotEmpty) {
      pending.removeFirst().complete();
    }
  });
  final SendPort echo = await ready.future;

  final List<double> samples = <double>[];
  for (var index = 0; index < warmup + iterations; index++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Completer<void> reply = Completer<void>();
    pending.add(reply);
    // 载荷形状与真 job 相近：一个字符串 + 一个小 Map。
    echo.send(<Object?>[
      'contentRule.content',
      <String, String>{'rulePath': 'contentRule.content'},
    ]);
    await reply.future;
    final double elapsed = _elapsedMs(stopwatch);
    if (index >= warmup) {
      samples.add(elapsed);
    }
  }
  replies.close();

  return _Timing(samples);
}

/// The echo isolate's body: answers its `SendPort`, then echoes every message back.
void _echoMain(SendPort replies) {
  final ReceivePort inbox = ReceivePort();
  replies.send(inbox.sendPort);
  inbox.listen((Object? _) => replies.send('pong'));
}

/// A bridge that answers immediately: it measures the **host side** of a `@js:` rule with the
/// sandbox taken out of the picture.
final class _InstantJsBridge implements JsBridge {
  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) =>
      Future<ParseResult<Object?>>.value(const ParseSuccess<Object?>(null));

  @override
  Future<void> dispose() async {}
}

/// P6：一项操作的常驻内存增量（MB），用 `ProcessInfo.currentRss` 前后相减。
///
/// 取不到「峰值」——Dart 没有 GC 钩子——所以每轮都报三个数：首次（近似工作集）、后续中位数
/// （净增长，>0 才可疑）、最大。`--release` 下这组数字才有意义，debug 的堆策略完全不同。
Future<_MemoryRow> _measureMemory({
  required String name,
  required Future<void> Function() operation,
  required int iterations,
}) async {
  final List<double> deltas = <double>[];
  for (var index = 0; index < iterations; index++) {
    // 先让上一轮的临时对象有机会被回收：RSS 不会自己缩小，但多跑几轮能看出「净增长」。
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final int before = ProcessInfo.currentRss;
    await operation();
    final int after = ProcessInfo.currentRss;
    deltas.add((after - before) / (1024 * 1024));
  }

  final List<double> rest = <double>[...deltas.skip(1)]..sort();
  final double median = rest.isEmpty ? deltas.first : rest[rest.length ~/ 2];

  return _MemoryRow(
    name: name,
    firstMb: deltas.first,
    medianMb: median,
    maxMb: deltas.reduce((double a, double b) => a > b ? a : b),
  );
}

/// P6 的两项：单章与千章目录的常驻增量。
///
/// 与 P1/P2 一样不含网络：夹具字符串在测量**之前**就建好，所以差值只算「解析 + 提取 + 拼接」。
Future<List<_MemoryRow>> _measureMemoryAll(
  _Harness harness, {
  required int iterations,
}) async {
  final String chapter = _chapterHtml();
  final String toc = _tocHtml();
  const JsPageContext context = _fallbackContext;

  return <_MemoryRow>[
    await _measureMemory(
      name: 'P6 单章（199 KB HTML → 正文）',
      iterations: iterations.clamp(3, 10),
      operation: () async {
        final RuleScope page = harness.pageScope(chapter);
        final String body = _success(
          await harness.pages.content(
            _contentRule,
            page,
            'contentRule.content',
          ),
          'contentRule.content',
        );
        _success(
          ParseSuccess<String>(
            await harness.pages.replaceContent(
              _replaceRule,
              htmlToText(body),
              'contentRule.replaceRegex',
              sourceId: 'https://example-novel.test',
              jsContext: context,
            ),
          ),
          'contentRule.replaceRegex',
        );
      },
    ),
    await _measureMemory(
      name: 'P6 千章目录（1000 条 → 章名 + 地址）',
      iterations: iterations.clamp(3, 10),
      operation: () async {
        final RuleScope page = harness.pageScope(toc);
        final List<RuleScope> items = _success(
          await harness.pages.list(_tocListRule, page, 'tocRule.chapterList'),
          'tocRule.chapterList',
        );
        await _readEntries(
          harness,
          items,
          nameRule: _tocNameRule,
          urlRule: _tocUrlRule,
        );
      },
    ),
  ];
}

// ---------------------------------------------------------------------------------------------
// 入口
// ---------------------------------------------------------------------------------------------

/// 本文件不打印任何页面正文；输出只有耗时、计数与夹具大小（C-SEC-4 的精神）。
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 未捕获的异常必须让进程结束：`--release` 下 Dart 的错误不会自动退出（见文件末尾的说明），
  // 否则一次「夹具没命中」会变成一个挂到天黑也不报错的进程。
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    stderr.writeln('tool/bench failed: $error');
    stderr.writeln(stackTrace);
    if (!Process.killPid(pid)) {
      exit(1);
    }

    return true;
  };
  final Map<String, String> options = _parseOptions(_argumentsOf(arguments));
  final int iterations = int.tryParse(options['iterations'] ?? '') ?? 20;
  final int warmup = int.tryParse(options['warmup'] ?? '') ?? 3;
  final Set<String> only = (options['only'] ?? 'p1,p2,p3')
      .split(',')
      .map((String part) => part.trim().toLowerCase())
      .where((String part) => part.isNotEmpty)
      .toSet();
  if (iterations <= 0 || warmup < 0) {
    stderr.writeln(
      'usage: BENCH_ARGS="--iterations=20 --warmup=3 --only=p1,p2,p3 '
      '--out=build/bench.json" flutter run -d windows --release '
      '-t tool/bench/bench.dart',
    );
    exit(2);
  }

  final _Harness harness = _Harness();
  final List<_Measurement> measurements = <_Measurement>[];

  if (only.contains('p1')) {
    measurements.addAll(
      await _measureChapter(harness, iterations: iterations, warmup: warmup),
    );
  }
  if (only.contains('p2')) {
    measurements.addAll(
      await _measureToc(
        harness,
        chapters: _tocChapters,
        iterations: iterations,
        warmup: warmup,
      ),
    );
  }

  final List<({int chapters, _Timing total})> linearity = only.contains('p2')
      ? await _measureTocLinearity(harness, iterations: iterations)
      : <({int chapters, _Timing total})>[];

  // P3 读的是计数器，不是耗时，所以它的采样次数与 P1/P2 不同量级（反正是纯 CPU，便宜）。
  final RuleCompileStats compileStats = only.contains('p3')
      ? await _measureRuleCompile(harness, iterations: iterations * 10)
      : const RuleCompileStats(lookups: 0, compilations: 0);

  // P5 要真 worker：每个 job 都是一次 isolate 往返，所以采样比 P1/P2 少。
  final ({_Timing roundtrip, JsInlineStats literal, JsInlineStats dynamic})?
  js = only.contains('p5')
      ? await _measureJs(
          harness,
          iterations: (iterations ~/ 4).clamp(1, 50),
          warmup: warmup,
        )
      : null;

  // P5 的分段（引擎侧 / 桥+worker / 前奏 / 信封）与机器底座，行直接并进主表。
  final List<_Measurement> jsSegments = only.contains('p5')
      ? await _measureJsSegments(
          harness,
          iterations: (iterations ~/ 4).clamp(1, 50),
          warmup: warmup,
        )
      : const <_Measurement>[];
  final _Timing? pingPong = only.contains('p5')
      ? await _measurePingPong((iterations ~/ 2).clamp(1, 100), warmup: warmup)
      : null;
  measurements.addAll(jsSegments);

  // P6 用 RSS 差值，采样少而稳（每轮之间留一个 ms 级空档让上一轮的临时对象有机会回收）。
  final List<_MemoryRow> memory = only.contains('p6')
      ? await _measureMemoryAll(harness, iterations: iterations)
      : const <_MemoryRow>[];

  final String chapterHtml = _chapterHtml();
  final String tocHtml = _tocHtml();
  final _Report report = _Report(
    fixtureBytes: (
      chapter: utf8.encode(chapterHtml).length,
      toc: utf8.encode(tocHtml).length,
    ),
    tocChapters: _tocChapters,
    measurements: measurements,
    linearity: linearity,
    compileStats: compileStats,
    iterations: iterations,
    warmup: warmup,
    jsRoundtrip: js?.roundtrip,
    pingPong: pingPong,
    inlineStats: js == null ? null : (literal: js.literal, dynamic: js.dynamic),
    memory: memory,
  );

  _printReport(report);

  final String? out = options['out'];
  if (out != null && out.isNotEmpty) {
    final File file = File(out);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    stdout.writeln('');
    stdout.writeln('report written to $out');
  }

  await harness.dispose();
  // 收尾只能自己结束进程：`--release`（AOT + Windows 嵌入器）上 `exit()` 会卡在 VM 关闭里，
  // 最后一行打印完仍挂到超时（最小复现：`main` 里 `ensureInitialized()` + `exit(0)` 同样挂起；
  // debug 模式下宿主会立刻断开）。本工具不进 CI，报告已经写在 stdout 与 `--out` 里，所以直接
  // 结束进程——**退出码因此没有意义**（见 `tool/bench/README.md` §2 的第 2 条用法）。
  stdout.writeln('');
  stdout.writeln('done（--release 下本进程自毁，退出码不作为成败判据）');
  if (!Process.killPid(pid)) {
    exit(0);
  }
}

/// 打印一张可直接粘进 `tool/bench/README.md` / `docs/dev/engine-parity.md` 的表。
void _printReport(_Report report) {
  stdout.writeln('tool/bench — 引擎性能基准（M26，ADR-0078 决策 4）');
  stdout.writeln(
    'platform=${Platform.operatingSystem} release=${!_isDebugBuild} '
    'dart=${Platform.version.split(' ').first}',
  );
  stdout.writeln(
    'fixtures: chapter=${_kb(report.fixtureBytes.chapter)} '
    'toc=${_kb(report.fixtureBytes.toc)} (${report.tocChapters} chapters) '
    'iterations=${report.iterations} warmup=${report.warmup}',
  );
  stdout.writeln('');
  stdout.writeln('| 指标 | 项 | 目标 | n | min | p50 | p95 | max |');
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final _Measurement measurement in report.measurements) {
    final _Timing timing = measurement.timing;
    stdout.writeln(
      '| ${measurement.metric} | ${measurement.name} | '
      '${measurement.target ?? '—'} | ${timing.count} | '
      '${_ms(timing.min)} | ${_ms(timing.p50)} | ${_ms(timing.p95)} | '
      '${_ms(timing.max)} |',
    );
  }

  if (report.linearity.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('P2 线性度（解析→列表→字段，p50）：');
    stdout.writeln('| 章数 | p50 (ms) | 每章 (µs) |');
    stdout.writeln('|---|---|---|');
    for (final ({int chapters, _Timing total}) row in report.linearity) {
      stdout.writeln(
        '| ${row.chapters} | ${_ms(row.total.p50)} | '
        '${(row.total.p50 * 1000 / row.chapters).toStringAsFixed(1)} |',
      );
    }
  }

  final _Timing? js = report.jsRoundtrip;
  if (js != null) {
    stdout.writeln('');
    stdout.writeln(
      'P5 JS job 固定开销（空脚本往返，n=${js.count}）：'
      'min ${_ms(js.min)} / p50 ${_ms(js.p50)} / p95 ${_ms(js.p95)} / '
      'max ${_ms(js.max)} ms',
    );
    if (report.pingPong case final _Timing floor) {
      stdout.writeln(
        'P5 机器底座（裸 isolate 往返，n=${floor.count}）：'
        'p50 ${_ms(floor.p50)} ms —— 「空脚本 − 底座」才是沙箱侧成本',
      );
    }
    // 体积灵敏度：源码每 KB 要多少时间。**只用来定性质，不用来外推**——把斜率乘以前奏长度
    // 会得到比整个空 job 还大的数（前奏的代码形状与填充语句不同），那是上界不是测量值。
    final _Measurement? bulk = report.measurements
        .where((_Measurement row) => row.name.contains('KB 脚本源码'))
        .firstOrNull;
    final int? prelude = _preludeChars();
    if (bulk != null) {
      final double perKbUs =
          (bulk.timing.p50 - js.p50) * 1000 / (_bulkBytes / 1024);
      stdout.writeln(
        'P5 体积灵敏度：源码 ≈ ${perKbUs.toStringAsFixed(0)} µs/KB'
        '${prelude == null ? '' : '（前奏 ${(prelude / 1024).toStringAsFixed(1)} KB）'}'
        ' ⇒ 固定成本随「每 job 重跑的沙箱源码体积」走，而不是消息往返',
      );
    }
    final ({JsInlineStats literal, JsInlineStats dynamic})? inline =
        report.inlineStats;
    if (inline != null) {
      stdout.writeln(
        'P5 内联覆盖：字面量写法 '
        '${inline.literal.inlinedCalls}/${inline.literal.calls}'
        '（${(inline.literal.inlineCoverage * 100).toStringAsFixed(0)}%）；'
        '带变量写法 ${inline.dynamic.inlinedCalls}/${inline.dynamic.calls}'
        '（${(inline.dynamic.inlineCoverage * 100).toStringAsFixed(0)}%）',
      );
    }
  }

  if (report.memory.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('P6 常驻增量（RSS，前后相减）：');
    stdout.writeln('| 项 | 首次 (MB) | 后续中位 (MB) | 最大 (MB) |');
    stdout.writeln('|---|---|---|---|');
    for (final _MemoryRow row in report.memory) {
      stdout.writeln(
        '| ${row.name} | ${row.firstMb.toStringAsFixed(2)} | '
        '${row.medianMb.toStringAsFixed(2)} | ${row.maxMb.toStringAsFixed(2)} |',
      );
    }
    stdout.writeln(
      '  （「首次」近似工作集，「后续中位」是重复一次操作的净增长；'
      'Dart 侧拿不到 GC 钩子，所以没有真峰值）',
    );
  }

  if (report.compileStats.lookups > 0) {
    final RuleCompileStats stats = report.compileStats;
    stdout.writeln('');
    stdout.writeln(
      'P3 规则编译：lookups=${stats.lookups} '
      'compilations=${stats.compilations} hits=${stats.hits} '
      'hitRate=${(stats.hitRate * 100).toStringAsFixed(1)}%',
    );
    stdout.writeln('  （改前无缓存：每次求值都编译一次，命中率 0%；R1 落地后同一命令应报 ≥95%）');
  }
}

/// `flutter run` 不转发命令行参数，所以选项走环境变量（与 `SPOT_CHECK_ARGS` 同一约定）。
List<String> _argumentsOf(List<String> arguments) {
  if (arguments.isNotEmpty) {
    return arguments;
  }

  return (Platform.environment['BENCH_ARGS'] ?? '')
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}

/// `--key=value` / `--flag` 两种形态；不认识的前缀直接跳过。
Map<String, String> _parseOptions(List<String> arguments) {
  final Map<String, String> options = <String, String>{};
  for (final String argument in arguments) {
    if (!argument.startsWith('--')) {
      continue;
    }
    final int separator = argument.indexOf('=');
    if (separator < 0) {
      options[argument.substring(2)] = '';
    } else {
      options[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
  }

  return options;
}

/// Unwraps a [ParseResult] or stops the run: a benchmark that silently measures a failure is worse
/// than one that fails (`C-SRC-4` 的同一立场).
T _success<T>(ParseResult<T> result, String rulePath) => switch (result) {
  ParseSuccess<T>(:final T data) => data,
  ParseFailure<T>(:final ParseFailureKind kind) => throw StateError(
    'benchmark rule failed: field=$rulePath kind=${kind.name}',
  ),
};

/// The JS context of a page scope, so `replaceRegex` / purge rules see the same page the rules do.
JsPageContext _contextOf(RuleScope scope) => switch (scope) {
  DomScope(:final JsPageContext? jsContext) => jsContext ?? _fallbackContext,
  JsonScope(:final JsPageContext? jsContext) => jsContext ?? _fallbackContext,
  RegexScope(:final JsPageContext? jsContext) => jsContext ?? _fallbackContext,
};

const JsPageContext _fallbackContext = JsPageContext(
  baseUrl: 'https://example-novel.test/book/1/',
  source: JsSourceInfo(name: '基准书源', url: 'https://example-novel.test'),
);

/// Whether this build runs without assertions — `flutter run --release` is the documented mode for
/// every number in `tool/bench/README.md`, because debug-mode numbers are 5–20× off.
bool get _isDebugBuild {
  var debug = false;
  assert(() {
    debug = true;

    return true;
  }());

  return debug;
}

/// Fails the run when [condition] does not hold.
///
/// Deliberately **not** an `assert`: `tool/bench/README.md` documents `--release` as the mode every
/// recorded number comes from, and a benchmark that quietly measured a non-matching rule would be
/// worse than one that stops.
void _verify(bool condition, String message) {
  if (!condition) {
    throw StateError('benchmark fixture check failed: $message');
  }
}

/// Stops [stopwatch], answers the elapsed milliseconds **and restarts it from zero**.
///
/// `Stopwatch.reset()` on its own leaves the watch stopped, so a reset without a start would
/// silently record 0 ms for every phase after the first one.
double _elapsedMs(Stopwatch stopwatch) {
  stopwatch.stop();
  final double elapsed = stopwatch.elapsedMicroseconds / 1000;
  stopwatch.reset();
  stopwatch.start();

  return elapsed;
}

String _ms(double value) => value.toStringAsFixed(2);

double _round(double value) => double.parse(value.toStringAsFixed(3));

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
