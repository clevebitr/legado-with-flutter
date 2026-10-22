// G2b spot-check: run one **real** book source through the production chain against
// the live site it points at, and print what each stage produced.
//
// Why this exists: `docs/dev/roadmap.md` §3.4 step 3 asks for a manual live run **before** the JS
// bridge is built, so the selectors this repository implements (`book-source.md` §3
// matrix, in particular #12 `@css:`) are checked against real HTML rather than only
// against the offline corpus. `docs/dev/testing.md` §1 forbids the network in tests,
// so this is a `tool/` entry point, not a test: it is never discovered by
// `flutter test` and never runs in CI.
//
// Usage (from the repository root):
//
//   flutter run -d windows -t tool/spot_check/spot_check.dart -- --source=<file.json> --keyword=剑来 [--plain-http]
//   flutter run -d windows -t tool/spot_check/spot_check.dart -- --list=<collection.json>
//
// `dart run` does **not** work here: the chain needs the real JS engine and the Flutter
// native assets, so the entry point must run under `flutter run` (the tool's usage message
// below says the same thing).
//
// `--source` accepts a single book source object or an array (a collection export);
// with an array, `--name=<substring>` picks one entry. `--json` prints the report as
// JSON instead of a table, which is what gets pasted into the PR / CHANGELOG record
// (`book-source.md` §10).
//
// The chain is the production one — use case → `renderUrlTemplate` →
// `core/network/HttpClient` → `RuleEngine` — so a stage that passes here is evidence
// about the shipped code, not about a harness-only shortcut. A stage that fails prints
// the `ParseFailureKind` and the `rulePath` of the rule that stopped it.
//
// The body of a fetched page is never written to disk; the report carries a short
// sample and a hash instead, which is enough to compare two runs without turning the
// console into a copy of someone else's page (C-SEC-4 spirit).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/concurrent_rate.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// How much of a produced value the report shows before the hash takes over.
const int _sampleLength = 60;

/// Rule flags a later phase of `book-source.md` §3 owns; a source that uses one of
/// them cannot be checked before that phase lands.
///
/// `@js:` is **not** in the list any more: matrix #14 landed with `docs/dev/roadmap.md` 3.4, so a
/// value-rule script is evaluable today. It is handled separately below, because it is
/// only supported outside **list rules** (`bookList` / `chapterList`, whose「JS 返回一列
/// 元素」 contract does not exist yet).
///
/// `@put:` / `@get:` left the list with the M1 grammar slice (matrix #16, `docs/dev/roadmap.md` 3.4 / b0),
/// `{{…}}` is no longer rejected wholesale below either (matrix #18, same slice), and `@@`
/// **left the list with G4**: matrix #15 has been implemented since that slice, so only a
/// **misplaced** `@@` — the engine's `unsupported:@@` — is rejected now
/// ([_hasMisplacedDefaultFlag]); the census counts both, because G4 needs a selectable one.
/// “M0-compatible” in the printed lines means “M0 plus the implemented M1 grammar”.
const List<String> _deferredFlags = <String>[
  '@xpath:',
  'webjs',
  'sourceregex',
  '<js>',
];

/// Whether [rule] carries a `@@` the engine cannot evaluate (matrix #15).
///
/// `@@` is a **prefix** of the rule body or of a `{{…}}` template's inner rule; anywhere else
/// the `@`-split leaves an empty segment and `RuleEngine` reports `unsupported:@@`
/// (`class.a@@class.b@text`), so a source written that way is not selectable today.
bool _hasMisplacedDefaultFlag(String rule) {
  var index = rule.indexOf('@@');
  while (index >= 0) {
    if (!_isDefaultFlagStart(rule.substring(0, index))) {
      return true;
    }
    index = rule.indexOf('@@', index + 2);
  }
  return false;
}

/// Whether the text [before] a `@@` can end a rule body: the value / branch / template start,
/// optionally preceded by matrix #7's `-` (`-@@class.a@text` reverses after the flag).
bool _isDefaultFlagStart(String before) {
  String trimmed = before.trimRight();
  if (trimmed.endsWith('-')) {
    trimmed = trimmed.substring(0, trimmed.length - 1).trimRight();
  }
  return trimmed.isEmpty ||
      trimmed.endsWith('||') ||
      trimmed.endsWith('&&') ||
      trimmed.endsWith('%%') ||
      trimmed.endsWith('{{');
}

/// The matrix #14 flag, checked per field rather than globally.
const String _jsFlag = '@js:';

/// The rule fields whose `@js:` this repository cannot evaluate yet.
///
/// A list rule would need “JS returns a list of elements” (upstream's `getElements`
/// `Mode.Js` branch). A URL template never evaluates a bare `@js:` flag: `searchUrl` /
/// `exploreUrl` run JavaScript only through their `{{…}}` placeholders, and a rule head
/// there is refused by name (matrix #18, `book-source.md` §4.2).
const List<String> _jsUnsupportedFields = <String>[
  'searchUrl',
  'exploreUrl',
  'ruleSearch.bookList',
  'ruleToc.chapterList',
];

