import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/http_policy.dart';

/// The book source fields a rule sees as `source`.
///
/// Only `name`, `url` and `group` are exposed; everything else stays on the host.
final class JsSourceInfo {
  /// Creates the sandbox view of a book source.
  const JsSourceInfo({
    required this.name,
    required this.url,
    this.group,
    this.jsLib,
  });

  /// The source's display name.
  final String name;

  /// The source's URL, which is also its id.
  final String url;

  /// The source's group, when it declares one.
  final String? group;

  /// The source's `jsLib`, as declared (`book-source.md` §6).
  ///
  /// **Host-side only**: [toJson] does not send it, so the sandbox's `source` object stays the
  /// three fields above (the whole entity is deliberately not exposed). The rule engine reads it
  /// here and resolves it through `JsLibStore` before building the job.
  final String? jsLib;

  /// The JSON object the sandbox receives as `source`.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'url': url,
    'group': group,
  };
}

/// The book fields a rule sees as `book`.
///
/// Only data lives here; the methods are added by the sandbox prelude.
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

  /// The book title.
  final String name;

  /// The author.
  final String author;

  /// The book's detail URL.
  final String bookUrl;

  /// The table-of-contents URL.
  final String tocUrl;

  /// The introduction.
  final String intro;

  /// The category.
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

/// One chapter as a script sees it (upstream's `chapter` binding).
///
/// Data only: `tocRule.formatJs` reads `chapter.title` / `chapter.url` and the flags, and the script
/// answers the new title through the job's result instead of mutating this object (S2).
final class JsChapterInfo {
  /// Creates the sandbox view of one chapter.
  const JsChapterInfo({
    required this.title,
    required this.url,
    this.isVip = false,
    this.isPay = false,
    this.isVolume = false,
    this.updateTime,
  });

  /// The chapter name the `chapterName` rule produced.
  final String title;

  /// The chapter URL, already absolute.
  final String url;

  /// Whether the source marked the chapter as VIP-only.
  final bool isVip;

  /// Whether the source marked the chapter as already bought.
  final bool isPay;

  /// Whether this entry is a volume heading rather than a chapter.
  final bool isVolume;

  /// The display-only update time, when the source had one.
  final String? updateTime;

  /// The JSON object the sandbox receives as `chapter`.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'url': url,
    'isVip': isVip,
    'isPay': isPay,
    'isVolume': isVolume,
    'updateTime': updateTime,
  };
}

/// One `parse.*` call from a running rule.
///
/// The call travels to the host, which evaluates [rule] with the rule engine and
/// answers the script.
final class JsParseRequest {
  /// Creates a parse request.
  const JsParseRequest({
    required this.rule,
    required this.wantsList,
    this.wantsValues = false,
    this.doc,
    this.content,
  });

  /// The nested rule the script asked to evaluate.
  final String rule;

  /// Whether the call answers several matches rather than one.
  final bool wantsList;

  /// Whether a list call answers **extracted values** (`java.getStringList`) instead of element
  /// documents (`parse.getElements`).
  ///
  /// Upstream's `java.getStringList(rule)` runs the whole rule including its extraction segment
  /// (`@css:.box img@src` answers URLs), while this repository's own `parse.getElements` answers the
  /// matched elements (ADR-0037 §决策 3). Both exist, so the request has to say which one it is.
  final bool wantsValues;

  /// The `doc` argument the rule passed, or `null` when it passed none.
  final String? doc;

  /// The page body a `java.setContent(html)` in the same script replaced the scope with, or `null`
  /// when the rule never called it.
  ///
  /// Upstream's `setContent` swaps the content later rules read inside the same evaluation; here
  /// the page scope lives on the host, so the override travels with every `parse.*` call that
  /// follows it (`book-source.md` §6).
  final String? content;
}

/// The `rulePath` marker of a `parse.*` call without a page-level scope.
const String jsParseScopeMarker = 'js:parse-scope';

/// The `rulePath` marker of a `parse.*` rule that would need a nested `@js:`.
const String jsParseRecursionMarker = 'js:parse-recursion';

/// The JSON marker that turns a plain object into the sandbox's response view.
///
/// It travels through the job envelope so the prelude can tell a response from an ordinary
/// `result` value; scripts never need to know it.
const String jsResponseMarker = '__strResponse';

