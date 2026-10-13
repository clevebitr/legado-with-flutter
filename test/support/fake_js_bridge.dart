import 'dart:collection';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_variables.dart';

/// Hand-written [JsBridge] double: records the jobs it is asked to run and answers with
/// queued results (`docs/dev/testing.md` §4).
///
/// Every `@js:` unit test goes through this instead of the native engine — the real worker
/// is only exercised by `integration_test/js_bridge_test.dart`, which is exactly the split
/// `testing.md` §4 asks for.
final class FakeJsBridge implements JsBridge {
  /// The jobs the engine submitted, in order.
  final List<JsJob> jobs = <JsJob>[];

  /// The result every job answers with, when [results] is empty.
  Object? result;

  /// Per-job results, consumed in call order and taking precedence over [result].
  final Queue<Object?> results = Queue<Object?>();

  /// When set, every job fails with this failure instead of answering.
  ParseFailure<Never>? failure;

  /// `parse.*` requests to run through the job's evaluator before the job answers.  ///
  /// A real worker calls [JsJob.parseEvaluator] when the script awaits `parse.*`
  /// (`book-source.md` §6); this double calls it once per request here, so an engine test can
  /// exercise the nested evaluation — including its boundaries — without a native engine. The
  /// **last** result decides the job's answer, which is how a `parse.*` failure becomes visible
  /// to the caller that asked for the rule.
  final List<JsParseRequest> parseRequests = <JsParseRequest>[];

  /// How many times [dispose] was called.
  int disposeCount = 0;

  /// The variables the script is pretended to have written through `java.put` (`§6`,
  /// matrix #17), merged into [variables] for the job's source.
  ///
  /// The real bridge merges them out of the worker's result envelope (ADR-0034 §决策 1);
  /// a double has no worker, so a test states them here. A `null` value clears the
  /// variable, exactly like the real report.
  final Map<String, String?> javaPuts = <String, String?>{};

  /// The store [javaPuts] is merged into, when a test wires one.
  JsVariableStore? variables;

  /// The bridge's answer for the job it is evaluating now.
  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) async {
    jobs.add(job);
    final JsVariableStore? store = variables;
    if (store != null && javaPuts.isNotEmpty) {
      store.merge(job.source.url, javaPuts);
    }
    if (parseRequests.isNotEmpty) {
      return _runParseRequests(job);
    }
    final ParseFailure<Never>? failed = failure;
    if (failed != null) {
      return ParseFailure<Object?>(
        kind: failed.kind,
        rulePath: failed.rulePath,
      );
    }

    return ParseSuccess<Object?>(
      results.isEmpty ? result : results.removeFirst(),
    );
  }

  /// Runs the queued `parse.*` requests against [job]'s evaluator.
  Future<ParseResult<Object?>> _runParseRequests(JsJob job) async {
    final JsParseEvaluator? evaluator = job.parseEvaluator;
    if (evaluator == null) {
      // 引擎确实没给 evaluator 时，worker 的边界就是这一条（§6 的 js:parse-scope）。
      return ParseFailure<Object?>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '${job.rulePath}:$jsParseScopeMarker',
      );
    }

    ParseResult<Object?> parsed = const ParseSuccess<Object?>(null);
    for (final JsParseRequest request in parseRequests) {
      parsed = await evaluator(request);
      if (parsed is ParseFailure<Object?>) {
        break;
      }
    }

    return parsed;
  }

  @override
  Future<void> dispose() async => disposeCount++;
}
