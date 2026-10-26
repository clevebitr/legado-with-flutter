import 'package:flutter_reader/core/logging/app_logger.dart';

/// Device-level secret storage (`docs/dev/roadmap.md` M22, ADR-0074 §决策 5).
///
/// The two values this project keeps here are the backup password and the WebDAV password: they must
/// not travel inside the backup itself (ADR-0074 §决策 5) and must not sit in `shared_preferences`
/// next to the non-secret settings.
///
/// Implementations never throw: a platform without a key store answers “not stored”, which the caller
/// turns into a visible warning instead of a crash (the same contract as the other platform ports).
abstract interface class SecretStore {
  /// The stored value of [key], or `null` when it is absent or unreadable.
  Future<String?> read(String key);

  /// Stores [value] under [key]; answers whether it was written.
  Future<bool> write(String key, String value);

  /// Removes [key]; answers whether the store is now free of it.
  Future<bool> delete(String key);
}

/// The fallback for a platform with no key store: writes are dropped, reads answer `null`.
///
/// A written-then-lost password is the one failure mode this cannot hide, so every write logs a
/// warning and answers `false` — the page then says the backup stays unencrypted instead of pretending
/// it was protected.
final class UnsupportedSecretStore implements SecretStore {
  /// Creates the fallback.
  const UnsupportedSecretStore({required this._logger});

  final AppLogger _logger;

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<bool> write(String key, String value) async {
    _logger.warning(
      'No secret store is available; the value under "$key" was not stored.',
    );

    return false;
  }

  @override
  Future<bool> delete(String key) async => true;
}
