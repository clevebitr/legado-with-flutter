import 'package:flutter_reader/core/utils/clock.dart';

/// Rate-limits repeated log lines by a stable key.
///
/// A batch check reads one field per item and one field per chapter, so a source with a broken
/// `tocRule.chapterUrl` used to write the **same** warning once per chapter (1363 lines in one
/// observed run). The line is worth keeping — it names the field that failed — but only once per
/// window; the ones in between are counted and reported on the next line as `suppressed=N`.
///
/// The window is wall-clock based and the caller supplies the [Clock], so a test can pin it
/// (`docs/dev/testing.md` §4). The table is bounded: a session may see many distinct keys, and a
/// log helper must not become a memory leak.
final class LogThrottle {
  /// Creates a throttle whose window defaults to one minute.
  LogThrottle({
    Clock? clock,
    this.window = const Duration(minutes: 1),
    this.capacity = 512,
  }) : _clock = clock ?? const SystemClock();

  final Clock _clock;

  /// How long one key stays silent after it was written.
  final Duration window;

  /// How many distinct keys are remembered before the oldest is forgotten.
  final int capacity;

  // 插入顺序即「最早写入」，超容量时从头部淘汰。
  final Map<String, _Entry> _entries = <String, _Entry>{};

  /// Whether a message with [key] may be written now, and how many were suppressed.
  ///
  /// Returns `null` while the key is inside its window (the message must not be written); on a
  /// write it returns the number of messages suppressed since the previous one, so the caller can
  /// append `suppressed=N` when it is not zero.
  int? admit(String key) {
    final DateTime now = _clock.now();
    final _Entry? previous = _entries.remove(key);
    if (previous != null && now.difference(previous.at) < window) {
      _entries[key] = _Entry(
        at: previous.at,
        suppressed: previous.suppressed + 1,
      );

      return null;
    }

    _entries[key] = _Entry(at: now, suppressed: 0);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }

    return previous?.suppressed ?? 0;
  }
}

/// One key's last write and the count suppressed since.
final class _Entry {
  const _Entry({required this.at, required this.suppressed});

  final DateTime at;
  final int suppressed;
}
