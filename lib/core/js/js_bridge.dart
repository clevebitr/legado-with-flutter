import 'package:flutter_reader/core/error/parse_result.dart';

/// The three book source fields the sandbox may see (`docs/dev/book-source.md` §6).
///
/// The whitelist exposes `name`, `url` and `group` only: everything else about a
/// source stays on the host side, so a rule cannot read — or leak — more than the
/// binding table allows (C-SRC-3).
final class JsSourceInfo {
  /// Creates the sandbox view of a book source.
  const JsSourceInfo({required this.name, required this.url, this.group});

  /// The source's display name (`bookSourceName`).
  final String name;

  /// The source's URL (`bookSourceUrl`), which is also its id.
  final String url;

  /// The source's group (`bookSourceGroup`), when it declares one.
  final String? group;

  /// The JSON object the sandbox receives as `source`.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'url': url,
    'group': group,
  };
}

/// One `@js:` evaluation: the rule script plus the variables §6 exposes to it.
final class JsJob {
  /// Creates a job.
  const JsJob({
    required this.script,
    required this.rulePath,
    required this.baseUrl,
    required this.page,
    required this.source,
    this.result,
  });

  /// The JavaScript the rule asked for, with the `@js:` flag already removed.
  final String script;

  /// The book source field this rule belongs to, e.g. `searchRule.name`.
  ///
  /// It travels into failures and into everything `log.*` writes, so a JS problem
  /// stays locatable (C-SRC-8, §6).
  final String rulePath;

  /// The page the rule was read on (the `baseUrl` binding).
  final String baseUrl;

  /// The 1-based page number (the `page` binding).
  final int page;

  /// The sandbox view of the book source (the `source` binding).
  final JsSourceInfo source;

  /// The value the rule produced so far (the `result` binding), when there is one.
  final Object? result;

  /// The JSON envelope the worker receives.
  Map<String, Object?> toJson() => <String, Object?>{
    'script': script,
    'rulePath': rulePath,
    'baseUrl': baseUrl,
    'page': page,
    'source': source.toJson(),
    'result': result,
  };
}

/// Runs `@js:` rules in a sandbox the UI isolate never blocks on (C-SRC-2, C-SRC-3).
///
/// The contract is deliberately small: one asynchronous evaluation method and a
/// release hook. It carries **no capacity parameters** — the engine count, the queue
/// and the timeouts belong to the implementation (ADR-0030 §决策 2), so a later
/// change of engine strategy never reaches a caller.
abstract interface class JsBridge {
  /// Evaluates [job] and returns its result as a JSON value.
  ///
  /// A timeout and a JS exception both come back as
  /// [ParseFailureKind.parseFailed], with `rulePath` marked `js:timeout` or
  /// `js:error` (`book-source.md` §6); nothing throws at the caller (C-ERR-1).
  ///
  /// Concurrent calls are safe (C-SRC-9): they queue in call order behind the single
  /// worker and never fail with “busy”.
  Future<ParseResult<Object?>> evaluate(JsJob job);

  /// Releases the worker. Safe to call more than once (ADR-0030 §决策 6).
  Future<void> dispose();
}

/// One running JS worker: a message channel plus a kill switch.
///
/// This is the seam between [JsBridge]'s queueing policy and the isolate that owns
/// the engine. Keeping it abstract is what makes the queue, the timeout accounting
/// and the kill/rebuild policy unit-testable without the native library, while the
/// hard `Isolate.kill` budget of C-SRC-2 stays in the bridge rather than in the
/// worker.
abstract interface class JsWorkerHandle {
  /// Envelopes the worker sends back: one result per job, plus `log.*` records.
  Stream<Map<String, Object?>> get messages;

  /// Sends one envelope to the worker.
  void send(Map<String, Object?> message);

  /// Stops the worker immediately (`Isolate.kill`, C-SRC-2).
  ///
  /// Called only when the engine failed to interrupt a runaway script itself.
  void kill();
}

/// Starts one worker on demand, with the budgets the bridge will hold it to.
///
/// Passing the budgets in keeps the runtime's interrupt and the bridge's hard budget
/// on the same numbers, so the two can never disagree.
typedef JsWorkerLauncher = Future<JsWorkerHandle> Function({
  required Duration timeout,
  required int memoryLimit,
});
