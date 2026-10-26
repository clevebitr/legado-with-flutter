// Batch probe: run a **whole** book source collection through the production chain against the
// live sites, and print a histogram of what failed where.
//
// Why this exists next to `spot_check.dart`: the single-source harness answers "does this one
// source still work", which is what G2b / G4 needed. M12 (`docs/dev/roadmap.md` §3.7 A/B) needs the
// opposite question — "which rule construct breaks the most sources" — and answering it by hand
// costs 128 manual runs per iteration. This entry point runs every source of a collection, records
// the `ParseFailureKind` + `rulePath` of the stage that stopped it, and aggregates the result.
//
// It is a `tool/` entry point, **not** a test: `docs/dev/testing.md` §1 forbids the network in
// tests. Like `spot_check.dart` it needs the real JS engine (`flutter_qjs_next` native library), so
// it must run under `flutter run -d <device> -t tool/spot_check/batch_probe.dart`.
//
// Usage (options travel through `SPOT_CHECK_ARGS`, see `spot_check.dart`):
//
//   SPOT_CHECK_ARGS="--source=<collection.json> --keyword=剑来 --out=build/probe.json" \
//     flutter run -d windows -t tool/spot_check/batch_probe.dart
//
// Report shape: one line per source (name, per-stage outcome), then histograms of
// `stage/kind/rulePath`. Bodies are never written: a stage records a length and a hash.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/js/quickjs_worker.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/features/book_source/domain/content_cache.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_content.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_book_info.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_content.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_toc.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/search_books.dart';

/// How much of a produced value the report keeps.
const int _sampleLength = 60;

const ContentCache _noContentCache = _NoContentCache();

/// A [ContentCache] that never stores anything (the probe must always hit the network).
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
    String? bookUrl,
  }) async {}

  @override
  Future<int> countForBook({
    required String sourceId,
    required String bookUrl,
  }) async => 0;

  @override
  Future<int> clearForBook({
    required String sourceId,
    required String bookUrl,
  }) async => 0;

  @override
  Future<int> countForSource(String sourceId) async => 0;

  @override
  Future<int> clearForSource(String sourceId) async => 0;

  @override
  Future<int> countAll() async => 0;

  @override
  Future<int> clearExpired() async => 0;

  @override
  Future<void> clearAll() async {}
}

/// One stage of one source.
final class _StageOutcome {
  _StageOutcome({
    required this.stage,
    required this.ok,
    this.kind,
    this.rulePath,
    this.count = 0,
    this.sample = '',
    this.hash = '',
    this.elapsedMs = 0,
  });

  final String stage;
  final bool ok;
  final String? kind;
  final String? rulePath;
  final int count;
  final String sample;
  final String hash;
  final int elapsedMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'stage': stage,
    'ok': ok,
    if (kind != null) 'kind': kind,
    if (rulePath != null) 'rulePath': rulePath,
    if (ok) 'count': count,
    if (sample.isNotEmpty) 'sample': sample,
    if (hash.isNotEmpty) 'sha256': hash,
    'elapsedMs': elapsedMs,
  };
}

/// Everything one source produced.
final class _SourceReport {
  _SourceReport(this.name, this.url);

  final String name;
  final String url;
  final List<_StageOutcome> stages = <_StageOutcome>[];
  String? importError;

  bool get isComplete =>
      stages.length == 4 && stages.every((_StageOutcome s) => s.ok);

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'url': url,
    if (importError != null) 'importError': importError,
    'complete': isComplete,
    'stages': <Map<String, Object?>>[
      for (final _StageOutcome stage in stages) stage.toJson(),
    ],
  };
}

