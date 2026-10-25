import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_manifest.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_snapshot.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';

/// The backup archive format: one zip with `manifest.json`, one JSON file per table and
/// `preferences.json` (`docs/dev/roadmap.md` M22, ADR-0073 §决策 2).
///
/// Both directions live here on purpose: the format is one specification, and splitting reader and
/// writer is how a round trip starts to disagree with itself (the same stance as
/// `replace_rule_exchange.dart`).
///
/// The rows are **plain JSON objects keyed by table column name**; this file never interprets a
/// column, it only moves them. Identities, merges and defaults belong to the data layer.

/// Writes [contents] into one zip archive.
Uint8List encodeBackupArchive(
  BackupContents contents, {
  required DateTime createdAt,
  required String appVersion,
}) {
  final Archive archive = Archive();

  void addDocument(String name, Object? document) {
    final List<int> bytes = utf8.encode(jsonEncode(document));
    // `archive` 4.x 的 `ArchiveFile(name, size, data)` 直接持有内存内容，编码时才压缩。
    archive.add(ArchiveFile(name, bytes.length, bytes));
  }

  addDocument(backupManifestFileName, <String, Object?>{
    'formatVersion': backupFormatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'tables': <String>[
      for (final BackupTable table in BackupTable.values) table.fileName,
    ],
    'preferences': backupPreferencesFileName,
  });
  for (final BackupTable table in BackupTable.values) {
    // 空表也写文件：这样「这张表本来就没数据」与「这份备份更旧、没有这张表」不会混为一谈。
    addDocument(
      table.fileName,
      contents.tables[table] ?? const <Map<String, Object?>>[],
    );
  }
  addDocument(backupPreferencesFileName, contents.preferences);

  return ZipEncoder().encodeBytes(archive);
}

/// Reads one archive, refusing anything this build does not understand.
///
/// Failures are [ParseFailure]s, never exceptions (C-ERR-1):
/// `backup.read.notZip` / `.sizeLimit` / `.entryCount` / `.entrySize` / `.totalSize` /
/// `.duplicateEntry` / `.manifest` / `.badManifest` / `.missingTable` / `.missingPreferences` /
/// `.badRow` (suffixed with the table's file name), and `backup.restore.formatVersion` for a newer
/// format.
ParseResult<BackupSnapshot> decodeBackupArchive(
  List<int> bytes, {
  // 上限可注入只为了让测试用几十字节验证拒绝分支；生产调用一律用默认值。
  int maxArchiveBytes = maxBackupArchiveBytes,
  int maxEntryBytes = maxBackupEntryBytes,
  int maxTotalBytes = maxBackupUncompressedBytes,
  int maxEntries = maxBackupEntryCount,
}) {
  try {
    return ParseSuccess<BackupSnapshot>(
      _decode(
        bytes,
        maxArchiveBytes: maxArchiveBytes,
        maxEntryBytes: maxEntryBytes,
        maxTotalBytes: maxTotalBytes,
        maxEntries: maxEntries,
      ),
    );
  } on _BackupFormatError catch (error) {
    return failureAt<BackupSnapshot>(
      kind: error.kind,
      rulePath: error.rulePath,
    );
  }
}

/// A format violation, turned into a [ParseFailure] by [decodeBackupArchive].
///
/// A private exception rather than a `ParseResult` per helper: the checks are a dozen early exits,
/// and threading a result type through each of them would bury the format itself.
final class _BackupFormatError implements Exception {
  const _BackupFormatError(
    this.rulePath, {
    this.kind = ParseFailureKind.parseFailed,
  });

  final String rulePath;
  final ParseFailureKind kind;
}

Never _fail(
  String rulePath, {
  ParseFailureKind kind = ParseFailureKind.parseFailed,
}) => throw _BackupFormatError(rulePath, kind: kind);

/// Runs [read], turning the archive library's two failure types into one format error.
///
/// `archive` 4.x reports a malformed structure as `ArchiveException` and an undecodable stream as
/// `FormatException`; both are reproduced in the codec tests, and neither may escape as an exception
/// (C-ERR-1). Keeping one helper is also what keeps both clauses measurable: the two call sites below
/// are the only places that touch the library.
T _guarded<T>(String rulePath, T Function() read) {
  try {
    return read();
  } on ArchiveException {
    _fail(rulePath);
  } on FormatException {
    _fail(rulePath);
  }
}