/// Reads the arguments from [arguments], or from `SPOT_CHECK_ARGS` when the host does
/// not forward them.
///
/// The chain needs the real JS engine (matrix #14 evaluates `@js:` rules), so this tool
/// runs on a device through `flutter run -d <device> -t tool/spot_check/spot_check.dart`,
/// and `flutter run` does not forward extra arguments to the Dart entrypoint. The
/// environment variable is how the caller passes them there; a plain CLI host
/// (`dart run`, which cannot compile a Flutter-dependent entrypoint) keeps using argv.
List<String> _argumentsOf(List<String> arguments) {
  if (arguments.isNotEmpty) {
    return arguments;
  }

  return (Platform.environment['SPOT_CHECK_ARGS'] ?? '')
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}

/// The harness reads every chapter live: a cache would hide the very behaviour it measures, so the
/// spot-check runs with the port answering “nothing stored” and dropping writes.
const ContentCache _noContentCache = _NoContentCache();

/// A [ContentCache] that never stores anything (`tool/spot_check` must always hit the network).
final class _NoContentCache implements ContentCache {
  const _NoContentCache();

  @override
  Future<String?> read({required String sourceId, required String url}) async =>
      null;

  @override
  Future<void> write({
    required String sourceId,
    required String url,
    required String body,
  }) async {}
}

Future<void> main(List<String> arguments) async {
  final Map<String, String> options = _parseOptions(_argumentsOf(arguments));
  final String? collection = options['list'];
  if (collection != null) {
    _listCandidates(File(collection));
    exit(0);
  }

  final String? sourcePath = options['source'];
  if (sourcePath == null) {
    stderr.writeln(
      'usage: flutter run -d <device> -t tool/spot_check/spot_check.dart '
      '-- --source=<file.json> [--keyword=剑来] [--name=<substring>] [--json]\n'
      '       flutter run -d <device> -t tool/spot_check/spot_check.dart '
      '-- --list=<collection.json>',
    );
    exit(2);
  }

  final BookSource source = _loadSource(
    File(sourcePath),
    name: options['name'],
  );
  final String keyword = options['keyword'] ?? '剑来';
  final Stopwatch stopwatch = Stopwatch()..start();
  final _Report report = await _runChain(
    source,
    keyword,
    allowPlainHttp: options.containsKey('plain-http'),
  );
  stopwatch.stop();
  report.elapsedMilliseconds = stopwatch.elapsedMilliseconds;

  if (options.containsKey('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    report.print();
  }
  // 显式 exit（而不是只设 exitCode）：本工具链需要真实 JS 引擎，所以它在
  // `flutter run -d <device> -t tool/spot_check/spot_check.dart` 下运行，而设备宿主不会
  // 因为 main 返回就退出，退出码也拿不回来。
  exit(report.isComplete ? 0 : 1);
}

/// Loads the source to check out of [file].
///
/// [file] may hold one object or a collection; [name] selects an entry of a collection
/// by substring, which is how a spot-check pins **which** of thousands of published
/// sources it ran.
BookSource _loadSource(File file, {String? name}) {
  final Object? decoded = jsonDecode(file.readAsStringSync());
  final List<Object?> entries = decoded is List ? decoded : <Object?>[decoded];
  final Map<String, Object?> entry = entries
      .whereType<Map<String, Object?>>()
      .firstWhere(
        (Map<String, Object?> item) =>
            name == null || '${item['bookSourceName']}'.contains(name),
        orElse: () => throw ArgumentError(
          'No book source matching "$name" in ${file.path}.',
        ),
      );

  return BookSource.fromLegadoJson(entry);
}

/// Runs the four stages of `docs/dev/roadmap.md` §4 against the live site of [source].
Future<_Report> _runChain(
  BookSource source,
  String keyword, {
  bool allowPlainHttp = false,
}) async {
  final AppLogger logger = AppLogger(level: LogLevel.warning);
  // 请求层是唯一的上网入口（C-NET-1）：页面抓取与规则里的 `http.*` 共用同一个客户端，
  // 因此也共用 cookie 与同一份书源并发预算（book-source.md §8）。
  final DioHttpClient http = DioHttpClient(
    cookies: InMemoryCookieManager(),
    logger: logger,
    // `--plain-http` 与 App 设置里的开关同义（C-SEC-2）：真实语料里仍有 `http://` 站点，
    // 而默认策略会直接拒绝它们（默认关闭是对的，探测时才需要显式打开）。
    policy: HttpPolicy(allowPlainHttp: allowPlainHttp),
  );
  // 引擎与桥共一份变量表：`@put:` / `@get:` 与 `java.put` / `java.get` 是同一份（ADR-0034）。
  final JsVariableStore variables = JsVariableStore();
  final PageFetchService pages = PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: QuickJsWorkerBridge(
        logger: logger,
        launch: launchQuickJsWorker,
        http: http,
        variables: variables,
      ),
      variables: variables,
    ),
    http: http,
    logger: logger,
  );
  final _Report report = _Report(source: source, keyword: keyword);

  // 逐段跑：上一段的产物是下一段的输入，任何一段失败都保留已得到的证据。
  final List<Book> books = <Book>[];
  switch (await SearchBooks(pages: pages).execute(source, keyword)) {
    case ParseSuccess<List<Book>>(:final List<Book> data):
      books.addAll(data);
      report.record(
        'search',
        _stage(
          books.length,
          books.isEmpty
              ? const <String>[]
              : <String>[
                  '${books.first.name} ${books.first.url}'
                      ' | kind=${_sample(books.first.kind ?? '-')}'
                      ' updateTime=${books.first.updateTime ?? '-'}',
                ],
        ),
      );
    case ParseFailure<List<Book>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.fail('search', kind, rulePath);
  }
  if (books.isEmpty) {
    return report;
  }

  final Book first = books.first;
  final BookInfo? info;
  switch (await FetchBookInfo(pages: pages).execute(source, first.url)) {
    case ParseSuccess<BookInfo>(:final BookInfo data):
      info = data;
      report.record(
        'bookInfo',
        // 逐字段打出来（都过 `_sample`）：G4 要为矩阵 #15–#19 每行给出「源名 + 字段 +
        // 产出样本」，而 `@@` / `@put:` / `@get:` / `java.*` 这些语法散落在各字段里
        // （b1b 的 `kind`、#17 的 `lastChapter`、#15 的 `intro` / `wordCount`），
        // 只打 name/author 的话这些行拿不到样本。
        _stage(1, <String>[
          '${data.name} | author=${data.author} | toc=${data.tocUrl}'
              ' | kind=${_sample(data.kind ?? '-')}'
              ' | lastChapter=${_sample(data.lastChapter ?? '-')}'
              ' | intro=${_sample(data.intro ?? '-')}'
              ' | wordCount=${_sample(data.wordCount ?? '-')}'
              ' | updateTime=${data.updateTime ?? '-'}',
        ]),
      );
    case ParseFailure<BookInfo>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.fail('bookInfo', kind, rulePath);
      return report;
  }

  final List<Chapter> chapters = <Chapter>[];
  switch (await FetchToc(pages: pages).execute(source, info.tocUrl)) {
    case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
      chapters.addAll(data);
      report.record(
        'toc',
        _stage(
          chapters.length,
          chapters.isEmpty
              ? const <String>[]
              : <String>[
                  '${chapters.first.name} ${chapters.first.url}'
                      ' updateTime=${chapters.first.updateTime ?? '-'}',
                ],
        ),
      );
    case ParseFailure<List<Chapter>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.fail('toc', kind, rulePath);
  }
  if (chapters.isEmpty) {
    return report;
  }

  switch (await FetchContent(
    pages: pages,
    cache: _noContentCache,
  ).execute(source, ChapterRequest(url: chapters.first.url))) {
    case ParseSuccess<String>(:final String data):
      report.record(
        'content',
        _stage(data.length, <String>['${_sample(data)} sha256=${_hash(data)}']),
      );
    case ParseFailure<String>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.fail('content', kind, rulePath);
  }

  return report;
}

