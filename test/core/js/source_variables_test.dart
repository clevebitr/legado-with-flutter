import 'dart:async';

import 'package:flutter_reader/core/js/source_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../support/fake_log_printer.dart';

/// A repository whose answers a test controls.
final class _FakeRepository implements SourceVariableRepository {
  /// What [read] answers, per source.
  final Map<String, Map<String, String>> stored =
      <String, Map<String, String>>{};

  /// Every [write] call, in order.
  final List<MapEntry<String, Map<String, String?>>> writes =
      <MapEntry<String, Map<String, String?>>>[];

  /// How many times [read] was asked (single-flight proof).
  int reads = 0;

  /// When set, [read] waits for it first.
  Completer<void>? gate;

  /// When true, both operations throw instead of answering.
  bool fail = false;

  @override
  Future<Map<String, String>> read(String sourceUrl) async {
    reads++;
    final Completer<void>? waiting = gate;
    if (waiting != null) {
      await waiting.future;
    }
    if (fail) {
      throw const FormatException('broken storage');
    }

    return stored[sourceUrl] ?? const <String, String>{};
  }

  @override
  Future<void> write(String sourceUrl, Map<String, String?> values) async {
    writes.add(MapEntry<String, Map<String, String?>>(sourceUrl, values));
    if (fail) {
      throw const FormatException('broken storage');
    }
  }
}

void main() {
  group('SourceVariableStore', () {
    test('ensureLoaded_givenANewSource_hydratesItFromTheRepository', () async {
      final _FakeRepository repository = _FakeRepository()
        ..stored['https://a.test'] = <String, String>{'token': 'abc'};
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
      );

      expect(store.snapshot('https://a.test'), isEmpty);
      await store.ensureLoaded('https://a.test');

      expect(store.snapshot('https://a.test'), <String, String>{
        'token': 'abc',
      });
    });

    test('ensureLoaded_whenCalledConcurrently_readsOnce', () async {
      // 一批 20 条搜索会同时问同一个源的变量：首读必须只查一次库。
      final _FakeRepository repository = _FakeRepository();
      final Completer<void> gate = Completer<void>();
      repository.gate = gate;
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
      );

      final Future<void> first = store.ensureLoaded('https://a.test');
      final Future<void> second = store.ensureLoaded('https://a.test');
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.reads, 1);
    });

    test('ensureLoaded_afterTheFirstLoad_doesNotTouchStorageAgain', () async {
      final _FakeRepository repository = _FakeRepository();
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
      );

      await store.ensureLoaded('https://a.test');
      await store.ensureLoaded('https://a.test');

      expect(repository.reads, 1);
    });

    test('ensureLoaded_givenAStorageFailure_seedsAnEmptyMap', () async {
      // 读失败不能拖慢每一个 job：留一张空表，规则只是少命中一次缓存。
      final FakeLogPrinter printer = FakeLogPrinter();
      final _FakeRepository repository = _FakeRepository()..fail = true;
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );

      await store.ensureLoaded('https://a.test');

      expect(store.snapshot('https://a.test'), isEmpty);
      expect(printer.events, hasLength(1));
    });

    test('snapshot_whenTheJobWrites_keepsTheStoredValues', () async {
      // 快照是不可变的：job 的写入走 merge，否则「写穿」会被悄悄绕过。
      final SourceVariableStore store = SourceVariableStore();
      await store.ensureLoaded('https://a.test');
      final Map<String, String> snapshot = store.snapshot('https://a.test');

      expect(() => snapshot['x'] = 'y', throwsUnsupportedError);
    });

    test('merge_givenAValue_writesItThrough', () async {
      final _FakeRepository repository = _FakeRepository();
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
      );
      await store.ensureLoaded('https://a.test');

      store.merge('https://a.test', <String, String?>{'token': 'abc'});
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), <String, String>{
        'token': 'abc',
      });
      expect(repository.writes.single.value, <String, String?>{'token': 'abc'});
    });

    test('merge_givenANullValue_removesTheKey', () async {
      final SourceVariableStore store = SourceVariableStore();
      await store.ensureLoaded('https://a.test');
      store.merge('https://a.test', <String, String?>{'token': 'abc'});

      store.merge('https://a.test', <String, String?>{'token': null});

      expect(store.snapshot('https://a.test'), isEmpty);
    });

    test('merge_givenNothing_doesNotWrite', () async {
      final _FakeRepository repository = _FakeRepository();
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
      );
      await store.ensureLoaded('https://a.test');

      store.merge('https://a.test', const <String, String?>{});
      await pumpEventQueue();

      expect(repository.writes, isEmpty);
    });

    test('merge_givenAStorageFailure_logsItAndKeepsTheValue', () async {
      // 变量是小抄：写不进库只记 warning，job 的结果不受影响。
      final FakeLogPrinter printer = FakeLogPrinter();
      final _FakeRepository repository = _FakeRepository();
      final SourceVariableStore store = SourceVariableStore(
        repository: repository,
        logger: AppLogger(level: LogLevel.debug, printer: printer),
      );
      await store.ensureLoaded('https://a.test');
      repository.fail = true;

      store.merge('https://a.test', <String, String?>{'token': 'abc'});
      await pumpEventQueue();

      expect(store.snapshot('https://a.test'), <String, String>{
        'token': 'abc',
      });
      expect(printer.events.single.level, Level.warning);
    });

    test('merge_givenTwoWritesInARow_persistsThemInOrder', () async {
      // 写入是按快照算出来的整份映射，乱序落库会让后到的旧值盖住新值。
      final List<Map<String, String?>> written = <Map<String, String?>>[];
      final SourceVariableStore store = SourceVariableStore(
        repository: _OrderedRepository(written),
      );
      await store.ensureLoaded('https://a.test');

      store.merge('https://a.test', <String, String?>{'a': '1'});
      store.merge('https://a.test', <String, String?>{'b': '2'});
      await pumpEventQueue();
      await pumpEventQueue();

      expect(written, <Map<String, String?>>[
        <String, String?>{'a': '1'},
        <String, String?>{'b': '2'},
      ]);
    });
  });
}

/// A repository that records every write in the order they reached it.
final class _OrderedRepository implements SourceVariableRepository {
  _OrderedRepository(this.written);

  final List<Map<String, String?>> written;

  @override
  Future<Map<String, String>> read(String sourceUrl) async =>
      const <String, String>{};

  @override
  Future<void> write(String sourceUrl, Map<String, String?> values) async {
    written.add(values);
  }
}
