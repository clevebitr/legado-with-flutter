import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecretStore] backed by the platform key store (`ADR-0074` §决策 5).
///
/// Android: Keystore-encrypted preferences; Windows: DPAPI; iOS/macOS: Keychain. The plugin also
/// ships a Linux implementation (libsecret) and a web one, neither of which this project ships.
///
/// The three calls are injectable so the error handling below is ordinary testable Dart — a
/// `MethodChannel` does not exist in the host VM.
final class FlutterSecureStorageSecretStore implements SecretStore {
  /// Creates the store; the callbacks default to the plugin.
  FlutterSecureStorageSecretStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    this._logger,
    SecretReader? read,
    SecretWriter? write,
    SecretDeleter? delete,
  }) : // 单行闭包默认值：插件的三个方法签名带具名参数，直接当 tear-off 类型不匹配。
       _read = read ?? ((String key) => storage.read(key: key)),
       _write =
           write ??
           ((String key, String value) =>
               storage.write(key: key, value: value)),
       _delete = delete ?? ((String key) => storage.delete(key: key));

  final AppLogger? _logger;
  final SecretReader _read;
  final SecretWriter _write;
  final SecretDeleter _delete;

  @override
  Future<String?> read(String key) async {
    try {
      return await _read(key);
    } on PlatformException catch (error, stackTrace) {
      _logger?.warning('Reading a secret failed.', error, stackTrace);

      return null;
    }
  }

  @override
  Future<bool> write(String key, String value) async {
    try {
      await _write(key, value);

      return true;
    } on PlatformException catch (error, stackTrace) {
      // 企业策略禁用 Keystore / CI 没有 DPAPI 时会走到这里：页面据此提示「备份未加密」。
      _logger?.warning('Writing a secret failed.', error, stackTrace);

      return false;
    }
  }

  @override
  Future<bool> delete(String key) async {
    try {
      await _delete(key);

      return true;
    } on PlatformException catch (error, stackTrace) {
      _logger?.warning('Deleting a secret failed.', error, stackTrace);

      return false;
    }
  }
}

/// Reads one secret from the platform store.
typedef SecretReader = Future<String?> Function(String key);

/// Writes one secret to the platform store.
typedef SecretWriter = Future<void> Function(String key, String value);

/// Deletes one secret from the platform store.
typedef SecretDeleter = Future<void> Function(String key);
