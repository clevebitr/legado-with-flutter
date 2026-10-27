import 'package:flutter_reader/core/js/js_helpers.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/redaction.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';

// 私有字段不能做具名初始化形参（Dart 限制），手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

/// The stable per-install identifier `java.androidId` answers with (M25/S3b).
///
/// Upstream returns Android's `Settings.Secure.ANDROID_ID` — a 64-bit hex value that is stable for
/// one app install on one device. This repository runs on Windows and iOS too and has no such id, so
/// it keeps its own: a random v4 UUID generated on first use and stored in the lightweight
/// preference store (a switch-sized value, not a record — C-DEP-2 only forbids putting *data* there).
///
/// **Registered difference** (`book-source.md` §6): the value is a UUID, not a 16-hex-digit Android
/// id. A rule that merely needs「a stable id」works; one that parses the Android format does not.
///
/// Where the install id lives: one short string, kept for as long as the app is installed.
abstract interface class InstallIdStore {
  /// The stored id, or `null` when this install never generated one.
  String? read();

  /// Stores [id] for the next launch.
  Future<void> write(String id);
}

/// [InstallIdStore] on top of the lightweight preference store.
///
/// A switch-sized value, not a record: `shared_preferences` is exactly what C-DEP-2 allows it for.
final class PreferenceInstallIdStore implements InstallIdStore {
  /// Creates the store on top of `PreferenceStore`.
  const PreferenceInstallIdStore(this._preferences);

  final PreferenceStore _preferences;

  @override
  String? read() => _preferences.readString(InstallId.preferenceKey);

  @override
  Future<void> write(String id) =>
      _preferences.writeString(InstallId.preferenceKey, id);
}

/// Hydration is explicit so the sandbox can read it **synchronously** later: `main()` awaits
/// [hydrate] before the first frame, exactly like the cookie jar (ADR-0068 §决策 4). Until it has
/// run, [value] is `null` and `java.androidId()` answers `''`.
final class InstallId {
  /// Creates an unhydrated holder.
  InstallId({AppLogger? logger}) : _logger = logger;

  /// The preference key the id lives under.
  static const String preferenceKey = 'install.id';

  final AppLogger? _logger;

  String? _value;

  /// The id, or `null` before [hydrate] has run.
  String? get value => _value;

  /// Reads the stored id, generating and storing one on first launch.
  ///
  /// A store that cannot be written still answers the generated id for this session: losing it only
  /// means the next launch looks like a new install, which a rule that pins a token to it would
  /// notice — worth a warning, not a crash.
  Future<void> hydrate(InstallIdStore store) async {
    final String? stored = store.read();
    if (stored != null && stored.trim().isNotEmpty) {
      _value = stored.trim();

      return;
    }
    final String generated = randomUuid();
    _value = generated;
    try {
      await store.write(generated);
    } on Exception catch (error, stackTrace) {
      _logger?.warning(
        'Could not persist the install id: key=${redactUrl(preferenceKey)}',
        describeError(error),
        stackTrace,
      );
    }
  }
}
