/// `cache.*` inside the sandbox (M25/S3b).
///
/// Upstream's `CacheManager` is a two-layer cache: an in-memory LRU in front of a **persistent**
/// `Cache` table (`key` / `value` / `deadline`), so a rule can stash a token and read it back after a
/// restart. This repository has no `Cache` table, and this slice does not add one — the store below is
/// memory-only and says so (`book-source.md` §6). It is still worth having: it is what keeps a login
/// token alive across the search → detail → toc → content jobs of one session, which is how the corpus
/// actually uses it.
///
/// Two budgets keep a hostile rule from eating the worker: `maxEntries` and `maxValueLength`.
library;

/// The binding name of the sandbox `cache` object.
const String jsCacheBinding = 'cache';

/// The key an envelope uses to report a failure the rule can read.
const String jsCacheErrorKey = '__error';

/// One `cache.*` store: insertion-ordered map with deadlines and a hard size budget.
///
/// A store lives as long as the worker (one per isolate), not per job: upstream's cache outlives a
/// job too, and `source.getLoginHeader` style flows depend on that.
final class JsCacheStore {
  /// Creates a store.
  JsCacheStore({
    this.maxEntries = 256,
    this.maxValueLength = 64 * 1024,
    int Function()? clock,
  }) : _clock = clock ?? _wallClock;

  /// How many keys stay cached; the least recently written/read one is dropped first.
  final int maxEntries;

  /// The longest value (in code units) a rule may store; longer writes fail readably.
  final int maxValueLength;

  // 插入顺序即「最旧」：命中时删掉再插回，让常用键留在尾部。
  // 过期判断只读这一个时钟：测试用假时钟验证 TTL，生产读墙上时钟。
  final int Function() _clock;

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};

  /// How many keys are currently cached.
  int get length => _entries.length;

  /// Applies one `cache.*` call, answering the value / `true` / `null` / `{jsCacheErrorKey}`.
  Object? apply(Object? args) {
    if (args is! Map) {
      return _failure('malformed cache call');
    }
    final Object? operation = args['operation'];
    final Object? rawKey = args['key'];
    if (operation is! String || operation.isEmpty || rawKey is! String) {
      return _failure('malformed cache call');
    }
    final String key = rawKey;
    try {
      switch (operation) {
        case 'put':
        case 'putMemory':
          final Object? value = args['value'];
          final String text = value is String
              ? value
              : (value?.toString() ?? '');
          if (text.length > maxValueLength) {
            return _failure(
              'cache.$operation value is longer than $maxValueLength characters',
            );
          }
          // `saveTime` 单位是秒（上游语义），0 / 缺省表示不过期。
          final int saveTime = (args['saveTime'] as num?)?.toInt() ?? 0;
          _store(key, text, saveTime);
          return true;
        case 'get':
        case 'getFromMemory':
          final String? value = _read(key);
          return value;
        case 'getInt':
          return int.tryParse(_read(key) ?? '');
        case 'getLong':
          return int.tryParse(_read(key) ?? '');
        case 'getDouble':
          return double.tryParse(_read(key) ?? '');
        case 'delete':
        case 'deleteMemory':
          _entries.remove(key);
          return true;
        default:
          return _failure('cache.$operation is not bound');
      }
    } on FormatException catch (error) {
      return _failure(error.message);
    }
  }

  /// Forgets everything; called when the worker is rebuilt.
  void clear() => _entries.clear();

  void _store(String key, String value, int saveTimeSeconds) {
    final int deadline = saveTimeSeconds <= 0
        ? 0
        : _clock() + saveTimeSeconds * 1000;
    _entries.remove(key);
    _entries[key] = _CacheEntry(value, deadline);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  String? _read(String key) {
    final _CacheEntry? entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (entry.isExpired(_clock())) {
      // 过期的键当场删掉：上游的 `get` 也只看 deadline，但它留着行等下次写覆盖。
      _entries.remove(key);
      return null;
    }
    // 命中即刷新 LRU 位置。
    _entries
      ..remove(key)
      ..[key] = entry;

    return entry.value;
  }

  Map<String, Object?> _failure(String message) => <String, Object?>{
    jsCacheErrorKey: message,
  };
}

int _wallClock() => DateTime.now().millisecondsSinceEpoch;

final class _CacheEntry {
  const _CacheEntry(this.value, this.deadline);

  final String value;

  /// Absolute deadline in milliseconds, or `0` for "never expires".
  final int deadline;

  bool isExpired(int now) => deadline != 0 && deadline <= now;
}
