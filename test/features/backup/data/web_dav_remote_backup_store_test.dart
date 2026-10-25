import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/web_dav_client.dart';
import 'package:flutter_reader/features/backup/data/web_dav_remote_backup_store.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_settings.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_backup_stores.dart';

/// A client that answers whatever the test needs and records what it was asked.
final class _RecordingClient implements WebDavClient {
  _RecordingClient({
    this.answer = const ParseSuccess<List<WebDavEntry>>(<WebDavEntry>[]),
    this.downloadBytes = const <int>[],
  });

  final ParseResult<List<WebDavEntry>> answer;
  final List<int> downloadBytes;

  final List<String> calls = <String>[];

  @override
  Future<ParseResult<List<WebDavEntry>>> list({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
  }) async {
    calls.add('list|${credentials.collectionUrl}|$allowPlainHttp');

    return answer;
  }

  @override
  Future<ParseResult<void>> upload({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required List<int> bytes,
  }) async {
    calls.add('upload|$name|${bytes.length}');

    return const ParseSuccess<void>(null);
  }

  @override
  Future<ParseResult<List<int>>> download({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required int maxBytes,
  }) async {
    calls.add('download|$name|$maxBytes');

    return ParseSuccess<List<int>>(downloadBytes);
  }

  @override
  Future<ParseResult<void>> delete({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
  }) async {
    calls.add('delete|$name');

    return const ParseSuccess<void>(null);
  }
}

