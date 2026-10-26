import 'package:flutter_reader/core/js/js_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calls one cache op on [store].
Object? _call(JsCacheStore store, Map<String, Object?> args) =>
    store.apply(args);

Object? _put(JsCacheStore store, String key, Object? value, {int? saveTime}) =>
    _call(store, <String, Object?>{
      'operation': 'put',
      'key': key,
      'value': value,
      'saveTime': ?saveTime,
    });

Object? _get(JsCacheStore store, String key) =>
    _call(store, <String, Object?>{'operation': 'get', 'key': key});

void main() {
  test('JsCacheStore_givenAValue_putsAndGetsIt', () {
    final JsCacheStore store = JsCacheStore();

    expect(_put(store, 'token', 'abc'), isTrue);
    expect(_get(store, 'token'), 'abc');
    expect(_get(store, 'missing'), isNull);
  });

  test('JsCacheStore_givenANonStringValue_storesItsToString', () {
    final JsCacheStore store = JsCacheStore();

    _put(store, 'n', 42);

    expect(_get(store, 'n'), '42');
    expect(
      _call(store, <String, Object?>{'operation': 'getInt', 'key': 'n'}),
      42,
    );
  });

  test('JsCacheStore_givenAOverlyLongValue_reportsIt', () {
    final JsCacheStore store = JsCacheStore(maxValueLength: 4);

    final Object? answer = _put(store, 'k', 'toolong');

    expect(
      (answer as Map<Object?, Object?>)[jsCacheErrorKey],
      contains('longer than 4 characters'),
    );
    expect(_get(store, 'k'), isNull);
  });

  test('JsCacheStore_givenExpiredEntry_answersNullAndForgetsIt', () {
    // 假时钟：TTL 的验证不能靠 `sleep`。
    int now = 1000;
    final JsCacheStore store = JsCacheStore(clock: () => now);

    _put(store, 'k', 'v', saveTime: 1);
    expect(_get(store, 'k'), 'v');

    now += 1500;

    expect(_get(store, 'k'), isNull);
    expect(store.length, 0);
  });

  test('JsCacheStore_givenMoreThanTheCap_dropsTheOldestKey', () {
    final JsCacheStore store = JsCacheStore(maxEntries: 2);

    _put(store, 'a', '1');
    _put(store, 'b', '2');
    _put(store, 'c', '3');

    expect(store.length, 2);
    expect(_get(store, 'a'), isNull);
    expect(_get(store, 'c'), '3');
  });

  test('JsCacheStore_givenAReadKeyword_refreshesTheEntry', () {
    final JsCacheStore store = JsCacheStore(maxEntries: 2);

    _put(store, 'a', '1');
    _put(store, 'b', '2');
    // 读一次 a，它就不再是最旧的。
    expect(_get(store, 'a'), '1');
    _put(store, 'c', '3');

    expect(_get(store, 'a'), '1');
    expect(_get(store, 'b'), isNull);
  });

  test('JsCacheStore_givenDelete_forgetsTheKey', () {
    final JsCacheStore store = JsCacheStore();

    _put(store, 'k', 'v');

    expect(
      _call(store, <String, Object?>{'operation': 'delete', 'key': 'k'}),
      isTrue,
    );
    expect(_get(store, 'k'), isNull);
  });

  test('JsCacheStore_givenMalformedCall_reportsIt', () {
    final JsCacheStore store = JsCacheStore();

    expect(
      (store.apply('nope') as Map<Object?, Object?>)[jsCacheErrorKey],
      contains('malformed'),
    );
    expect(
      (_call(store, <String, Object?>{'operation': 'get'})
          as Map<Object?, Object?>)[jsCacheErrorKey],
      contains('malformed'),
    );
    expect(
      (_call(store, <String, Object?>{'operation': 'nope', 'key': 'k'})
          as Map<Object?, Object?>)[jsCacheErrorKey],
      contains('is not bound'),
    );
  });

  test('JsCacheStore_givenTypedGetters_readTheStoredText', () {
    final JsCacheStore store = JsCacheStore();
    _put(store, 'i', '7');
    _put(store, 'd', '1.5');
    _put(store, 'x', 'abc');

    expect(
      _call(store, <String, Object?>{'operation': 'getLong', 'key': 'i'}),
      7,
    );
    expect(
      _call(store, <String, Object?>{'operation': 'getDouble', 'key': 'd'}),
      1.5,
    );
    expect(
      _call(store, <String, Object?>{'operation': 'getInt', 'key': 'x'}),
      isNull,
    );
  });

  test('JsCacheStore_givenClear_forgetsEverything', () {
    final JsCacheStore store = JsCacheStore();
    _put(store, 'k', 'v');

    store.clear();

    expect(store.length, 0);
  });
}
