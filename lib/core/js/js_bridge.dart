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

/// The sandbox view of the **book being read** (`book-source.md` §6, ADR-0055 P2).
///
/// Upstream binds its `Book` entity as `book` (`AnalyzeUrl.kt:373`), and real sources read
/// `book.name` / `book.author` / `book.bookUrl` / `book.tocUrl` / `book.intro` from URL and
/// chapter rules. This class carries the **data** fields; the methods a source may call
/// (`getVariable` / `putVariable` / `setType` / `setReverseToc`) are built by the sandbox
/// prelude around that JSON, because they need the rule-variable table (ADR-0057 §决策 2).
final class JsBookInfo {
  /// Creates the sandbox view of a book.
  const JsBookInfo({
    this.name = '',
    this.author = '',
    this.bookUrl = '',
    this.tocUrl = '',
    this.intro = '',
    this.kind = '',
  });

  /// The book title (`book.name`).
  final String name;

  /// The author (`book.author`).
  final String author;

  /// The book's detail URL (`book.bookUrl`).
  final String bookUrl;

  /// The table-of-contents URL (`book.tocUrl`).
  final String tocUrl;

  /// The introduction (`book.intro`).
  final String intro;

  /// The category (`book.kind`).
  final String kind;

  /// The JSON object the sandbox receives as `book`.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'author': author,
    'bookUrl': bookUrl,
    'tocUrl': tocUrl,
    'intro': intro,
    'kind': kind,
  };
}

/// One `parse.*` call from a running rule (`docs/dev/book-source.md` §6).
/// One `parse.*` call from a running rule (`docs/dev/book-source.md` §6).
///
/// The engine owns the rule language, so `parse.getString` / `parse.getElements` cannot be
/// answered inside the worker isolate: the call travels back to the host, which evaluates
/// [rule] with the engine and answers the script. [doc] is the second argument the rule
/// passed; §6 fixes what a rule may pass as it.
final class JsParseRequest {
  /// Creates a parse request.
  const JsParseRequest({required this.rule, required this.wantsList, this.doc});

  /// The nested rule the script asked to evaluate.
  final String rule;

  /// Whether the call came from `parse.getElements` (`true`) or `parse.getString`.
  ///
  /// It is the same split as `getStringList` versus `getString` upstream, and the
  /// engine needs it: one returns every match, the other the first value.
  final bool wantsList;

  /// The `doc` argument the rule passed, or `null` when it passed none.
  final String? doc;
}

/// The `rulePath` marker of a `parse.*` call without a page-level scope (`book-source.md`
/// §6).
///
/// It lives in the contract rather than in one implementation because the engine refuses the
/// call (it owns the scope) and the bridge fails the job with it (it owns the job).
const String jsParseScopeMarker = 'js:parse-scope';

/// The `rulePath` marker of a `parse.*` rule that would need a nested `@js:` (`§6`).
///
/// The single worker is busy running the job that asked, so a nested evaluation could only
/// wait on its own queue (ADR-0030 §决策 1/3). It is refused instead of deadlocking.
const String jsParseRecursionMarker = 'js:parse-recursion';

