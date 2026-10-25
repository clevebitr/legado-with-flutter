import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/backup_archive_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_test/flutter_test.dart';

/// A contents fixture with every table present and two rows in two of them.
BackupContents _contents() => BackupContents(
  tables:
      <BackupTable, List<Map<String, Object?>>>{
          for (final BackupTable table in BackupTable.values)
            table: <Map<String, Object?>>[],
        }
        ..[BackupTable.books] = <Map<String, Object?>>[
          <String, Object?>{
            'sourceUrl': 'https://a.example',
            'bookUrl': 'https://a.example/book/1',
            'name': '剑来',
          },
        ]
        ..[BackupTable.bookSources] = <Map<String, Object?>>[
          <String, Object?>{
            'url': 'https://a.example',
            'fingerprint': 'abc',
            'payload': '{"bookSourceName":"a"}',
          },
        ],
  preferences: <String, Object?>{
    'settings.themeMode': 1,
    'reader.fontScale': 1.2,
  },
);

/// A zip built from [entries] (name → text), so a test can craft a malformed archive.
Uint8List _zipOf(Map<String, String> entries) {
  final Archive archive = Archive();
  for (final MapEntry<String, String> entry in entries.entries) {
    final List<int> bytes = utf8.encode(entry.value);
    archive.add(ArchiveFile(entry.key, bytes.length, bytes));
  }

  return ZipEncoder().encodeBytes(archive);
}

/// A manifest document with every key valid unless overridden.
String _manifest({
  Object? formatVersion = 1,
  Object? createdAt = '2026-10-25T12:00:00.000Z',
  Object? appVersion = '9.9.9',
}) => jsonEncode(<String, Object?>{
  'formatVersion': formatVersion,
  'createdAt': createdAt,
  'appVersion': appVersion,
});

/// Every file a version 1 archive carries, with the manifest replaced by [manifest].
Map<String, String> _archiveFiles({String? manifest}) => <String, String>{
  backupManifestFileName: manifest ?? _manifest(),
  for (final BackupTable table in BackupTable.values) table.fileName: '[]',
  backupPreferencesFileName: '{}',
};

/// The failure of [result], asserted to be one.
ParseFailure<T> _failureOf<T>(ParseResult<T> result) {
  expect(result, isA<ParseFailure<T>>());

  return result as ParseFailure<T>;
}

