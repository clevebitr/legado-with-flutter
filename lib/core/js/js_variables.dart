/// The variables `@put:` / `@get:`, `{{name}}` and `java.put` / `java.get` share
/// (`docs/dev/book-source.md` §4 and §6; matrix #16, #17, #18).
///
/// Upstream keeps a rule variable on the object the rule belongs to (`AnalyzeRule.put`
/// writes to `chapter` / `book` / `ruleData` / `source`, `AnalyzeRule.kt:801-810`), so a
/// value written while reading one book source can be read while reading that same source
/// later — including from JavaScript, whose `java` binding is that very object
/// (`AnalyzeRule.kt:835`). This store keeps the same keying, the **book source URL**, and
/// the same ability to cross the JS boundary, but not upstream's persistence: it lives as
/// long as the injected instance, which is the provider scope (ADR-0034 §决策 2).
///
/// It is deliberately **not** shared mutable global state in the sense C-SRC-9 forbids:
/// the map belongs to one injected object, every method is synchronous — so an
/// interleaved evaluation can never observe a half-applied update — and the sandbox stays
/// free of it, because JavaScript reads a snapshot the job carries rather than this map
/// (ADR-0034 §决策 1).
final class JsVariableStore {
  final Map<String, Map<String, String>> _bySource =
      <String, Map<String, String>>{};

  /// Every variable of [sourceId] as a job receives it, or an empty map when the source
  /// has none.
  ///
  /// The returned map is unmodifiable: a script's writes travel back with the job's
  /// result and are applied by [merge], so nothing outside this class can mutate the
  /// store behind its back.
  Map<String, String> snapshot(String sourceId) =>
      Map<String, String>.unmodifiable(
        _bySource[sourceId] ?? const <String, String>{},
      );

  /// The value [sourceId] holds under [key], or `null` when it never wrote one.
  ///
  /// `null` and `''` are deliberately different: `@get:` / `{{name}}` render an absent
  /// variable as an empty string (`book-source.md` §4), while an empty value is a value a
  /// rule chose to write.
  String? read(String sourceId, String key) => _bySource[sourceId]?[key];

  /// Writes [value] under [key] for [sourceId]; a `null` [value] removes the key
  /// (upstream's `putVariable(key, null)`, `RuleDataInterface.kt:8-14`).
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

  /// Applies the variables a JavaScript job reported back, keeping the ones it did not
  /// mention.
  ///
  /// The worker answers with its whole per-source map, not a diff, so an untouched key is
  /// simply carried over. That is why this is a merge and not a replacement: a job must
  /// never erase a variable another job wrote in the meantime. A `null` value removes the
  /// key, which is how a script spells "forget it".
  void merge(String sourceId, Map<String, String?> values) {
    for (final MapEntry<String, String?> entry in values.entries) {
      write(sourceId, entry.key, entry.value);
    }
  }

  /// The mutable map of [sourceId], created on first write.
  Map<String, String> _sourceVariablesFor(String sourceId) =>
      _bySource.putIfAbsent(sourceId, () => <String, String>{});
}
