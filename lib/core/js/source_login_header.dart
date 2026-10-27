import 'dart:async';
import 'dart:convert';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';

// 私有字段不能做具名初始化形参（Dart 限制），手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

/// The persisted side of a source's **login header** (`source.putLoginHeader`, M25/S3b).
///
/// Upstream keeps it in `CacheManager` under `loginHeader_<bookSourceUrl>` (`BaseSource.kt:133-156`),
/// so the unit is the source **URL**, not the row: that is all a running rule has, and two imports
/// of the same URL are one source to upstream.
abstract interface class SourceLoginHeaderRepository {
  /// The header JSON stored for [sourceUrl], or `null` when it never signed in.
  Future<String?> read(String sourceUrl);

  /// Stores [header] for [sourceUrl]; `null` clears it.
  Future<void> write(String sourceUrl, String? header);
}

/// A repository that stores nothing, for tests and for a build without storage.
final class InMemorySourceLoginHeaderRepository
    implements SourceLoginHeaderRepository {
  /// Creates an empty repository.
  InMemorySourceLoginHeaderRepository();

  final Map<String, String> _headers = <String, String>{};

  @override
  Future<String?> read(String sourceUrl) async => _headers[sourceUrl];

  @override
  Future<void> write(String sourceUrl, String? header) async {
    if (header == null) {
      _headers.remove(sourceUrl);

      return;
    }
    _headers[sourceUrl] = header;
  }
}

/// The login header of every source the engine has run, written through to
/// [SourceLoginHeaderRepository].
///
/// Why a store and not a database read per request: a request asks for it synchronously
/// (`headersOf` runs on the way into every fetch, and the sandbox reads it inside a rule), while
/// storage is asynchronous. So the value is hydrated once per source and then kept in memory —
/// the same contract as `SourceVariableStore` (`ADR-0076 §决策 1`), except that the sandbox writes
/// through immediately instead of waiting for the job to end: upstream's `putLoginHeader` takes
/// effect at once, and a login script that writes it and then fetches a page expects that
/// (`BaseSource.kt:150-157`).
final class SourceLoginHeaderStore {
  /// Creates the store on top of [repository].
  ///
  /// A `null` repository keeps the value in memory only (unit tests, and a build whose storage is
  /// not wired yet); the sandbox behaviour is identical either way.
  SourceLoginHeaderStore({
    SourceLoginHeaderRepository? repository,
    AppLogger? logger,
  }) : _repository = repository,
       _logger = logger;

  final SourceLoginHeaderRepository? _repository;
  final AppLogger? _logger;

  final Map<String, String?> _bySource = <String, String?>{};

  // 同一个源的并发首读只查一次库（一批 20 条搜索会同时要同一个源的值）。
  final Map<String, Future<void>> _loads = <String, Future<void>>{};

  // 写入按调用顺序落库：两次 put 若乱序，后到的旧值会盖住新值。
  Future<void> _pendingWrite = Future<void>.value();

  /// Makes sure the value of [sourceUrl] is loaded, and answers once it is.
  ///
  /// Idempotent and single-flight per source: the bridge calls it before every job.
  Future<void> ensureLoaded(String sourceUrl) {
    final Future<void>? loading = _loads[sourceUrl];
    if (loading != null) {
      return loading;
    }
    final Future<void> created = _load(sourceUrl);
    _loads[sourceUrl] = created;

    return created;
  }

  Future<void> _load(String sourceUrl) async {
    // 已经有人写过（`put` 先落内存、再排队落库）：内存里的值比库里的新，别用旧值盖回去。
    if (_bySource.containsKey(sourceUrl)) {
      return;
    }
    final SourceLoginHeaderRepository? repository = _repository;
    if (repository == null) {
      _bySource[sourceUrl] = null;

      return;
    }
    try {
      _bySource[sourceUrl] = await repository.read(sourceUrl);
    } on Exception catch (error, stackTrace) {
      // 首读失败按「没有登录头」处理：重试会拖慢每一个 job，而没有它只是少带一个头。
      _logger?.warning(
        'Could not read the login header: source=${redactUrl(sourceUrl)}',
        describeError(error),
        stackTrace,
      );
      _bySource[sourceUrl] = null;
    }
  }

  /// The header JSON of [sourceUrl], as a job receives it, or `null` when there is none.
  String? snapshot(String sourceUrl) => _bySource[sourceUrl];

  /// Stores [header] for [sourceUrl] and persists it; `null` clears the value.
  void put(String sourceUrl, String? header) {
    _bySource[sourceUrl] = header;

    final SourceLoginHeaderRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await repository.write(sourceUrl, header);
      } on Exception catch (error, stackTrace) {
        // 落库失败只记 warning：登录头丢了只是要重新登录一次。
        _logger?.warning(
          'Could not persist the login header: source=${redactUrl(sourceUrl)}',
          describeError(error),
          stackTrace,
        );
      }
    });
  }
}

/// The `Cookie` value inside a login header, or `null` when it has none.
///
/// Upstream's `putLoginHeader` merges that cookie into the source's cookie jar
/// (`BaseSource.kt:150-153`), because the `Cookie` header of a **login** header is what later
/// requests need and the jar is what actually sends it (our HTTP client overwrites any `Cookie`
/// header with the jar's value, `_CookieInterceptor`).
///
/// A value that does not decode to a JSON object answers `null`: a rule may store anything, and a
/// broken header must cost the cookie merge, not the request.
String? loginHeaderCookieOf(String header) {
  final Object? decoded = _tryDecode(header);
  if (decoded is! Map<Object?, Object?>) {
    return null;
  }
  for (final MapEntry<Object?, Object?> entry in decoded.entries) {
    final Object? name = entry.key;
    final Object? value = entry.value;
    if (name is String && name.toLowerCase() == 'cookie' && value is String) {
      final String cookie = value.trim();

      return cookie.isEmpty ? null : cookie;
    }
  }

  return null;
}

Object? _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
