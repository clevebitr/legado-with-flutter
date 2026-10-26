import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/web_dav_client.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_settings_repository.dart';
import 'package:flutter_reader/features/backup/domain/repositories/remote_backup_store.dart';

/// [RemoteBackupStore] on top of the WebDAV client (`docs/dev/roadmap.md` M22, ADR-0074 §决策 6).
///
/// Settings and the password are read on **every** call: the page can change the URL, the user name or
/// the password without the store holding a stale copy, and a missing password is reported as such
/// instead of producing a 401.
final class WebDavRemoteBackupStore implements RemoteBackupStore {
  /// Creates the store.
  const WebDavRemoteBackupStore({
    required this._client,
    required this._settings,
    required this._allowPlainHttp,
  });

  final WebDavClient _client;
  final BackupSettingsRepository _settings;
  final bool _allowPlainHttp;

  @override
  Future<bool> isConfigured() async =>
      (await _settings.load()).isWebDavConfigured;

  @override
  Future<ParseResult<List<RemoteBackup>>> list() async {
    final ParseResult<WebDavCredentials> credentials = await _credentialsOf(
      'backup.webdav.list',
    );
    if (credentials case ParseFailure<WebDavCredentials>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<List<RemoteBackup>>(kind: kind, rulePath: rulePath);
    }

    final ParseResult<List<WebDavEntry>> listed = await _client.list(
      credentials: (credentials as ParseSuccess<WebDavCredentials>).data,
      allowPlainHttp: _allowPlainHttp,
    );

    return switch (listed) {
      ParseSuccess<List<WebDavEntry>>(:final List<WebDavEntry> data) =>
        ParseSuccess<List<RemoteBackup>>(<RemoteBackup>[
          for (final WebDavEntry entry in data)
            // 同一个集合里可能有别人的文件：只认本应用的命名（ADR-0074 §决策 2）。
            if (backupFilePattern.hasMatch(entry.name))
              RemoteBackup(
                name: entry.name,
                sizeBytes: entry.sizeBytes,
                modifiedAt: entry.modifiedAt,
              ),
        ]),
      ParseFailure<List<WebDavEntry>>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<RemoteBackup>>(kind: kind, rulePath: rulePath),
    };
  }

  @override
  Future<ParseResult<void>> upload({
    required String name,
    required List<int> bytes,
  }) async {
    final ParseResult<WebDavCredentials> credentials = await _credentialsOf(
      'backup.webdav.upload',
    );
    if (credentials case ParseFailure<WebDavCredentials>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<void>(kind: kind, rulePath: rulePath);
    }

    return _client.upload(
      credentials: (credentials as ParseSuccess<WebDavCredentials>).data,
      allowPlainHttp: _allowPlainHttp,
      name: name,
      bytes: bytes,
    );
  }

  @override
  Future<ParseResult<List<int>>> download(RemoteBackup backup) async {
    final ParseResult<WebDavCredentials> credentials = await _credentialsOf(
      'backup.webdav.download',
    );
    if (credentials case ParseFailure<WebDavCredentials>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<List<int>>(kind: kind, rulePath: rulePath);
    }

    return _client.download(
      credentials: (credentials as ParseSuccess<WebDavCredentials>).data,
      allowPlainHttp: _allowPlainHttp,
      name: backup.name,
      maxBytes: maxBackupArchiveBytes,
    );
  }

  @override
  Future<ParseResult<void>> delete(RemoteBackup backup) async {
    final ParseResult<WebDavCredentials> credentials = await _credentialsOf(
      'backup.webdav.delete',
    );
    if (credentials case ParseFailure<WebDavCredentials>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<void>(kind: kind, rulePath: rulePath);
    }

    return _client.delete(
      credentials: (credentials as ParseSuccess<WebDavCredentials>).data,
      allowPlainHttp: _allowPlainHttp,
      name: backup.name,
    );
  }

  @override
  Future<ParseResult<int>> prune({required int keep}) async {
    final ParseResult<List<RemoteBackup>> listed = await list();
    if (listed case ParseFailure<List<RemoteBackup>>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<int>(kind: kind, rulePath: rulePath);
    }

    final List<RemoteBackup> backups =
        (listed as ParseSuccess<List<RemoteBackup>>).data;
    var removed = 0;
    for (final RemoteBackup backup in backups.skip(keep < 0 ? 0 : keep)) {
      final ParseResult<void> deleted = await delete(backup);
      if (deleted is ParseFailure<void>) {
        // 远端删除失败不阻塞本地备份：记下第一处失败，让页面能看到。
        return failureAt<int>(kind: deleted.kind, rulePath: deleted.rulePath);
      }
      removed += 1;
    }

    return ParseSuccess<int>(removed);
  }

  /// The credentials of the cloud side, or a failure naming what is missing.
  Future<ParseResult<WebDavCredentials>> _credentialsOf(String rulePath) async {
    final BackupSettings settings = await _settings.load();
    if (!settings.isWebDavConfigured) {
      return failureAt<WebDavCredentials>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$rulePath.notConfigured',
      );
    }
    final String? password = await _settings.readWebDavPassword();
    if (password == null || password.isEmpty) {
      return failureAt<WebDavCredentials>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: '$rulePath.noPassword',
      );
    }

    return ParseSuccess<WebDavCredentials>(
      WebDavCredentials(
        collectionUrl: settings.webDavUrl,
        username: settings.webDavUsername,
        password: password,
      ),
    );
  }
}