/// Evaluates a nested rule for `parse.*` against the page a job runs on (§6).
///
/// A job carries one of these when the engine can offer a page-level scope; the bridge
/// calls it for every `parse.*` request the script makes. The engine returns the nested
/// rule's own failure — `unsupportedRule` for the boundaries §6 registers — and the job
/// fails with it instead of the script silently seeing an empty value (C-SRC-4).
typedef JsParseEvaluator = Future<ParseResult<Object?>> Function(
  JsParseRequest request,
);

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
    this.sourceHeaders,
    this.parseEvaluator,
    this.variables = const <String, String>{},
    this.key,
    this.bookName,
    this.chapterTitle,
    this.book,
  });

  /// The JavaScript the rule asked for, with the `@js:` flag already removed.
  final String script;

  /// The book source field this rule belongs to, e.g. `searchRule.name`.
  ///
  /// It travels into failures and into everything `log.*` writes, so a JS problem
  /// stays locatable (C-SRC-8, §6).
  final String rulePath;

  /// The variables the script may read and write through `java.get` / `java.put`
  /// (`book-source.md` §6, matrix #16/#17).
  ///
  /// It is a **snapshot** of the source's variables, taken when the job is built: the
  /// script reads them synchronously inside the worker (ADR-0034 §决策 1), and whatever
  /// it writes travels back with the job's result, where the bridge merges it into the
  /// store. A job therefore never sees a variable written by another job that started
  /// after it.
  final Map<String, String> variables;

  /// The search keyword (upstream's `key` binding in a URL rule), or `null` when this job
  /// is not evaluating a URL.
  ///
  /// Upstream binds `key` only in `AnalyzeUrl.evalJS` (`AnalyzeUrl.kt:377`), and the URL
  /// is the one place a rule template cannot get the keyword from anywhere else. It stays
  /// `null` for every other job, so a field rule reading `key` fails with `js:error`
  /// instead of silently seeing an empty string (ADR-0034 §决策 3).
  final String? key;

  /// The book being read, when the stage knows it (`book-source.md` §6, ADR-0049).
  ///
  /// It answers `java.get('bookName')` **before** the variable store does, which is upstream's
  /// order (`AnalyzeRule.get`, `AnalyzeRule.kt:812-821`): a rule that reads the book name gets
  /// the book, not a variable that happens to share the name.
  final String? bookName;

  /// The chapter being read, when the stage knows it (§6, ADR-0049).
  ///
  /// It answers `java.get('title')`. `null` means "this stage has no single chapter" — a
  /// search or a table of contents — and the read falls through to the variable store.
  final String? chapterTitle;

  /// The book being read, when the stage knows it (ADR-0055 P2).
  ///
  /// It becomes the `book` binding. `null` when the stage has no book (search / explore), and
  /// the worker then binds `book` to `null`, so a source's `typeof book` guard still works.
  final JsBookInfo? book;

  /// The page the rule was read on (the `baseUrl` binding).
  final String baseUrl;

  /// The 1-based page number (the `page` binding).
  final int page;

  /// The sandbox view of the book source (the `source` binding).
  final JsSourceInfo source;

  /// The value the rule produced so far (the `result` binding), when there is one.
  final Object? result;

  /// The book source's own `header` field (`book-source.md` §2), when it declares one.
  ///
  /// It is the default for every `http.*` call of this job, because upstream's
  /// `java.ajax` builds its request from the source (`AnalyzeUrl`), and a source that
  /// needs a `Referer` needs it for its JS requests too (C-NET-4). It stays on the host
  /// side: [toJson] does not send it, so `source` remains the only view a rule gets.
  final Map<String, String>? sourceHeaders;

  /// Evaluates `parse.*` rules for this job (`book-source.md` §6), when the engine can.
  ///
  /// `null` means the job may not run `parse.*` at all — every request then fails with
  /// `js:parse-scope`, which is the explicit boundary ADR-0029 §决策 5 asks for. The
  /// callback is host-side only; [toJson] does not send it.
  final JsParseEvaluator? parseEvaluator;

  /// The JSON envelope the worker receives.
  Map<String, Object?> toJson() => <String, Object?>{
    'script': script,
    'rulePath': rulePath,
    'baseUrl': baseUrl,
    'page': page,
    'source': source.toJson(),
    'result': result,
    'variables': variables,
    'key': key,
    'bookName': bookName,
    'chapterTitle': chapterTitle,
    'book': book?.toJson(),
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
/// on the same numbers, so the two can never disagree, and keeps §6's per-rule call
/// quota in the one place that can count real binding calls (the bridge, ADR-0030
/// §决策 3).
typedef JsWorkerLauncher = Future<JsWorkerHandle> Function({
  required Duration timeout,
  required int memoryLimit,
});
