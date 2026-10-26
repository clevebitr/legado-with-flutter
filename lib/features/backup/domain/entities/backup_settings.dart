import 'package:flutter_reader/features/backup/domain/entities/backup_location.dart';

/// Smallest number of backups the retention keeps.
const int minBackupRetention = 1;

/// Largest number of backups the retention keeps.
const int maxBackupRetention = 30;

/// Default retention: five files, which covers 「昨天 / 上周」 without growing without bound.
const int defaultBackupRetention = 5;

/// The backup feature's own settings (`docs/dev/roadmap.md` M22, ADR-0074).
///
/// Only **non-secret** values live here; the backup password and the WebDAV password are kept in the
/// platform key store (`ADR-0074` §决策 5), which is why this entity carries just two
/// 「是否已保存」flags for them.
final class BackupSettings {
  const BackupSettings._({
    required this.isAutoEnabled,
    required this.retention,
    required this.location,
    required this.hasPassword,
    required this.webDavUrl,
    required this.webDavUsername,
    required this.hasWebDavPassword,
    required this.lastAutoBackupAt,
  });

  /// Creates settings, clamping [retention] into its documented range.
  factory BackupSettings({
    bool isAutoEnabled = false,
    int retention = defaultBackupRetention,
    BackupLocation location = const AppPrivateBackupLocation(),
    bool hasPassword = false,
    String webDavUrl = '',
    String webDavUsername = '',
    bool hasWebDavPassword = false,
    DateTime? lastAutoBackupAt,
  }) => BackupSettings._(
    isAutoEnabled: isAutoEnabled,
    retention: retention.clamp(minBackupRetention, maxBackupRetention),
    location: location,
    hasPassword: hasPassword,
    webDavUrl: webDavUrl,
    webDavUsername: webDavUsername,
    hasWebDavPassword: hasWebDavPassword,
    lastAutoBackupAt: lastAutoBackupAt,
  );

  /// The settings before anything was stored.
  static const BackupSettings defaults = BackupSettings._(
    isAutoEnabled: false,
    retention: defaultBackupRetention,
    location: AppPrivateBackupLocation(),
    hasPassword: false,
    webDavUrl: '',
    webDavUsername: '',
    hasWebDavPassword: false,
    lastAutoBackupAt: null,
  );

  /// Whether a backup runs once a day at start-up (`ADR-0074` §决策 2).
  final bool isAutoEnabled;

  /// How many `backup*.zip` files the location keeps; `1` is upstream's `onlyLatestBackup`.
  final int retention;

  /// Where the automatic backup, the safety copy and 「保存到备份位置」 write.
  final BackupLocation location;

  /// Whether a backup password is stored (a stored password means archives are encrypted).
  final bool hasPassword;

  /// The WebDAV collection URL, empty when the cloud side is not configured.
  final String webDavUrl;

  /// The WebDAV user name.
  final String webDavUsername;

  /// Whether a WebDAV password is stored.
  final bool hasWebDavPassword;

  /// When the last successful automatic backup ran, `null` when it never did.
  final DateTime? lastAutoBackupAt;

  /// Whether the cloud side has everything it needs besides the password itself.
  bool get isWebDavConfigured =>
      webDavUrl.isNotEmpty && webDavUsername.isNotEmpty;

  /// A copy with the given fields replaced; [retention] is clamped again.
  BackupSettings copyWith({
    bool? isAutoEnabled,
    int? retention,
    BackupLocation? location,
    bool? hasPassword,
    String? webDavUrl,
    String? webDavUsername,
    bool? hasWebDavPassword,
    DateTime? lastAutoBackupAt,
    bool clearLastAutoBackupAt = false,
  }) => BackupSettings(
    isAutoEnabled: isAutoEnabled ?? this.isAutoEnabled,
    retention: retention ?? this.retention,
    location: location ?? this.location,
    hasPassword: hasPassword ?? this.hasPassword,
    webDavUrl: webDavUrl ?? this.webDavUrl,
    webDavUsername: webDavUsername ?? this.webDavUsername,
    hasWebDavPassword: hasWebDavPassword ?? this.hasWebDavPassword,
    lastAutoBackupAt: clearLastAutoBackupAt
        ? null
        : (lastAutoBackupAt ?? this.lastAutoBackupAt),
  );
}