void main() {
  group('encodeBackupArchive / decodeBackupArchive', () {
    test('roundTrip_givenEveryTable_writesAndReadsThemBack', () {
      final BackupContents contents = _contents();
      final Uint8List bytes = encodeBackupArchive(
        contents,
        createdAt: DateTime.utc(2026, 10, 25, 12),
        appVersion: '9.9.9',
      );

      final ParseResult<BackupSnapshot> decoded = decodeBackupArchive(bytes);

      final BackupSnapshot snapshot =
          (decoded as ParseSuccess<BackupSnapshot>).data;
      expect(snapshot.manifest.formatVersion, backupFormatVersion);
      expect(snapshot.manifest.createdAt, DateTime.utc(2026, 10, 25, 12));
      expect(snapshot.manifest.appVersion, '9.9.9');
      expect(snapshot.contents.tables, contents.tables);
      expect(snapshot.contents.preferences, contents.preferences);
    });

    test('encodeBackupArchive_givenAnEmptyTable_stillWritesItsFile', () {
      // 空表也写文件：恢复时「本来没数据」与「这份备份更旧、没有这张表」必须能区分。
      final Uint8List bytes = encodeBackupArchive(
        _contents(),
        createdAt: DateTime.utc(2026),
        appVersion: '1',
      );

      final Archive archive = ZipDecoder().decodeBytes(bytes);

      expect(
        archive.map((ArchiveFile file) => file.name),
        containsAll(<String>[
          for (final BackupTable table in BackupTable.values) table.fileName,
          backupManifestFileName,
          backupPreferencesFileName,
        ]),
      );
    });

    test('decodeBackupArchive_givenABrokenZip64Locator_answersNotZip', () {
      // 在 EOCD 前面塞一个 zip64 locator 签名：archive 转去解析 zip64 尾记录并抛 ArchiveException。
      final Uint8List broken = _withBrokenZip64Locator(_zipOf(_archiveFiles()));

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(broken);

      expect(_failureOf(result).rulePath, 'backup.read.notZip');
    });

    test('decodeBackupArchive_givenBytesThatAreNotAZip_answersNoManifest', () {
      // 纯垃圾字节不会让 archive 抛：它解出一个空档案，于是失败落在「没有 manifest」。
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        utf8.encode('not a zip at all'),
      );

      expect(_failureOf(result).rulePath, 'backup.read.manifest');
    });

    test('decodeBackupArchive_givenAnArchiveAboveTheCap_answersSizeLimit', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles()),
        maxArchiveBytes: 8,
      );

      expect(_failureOf(result).rulePath, 'backup.read.sizeLimit');
    });

    test('decodeBackupArchive_givenTooManyEntries_answersEntryCount', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles()),
        maxEntries: 2,
      );

      expect(_failureOf(result).rulePath, 'backup.read.entryCount');
    });

    test('decodeBackupArchive_givenAnEntryAboveTheCap_answersEntrySize', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(appVersion: 'x' * 512))),
        maxEntryBytes: 64,
      );

      expect(_failureOf(result).rulePath, 'backup.read.entrySize');
    });

    test('decodeBackupArchive_givenATotalAboveTheCap_answersTotalSize', () {
      // 单条都没超，合计超了：两个上限都要在解压之前把关。
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(appVersion: 'x' * 200))),
        maxEntryBytes: 4096,
        maxTotalBytes: 64,
      );

      expect(_failureOf(result).rulePath, 'backup.read.totalSize');
    });

    test(
      'decodeBackupArchive_givenTwoEntriesWithTheSameName_answersDuplicate',
      () {
        final Map<String, String> files = _archiveFiles();
        files['nested/${BackupTable.books.fileName}'] = '[]';

        final ParseResult<BackupSnapshot> result = decodeBackupArchive(
          _zipOf(files),
        );

        expect(_failureOf(result).rulePath, 'backup.read.duplicateEntry');
      },
    );

    test('decodeBackupArchive_givenNoManifest_answersManifest', () {
      final Map<String, String> files = _archiveFiles()
        ..remove(backupManifestFileName);

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.manifest');
    });

    test('decodeBackupArchive_givenAnUnreadableManifest_answersItsFile', () {
      final Map<String, String> files = _archiveFiles()
        ..[backupManifestFileName] = '{not json';

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.manifest.json');
    });

    test('decodeBackupArchive_givenANonObjectManifest_answersBadManifest', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: '[]')),
      );

      expect(_failureOf(result).rulePath, 'backup.read.badManifest');
    });

    test('decodeBackupArchive_givenANonIntegerVersion_answersBadManifest', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(formatVersion: '1'))),
      );

      expect(_failureOf(result).rulePath, 'backup.read.badManifest');
    });

    test('decodeBackupArchive_givenANewerFormat_answersUnsupportedRule', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(formatVersion: 2))),
      );

      final ParseFailure<BackupSnapshot> failure = _failureOf(result);
      expect(failure.kind, ParseFailureKind.unsupportedRule);
      expect(failure.rulePath, 'backup.restore.formatVersion');
    });

    test('decodeBackupArchive_givenAVersionBelowOne_answersBadManifest', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(formatVersion: 0))),
      );

      expect(_failureOf(result).rulePath, 'backup.read.badManifest');
    });

    test('decodeBackupArchive_givenAnUnparsableDate_answersBadManifest', () {
      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(_archiveFiles(manifest: _manifest(createdAt: 'yesterday'))),
      );

      expect(_failureOf(result).rulePath, 'backup.read.badManifest');
    });

    test(
      'decodeBackupArchive_givenANonStringAppVersion_answersBadManifest',
      () {
        final ParseResult<BackupSnapshot> result = decodeBackupArchive(
          _zipOf(_archiveFiles(manifest: _manifest(appVersion: 7))),
        );

        expect(_failureOf(result).rulePath, 'backup.read.badManifest');
      },
    );

    test('decodeBackupArchive_givenAMissingTableFile_answersMissingTable', () {
      final Map<String, String> files = _archiveFiles()
        ..remove(BackupTable.rules.fileName);

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.missingTable');
    });

    test(
      'decodeBackupArchive_givenNoPreferencesFile_answersMissingPreferences',
      () {
        final Map<String, String> files = _archiveFiles()
          ..remove(backupPreferencesFileName);

        final ParseResult<BackupSnapshot> result = decodeBackupArchive(
          _zipOf(files),
        );

        expect(_failureOf(result).rulePath, 'backup.read.missingPreferences');
      },
    );

    test('decodeBackupArchive_givenANonArrayTableFile_answersThatFile', () {
      final Map<String, String> files = _archiveFiles()
        ..[BackupTable.books.fileName] = '{"rows":[]}';

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.books.json');
    });

    test('decodeBackupArchive_givenANonObjectRow_answersThatFile', () {
      final Map<String, String> files = _archiveFiles()
        ..[BackupTable.books.fileName] = '["nope"]';

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.books.json');
    });

    test('decodeBackupArchive_givenANonObjectPreferencesFile_answersIt', () {
      final Map<String, String> files = _archiveFiles()
        ..[backupPreferencesFileName] = '[]';

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(
        _zipOf(files),
      );

      expect(_failureOf(result).rulePath, 'backup.read.preferences.json');
    });

    test(
      'decodeBackupArchive_givenEntriesUnderAFolder_readsThemByBaseName',
      () {
        // 用户把备份重新压成「backup2026-10-25/…」也能读：目录前缀不是格式的一部分。
        final Map<String, String> files = <String, String>{
          for (final MapEntry<String, String> entry in _archiveFiles().entries)
            'backup2026-10-25/${entry.key}': entry.value,
        };

        final ParseResult<BackupSnapshot> result = decodeBackupArchive(
          _zipOf(files),
        );

        expect(result, isA<ParseSuccess<BackupSnapshot>>());
      },
    );

    test('decodeBackupArchive_givenALyingUncompressedSize_answersThatFile', () {
      // 中央目录把解压后的大小写小：archive 在解压时抛 ArchiveException，条目照样是「读不出来」。
      final Uint8List bytes = _zipOf(
        _archiveFiles(manifest: _manifest(appVersion: 'x' * 2000)),
      );
      final int centralIndex = _indexOfCentralHeader(
        bytes,
        backupManifestFileName,
      );
      bytes[centralIndex + 24] = 0xFF;
      bytes[centralIndex + 25] = 0x00;
      bytes[centralIndex + 26] = 0x00;
      bytes[centralIndex + 27] = 0x00;

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(bytes);

      expect(_failureOf(result).rulePath, 'backup.read.manifest.json');
    });

    test('decodeBackupArchive_givenCorruptDeflateData_answersThatFile', () {
      final Uint8List bytes = _zipOf(
        _archiveFiles(manifest: _manifest(appVersion: 'x' * 4096)),
      );
      // 找到 manifest 的本地头，把压缩流中间一个字节打坏：解压时 archive 抛 ArchiveException。
      final int headerIndex = _indexOfLocalHeader(
        bytes,
        backupManifestFileName,
      );
      final int nameLength =
          bytes[headerIndex + 26] | (bytes[headerIndex + 27] << 8);
      final int extraLength =
          bytes[headerIndex + 28] | (bytes[headerIndex + 29] << 8);
      bytes[headerIndex + 30 + nameLength + extraLength + 8] ^= 0xFF;

      final ParseResult<BackupSnapshot> result = decodeBackupArchive(bytes);

      expect(_failureOf(result).rulePath, 'backup.read.manifest.json');
    });
  });

  group('encryption', () {
    Uint8List encrypted() => encodeBackupArchive(
      _contents(),
      createdAt: DateTime.utc(2026, 10, 25, 12),
      appVersion: '9.9.9',
      password: 'secret',
    );

    test('isEncryptedBackupArchive_givenAPlainArchive_answersFalse', () {
      final Uint8List bytes = encodeBackupArchive(
        _contents(),
        createdAt: DateTime.utc(2026),
        appVersion: '1',
      );

      expect(isEncryptedBackupArchive(bytes), isFalse);
    });

    test('isEncryptedBackupArchive_givenAnEncryptedArchive_answersTrue', () {
      expect(isEncryptedBackupArchive(encrypted()), isTrue);
    });

    test('isEncryptedBackupArchive_givenGarbage_answersFalse', () {
      expect(isEncryptedBackupArchive(utf8.encode('not a zip')), isFalse);
    });

    test('decodeBackupArchive_givenTheRightPassword_roundTrips', () {
      final ParseResult<BackupSnapshot> decoded = decodeBackupArchive(
        encrypted(),
        password: 'secret',
      );

      expect(decoded, isA<ParseSuccess<BackupSnapshot>>());
      expect(
        (decoded as ParseSuccess<BackupSnapshot>)
            .data
            .contents
            .tables[BackupTable.books],
        hasLength(1),
      );
    });

    test('decodeBackupArchive_givenNoPassword_asksForOne', () {
      final ParseResult<BackupSnapshot> decoded = decodeBackupArchive(
        encrypted(),
      );

      expect(
        (decoded as ParseFailure<BackupSnapshot>).rulePath,
        'backup.read.passwordRequired',
      );
    });

    test('decodeBackupArchive_givenAWrongPassword_answersBadPassword', () {
      final ParseResult<BackupSnapshot> decoded = decodeBackupArchive(
        encrypted(),
        password: 'wrong',
      );

      expect(
        (decoded as ParseFailure<BackupSnapshot>).rulePath,
        'backup.read.badPassword',
      );
    });

    test('decodeBackupArchive_givenAPasswordForAPlainArchive_stillReads', () {
      // 口令不是包的属性：没有加密的包带口令也照读（用户可能记错了哪个是加密的）。
      final Uint8List bytes = encodeBackupArchive(
        _contents(),
        createdAt: DateTime.utc(2026),
        appVersion: '1',
      );

      expect(
        decodeBackupArchive(bytes, password: 'secret'),
        isA<ParseSuccess<BackupSnapshot>>(),
      );
    });
  });

  group('entities', () {
    test('countOf_givenATableWithRows_answersItsLength', () {
      expect(_contents().countOf(BackupTable.bookSources), 1);
    });

    test('countOf_givenAnAbsentTable_answersZero', () {
      const BackupContents contents = BackupContents(
        tables: <BackupTable, List<Map<String, Object?>>>{},
        preferences: <String, Object?>{},
      );

      expect(contents.countOf(BackupTable.books), 0);
    });

    test('totalRows_givenTwoTablesWithRows_sumsThem', () {
      expect(_contents().totalRows, 2);
    });
  });
}