/// Lists the sources of a collection that this repository can evaluate today.
///
/// The filter is the one the spot-check itself uses to pick a source: an M0 search
/// template on HTTPS, and no rule carrying a flag of a later phase. `@css:` is marked
/// so the run can prefer a source that exercises matrix #12 on real HTML.
void _listCandidates(File file) {
  final Object? decoded = jsonDecode(file.readAsStringSync());
  final List<Object?> entries = decoded is List ? decoded : <Object?>[decoded];
  var compatible = 0;
  var degraded = 0;
  var withJs = 0;
  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    if (!_isM0Compatible(item)) {
      continue;
    }
    compatible++;
    final String rules = jsonEncode(item);
    final bool needsDegradation = _needsUnknownTypeDegradation(item);
    final bool usesJs = _usesValueRuleJs(item);
    if (needsDegradation) {
      degraded++;
    }
    if (usesJs) {
      withJs++;
    }
    stdout.writeln(
      '${rules.contains('@css:') ? 'css ' : '    '}'
      '${needsDegradation ? 'degraded' : '        '}'
      '${usesJs ? '\tjs' : '\t  '}\t'
      '${item['bookSourceName']}\t${item['bookSourceUrl']}',
    );
  }
  stdout.writeln(
    '-- $compatible of ${entries.length} sources are M0-compatible.',
  );
  stdout.writeln(
    '-- $degraded of $compatible M0-compatible sources rely on the unknown-type '
    'degradation (ADR-0032).',
  );
  stdout.writeln(
    '-- $withJs of $compatible M0-compatible sources use a value-rule `@js:` '
    '(matrix #14); their scripts still have to stay inside `book-source.md` §6.',
  );
  _printConcurrentRateCensus(entries);
  _printM1GrammarCensus(entries);
  _printLiteralUrlCensus(entries);
  _printJsonItemResultCensus(entries);
  _printBookSourceIdentityCensus(entries);
}

