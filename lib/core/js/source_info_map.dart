import 'dart:collection';

/// The per-source **info map** a rule reads as `infoMap` (`docs/dev/book-source.md` §6, M25/S3b).
///
/// Upstream keeps one `InfoMap` per source URL (`CacheManager` key `infoMap_<url>`, `InfoMap.kt:10-40`)
/// and hands the **same object** to every explore rule, so a token computed while one category loads
/// is still there when the next one loads. Our sandbox lives in an isolate that cannot hold a live
/// host object, so the map travels the way the other source state does: a snapshot goes down with the
/// job, the rule mutates its own copy, and the bridge merges what came back.
///
/// **Memory only**, exactly like `cache.*`: there is no `Cache` row to write to, so the values are
/// kept for the session and are gone after a restart. That is the registered difference
/// (`book-source.md` §6); the trigger for adding persistence is a source that needs a value across
/// launches.
final class SourceInfoMapStore {
  /// How many sources keep their map; the oldest one is dropped past this bound.
  ///
  /// An explore map is a handful of short strings, and only sources with an `exploreUrl` ever have
  /// one — the bound exists so a session that browses hundreds of sources cannot grow without end.
  static const int maxSources = 32;

  // 访问顺序即 LRU 顺序：刚用过（读或写）的源排到最后。
  final LinkedHashMap<String, Map<String, String>> _bySource =
      LinkedHashMap<String, Map<String, String>>();

  /// The map of [sourceUrl] as a job receives it; an absent source answers an empty map.
  Map<String, String> snapshot(String sourceUrl) {
    final Map<String, String>? stored = _bySource.remove(sourceUrl);
    if (stored == null) {
      return const <String, String>{};
    }
    _bySource[sourceUrl] = stored;

    return Map<String, String>.unmodifiable(stored);
  }

  /// Applies what a job reported back; a `null` value deletes the key.
  void merge(String sourceUrl, Map<String, String?> values) {
    if (values.isEmpty) {
      return;
    }
    final Map<String, String> current =
        _bySource.remove(sourceUrl) ?? <String, String>{};
    _bySource[sourceUrl] = current;
    for (final MapEntry<String, String?> entry in values.entries) {
      final String? value = entry.value;
      if (value == null) {
        current.remove(entry.key);
      } else {
        current[entry.key] = value;
      }
    }
    while (_bySource.length > maxSources) {
      _bySource.remove(_bySource.keys.first);
    }
  }
}
