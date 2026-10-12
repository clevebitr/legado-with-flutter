// G2b spot-check: run one **real** book source through the production chain against
// the live site it points at, and print what each stage produced.
//
// Why this exists: `PLAN.md` §3.4 step 3 asks for a manual live run **before** the JS
// bridge is built, so the selectors this repository implements (`book-source.md` §3
// matrix, in particular #12 `@css:`) are checked against real HTML rather than only
// against the offline corpus. `docs/dev/testing.md` §1 forbids the network in tests,
// so this is a `tool/` entry point, not a test: it is never discovered by
// `flutter test` and never runs in CI.
//
// Usage (from the repository root):
//
//   dart run tool/spot_check/spot_check.dart --source=<file.json> --keyword=剑来
//   dart run tool/spot_check/spot_check.dart --list=<collection.json>
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
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
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
const List<String> _deferredFlags = <String>[
  '@js:',
  '@xpath:',
  '@put:',
  '@get:',
  'webjs',
  'sourceregex',
  '@@',
  '<js>',
];

Future<void> main(List<String> arguments) async {
  final Map<String, String> options = _parseOptions(arguments);
  final String? collection = options['list'];
  if (collection != null) {
    _listCandidates(File(collection));
    return;
  }

  final String? sourcePath = options['source'];
  if (sourcePath == null) {
    stderr.writeln(
      'usage: dart run tool/spot_check/spot_check.dart '
      '--source=<file.json> [--keyword=剑来] [--name=<substring>] [--json]\n'
      '       dart run tool/spot_check/spot_check.dart --list=<collection.json>',
    );
    exitCode = 2;
    return;
  }

  final BookSource source = _loadSource(
    File(sourcePath),
    name: options['name'],
  );
  final String keyword = options['keyword'] ?? '剑来';
  final _Report report = await _runChain(source, keyword);

  if (options.containsKey('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    report.print();
  }
  exitCode = report.isComplete ? 0 : 1;
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

/// Runs the four stages of `PLAN.md` §4 against the live site of [source].
Future<_Report> _runChain(BookSource source, String keyword) async {
  final AppLogger logger = AppLogger(level: LogLevel.warning);
  final PageFetchService pages = PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: QuickJsWorkerBridge(
        logger: logger,
        launch: launchQuickJsWorker,
      ),
    ),
    http: DioHttpClient(
      cookies: InMemoryCookieManager(),
      logger: logger,
      policy: const HttpPolicy(),
    ),
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
              : <String>['${books.first.name} ${books.first.url}'],
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
        _stage(1, <String>[
          '${data.name} | author=${data.author} | toc=${data.tocUrl}',
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
              : <String>['${chapters.first.name} ${chapters.first.url}'],
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

  switch (await FetchContent(pages: pages)
      .execute(source, chapters.first.url)) {
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
    if (needsDegradation) {
      degraded++;
    }
    stdout.writeln(
      '${rules.contains('@css:') ? 'css ' : '    '}'
      '${needsDegradation ? 'degraded' : '        '}\t'
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
    final String trimmed = rule.value.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith(':')) {
      return false;
    }
    // `{{…}}` 内嵌规则是 M1（矩阵 #18），而搜索 URL 的 `{{key}}` / `{{page}}` 是 M0。
    if (rule.key != 'searchUrl' && rule.value.contains('{{')) {
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
    stdout.writeln(isComplete ? 'RESULT  : complete' : 'RESULT  : incomplete');
  }
}