/// The rule strings of [item], keyed by `section.field`.
///
/// The same sections the filter inspects, plus `ruleExplore`'s own fields: `exploreUrl` is a
/// URL field (a category list), not a rule, so it is not collected here.
Map<String, String> _ruleFieldsOf(Map<String, Object?> item) {
  final Map<String, String> rules = <String, String>{};
  void collect(String prefix, Object? value) {
    if (value is String) {
      rules[prefix] = value;
    } else if (value is Map<String, Object?>) {
      value.forEach(
        (String key, Object? nested) => collect('$prefix.$key', nested),
      );
    }
  }

  for (final String key in <String>[
    'ruleSearch',
    'ruleBookInfo',
    'ruleToc',
    'ruleContent',
    'ruleExplore',
  ]) {
    collect(key, item[key]);
  }
  return rules;
}

/// Prints how many sources use each M1 row, and how many of those are selectable today.
///
/// G4 (`docs/dev/roadmap.md` §4) has to name a real source per row, and the harness is the only place
/// statistics may come from (`docs/dev/test-environment.md` §6, trap 13: a throwaway script
/// once produced the unreproducible 58.1%). The patterns therefore live here and the command
/// is the `--list` run itself.
void _printM1GrammarCensus(List<Object?> entries) {
  // #19's `{$jsonpath}` template: a `{$` whose `{` is **not** the `{` of `{{…}}` (matrix
  // #18). A substring count would report every `{{$.x}}` as a legacy template as well.
  final RegExp legacyTemplate = RegExp(r'(?<!\{)\{\$');
  final RegExp putFlag = RegExp(r'@put:|@get:');
  final RegExp javaVariable = RegExp(r'java\.(put|get)\s*\(');
  // Upstream's *synchronous HTTP* spelling of the same name (ADR-0037 §决策 5 refuses it):
  // `java.get(url, {...})`. #17 may only be evidenced by the variable form, so the two are
  // counted apart.
  final RegExp javaHttpVerb = RegExp(r'java\.get\s*\([^)]*,\s*\{');

  final List<({String row, bool Function(String) uses})> rows =
      <({String row, bool Function(String) uses})>[
        (row: '#15 @@', uses: (String r) => r.contains('@@')),
        (row: '#16 @put:/@get:', uses: putFlag.hasMatch),
        (row: '#17 java.put/java.get', uses: javaVariable.hasMatch),
        (row: '#18 {{…}}', uses: (String r) => r.contains('{{')),
        (row: r'#19 {$…}', uses: legacyTemplate.hasMatch),
      ];

  final Map<String, int> total = <String, int>{
    for (final ({String row, bool Function(String) uses}) row in rows)
      row.row: 0,
  };
  final Map<String, int> selectable = <String, int>{
    for (final ({String row, bool Function(String) uses}) row in rows)
      row.row: 0,
  };
  var variableForm = 0;
  var httpOnlyForm = 0;

  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final Map<String, String> fields = _ruleFieldsOf(item);
    final bool compatible = _isM0Compatible(item);
    for (final ({String row, bool Function(String) uses}) row in rows) {
      if (!fields.values.any(row.uses)) {
        continue;
      }
      total.update(row.row, (int count) => count + 1);
      if (compatible) {
        selectable.update(row.row, (int count) => count + 1);
      }
    }

    final List<String> javaUses = fields.values
        .where(javaVariable.hasMatch)
        .toList();
    if (javaUses.isNotEmpty) {
      if (javaUses.any((String value) => !javaHttpVerb.hasMatch(value))) {
        variableForm++;
      } else {
        httpOnlyForm++;
      }
    }
  }

  stdout.writeln(
    '-- M1 grammar census (whole collection; G4 needs one source per row):',
  );
  for (final ({String row, bool Function(String) uses}) row in rows) {
    stdout.writeln(
      '    ${row.row}: ${total[row.row]} sources'
      ' (${selectable[row.row]} of them selectable today)',
    );
  }
  stdout.writeln(
    '    #17 form: $variableForm sources use the **variable** form (usable as evidence), '
    '$httpOnlyForm only the refused synchronous-HTTP one (ADR-0037 §决策 5).',
  );
}