/// The offset of the **central directory** header of [name] inside a zip built by [_zipOf].
int _indexOfCentralHeader(Uint8List bytes, String name) {
  final List<int> needle = utf8.encode(name);
  for (var index = 0; index < bytes.length - needle.length; index++) {
    if (bytes[index] != 0x50 ||
        bytes[index + 1] != 0x4B ||
        bytes[index + 2] != 0x01 ||
        bytes[index + 3] != 0x02) {
      continue;
    }
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (bytes[index + 46 + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return index;
    }
  }

  fail('Central header of $name not found.');
}

/// Writes a zip64 locator signature in front of the EOCD so the decoder must refuse the zip.
///
/// `archive` 4.x 在这里抛 `ArchiveException`（实测），这是 `backup.read.notZip` 唯一能构造出来的
/// 触发路径：普通垃圾字节会被它安静地解成一个空档案，失败落在「没有 manifest」。
Uint8List _withBrokenZip64Locator(Uint8List bytes) {
  for (var index = bytes.length - 22; index >= 20; index--) {
    if (bytes[index] == 0x50 &&
        bytes[index + 1] == 0x4B &&
        bytes[index + 2] == 0x05 &&
        bytes[index + 3] == 0x06) {
      bytes[index - 20] = 0x50;
      bytes[index - 19] = 0x4B;
      bytes[index - 18] = 0x06;
      bytes[index - 17] = 0x07;

      return bytes;
    }
  }

  fail('End of central directory not found.');
}

/// The offset of the local file header of [name] inside a zip built by [_zipOf].
int _indexOfLocalHeader(Uint8List bytes, String name) {
  final List<int> needle = utf8.encode(name);
  for (var index = 0; index < bytes.length - needle.length; index++) {
    if (bytes[index] != 0x50 || bytes[index + 1] != 0x4B) {
      continue;
    }
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (bytes[index + 30 + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return index;
    }
  }

  fail('Local header of $name not found.');
}