void main() {
  FakeBackupSettingsRepository configured() => FakeBackupSettingsRepository(
    settings: BackupSettings(
      webDavUrl: 'https://dav.test/backups',
      webDavUsername: 'user',
      hasWebDavPassword: true,
    ),
    webDavPassword: 'secret',
  );

  WebDavRemoteBackupStore storeOver(
    _RecordingClient client,
    FakeBackupSettingsRepository settings, {
    bool allowPlainHttp = false,
  }) => WebDavRemoteBackupStore(
    client: client,
    settings: settings,
    allowPlainHttp: allowPlainHttp,
  );

  group('configuration', () {
    test('list_givenNoUrl_answersNotConfigured', () async {
      final _RecordingClient client = _RecordingClient();

      final ParseResult<List<RemoteBackup>> result = await storeOver(
        client,
        FakeBackupSettingsRepository(),
      ).list();

      expect(
        (result as ParseFailure<List<RemoteBackup>>).rulePath,
        'backup.webdav.list.notConfigured',
      );
      expect(client.calls, isEmpty);
    });

    test('list_givenNoPassword_answersNoPassword', () async {
      final _RecordingClient client = _RecordingClient();

      final ParseResult<List<RemoteBackup>> result = await storeOver(
        client,
        // 不用 const：const 构造会在编译期折叠，域层的构造行就没有执行点（ADR-0019）。
        // ignore: prefer_const_constructors
        FakeBackupSettingsRepository(
          settings: BackupSettings(
            webDavUrl: 'https://dav.test/b',
            webDavUsername: 'u',
          ),
        ),
      ).list();

      expect(
        (result as ParseFailure<List<RemoteBackup>>).rulePath,
        'backup.webdav.list.noPassword',
      );
    });

    test('isConfigured_givenAllFields_isTrue', () async {
      expect(
        await storeOver(_RecordingClient(), configured()).isConfigured(),
        isTrue,
      );
      expect(
        await storeOver(
          _RecordingClient(),
          FakeBackupSettingsRepository(),
        ).isConfigured(),
        isFalse,
      );
    });
  });

  group('list', () {
    test('list_givenServerEntries_keepsOnlyOurNames', () async {
      final _RecordingClient client = _RecordingClient(
        answer: ParseSuccess<List<WebDavEntry>>(<WebDavEntry>[
          WebDavEntry(
            name: 'backup2026-10-25.zip',
            sizeBytes: 10,
            modifiedAt: _epoch,
          ),
          WebDavEntry(name: 'report.zip', sizeBytes: 5, modifiedAt: _epoch),
        ]),
      );

      final ParseResult<List<RemoteBackup>> result = await storeOver(
        client,
        configured(),
      ).list();

      final List<RemoteBackup> backups =
          (result as ParseSuccess<List<RemoteBackup>>).data;
      expect(backups.map((RemoteBackup backup) => backup.name), <String>[
        'backup2026-10-25.zip',
      ]);
      expect(client.calls.single, 'list|https://dav.test/backups|false');
    });

    test('list_givenAClientFailure_passesItThrough', () async {
      final _RecordingClient client = _RecordingClient(
        answer: const ParseFailure<List<WebDavEntry>>(
          kind: ParseFailureKind.networkForbidden,
          rulePath: 'backup.webdav.list',
        ),
      );

      final ParseResult<List<RemoteBackup>> result = await storeOver(
        client,
        configured(),
      ).list();

      expect(
        (result as ParseFailure<List<RemoteBackup>>).kind,
        ParseFailureKind.networkForbidden,
      );
    });
  });

  group('upload / download / delete', () {
    test('upload_givenBytes_sendsOurName', () async {
      final _RecordingClient client = _RecordingClient();

      final ParseResult<void> result = await storeOver(
        client,
        configured(),
      ).upload(name: 'backup2026-10-25.zip', bytes: <int>[1, 2]);

      expect(result, isA<ParseSuccess<void>>());
      expect(client.calls.single, 'upload|backup2026-10-25.zip|2');
    });

    test('upload_givenNoPassword_doesNotCallTheClient', () async {
      final _RecordingClient client = _RecordingClient();

      final ParseResult<void> result = await storeOver(
        client,
        // 不用 const：const 构造会在编译期折叠，域层的构造行就没有执行点（ADR-0019）。
        // ignore: prefer_const_constructors
        FakeBackupSettingsRepository(
          settings: BackupSettings(
            webDavUrl: 'https://dav.test/b',
            webDavUsername: 'u',
          ),
        ),
      ).upload(name: 'a.zip', bytes: <int>[1]);

      expect(
        (result as ParseFailure<void>).rulePath,
        'backup.webdav.upload.noPassword',
      );
      expect(client.calls, isEmpty);
    });

    test('download_givenAnEntry_asksForItWithTheSizeLimit', () async {
      final _RecordingClient client = _RecordingClient(
        downloadBytes: <int>[80, 75],
      );

      final ParseResult<List<int>> result = await storeOver(
        client,
        configured(),
      ).download(RemoteBackup(name: 'a.zip', sizeBytes: 2, modifiedAt: _epoch));

      expect((result as ParseSuccess<List<int>>).data, <int>[80, 75]);
      expect(client.calls.single, startsWith('download|a.zip|'));
    });

    test('delete_givenAnEntry_deletesIt', () async {
      final _RecordingClient client = _RecordingClient();

      final ParseResult<void> result = await storeOver(
        client,
        configured(),
      ).delete(RemoteBackup(name: 'a.zip', sizeBytes: 1, modifiedAt: _epoch));

      expect(result, isA<ParseSuccess<void>>());
      expect(client.calls.single, 'delete|a.zip');
    });

    test('prune_givenMoreArchivesThanTheRetention_deletesTheOldest', () async {
      final _RecordingClient client = _RecordingClient(
        answer: ParseSuccess<List<WebDavEntry>>(<WebDavEntry>[
          WebDavEntry(
            name: 'backup2026-10-25.zip',
            sizeBytes: 1,
            modifiedAt: _epoch,
          ),
          WebDavEntry(
            name: 'backup2026-10-24.zip',
            sizeBytes: 1,
            modifiedAt: _epoch,
          ),
        ]),
      );

      final ParseResult<int> result = await storeOver(
        client,
        configured(),
      ).prune(keep: 1);

      expect((result as ParseSuccess<int>).data, 1);
      expect(client.calls, contains('delete|backup2026-10-24.zip'));
    });

    test('prune_givenAListFailure_answersIt', () async {
      final _RecordingClient client = _RecordingClient(
        answer: const ParseFailure<List<WebDavEntry>>(
          kind: ParseFailureKind.networkFailed,
          rulePath: 'backup.webdav.list',
        ),
      );

      final ParseResult<int> result = await storeOver(
        client,
        configured(),
      ).prune(keep: 1);

      expect(
        (result as ParseFailure<int>).kind,
        ParseFailureKind.networkFailed,
      );
    });

    test('prune_givenNoPassword_answersIt', () async {
      final ParseResult<int> result = await storeOver(
        _RecordingClient(),
        FakeBackupSettingsRepository(),
      ).prune(keep: 1);

      expect(
        (result as ParseFailure<int>).rulePath,
        'backup.webdav.list.notConfigured',
      );
    });
  });
}

final DateTime _epoch = DateTime.utc(1970);