/// Prints how many sources have a rule field whose **entire** value is a literal URL.
///
/// Registered in `docs/dev/roadmap.md` §3.7 as “gather evidence first, then schedule”: such a value has no
/// rule head, so it falls into the default type, ADR-0032 degrades it to a CSS selector and the
/// field fails (b5 bumped into it through a derived `bookUrl`). Only a census over the real
/// sources can say whether that is worth a fix, hence the count *and* the field distribution.
void _printLiteralUrlCensus(List<Object?> entries) {
  // A literal URL carries **no** rule syntax at all: braces (a `{{…}}` template), `@` (a flag)
  // or `#` (a `##` replacement) would make it a rule. `searchUrl` / `exploreUrl` are URL fields
  // by design and are not inspected here (see [_ruleFieldsOf]).
  final RegExp literalUrl = RegExp(r'^https?://[^\s{}@#]+$');
  final Map<String, int> byField = <String, int>{};
  var sources = 0;

  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final List<String> hits = <String>[
      for (final MapEntry<String, String> entry in _ruleFieldsOf(item).entries)
        if (literalUrl.hasMatch(entry.value.trim())) entry.key,
    ];
    if (hits.isEmpty) {
      continue;
    }
    sources++;
    for (final String field in hits) {
      byField.update(field, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  stdout.writeln(
    '-- rule fields that are an entirely literal URL (whole collection; PLAN §3.7): '
    '$sources sources.',
  );
  final List<MapEntry<String, int>> sorted = byField.entries.toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
  for (final MapEntry<String, int> entry in sorted) {
    stdout.writeln('    ${entry.key}: ${entry.value}');
  }
}

/// Prints how many sources script against a **JSON item** as `result` (b7's evidence step).
///
/// `book-source.md` §6 writes that a JSON scope hands a script the item's **JSON text**
/// (`_contentOf(JsonScope) = jsonEncode(value)`), while upstream `AnalyzeRule.evalJS(rule, result)`
/// binds the item **object** - so `result.comic_id` works upstream and is `undefined` here.
/// `docs/dev/roadmap.md` §3.5 b7 asks for the count and the field distribution **before** the contract is
/// touched, and this census is that evidence (`docs/dev/roadmap.md` §3.7); a throwaway script may not produce
/// the numbers (`docs/dev/test-environment.md` §6, trap 13).
///
/// Two shapes put a script on a JSON item: a **JSON list rule** (`bookList` / `chapterList`, whose
/// sibling fields are read once per item) and a **JSON `init`** (`ruleBookInfo.init` makes the later
/// detail fields read a sub-object, `docs/dev/roadmap.md` §3.5 b6). A whole JSON page is deliberately **not**
/// counted: there upstream's `result` is the response String, exactly as here (§6).
///
/// A script that reads the text correctly - `JSON.parse(result)` - is counted separately, because
/// it is *not* affected by the binding difference (upstream would break on it instead).
void _printJsonItemResultCensus(List<Object?> entries) {
  // 成员访问的两种写法：`result.member` 与 `result['member']`。`JSON.parse(result).x` 不会命中
  // （`result` 后面紧跟 `)`），因此两类计数天然互斥。
  final RegExp memberAccess = RegExp(
    r'''result\s*(?:\.\s*[A-Za-z_$][\w$]*|\[\s*['"][^'"]+['"]\s*\])''',
  );
  final RegExp jsonParseOfResult = RegExp(
    r'JSON\s*\.\s*parse\s*\(\s*result\s*\)',
  );
  final Map<String, int> byField = <String, int>{};
  final List<String> samples = <String>[];
  var sources = 0;
  var parsedInstead = 0;

  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final Map<String, String> fields = _ruleFieldsOf(item);
    final Set<String> itemFields = <String>{};
    // 列表规则的兄弟字段读的是**每一条**（上游 `getElements` 的 item），所以它们落在 JSON 条目上。
    const Map<String, String> listRules = <String, String>{
      'ruleSearch': 'bookList',
      'ruleExplore': 'bookList',
      'ruleToc': 'chapterList',
    };
    for (final MapEntry<String, String> section in listRules.entries) {
      if (!_isJsonRule(fields['${section.key}.${section.value}'])) {
        continue;
      }
      itemFields.addAll(
        fields.keys.where(
          (String key) =>
              key.startsWith('${section.key}.') &&
              key != '${section.key}.${section.value}',
        ),
      );
    }
    // b6 之后 `init` 也让详情字段落在 JSON 子对象上（上游 `setContent(getElement(init))`）。
    if (_isJsonRule(fields['ruleBookInfo.init'])) {
      itemFields.addAll(
        fields.keys.where(
          (String key) =>
              key.startsWith('ruleBookInfo.') && key != 'ruleBookInfo.init',
        ),
      );
    }

    final List<String> hits = <String>[];
    for (final String field in itemFields) {
      final String scripts = _jsSegmentsOf(fields[field] ?? '');
      if (jsonParseOfResult.hasMatch(scripts)) {
        parsedInstead++;
      }
      if (memberAccess.hasMatch(scripts)) {
        hits.add(field);
      }
    }
    if (hits.isEmpty) {
      continue;
    }
    sources++;
    for (final String field in hits) {
      byField.update(field, (int count) => count + 1, ifAbsent: () => 1);
    }
    if (samples.length < 3) {
      samples.add('${item['bookSourceName']} (${hits.join(', ')})');
    }
  }

  final int fieldCount = byField.values.fold(
    0,
    (int sum, int count) => sum + count,
  );
  stdout.writeln(
    '-- JSON items bound to a script as `result` (b7 evidence, whole collection; PLAN §3.5): '
    '$sources sources, $fieldCount fields.',
  );
  final List<MapEntry<String, int>> sorted = byField.entries.toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
  for (final MapEntry<String, int> entry in sorted) {
    stdout.writeln('    ${entry.key}: ${entry.value}');
  }
  if (samples.isNotEmpty) {
    stdout.writeln('    samples: ${samples.join(' | ')}');
  }
  stdout.writeln(
    '    $parsedInstead fields use `JSON.parse(result)` instead (they read the JSON text '
    'correctly, so they are not affected by the binding difference).',
  );
}

/// Whether [rule] is read as JSON by the engine (matrix #13, `book-source.md` §3.2).
///
/// The engine decides this from the rule text itself, so the census does the same instead of
/// guessing a page type: a bare `$.` / `$[` form or an explicit `@json:` flag is JSON.
bool _isJsonRule(String? rule) {
  final String text = (rule ?? '').trim();

  return text.contains(r'$.') ||
      text.contains(r'$[') ||
      text.toLowerCase().contains('@json:');
}

/// The JavaScript segments of [rule]: every `@js:` tail and every `{{…}}` body.
///
/// `@js:` is terminal (it swallows the rest of the rule, `book-source.md` §3 #14), so the tail is
/// the script; a `{{…}}` holds a script when its inner text is not a rule head (§3 #18). Both are
/// collected because both bind `result` to the current scope - the G4 case that opened b7 used
/// `@js:`, and `{{result.x}}` is the same family.
String _jsSegmentsOf(String rule) {
  final StringBuffer scripts = StringBuffer();
  for (final RegExpMatch match in RegExp(
    '@js:',
    caseSensitive: false,
  ).allMatches(rule)) {
    scripts.writeln(rule.substring(match.end));
  }
  for (final RegExpMatch match in RegExp(
    r'\{\{([^{}]*)\}\}',
  ).allMatches(rule)) {
    scripts.writeln(match.group(1));
  }

  return scripts.toString();
}

/// Prints the duplicate shape of [entries] - evidence for the import-identity ruling (P5-0).
///
/// `docs/dev/roadmap.md` §3.6 5.0 has to decide the `book_sources` primary key and what importing the same
/// source twice does. `bookSourceUrl` is upstream's natural id, but the real corpus also has
/// “same URL, different rules” instances, so the ruling needs the **shape** rather than an
/// assumption - and it comes from the harness (`docs/dev/test-environment.md` §6, trap 13).
///
/// Two entries count as the same when [bookSourceFingerprint] says so - i.e. when every field
/// that makes a source **behave** the same way is equal. The rule itself lives in `domain/`
/// (`lib/features/book_source/domain/book_source_fingerprint.dart`), so the census and the
/// repository cannot drift apart; this file only groups by URL and counts.
void _printBookSourceIdentityCensus(List<Object?> entries) {
  final Map<String, List<String>> byUrl = <String, List<String>>{};
  var total = 0;
  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    total++;
    byUrl
        .putIfAbsent('${item['bookSourceUrl']}', () => <String>[])
        .add(bookSourceFingerprint(item));
  }

  var repeated = 0;
  var identical = 0;
  var differing = 0;
  var most = 1;
  for (final List<String> fingerprints in byUrl.values) {
    if (fingerprints.length > most) {
      most = fingerprints.length;
    }
    if (fingerprints.length < 2) {
      continue;
    }
    repeated++;
    if (fingerprints.toSet().length == 1) {
      identical++;
    } else {
      differing++;
    }
  }

  stdout.writeln(
    '-- book source identity (whole collection; PLAN §3.6 5.0): $total entries, '
    '${byUrl.length} distinct bookSourceUrl.',
  );
  stdout.writeln(
    '    $repeated URLs appear more than once (max $most entries): $identical of them have '
    'every entry identical on the behaviour fields, $differing carry at least one that '
    'differs.',
  );
}