BackupSnapshot _decode(
  List<int> bytes, {
  required int maxArchiveBytes,
  required int maxEntryBytes,
  required int maxTotalBytes,
  required int maxEntries,
}) {
  if (bytes.length > maxArchiveBytes) {
    _fail('backup.read.sizeLimit');
  }

  final Archive archive = _guarded(
    'backup.read.notZip',
    () => ZipDecoder().decodeBytes(bytes),
  );

  final List<ArchiveFile> files = <ArchiveFile>[
    for (final ArchiveFile file in archive)
      if (file.isFile) file,
  ];
  if (files.length > maxEntries) {
    _fail('backup.read.entryCount');
  }

  // 先按中央目录里的声明值判大小，再碰 `content`：读 content 才会解压，zip 炸弹就卡在这一步前。
  var declaredTotal = 0;
  for (final ArchiveFile file in files) {
    if (file.size > maxEntryBytes) {
      _fail('backup.read.entrySize');
    }
    declaredTotal += file.size;
    if (declaredTotal > maxTotalBytes) {
      _fail('backup.read.totalSize');
    }
  }

  final Map<String, ArchiveFile> index = _indexByBaseName(files);
  final BackupManifest manifest = _manifestOf(index);

  final Map<BackupTable, List<Map<String, Object?>>> tables =
      <BackupTable, List<Map<String, Object?>>>{};
  for (final BackupTable table in BackupTable.values) {
    final ArchiveFile? file = index[table.fileName];
    if (file == null) {
      _fail('backup.read.missingTable');
    }
    tables[table] = _rowsOf(file, table);
  }

  final ArchiveFile? preferencesFile = index[backupPreferencesFileName];
  if (preferencesFile == null) {
    _fail('backup.read.missingPreferences');
  }

  return BackupSnapshot(
    manifest: manifest,
    contents: BackupContents(
      tables: tables,
      preferences: _preferencesOf(preferencesFile),
    ),
  );
}

/// Maps every entry by its file name, ignoring a folder prefix the user added by re-zipping.
///
/// Two entries with the same base name are ambiguous, so they are refused instead of silently
/// picking one.
Map<String, ArchiveFile> _indexByBaseName(List<ArchiveFile> files) {
  final Map<String, ArchiveFile> index = <String, ArchiveFile>{};
  for (final ArchiveFile file in files) {
    final String baseName = file.name.split('/').last;
    if (index.containsKey(baseName)) {
      _fail('backup.read.duplicateEntry');
    }
    index[baseName] = file;
  }

  return index;
}

BackupManifest _manifestOf(Map<String, ArchiveFile> index) {
  final ArchiveFile? file = index[backupManifestFileName];
  if (file == null) {
    _fail('backup.read.manifest');
  }

  final Map<String, Object?> document = _jsonObjectOf(file, 'manifest.json');
  final Object? formatVersion = document['formatVersion'];
  if (formatVersion is! int) {
    _fail('backup.read.badManifest');
  }
  if (formatVersion > backupFormatVersion) {
    _fail(
      'backup.restore.formatVersion',
      kind: ParseFailureKind.unsupportedRule,
    );
  }
  if (formatVersion < 1) {
    _fail('backup.read.badManifest');
  }

  final Object? createdAt = document['createdAt'];
  final DateTime? parsedCreatedAt = createdAt is String
      ? DateTime.tryParse(createdAt)
      : null;
  if (parsedCreatedAt == null) {
    _fail('backup.read.badManifest');
  }

  final Object? appVersion = document['appVersion'];
  if (appVersion is! String) {
    _fail('backup.read.badManifest');
  }

  return BackupManifest(
    formatVersion: formatVersion,
    createdAt: parsedCreatedAt.toUtc(),
    appVersion: appVersion,
  );
}

List<Map<String, Object?>> _rowsOf(ArchiveFile file, BackupTable table) {
  final Object? decoded = _jsonOf(file, table.fileName);
  if (decoded is! List) {
    _fail('backup.read.${table.fileName}');
  }

  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  for (final Object? row in decoded) {
    if (row is! Map) {
      _fail('backup.read.${table.fileName}');
    }
    rows.add(_stringKeyed(row));
  }

  return rows;
}

Map<String, Object?> _preferencesOf(ArchiveFile file) {
  final Object? decoded = _jsonOf(file, backupPreferencesFileName);
  if (decoded is! Map) {
    _fail('backup.read.$backupPreferencesFileName');
  }

  return _stringKeyed(decoded);
}

Map<String, Object?> _jsonObjectOf(ArchiveFile file, String name) {
  final Object? decoded = _jsonOf(file, name);
  if (decoded is! Map) {
    _fail('backup.read.badManifest');
  }

  return _stringKeyed(decoded);
}

/// Narrowed view of a decoded JSON object: only string keys survive.
///
/// `jsonDecode` already answers string keys, so this is a type narrowing rather than a filter — the
/// `if` keeps the compiler from needing `!` on `entry.key` (C-TYPE-2).
Map<String, Object?> _stringKeyed(Map<Object?, Object?> document) =>
    <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in document.entries)
        if (entry.key case final String key) key: entry.value,
    };

Object? _jsonOf(ArchiveFile file, String name) {
  // 解压发生在这行，所以「条目读不出来」在这里判，而不是在解压前的声明大小检查里。
  final List<int> content = _guarded('backup.read.$name', () => file.content);

  try {
    return jsonDecode(utf8.decode(content));
  } on FormatException {
    _fail('backup.read.$name');
  }
}
