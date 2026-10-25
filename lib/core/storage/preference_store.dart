import 'package:shared_preferences/shared_preferences.dart';

/// Typed access to the key-value store for light switches.
///
/// Knows no setting names; which key carries which setting belongs to the feature.
final class PreferenceStore {
  /// Creates a store on top of the platform preferences instance.
  const PreferenceStore(this._preferences);

  final SharedPreferences _preferences;

  /// The stored `int` under [key], or `null` when absent or of another type.
  int? readInt(String key) => _narrow<int>(key);

  /// The stored `double` under [key], or `null` when absent or of another type.
  double? readDouble(String key) => _narrow<double>(key);

  /// The stored `String` under [key], or `null` when absent or of another type.
  String? readString(String key) => _narrow<String>(key);

  /// The stored `bool` under [key], or `null` when absent or of another type.
  bool? readBool(String key) => _narrow<bool>(key);

  // 用 is 检查而不是 typed getter：后者会强转并抛 TypeError，损坏的存储不应让 App 崩溃。
  T? _narrow<T>(String key) {
    final Object? value = _preferences.get(key);

    return value is T ? value : null;
  }

  /// Stores [value] under [key].
  Future<void> writeInt(String key, int value) async {
    await _preferences.setInt(key, value);
  }

  /// Stores [value] under [key].
  Future<void> writeDouble(String key, double value) async {
    await _preferences.setDouble(key, value);
  }

  /// Stores [value] under [key].
  Future<void> writeString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  /// Stores [value] under [key].
  Future<void> writeBool(String key, bool value) async {
    await _preferences.setBool(key, value);
  }

  /// Removes [key], if present.
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }

  /// Every stored value that belongs to the preferences value domain
  /// (`docs/dev/roadmap.md` M22, ADR-0073 §决策 4).
  ///
  /// Used by the backup: it lets the zip carry the settings without the backup feature knowing any
  /// `settings.*` / `reader.*` key name, so a setting added later is backed up automatically. Keys
  /// whose value is outside the domain (a `List<Object?>`, a nested map) are left out: they cannot be
  /// written back, and carrying them would only make the file harder to read.
  Map<String, Object?> snapshot() {
    final Map<String, Object?> values = <String, Object?>{};
    for (final String key in _preferences.getKeys()) {
      final Object? value = _preferences.get(key);
      if (_isStorable(value)) {
        values[key] = value;
      }
    }

    return values;
  }

  /// Writes every entry of [values] this store can hold, leaving other keys untouched.
  ///
  /// Restoring is a merge, never a wipe (ADR-0073 §决策 3): a key absent from [values] keeps its
  /// current value, so an old backup cannot silently delete a setting it never knew about.
  ///
  /// Answers how many keys were written, which is what the restore report counts.
  Future<int> writeAll(Map<String, Object?> values) async {
    var written = 0;
    for (final MapEntry<String, Object?> entry in values.entries) {
      final Object? value = entry.value;
      switch (value) {
        case final bool flag:
          await _preferences.setBool(entry.key, flag);
        case final int number:
          await _preferences.setInt(entry.key, number);
        case final double number:
          await _preferences.setDouble(entry.key, number);
        case final String text:
          await _preferences.setString(entry.key, text);
        case final List<Object?> list
            when list.every((Object? item) => item is String):
          // JSON 解码得到的是 `List<dynamic>`，元素类型在这里窄化成 `List<String>`。
          await _preferences.setStringList(entry.key, list.cast<String>());
        // null 与不属于值域的类型跳过：写不进去的值不该让整次恢复失败。
        default:
          continue;
      }
      written += 1;
    }

    return written;
  }

  // 只有 shared_preferences 自己支持的值类型才进快照，判断标准与 writeAll 的写回分支一一对应。
  bool _isStorable(Object? value) => switch (value) {
    bool() || int() || double() || String() => true,
    final List<Object?> list => list.every((Object? item) => item is String),
    _ => false,
  };
}