/// Prints the `concurrentRate` distribution of [entries] (`book-source.md` §8).
///
/// ADR-0036 §决策 8 makes this census part of the M1-b2 acceptance: the syntax is
/// **milliseconds** upstream, and if authors read `n/m` as “per second” the unit has to be
/// re-adjudicated with a new ADR — which needs this number rather than an opinion. The
/// classification uses the production parser (`parseConcurrentRate`), so what the tool counts
/// as illegal is exactly what the request layer refuses (ADR-0036 §决策 2).
///
/// The census covers **every** source of the collection, not only the M0-compatible ones: a
/// declaration is independent of how far the rule syntax is supported.
void _printConcurrentRateCensus(List<Object?> entries) {
  final Map<String, int> declared = <String, int>{};
  final List<int> intervals = <int>[];
  var noGate = 0;
  var limited = 0;
  var invalid = 0;

  for (final Object? item in entries) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final Object? value = item['concurrentRate'];
    if (value is! String || value.trim().isEmpty) {
      continue;
    }
    declared.update(value.trim(), (int count) => count + 1, ifAbsent: () => 1);

    final ConcurrentRateDeclaration parsed = parseConcurrentRate(value);
    if (parsed.isInvalid) {
      invalid++;
    } else if (parsed.rate case final ConcurrentRate rate) {
      limited++;
      intervals.add(rate.intervalMilliseconds);
    } else {
      noGate++;
    }
  }

  final List<MapEntry<String, int>> sorted = declared.entries.toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
  stdout.writeln(
    '-- concurrentRate: ${sorted.fold<int>(0, (int sum, MapEntry<String, int> entry) => sum + entry.value)} '
    'sources declare one ($limited limited, $noGate no gate, $invalid invalid).',
  );
  for (final MapEntry<String, int> entry in sorted.take(_maxRateLines)) {
    final ConcurrentRateDeclaration parsed = parseConcurrentRate(entry.key);
    stdout.writeln(
      '    ${entry.value}\t${entry.key}\t'
      '${parsed.isInvalid
          ? 'invalid'
          : parsed.isLimited
          ? 'limited'
          : 'no gate'}',
    );
  }
  if (sorted.length > _maxRateLines) {
    stdout.writeln(
      '    … ${sorted.length - _maxRateLines} more distinct values',
    );
  }
  if (intervals.isNotEmpty) {
    intervals.sort();
    stdout.writeln(
      '    intervals(ms): min=${intervals.first} '
      'median=${intervals[intervals.length ~/ 2]} max=${intervals.last}',
    );
  }
}

