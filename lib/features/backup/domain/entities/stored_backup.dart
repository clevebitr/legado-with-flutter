/// One backup archive that exists somewhere (`docs/dev/roadmap.md` M22, ADR-0074).
final class StoredBackup {
  /// Creates a stored backup.
  const StoredBackup({
    required this.name,
    required this.directory,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// The file name, `backup<yyyy-MM-dd>.zip` or `backup-before-restore-…zip` (with `.enc` appended
  /// when the archive is encrypted).
  final String name;

  /// The absolute directory it lives in.
  final String directory;

  /// The absolute path of the file.
  String get path => '$directory/$name';

  /// The file size in bytes.
  final int sizeBytes;

  /// When the file was last written.
  final DateTime modifiedAt;

  /// Whether the file name says the archive is encrypted (`ADR-0074` §决策 4).
  bool get isEncrypted => name.endsWith('.enc');
}

/// One backup archive on the WebDAV server (`docs/dev/roadmap.md` M22, ADR-0074 §决策 6).
final class RemoteBackup {
  /// Creates a remote backup entry.
  const RemoteBackup({
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// The file name inside the remote collection.
  final String name;

  /// The size the server reported, `0` when it did not.
  final int sizeBytes;

  /// When the server says it was last modified.
  final DateTime modifiedAt;

  /// Whether the file name says the archive is encrypted.
  bool get isEncrypted => name.endsWith('.enc');
}

/// The file-name pattern every archive this app writes matches, encrypted or not.
///
/// Retention only ever deletes files matching this: a user's own `report.zip` sitting in the same
/// folder is not ours to remove (`ADR-0074` §决策 2).
final RegExp backupFilePattern = RegExp(r'^backup.*\.zip(\.enc)?$');

/// The name a backup written at [instant] gets: `backup<yyyy-MM-dd>.zip[.enc]`.
String backupNameFor(DateTime instant, {required bool isEncrypted}) {
  final DateTime local = instant.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  final String base = 'backup${local.year}-$month-$day.zip';

  return isEncrypted ? '$base.enc' : base;
}

/// The name the safety copy written before an overwrite restore gets
/// (`ADR-0074` §决策 3): timestamped to the second so it never overwrites a backup.
String safetyBackupNameFor(DateTime instant, {required bool isEncrypted}) {
  final DateTime local = instant.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final String stamp =
      '${local.year}${two(local.month)}${two(local.day)}'
      '-${two(local.hour)}${two(local.minute)}${two(local.second)}';
  final String base = 'backup-before-restore-$stamp.zip';

  return isEncrypted ? '$base.enc' : base;
}