/// A response as a `loginCheckJs` interceptor sees it: the sandbox `result` object.
///
/// Upstream hands the interceptor a `StrResponse` and replaces the page with whatever the script
/// returns, so `result` is not the body — it is a small object the script reads (`body` property,
/// `url()` / `code()` / `headers()` methods) and returns (`book-source.md` §6, ADR-0068 addendum).
///
/// The URL travels as `__url` because `url` itself is the method name upstream exposes; the body
/// stays a plain `body` property, which is the form upstream's own JS helpers use
/// (`getStrResponse().body`).
final class JsResponseView {
  /// Creates the response view of one fetched page.
  const JsResponseView({
    required this.url,
    required this.body,
    this.code = 200,
    this.headers = const <String, String>{},
  });

  /// The page's final URL (after redirects).
  final String url;

  /// The page body.
  final String body;

  /// The HTTP status code.
  final int code;

  /// The response headers, lower-cased for lookup.
  final Map<String, String> headers;

  /// The JSON object the prelude turns into the sandbox `result`.
  ///
  /// The status and the headers travel as `__code` / `__headers` for the same reason as
  /// [url]: `code()` and `headers()` are method names upstream, so the data cannot sit on them.
  Map<String, Object?> toJson() => <String, Object?>{
    jsResponseMarker: true,
    'body': body,
    '__url': url,
    '__code': code,
    '__headers': headers,
  };
}

/// Evaluates a nested rule for `parse.*` against the page a job runs on.
typedef JsParseEvaluator = Future<ParseResult<Object?>> Function(
  JsParseRequest request,
);

/// One `@js:` evaluation: the rule script plus the bindings it sees.
final class JsJob {
  /// Creates a job.
  const JsJob({
    required this.script,
    required this.rulePath,
    required this.baseUrl,
    required this.page,
    required this.source,
    this.result,
    this.response,
    this.sourceHeaders,
    this.parseEvaluator,
    this.variables = const <String, String>{},
    this.sourceVariables = const <String, String>{},
    this.jsLib,
    this.titleFormatChapters,
    this.key,
    this.bookName,
    this.chapterTitle,
    this.book,
    this.loginInfo = const <String, String>{},
    this.webViewUA = defaultUserAgent,
    this.androidId,
    this.src,
    this.chapter,
    this.nextChapterUrl,
    this.fromBookInfo = false,
  });

  /// The JavaScript the rule asked for, with the `@js:` flag already removed.
  final String script;

  /// The book source field this rule belongs to, e.g. `searchRule.name`.
  final String rulePath;

  /// The variables the script reads and writes through `java.get` / `java.put`.
  ///
  /// A snapshot taken when the job is built; writes travel back with the result.
  final Map<String, String> variables;

  /// The variables the script reads and writes through `source.getVariable` / `setVariable`
  /// (ADR-0076 §决策 1).
  ///
  /// A snapshot of the **persisted** per-source map: unlike [variables] these values outlive the
  /// app, so the bridge writes what the job reported back to storage
  /// (`SourceVariableStore.merge`).
  final Map<String, String> sourceVariables;

  /// The chapters a `tocRule.formatJs` pass rewrites, or `null` for an ordinary job (S2).
  ///
  /// Non-null switches the job into **title-format mode**: [script] is the `formatJs` rule and it
  /// runs **once per chapter in one scope**, with `index` (1-based), `chapter`, `title` and `gInt`
  /// bound — `gInt` deliberately persists across the loop, exactly like upstream's shared
  /// `ScriptBindings` (`BookChapterList.kt:141-163`). The answer is a list aligned with this list:
  /// a string replaces the title, `null` keeps the previous one.
  final List<JsChapterInfo>? titleFormatChapters;

  /// The source's **resolved** `jsLib`: the JavaScript the worker runs before the rule itself
  /// (ADR-0078 S1).
  ///
  /// It is already the concatenation of everything the field declared (`JsLibStore.resolve`), so
  /// the sandbox never has to fetch. `null` means the source declares no library.
  final String? jsLib;

  /// The search keyword (the `key` binding) of a URL rule, or `null` otherwise.
  final String? key;

  /// The book name `java.get('bookName')` answers with, when the stage knows it.
  final String? bookName;

  /// The chapter title `java.get('title')` answers with, when the stage knows one.
  final String? chapterTitle;

  /// The book being read (the `book` binding), or `null` when the stage has none.
  final JsBookInfo? book;

  /// The source's `loginUi` values, as `source.getLoginInfo()` / `getLoginInfoMap()` read them
  /// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
  ///
  /// A **snapshot**: the sandbox is an isolate and cannot ask the host mid-script, so the values
  /// travel with the job (the same mechanism as the rule variables, ADR-0034). Empty means「never
  /// signed in」, which is what a source that declares no `loginUi` always answers.
  final Map<String, String> loginInfo;

  /// The `User-Agent` a WebView would send (`java.getWebViewUA`, M25/S3b).
  ///
  /// A constant per job: upstream reads the platform WebView's default UA once, which for us is the
  /// desktop Chrome string every request already sends (`core/network/http_policy.dart`).
  final String webViewUA;

