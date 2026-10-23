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
}
