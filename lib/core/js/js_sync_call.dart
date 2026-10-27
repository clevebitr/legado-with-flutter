/// The **synchronous** `java.*` / `cookie.*` family (ADR-0076 §决策 1).
///
/// Upstream's Rhino sandbox blocks the calling thread until the page arrives, so a rule writes
/// `java.ajax(url)` and reads the body straight away. A QuickJS isolate cannot block on the host
/// (Dart has no synchronous TLS), so this repository replays instead:
///
/// * the worker keeps a per-job cache of every synchronous answer it has already received;
/// * a call that is **not** in the cache raises a sentinel, the worker fetches the page from the
///   bridge, stores the answer and runs the script **again from its first line**;
/// * on the next pass the same call answers synchronously from the cache, so the rule sees the
///   value it asked for without ever learning that it ran twice.
///
/// Everything that makes the replay safe lives here: the verbs, the request shape (so the bridge
/// validates it once), the cache key (so a pass hits the same entry) and the cache itself.
library;

import 'dart:collection';

/// The verbs the synchronous channel binds.
///
/// The names are the sandbox spellings, minus the object they hang off (`java.ajax` → `ajax`,
/// `cookie.setCookie` → [cookieSet]), because the worker's envelope carries one flat operation.
enum JsSyncOperation {
  /// `java.ajax(url[, headers])`: the body of a GET.
  ajax,

  /// `java.post(url, body, headers)`: the whole response (a rule reads `header('Location')`).
  post,

  /// `java.head(url)`: the whole response of a HEAD.
  head,

  /// `java.connect(url[, header[, callTimeout]])`: the whole response, with a **failure swallowed**.
  ///
  /// Upstream wraps the fetch in `runCatching` and answers a response whose body is the error text,
  /// because a rule uses it as「try this address」rather than as a required page.
  connect,

  /// `java.ajaxAll(urlList[, skipRateLimit])`: the whole responses of several addresses.
  ///
  /// Upstream fetches them concurrently (`mapAsync(threadCount)`) and **propagates** a failure, so
  /// one bad address fails the call; `skipRateLimit` only bypasses the per-source budget there.
  ajaxAll,

  /// `java.getCookie(url[, key])`: one cookie's value, or the whole `Cookie` header without `key`.
  getCookie,

  /// `cookie.getCookie(url[, key])`: same as `getCookie` under upstream's other spelling.
  cookieGet,

  /// `cookie.setCookie(url, cookie)`: stores one `name=value` (or a whole `a=1; b=2`).
  cookieSet,

  /// `cookie.removeCookie(url, key)`: drops one cookie.
  cookieRemove,
}

/// One validated synchronous call, decoded on the host isolate.
final class JsSyncRequest {
  /// Creates a request.
  const JsSyncRequest({
    required this.operation,
    required this.url,
    this.body,
    this.headers = const <String, String>{},
    this.key,
    this.urls = const <String>[],
  });

  /// The verb the rule called.
  final JsSyncOperation operation;

  /// The absolute-or-relative address the rule passed.
  final String url;

  /// The form body of a [JsSyncOperation.post].
  final String? body;

  /// The headers the rule declared.
  final Map<String, String> headers;

  /// The cookie name, for the three cookie verbs; `null` asks for the whole header.
  final String? key;

  /// The addresses of a [JsSyncOperation.ajaxAll]; empty for every other verb.
  final List<String> urls;

  /// The JSON envelope the worker sends to the bridge.
  Map<String, Object?> toJson() => <String, Object?>{
    'operation': operation.name,
    'url': url,
    'body': body,
    'headers': headers,
    'key': key,
    'urls': urls,
  };

  /// The identity of this call inside one job's replay cache.
  ///
  /// The body and the cookie name are part of it: two `java.post` calls to one address with
  /// different forms are two different pages, and two cookie reads name two different cookies.
  String get cacheKey => <String>[
    operation.name,
    url,
    body ?? '',
    key ?? '',
    urls.join(_cacheKeySeparator),
  ].join(_cacheKeySeparator);
}

// NUL never appears in a URL, a form body or a cookie name, so it cannot make two calls collide.
const String _cacheKeySeparator = '\u0000';

/// Reads one synchronous call's arguments, or `null` when they are unusable.
///
/// The arguments are JSON: `{operation, url, body, headers, key}`.
JsSyncRequest? decodeJsSyncRequest(Object? args) {
  if (args is! Map) {
    return null;
  }
  final JsSyncOperation? operation = switch (args['operation']) {
    'ajax' => JsSyncOperation.ajax,
    'post' => JsSyncOperation.post,
    'head' => JsSyncOperation.head,
    'connect' => JsSyncOperation.connect,
    'ajaxAll' => JsSyncOperation.ajaxAll,
    'getCookie' => JsSyncOperation.getCookie,
    'cookieGet' => JsSyncOperation.cookieGet,
    'cookieSet' => JsSyncOperation.cookieSet,
    'cookieRemove' => JsSyncOperation.cookieRemove,
    _ => null,
  };
  final Object? url = args['url'];
  final Object? body = args['body'];
  final Object? key = args['key'];
  final List<String> urls = _urlsOf(args['urls']);
  if (operation == null) {
    return null;
  }
  // `ajaxAll` 带的是地址列表；别的动词带的是单个地址。
  if (operation == JsSyncOperation.ajaxAll) {
    if (urls.isEmpty) {
      return null;
    }
  } else if (url is! String || url.isEmpty) {
    return null;
  }
  if (body is! String? || key is! String?) {
    return null;
  }
  final Map<String, String>? headers = _headersOf(args['headers']);
  if (headers == null) {
    return null;
  }
  // 只有 post / cookieSet 有载荷正文；别的动词带上它说明信封被拼错了，宁可拒绝。
  if (body != null &&
      operation != JsSyncOperation.post &&
      operation != JsSyncOperation.cookieSet) {
    return null;
  }

  return JsSyncRequest(
    operation: operation,
    // `ajaxAll` 没有单个地址：空串表示「见 urls」，与别的动词的必填 url 区分开。
    url: url is String ? url : '',
    body: body,
    headers: headers,
    key: key,
    urls: urls,
  );
}