/// How many distinct `concurrentRate` values the census prints.
const int _maxRateLines = 20;

/// Whether [item] carries `@js:` in a field this repository can evaluate (matrix #14).
bool _usesValueRuleJs(Map<String, Object?> item) {
  final Map<String, String> rules = <String, String>{};
  void collect(String prefix, Object? value) {
    if (value is String) {
      rules[prefix] = value;
    } else if (value is Map<String, Object?>) {
      value.forEach(
        (String key, Object? nested) => collect('$prefix.$key', nested),
      );
    }
  }

  for (final String key in <String>[
    'ruleSearch',
    'ruleBookInfo',
    'ruleToc',
    'ruleContent',
  ]) {
    collect(key, item[key]);
  }

  return rules.entries.any(
    (MapEntry<String, String> rule) =>
        rule.value.toLowerCase().contains(_jsFlag),
  );
}

/// The selector types this repository implements (`book-source.md` §3, matrix #2..#4).
const List<String> _implementedTypes = <String>[
  'class',
  'id',
  'tag',
  'text',
  'children',
];

/// Whether [item] needs ADR-0032's unknown-type degradation for its chain rules.
///
/// List rules (`bookList` / `chapterList`) treat every `@`-segment as a selector, value
/// rules treat all but the last one that way (the last is the extraction), and `||`
/// branches are inspected separately — the same check the engine performs. This is what
/// makes the figure behind ADR-0032 reproducible rather than trusted (the number itself
/// lives in that ADR and in `book-source.md` §3; it was recomputed here after the first
/// one turned out to come from a throwaway script).
bool _needsUnknownTypeDegradation(Map<String, Object?> item) {
  final List<({String rule, bool isList})> rules =
      <({String rule, bool isList})>[
        (rule: _ruleText(item, 'ruleSearch', 'bookList'), isList: true),
        (rule: _ruleText(item, 'ruleToc', 'chapterList'), isList: true),
        (rule: _ruleText(item, 'ruleSearch', 'bookUrl'), isList: false),
        (rule: _ruleText(item, 'ruleToc', 'chapterUrl'), isList: false),
        (rule: _ruleText(item, 'ruleContent', 'content'), isList: false),
      ];

  for (final ({String rule, bool isList}) entry in rules) {
    for (final String branch in entry.rule.split('||')) {
      final List<String> segments = branch
          .split('@')
          .map((String segment) => segment.trim())
          .toList();
      final List<String> selectors = entry.isList
          ? segments
          : segments.sublist(0, segments.length - 1);
      for (final String selector in selectors) {
        if (selector.isEmpty || _isKnownSelector(selector)) {
          continue;
        }

        return true;
      }
    }
  }

  return false;
}

/// Reads one rule string out of a nested section of a book source JSON.
String _ruleText(Map<String, Object?> item, String section, String key) {
  final Map<String, Object?> rules =
      item[section] as Map<String, Object?>? ?? const <String, Object?>{};

  return '${rules[key] ?? ''}';
}

/// Whether [selector] is one the engine handles without ADR-0032's degradation.
bool _isKnownSelector(String selector) {
  final String lower = selector.toLowerCase();
  if (lower.startsWith('@css:') ||
      lower.startsWith('@json:') ||
      selector.startsWith(r'$.') ||
      selector.startsWith(r'$[')) {
    return true;
  }

  return _implementedTypes.contains(selector.split('.').first);
}

/// Whether [item] uses only what this repository implements today.
bool _isM0Compatible(Map<String, Object?> item) {
  final Map<String, String> rules = <String, String>{};
  void collect(String prefix, Object? value) {
    if (value is String) {
      rules[prefix] = value;
    } else if (value is Map<String, Object?>) {
      value.forEach(
        (String key, Object? nested) => collect('$prefix.$key', nested),
      );
    }
  }

  for (final String key in <String>[
    'searchUrl',
    'ruleSearch',
    'ruleBookInfo',
    'ruleToc',
    'ruleContent',
  ]) {
    collect(key, item[key]);
  }

  final String search = rules['searchUrl'] ?? '';
  // 搜索模板必须能渲染，且不能是 `{"method":"POST"}` 那种表单搜索：本仓只发 GET（C-NET-1）。
  final String literal = search
      .replaceAll('{{key}}', '')
      .replaceAll('{{page}}', '')
      .replaceAll('{{baseUrl}}', '');
  if (!search.contains('{{key}}') ||
      !search.startsWith('https://') ||
      literal.contains('{')) {
    return false;
  }
  for (final String required in <String>[
    'ruleSearch.bookList',
    'ruleToc.chapterList',
    'ruleContent.content',
  ]) {
    if ((rules[required] ?? '').isEmpty) {
      return false;
    }
  }

  for (final MapEntry<String, String> rule in rules.entries) {
    final String lower = rule.value.toLowerCase();
    for (final String flag in _deferredFlags) {
      if (lower.contains(flag)) {
        return false;
      }
    }
    if (lower.contains(_jsFlag) && _jsUnsupportedFields.contains(rule.key)) {
      return false;
    }
    if (_hasMisplacedDefaultFlag(rule.value)) {
      return false;
    }
    // `{{…}}`（矩阵 #18）已在 3.4 落地，不能再按「`{` 开头 = 表单 / 选项对象」排除——
    // 只认**单**花括号开头（`{"method":"POST"}` 那类对象）与 `:正则` 头部；
    // searchUrl 里的裸 `{` 仍由上面的模板检查保守地挡掉（宁可少收）。
    final String trimmed = rule.value.trimLeft();
    if (trimmed.startsWith(':') ||
        (trimmed.startsWith('{') && !trimmed.startsWith('{{'))) {
      return false;
    }
  }

  return true;
}

