/// Variables shared by `@put:` / `@get:`, `{{name}}` and `java.put` / `java.get`.
///
/// Keyed by book source URL; lives as long as the injected instance.
final class JsVariableStore {
  final Map<String, Map<String, String>> _bySource =
      <String, Map<String, String>>{};

  /// Every variable of [sourceId], as a job receives it.
  ///
  /// The map is unmodifiable; a job's writes go through [merge].
  Map<String, String> snapshot(String sourceId) =>
      Map<String, String>.unmodifiable(
        _bySource[sourceId] ?? const <String, String>{},
      );

  /// The value [sourceId] holds under [key], or `null` when it never wrote one.
  ///
  /// `null` and `''` differ: an absent variable renders as an empty string.
  String? read(String sourceId, String key) => _bySource[sourceId]?[key];

  /// Writes [value] under [key]; a `null` [value] removes the key.
  void write(String sourceId, String key, String? value) {
    final Map<String, String>? current = _bySource[sourceId];
    if (value == null) {
      if (current == null) {
        return;
      }
      current.remove(key);
      if (current.isEmpty) {
        _bySource.remove(sourceId);
      }

      return;
    }

    (current ?? _sourceVariablesFor(sourceId))[key] = value;
  }

  /// Applies the variables a JS job reported back, keeping the ones it omitted.
  ///
  /// A `null` value removes the key.
  void merge(String sourceId, Map<String, String?> values) {
    for (final MapEntry<String, String?> entry in values.entries) {
      write(sourceId, entry.key, entry.value);
    }
  }

  Map<String, String> _sourceVariablesFor(String sourceId) =>
      _bySource.putIfAbsent(sourceId, () => <String, String>{});
}
