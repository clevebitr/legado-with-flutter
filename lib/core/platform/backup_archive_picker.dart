import 'package:flutter_reader/core/error/parse_result.dart';

/// Asks the platform for one backup archive and hands back its bytes
/// (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// A cancel answers `ParseSuccess(null)`; an archive above the cap answers
/// [ParseFailureKind.parseFailed] with `rulePath: 'backup.read.sizeLimit'`.
///
/// The cap is checked by the dialog implementation **before** the bytes are read, so a multi-gigabyte
/// file cannot be pulled into memory by mistake (C-SEC-5).
abstract interface class BackupArchivePicker {
  /// Lets the user pick one `.zip` and returns it, or `null` when nothing was picked.
  Future<ParseResult<PickedBackupArchive?>> pick({required int maxBytes});
}

/// The fallback for a platform with no file dialog: it answers “nothing picked”.
final class UnsupportedBackupArchivePicker implements BackupArchivePicker {
  /// Creates the fallback.
  const UnsupportedBackupArchivePicker();

  @override
  Future<ParseResult<PickedBackupArchive?>> pick({
    required int maxBytes,
  }) async => const ParseSuccess<PickedBackupArchive?>(null);
}

/// Opens the platform's file dialog and answers what the user picked.
///
/// [maxBytes] is the cap the dialog must enforce before reading the file; the implementation
/// answers [OversizedBackupArchive] instead of loading it.
typedef BackupArchiveOpener = Future<BackupArchiveSelection?> Function({
  required int maxBytes,
});

/// What a file dialog produced: a readable archive, a refused oversized one, or `null` for cancel.
sealed class BackupArchiveSelection {
  /// Const constructor for the sealed hierarchy.
  const BackupArchiveSelection({required this.name});

  /// The file's name, for logs only.
  final String name;
}

/// An archive the user picked, within the cap.
final class PickedBackupArchive extends BackupArchiveSelection {
  /// Creates the picked archive.
  const PickedBackupArchive({required super.name, required this.bytes});

  /// The archive's bytes.
  final List<int> bytes;
}

/// An archive the user picked that is larger than the cap the dialog was given.
///
/// It carries the size instead of the bytes: the point of the type is that nothing was read.
final class OversizedBackupArchive extends BackupArchiveSelection {
  /// Creates the refusal.
  const OversizedBackupArchive({required super.name, required this.length});

  /// The file's size in bytes, as the platform reported it.
  final int length;
}