/// One stage's outcome for the report.
({int count, List<String> samples}) _stage(int count, List<String> samples) =>
    (count: count, samples: samples);

/// A short, single-line sample of [value]. The full value never leaves the process.
String _sample(String value) {
  final String flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();

  return flat.length <= _sampleLength
      ? flat
      : '${flat.substring(0, _sampleLength)}…';
}

/// The first 16 hex characters of `value`'s SHA-256, for comparing two runs.
String _hash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 16);

/// Parses `--key=value` options.
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

/// The evidence one spot-check run produces.
final class _Report {
  _Report({required this.source, required this.keyword});

  /// The book source that was checked.
  final BookSource source;

  /// The keyword the search template was rendered with.
  final String keyword;

  /// Wall-clock time the whole chain took, in milliseconds.
  ///
  /// It is recorded because `concurrentRate` (`book-source.md` §8) is only observable as
  /// **time**: with a rate declared, `n` requests cannot all happen inside one window, so the
  /// run's duration is the regression's evidence (see the README's M1-b2 record).
  int elapsedMilliseconds = 0;

  final Map<String, ({int count, List<String> samples})> _stages =
      <String, ({int count, List<String> samples})>{};
  final Map<String, ({ParseFailureKind kind, String rulePath})> _failures =
      <String, ({ParseFailureKind kind, String rulePath})>{};

  /// Records a stage that produced values.
  void record(String stage, ({int count, List<String> samples}) outcome) =>
      _stages[stage] = outcome;

  /// Records a stage that stopped the chain.
  void fail(String stage, ParseFailureKind kind, String rulePath) =>
      _failures[stage] = (kind: kind, rulePath: rulePath);

  /// Whether every stage of the chain produced values.
  bool get isComplete =>
      _failures.isEmpty &&
      const <String>[
        'search',
        'bookInfo',
        'toc',
        'content',
      ].every((String stage) => (_stages[stage]?.count ?? 0) > 0);

  /// The report as a JSON object, for the `book-source.md` §10 record.
  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.name,
    'sourceUrl': source.url,
    'keyword': keyword,
    'headers': source.headers,
    'complete': isComplete,
    'elapsedMs': elapsedMilliseconds,
    'stages': <String, Object?>{
      for (final MapEntry<String, ({int count, List<String> samples})> entry
          in _stages.entries)
        entry.key: <String, Object?>{
          'count': entry.value.count,
          'samples': entry.value.samples,
        },
    },
    'failures': <String, Object?>{
      for (final MapEntry<String, ({ParseFailureKind kind, String rulePath})>
          entry
          in _failures.entries)
        entry.key: <String, Object?>{
          'kind': entry.value.kind.name,
          'rulePath': entry.value.rulePath,
        },
    },
  };

  /// Prints the report as a table.
  void print() {
    stdout.writeln('source : ${source.name} (${source.url})');
    stdout.writeln('keyword: $keyword');
    stdout.writeln('headers: ${source.headers ?? 'none'}');
    // 限速声明也打出来：`concurrentRate` 会进请求层预算（§8、ADR-0036），所以一次真实源
    // 回归记录要说清楚这条链路是在哪份声明下跑完的。
    stdout.writeln(
      'rate   : ${source.concurrentRate?.trim().isNotEmpty ?? false ? source.concurrentRate : 'none declared'}',
    );
    for (final String stage in const <String>[
      'search',
      'bookInfo',
      'toc',
      'content',
    ]) {
      final ({int count, List<String> samples})? ok = _stages[stage];
      final ({ParseFailureKind kind, String rulePath})? failure =
          _failures[stage];
      if (failure != null) {
        stdout.writeln(
          '${stage.padRight(8)} FAILED  ${failure.kind.name} at ${failure.rulePath}',
        );
        continue;
      }
      if (ok == null) {
        stdout.writeln(
          '${stage.padRight(8)} skipped (an earlier stage stopped)',
        );
        continue;
      }
      stdout.writeln(
        '${stage.padRight(8)} ok      count=${ok.count} ${ok.samples.join(' | ')}',
      );
    }
    stdout.writeln(
      'elapsed: ${(elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );
    stdout.writeln(isComplete ? 'RESULT  : complete' : 'RESULT  : incomplete');
  }
}
