/// Where the backups are written (`docs/dev/roadmap.md` M22, ADR-0074 §决策 1).
///
/// One concept for three writers: the automatic backup, the safety copy before an overwrite restore
/// and the page's 「保存到备份位置」. 「另存为…」 stays a system save dialog and is not modelled here.
sealed class BackupLocation {
  /// Const constructor for the sealed hierarchy.
  const BackupLocation();
}

/// The app's own support directory, `backups/` under it.
///
/// The default: it needs no permission and survives as long as the app is installed.
final class AppPrivateBackupLocation extends BackupLocation {
  /// Creates the default location.
  const AppPrivateBackupLocation();
}

/// A folder the user picked through the system directory dialog.
///
/// The path may stop existing (folder deleted, SD card removed, permission revoked); the store falls
/// back to [AppPrivateBackupLocation] and the page says so instead of losing the backup silently.
final class FolderBackupLocation extends BackupLocation {
  /// Creates a user-folder location.
  const FolderBackupLocation(this.path);

  /// The absolute path of the folder.
  final String path;
}
