import 'dart:async';

// 私有字段不能做具名初始化形参（Dart 限制），手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';

/// The persisted side of a book source's variable map (`source.getVariable` /
/// `source.setVariable`, ADR-0076 §决策 1).
///
/// Upstream keeps `BaseSource.getVariableMap()` in the database, so a rule that stores a token
/// there finds it on the next run — that is the only reason a source uses the door instead of
/// `java.put`. The port answers the whole map of one source because that is the unit the sandbox
/// seeds its job with.
abstract interface class SourceVariableRepository {
  /// Reads every variable [sourceUrl] holds; an absent source answers an empty map.
  Future<Map<String, String>> read(String sourceUrl);

  /// Applies [values] for [sourceUrl]: a `null` value deletes the key.
  Future<void> write(String sourceUrl, Map<String, String?> values);
}

/// A repository that stores nothing, for tests and for a build without storage.
final class InMemorySourceVariableRepository
    implements SourceVariableRepository {
  /// Creates an empty repository.
  InMemorySourceVariableRepository();

  final Map<String, Map<String, String>> _bySource =
      <String, Map<String, String>>{};

  @override
  Future<Map<String, String>> read(String sourceUrl) async =>
      Map<String, String>.unmodifiable(
        _bySource[sourceUrl] ?? const <String, String>{},
      );

  @override
  Future<void> write(String sourceUrl, Map<String, String?> values) async {
    final Map<String, String> current = _bySource.putIfAbsent(
      sourceUrl,
      () => <String, String>{},
    );
    for (final MapEntry<String, String?> entry in values.entries) {
      final String? value = entry.value;
      if (value == null) {
        current.remove(entry.key);
      } else {
        current[entry.key] = value;
      }
    }
  }
}

/// The in-memory view of every source's variables, written through to
/// [SourceVariableRepository].
///
/// The sandbox is an isolate and cannot await a database mid-script, so a job receives a
/// **snapshot** ([snapshot]) and reports its writes back with the result ([merge]); exactly the
/// contract the rule variables already use (ADR-0034 §决策 1). What differs is persistence: these
/// values outlive the app, so the store hydrates once per source and writes through.
final class SourceVariableStore {
  /// Creates the store on top of [repository].
  ///
  /// A `null` repository keeps the values in memory only (unit tests, and a build whose storage
  /// is not wired yet); the sandbox behaviour is identical either way.
  SourceVariableStore({SourceVariableRepository? repository, AppLogger? logger})
    : _repository = repository,
      _logger = logger;
  final SourceVariableRepository? _repository;
  final AppLogger? _logger;

  final Map<String, Map<String, String>> _bySource =
      <String, Map<String, String>>{};

  // 同一个源的并发首读只查一次库（一批 20 条搜索会同时要同一个源的快照）。
  final Map<String, Future<void>> _loads = <String, Future<void>>{};

  // 写入是按最近一次快照算出来的整份映射，所以必须排队落库：并发写会让后到的旧值盖住新值。
  Future<void> _pendingWrite = Future<void>.value();

  /// Makes sure the variables of [sourceUrl] are loaded, and answers once they are.
  ///
  /// Idempotent and single-flight per source: the rule engine calls it before every `@js:` job, and
  /// after the first call it is a completed future.
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
    final SourceVariableRepository? repository = _repository;
    final Map<String, String> stored = repository == null
        ? const <String, String>{}
        : await _readOrEmpty(repository, sourceUrl);
    // 首读失败时留一张空表：重试会拖慢每一个 job，而变量读空只让规则少命中一次缓存。
    _bySource[sourceUrl] = <String, String>{...stored};
  }

  /// Every variable of [sourceUrl], as a job receives it.
  ///
  /// Unmodifiable: a job's writes go through [merge], which is what makes them persist.
  Map<String, String> snapshot(String sourceUrl) =>
      Map<String, String>.unmodifiable(
        _bySource[sourceUrl] ?? const <String, String>{},
      );

  /// Applies the variables a job reported back, keeping the ones it omitted.
  ///
  /// A `null` value removes the key. Called from the bridge for **every** job that touched the
  /// door, successful or not — upstream's writes take effect immediately.
  void merge(String sourceUrl, Map<String, String?> values) {
    if (values.isEmpty) {
      return;
    }
    final Map<String, String> current = _bySource.putIfAbsent(
      sourceUrl,
      () => <String, String>{},
    );
    for (final MapEntry<String, String?> entry in values.entries) {
      final String? value = entry.value;
      if (value == null) {
        current.remove(entry.key);
      } else {
        current[entry.key] = value;
      }
    }

    final SourceVariableRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    _pendingWrite = _pendingWrite.then(
      (_) => _write(repository, sourceUrl, values),
    );
  }

  // 落库失败只记 warning：变量是可再生的小抄，丢了顶多让规则再取一次。
  Future<void> _write(
    SourceVariableRepository repository,
    String sourceUrl,
    Map<String, String?> values,
  ) async {
    try {
      await repository.write(sourceUrl, <String, String?>{...values});
    } on Exception catch (error, stackTrace) {
      _logger?.warning(
        'Could not persist the source variables: source=${redactUrl(sourceUrl)}',
        describeError(error),
        stackTrace,
      );
    }
  }

  Future<Map<String, String>> _readOrEmpty(
    SourceVariableRepository repository,
    String sourceUrl,
  ) async {
    try {
      return await repository.read(sourceUrl);
    } on Exception catch (error, stackTrace) {
      _logger?.warning(
        'Could not read the source variables: source=${redactUrl(sourceUrl)}',
        describeError(error),
        stackTrace,
      );

      return const <String, String>{};
    }
  }
}
