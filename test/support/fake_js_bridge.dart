import 'dart:collection';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';

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

  /// How many times [dispose] was called.
  int disposeCount = 0;

  /// The bridge's answer for the job it is evaluating now.
  @override
  Future<ParseResult<Object?>> evaluate(JsJob job) async {
    jobs.add(job);
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

  @override
  Future<void> dispose() async => disposeCount++;
}