  /// The install id `java.androidId` answers with (M25/S3b), or `null` when the host has none.
  ///
  /// Upstream returns Android's `Settings.Secure.ANDROID_ID`; this repository has no such id, so the
  /// assembly root passes a stable per-install value and the sandbox answers `''` when it is absent
  /// (registered in `book-source.md` §6).
  final String? androidId;

  /// The page body the rule was read on (the `src` binding, M25/S3b).
  ///
  /// Upstream's `AnalyzeRule.evalJS` binds `src` to the scope's content — the fetched page, or a
  /// `java.setContent(html)` replacement made before this evaluation. It is `null` where there is no
  /// page (a URL rule, a `header` rule), which is also upstream's value there.
  final String? src;

  /// The chapter this job belongs to (the `chapter` binding, M25/S3b), or `null` when the stage has
  /// none — a search page, a detail page, or a `tocRule.formatJs` pass (which rebinds `chapter` per
  /// chapter inside the loop).
  final JsChapterInfo? chapter;

  /// The next chapter's URL (the `nextChapterUrl` binding), when the reader knows it.
  ///
  /// Upstream sets it on the content stage so a `nextContentUrl` / `content` rule can tell "the next
  /// page is the next chapter" apart (and so a rule can build that address).
  final String? nextChapterUrl;

  /// Whether the running rules were reached from the book info stage (the `fromBookInfo` binding).
  ///
  /// Sources use it to answer differently on the detail page than on a list page.
  final bool fromBookInfo;

  /// The page the rule was read on (the `baseUrl` binding).
  final String baseUrl;

  /// The 1-based page number (the `page` binding).
  final int page;

  /// The sandbox view of the book source (the `source` binding).
  final JsSourceInfo source;

  /// The value the rule produced so far (the `result` binding), when there is one.
  final Object? result;

  /// The response a `loginCheckJs` interceptor reads as `result`, when this job is one.
  ///
  /// When set it **wins over** [result]: the interceptor's `result` is a response object, not the
  /// page text (ADR-0068 addendum).
  final JsResponseView? response;

  /// The book source's own `header` field, the default for its `http.*` calls.
  ///
  /// Host-side only: [toJson] does not send it.
  final Map<String, String>? sourceHeaders;

  /// Evaluates `parse.*` rules for this job, or `null` when it may not run them.
  ///
  /// Host-side only: [toJson] does not send it.
  final JsParseEvaluator? parseEvaluator;

  /// The JSON envelope the worker receives.
  Map<String, Object?> toJson() => <String, Object?>{
    'script': script,
    'rulePath': rulePath,
    'baseUrl': baseUrl,
    'page': page,
    'source': source.toJson(),
    'result': result,
    'response': response?.toJson(),
    'variables': variables,
    'sourceVariables': sourceVariables,
    'jsLib': jsLib,
    'titleFormatChapters': <Map<String, Object?>>[
      for (final JsChapterInfo chapter
          in titleFormatChapters ?? const <JsChapterInfo>[])
        chapter.toJson(),
    ],
    'titleFormat': titleFormatChapters != null,
    'key': key,
    'bookName': bookName,
    'chapterTitle': chapterTitle,
    'book': book?.toJson(),
    'loginInfo': loginInfo,
    'webViewUA': webViewUA,
    'androidId': androidId,
    'src': src,
    'chapter': chapter?.toJson(),
    'nextChapterUrl': nextChapterUrl,
    'fromBookInfo': fromBookInfo,
  };
}

/// Runs `@js:` rules off the UI isolate.
///
/// Timeouts and JS exceptions come back as failures; nothing throws at the caller.
abstract interface class JsBridge {
  /// Evaluates [job] and returns its result as a JSON value.
  ///
  /// Concurrent calls queue in call order and never fail with "busy".
  Future<ParseResult<Object?>> evaluate(JsJob job);

  /// Releases the worker. Safe to call more than once.
  Future<void> dispose();
}

/// One running JS worker: a message channel plus a kill switch.
abstract interface class JsWorkerHandle {
  /// Envelopes the worker sends back: one result per job, plus `log.*` records.
  Stream<Map<String, Object?>> get messages;

  /// Sends one envelope to the worker.
  void send(Map<String, Object?> message);

  /// Stops the worker immediately; only used when the engine could not interrupt it.
  void kill();
}

/// Starts one worker on demand, with the budgets the bridge will hold it to.
typedef JsWorkerLauncher = Future<JsWorkerHandle> Function({
  required Duration timeout,
  required int memoryLimit,
});
