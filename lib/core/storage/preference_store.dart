import 'package:shared_preferences/shared_preferences.dart';

/// Typed access to the key-value store for light switches (C-NET-9).
///
/// Mechanism only: **which** key carries **which** setting belongs to the feature's `data/`
/// layer (`features/settings/data/`), so this class knows no setting names. Keeping
/// `shared_preferences` behind one seam also keeps it out of `domain/` and `presentation/`
/// (C-NET-7) and gives the settings tests a single thing to fake.
final class PreferenceStore {
  /// Creates a store on top of the platform preferences instance.
  const PreferenceStore(this._preferences);

  final SharedPreferences _preferences;

  /// The stored `int` under [key], or `null` when absent or of another type.
  ///
  /// It reads the raw value and narrows it, instead of calling `getInt`/`getDouble`: the typed
  /// getters **cast** and throw a `TypeError` (an `Error`, forbidden to catch — ADR-0022) when a
  /// key holds another type, and a hand-edited store must not crash the app.
  int? readInt(String key) => _narrow<int>(key);

  /// The stored `double` under [key], or `null` when absent or of another type.
  double? readDouble(String key) => _narrow<double>(key);

  /// The stored `String` under [key], or `null` when absent or of another type.
  String? readString(String key) => _narrow<String>(key);

  /// The stored `bool` under [key], or `null` when absent or of another type.
  ///
  /// Same narrowing rationale as the other readers: the typed getters cast and throw, and a view
  /// flag must fall back to its default instead of crashing the list.
  bool? readBool(String key) => _narrow<bool>(key);

  /// The stored value under [key] when it is a [T], else `null`.
  T? _narrow<T>(String key) {
    final Object? value = _preferences.get(key);

    return value is T ? value : null;
  }

  /// Stores [value] under [key].
  ///
  /// The boolean answer of `shared_preferences` is deliberately dropped: a failed write leaves
  /// the previous value in place, and the settings page re-reads the store after every write, so
  /// the UI shows what is actually stored rather than what was asked for.
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
}