/// Reads the address list of a `java.ajaxAll` call; anything unusable answers an empty list.
List<String> _urlsOf(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  final List<String> urls = <String>[];
  for (final Object? entry in value) {
    if (entry is! String || entry.isEmpty) {
      return const <String>[];
    }
    urls.add(entry);
  }

  return urls;
}

Map<String, String>? _headersOf(Object? value) {
  if (value == null) {
    return const <String, String>{};
  }
  if (value is! Map) {
    return null;
  }
  final Map<String, String> headers = <String, String>{};
  for (final MapEntry<Object?, Object?> entry in value.entries) {
    final Object? key = entry.key;
    final Object? header = entry.value;
    if (key is! String || header is! String) {
      return null;
    }
    headers[key] = header;
  }

  return headers;
}

/// One answer a pass has already received: a value, or the failure that ended the fetch.
///
/// A failed fetch is cached too. Upstream's `java.ajax` **throws** on a transport failure, so the
/// rule can catch it and try a mirror; replaying the failure is what keeps that `try` / `catch`
/// from turning into an endless pass loop.
final class JsSyncEntry {
  /// A successful answer; [value] is what the script receives.
  const JsSyncEntry.value(this.value) : failure = null;

  /// A failed answer; the next pass throws [failure] inside the script.
  const JsSyncEntry.failure(String this.failure) : value = null;

  /// The value the script receives, for a successful answer.
  final Object? value;

  /// The failure kind name the next pass throws, for a failed answer.
  final String? failure;

  /// Whether this entry carries a value.
  bool get isSuccess => failure == null;

  /// The envelope the worker hands the sandbox for this entry.
  Map<String, Object?> toEnvelope() => isSuccess
      ? <String, Object?>{'ok': true, 'value': value}
      : <String, Object?>{'ok': false, 'message': failure};
}

/// The default bound on the number of synchronous calls one job may fetch.
///
/// Upstream's sandbox never runs a script twice, so this bound is what keeps a rule that walks a
/// long list one `java.ajax` at a time from taking `n` passes: past it the job fails with
/// `js:replay`, which says «this rule cannot be replayed» instead of timing out.
const int defaultJsMaxReplayPasses = 16;

/// The per-job cache a pass reads and a fetch fills (ADR-0076 §决策 1).
///
/// Bounded on purpose: a rule that walks a long list one `java.ajax` at a time must hit the pass
/// limit (`JsReplayLimit`) before it can grow the cache without bound.
final class JsSyncCache {
  /// Creates an empty cache; [maxEntries] is the number of distinct calls it remembers.
  ///
  /// The bound is enforced by eviction rather than by an assertion: a value below 1 would make the
  /// cache forget every answer, which the pass limit already turns into a readable failure
  /// (`book-source.md` §6) — release builds must not depend on `assert` either way.
  JsSyncCache({this.maxEntries = defaultMaxSyncEntries});

  /// The default bound: far above the 16 passes one job may take.
  static const int defaultMaxSyncEntries = 64;

  /// How many distinct calls the cache remembers.
  final int maxEntries;

  // LinkedHashMap 保序，淘汰时丢最旧的那条。
  final LinkedHashMap<String, JsSyncEntry> _entries =
      LinkedHashMap<String, JsSyncEntry>();

  /// How many calls the cache currently remembers.
  int get length => _entries.length;

  /// The answer [request] already has, or `null` when this pass has to fetch it.
  JsSyncEntry? lookup(JsSyncRequest request) => _entries[request.cacheKey];

  /// Remembers [entry] for [request], dropping the oldest call when full.
  void store(JsSyncRequest request, JsSyncEntry entry) {
    _entries.remove(request.cacheKey);
    _entries[request.cacheKey] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Forgets everything; a new job starts with an empty cache.
  void clear() => _entries.clear();
}

/// The value [key] holds inside a `Cookie` header, or `null` when the header does not carry it.
///
/// Upstream reads through `CookieManager`, which has no per-name lookup; the header is the shape
/// both sides agree on (`a=1; b=2`). Values may contain `=`, so only the first one splits.
String? cookieValueOf(String? header, String key) {
  if (header == null || header.isEmpty) {
    return null;
  }
  for (final String pair in header.split(';')) {
    final String trimmed = pair.trim();
    final int equals = trimmed.indexOf('=');
    if (equals <= 0) {
      continue;
    }
    if (trimmed.substring(0, equals).trim() == key) {
      return trimmed.substring(equals + 1).trim();
    }
  }

  return null;
}
