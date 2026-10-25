/// The format version this build writes and the newest one it reads
/// (`docs/dev/roadmap.md` M22, ADR-0073 §决策 2).
///
/// It is the only compatibility hook: a future build bumps it and decides what an older archive
/// means. This build refuses anything above it instead of guessing.
const int backupFormatVersion = 1;

/// The manifest file every archive carries at its root.
const String backupManifestFileName = 'manifest.json';

/// The preferences file every archive carries at its root.
const String backupPreferencesFileName = 'preferences.json';

/// Largest archive a restore accepts, in bytes (C-SEC-5).
const int maxBackupArchiveBytes = 64 * 1024 * 1024;

/// Largest single entry a restore accepts after decompression, in bytes.
const int maxBackupEntryBytes = 16 * 1024 * 1024;

/// Largest total size of all decompressed entries, in bytes.
const int maxBackupUncompressedBytes = 64 * 1024 * 1024;

/// Largest number of entries a restore accepts; a backup has `7 + 2` at most.
const int maxBackupEntryCount = 32;

/// What one archive says about itself.
final class BackupManifest {
  /// Creates the manifest.
  const BackupManifest({
    required this.formatVersion,
    required this.createdAt,
    required this.appVersion,
  });

  /// The format the archive was written in.
  final int formatVersion;

  /// When the archive was written, in UTC.
  final DateTime createdAt;

  /// The `version` field of the `pubspec.yaml` that wrote it.
  final String appVersion;
}