Future<void> main(List<String> arguments) async {
  final Map<String, String> options = _parseOptions(_argumentsOf(arguments));
  final String? path = options['source'];
  if (path == null) {
    stderr.writeln(
      'usage: flutter run -d <device> -t tool/spot_check/batch_probe.dart '
      '-- --source=<collection.json> [--keyword=剑来] [--out=build/probe.json] '
      '[--limit=10] [--concurrency=4] [--plain-http]',
    );
    exit(2);
  }

  final String keyword = options['keyword'] ?? '剑来';
  final int limit = int.tryParse(options['limit'] ?? '') ?? 1 << 30;
  final int concurrency = int.tryParse(options['concurrency'] ?? '') ?? 4;
  final bool allowPlainHttp = options.containsKey('plain-http');

  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  final List<Object?> entries = decoded is List ? decoded : <Object?>[decoded];
  final List<Map<String, Object?>> selected = entries
      .whereType<Map<String, Object?>>()
      .take(limit)
      .toList();

  final AppLogger logger = AppLogger(level: LogLevel.error);
  // 请求层是唯一的上网入口（C-NET-1），探测与生产走同一个实现。
  final DioHttpClient http = DioHttpClient(
    cookies: InMemoryCookieManager(),
    logger: logger,
    policy: HttpPolicy(allowPlainHttp: allowPlainHttp),
  );
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

  final List<_SourceReport> reports = <_SourceReport>[];
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final int index = next++;
      if (index >= selected.length) {
        return;
      }
      final Map<String, Object?> entry = selected[index];
      final String name = '${entry['bookSourceName'] ?? '?'}';
      final String url = '${entry['bookSourceUrl'] ?? '?'}';
      final _SourceReport report = _SourceReport(name, url);
      final BookSource source;
      try {
        source = BookSource.fromLegadoJson(entry);
      } on Object catch (error) {
        report.importError = '$error';
        reports.add(report);
        stdout.writeln('[import] $name  $error');
        continue;
      }
      try {
        await _runChain(
          pages: pages,
          source: source,
          keyword: keyword,
          report: report,
        );
      } on Object catch (error) {
        // 一个源把异常抛到批外时，探测本身要继续：这正是生产链路必须修的行为。
        report.stages.add(
          _StageOutcome(stage: 'threw', ok: false, kind: '$error'),
        );
      }
      reports.add(report);
      stdout.writeln(_line(report));
    }
  }

  await Future.wait(<Future<void>>[
    for (var index = 0; index < concurrency; index++) worker(),
  ]);

  final Map<String, Object?> summary = _summary(reports);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
  final String? out = options['out'];
  if (out != null) {
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'keyword': keyword,
          'summary': summary,
          'sources': <Map<String, Object?>>[
            for (final _SourceReport report in reports) report.toJson(),
          ],
        }),
      );
    stdout.writeln('-- report written to $out');
  }
  exit(0);
}

/// Runs the four stages of `docs/dev/roadmap.md` §4 for one source.
Future<void> _runChain({
  required PageFetchService pages,
  required BookSource source,
  required String keyword,
  required _SourceReport report,
}) async {
  final Stopwatch searchWatch = Stopwatch()..start();
  final ParseResult<List<Book>> search = await SearchBooks(pages: pages)
      .execute(source, keyword);
  searchWatch.stop();
  final List<Book> books;
  switch (search) {
    case ParseSuccess<List<Book>>(:final List<Book> data):
      if (data.isEmpty) {
        report.stages.add(
          _StageOutcome(
            stage: 'search',
            ok: false,
            kind: 'empty',
            rulePath: 'searchRule.bookList',
            elapsedMs: searchWatch.elapsedMilliseconds,
          ),
        );

        return;
      }
      books = data;
      report.stages.add(
        _StageOutcome(
          stage: 'search',
          ok: true,
          count: books.length,
          sample: '${books.first.name} | ${books.first.author}',
          elapsedMs: searchWatch.elapsedMilliseconds,
        ),
      );
    case ParseFailure<List<Book>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.stages.add(
        _StageOutcome(
          stage: 'search',
          ok: false,
          kind: kind.name,
          rulePath: rulePath,
          elapsedMs: searchWatch.elapsedMilliseconds,
        ),
      );

      return;
  }

  final Book first = books.first;
  final Stopwatch infoWatch = Stopwatch()..start();
  final ParseResult<BookInfo> info = await FetchBookInfo(pages: pages)
      .execute(source, first.url);
  infoWatch.stop();
  final String tocUrl;
  switch (info) {
    case ParseSuccess<BookInfo>(:final BookInfo data):
      tocUrl = data.tocUrl;
      report.stages.add(
        _StageOutcome(
          stage: 'bookInfo',
          ok: true,
          count: 1,
          sample: '${data.name} | ${data.author} | toc=$tocUrl',
          elapsedMs: infoWatch.elapsedMilliseconds,
        ),
      );
    case ParseFailure<BookInfo>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.stages.add(
        _StageOutcome(
          stage: 'bookInfo',
          ok: false,
          kind: kind.name,
          rulePath: rulePath,
          elapsedMs: infoWatch.elapsedMilliseconds,
        ),
      );

      return;
  }

  final Stopwatch tocWatch = Stopwatch()..start();
  final ParseResult<List<Chapter>> toc = await FetchToc(pages: pages)
      .execute(source, tocUrl);
  tocWatch.stop();
  final List<Chapter> chapters;
  switch (toc) {
    case ParseSuccess<List<Chapter>>(:final List<Chapter> data):
      if (data.isEmpty) {
        report.stages.add(
          _StageOutcome(
            stage: 'toc',
            ok: false,
            kind: 'empty',
            rulePath: 'tocRule.chapterList',
            elapsedMs: tocWatch.elapsedMilliseconds,
          ),
        );

        return;
      }
      chapters = data;
      report.stages.add(
        _StageOutcome(
          stage: 'toc',
          ok: true,
          count: chapters.length,
          sample: chapters.first.name,
          elapsedMs: tocWatch.elapsedMilliseconds,
        ),
      );
    case ParseFailure<List<Chapter>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ):
      report.stages.add(
        _StageOutcome(
          stage: 'toc',
          ok: false,
          kind: kind.name,
          rulePath: rulePath,
          elapsedMs: tocWatch.elapsedMilliseconds,
        ),
      );

      return;
  }

  final Stopwatch contentWatch = Stopwatch()..start();
  final ParseResult<ChapterContent> content = await FetchContent(
    pages: pages,
    cache: _noContentCache,
  ).execute(source, ChapterRequest(url: chapters.first.url));
  contentWatch.stop();
  report.stages.add(switch (content) {
    ParseSuccess<ChapterContent>(:final ChapterContent data) => _StageOutcome(
      stage: 'content',
      ok: true,
      count: data.body.length,
      sample: _sample(data.body),
      hash: _hash(data.body),
      elapsedMs: contentWatch.elapsedMilliseconds,
    ),
    ParseFailure<ChapterContent>(
      :final ParseFailureKind kind,
      :final String rulePath,
    ) =>
      _StageOutcome(
        stage: 'content',
        ok: false,
        kind: kind.name,
        rulePath: rulePath,
        elapsedMs: contentWatch.elapsedMilliseconds,
      ),
  });
}

/// Counts where each stage stopped, grouped by `kind` and by `rulePath`.
Map<String, Object?> _summary(List<_SourceReport> reports) {
  final Map<String, int> byStage = <String, int>{};
  final Map<String, int> byReason = <String, int>{};
  final Map<String, int> byRulePath = <String, int>{};
  var complete = 0;
  var importErrors = 0;
  for (final _SourceReport report in reports) {
    if (report.importError != null) {
      importErrors++;
      continue;
    }
    if (report.isComplete) {
      complete++;
    }
    for (final _StageOutcome stage in report.stages) {
      if (stage.ok) {
        byStage['${stage.stage}:ok'] = (byStage['${stage.stage}:ok'] ?? 0) + 1;
      } else {
        byStage['${stage.stage}:fail'] =
            (byStage['${stage.stage}:fail'] ?? 0) + 1;
        final String reason = '${stage.stage}/${stage.kind}';
        byReason[reason] = (byReason[reason] ?? 0) + 1;
        final String path = '${stage.stage}/${stage.rulePath}';
        byRulePath[path] = (byRulePath[path] ?? 0) + 1;
      }
      // 搜索阶段是最前面的门：只有它还活着，后面三段的失败才有分布意义。
      if (stage.stage == 'search' && !stage.ok) {
        break;
      }
    }
  }
  Map<String, int> sorted(Map<String, int> map) {
    final List<MapEntry<String, int>> entries = map.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    return <String, int>{
      for (final MapEntry<String, int> e in entries) e.key: e.value,
    };
  }

  return <String, Object?>{
    'sources': reports.length,
    'importErrors': importErrors,
    'complete': complete,
    'byStage': sorted(byStage),
    'byReason': sorted(byReason),
    'byRulePath': sorted(byRulePath),
  };
}

String _line(_SourceReport report) {
  final String stages = report.stages
      .map(
        (_StageOutcome s) =>
            s.ok ? '${s.stage}=${s.count}' : '${s.stage}!${s.kind}',
      )
      .join(' ');
  final String tail = report.stages
      .where((_StageOutcome s) => !s.ok)
      .map((_StageOutcome s) => s.rulePath ?? '')
      .join(' ');
  return '[${report.isComplete ? 'ok' : '--'}] ${report.name}  $stages'
      '${tail.isEmpty ? '' : '  @$tail'}';
}

String _sample(String value) {
  final String flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= _sampleLength
      ? flat
      : '${flat.substring(0, _sampleLength)}…';
}

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

/// Reads the options from [arguments], or from `SPOT_CHECK_ARGS` when the host does
/// not forward them (`flutter run` swallows `--`-prefixed arguments).
List<String> _argumentsOf(List<String> arguments) => arguments.isNotEmpty
    ? arguments
    : (Platform.environment['SPOT_CHECK_ARGS'] ?? '')
          .split(' ')
          .where((String part) => part.isNotEmpty)
          .toList();

/// Parses `--name=value` / `--flag` options.
Map<String, String> _parseOptions(List<String> arguments) {
  final Map<String, String> options = <String, String>{};
  for (final String argument in arguments) {
    if (!argument.startsWith('--')) {
      continue;
    }
    final int equals = argument.indexOf('=');
    if (equals < 0) {
      options[argument.substring(2)] = '';

      continue;
    }
    options[argument.substring(2, equals)] = argument.substring(equals + 1);
  }

  return options;
}
