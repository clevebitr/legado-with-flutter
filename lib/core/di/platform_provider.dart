import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/platform/backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/external_url_opener.dart';
import 'package:flutter_reader/core/platform/file_selector_background_image_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/file_selector_backup_directory_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_saver.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/flutter_secure_storage_secret_store.dart';
import 'package:flutter_reader/core/platform/install_id.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_reader/core/platform/secret_store.dart';
import 'package:flutter_reader/core/platform/share_plus_file_sharer.dart';
import 'package:flutter_reader/core/platform/sharing_backup_archive_saver.dart';
import 'package:flutter_reader/core/platform/sharing_json_file_saver.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/platform/web_page_fetcher.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_provider.g.dart';

/// Provides the platform facts other layers branch on.
///
/// Tests override it with a fake to simulate Android or a desktop host.
@Riverpod(keepAlive: true)
PlatformInfo platformInfo(Ref ref) => const SystemPlatformInfo();

/// Provides the platform dynamic color source, or `null` when it has none.
///
/// The name avoids a generated-class collision with [DynamicColorProvider].
@Riverpod(keepAlive: true)
DynamicColorProvider? platformDynamicColor(Ref ref) =>
    resolveDynamicColorProvider(ref.watch(platformInfoProvider));

/// Provides the platform file picker for book-source imports.
///
/// Unsupported platforms get a no-op picker instead of an exception.
@Riverpod(keepAlive: true)
JsonFilePicker jsonFilePicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorJsonFilePicker()
      : const UnsupportedJsonFilePicker();
}

/// Provides the system share sheet, or a no-op on platforms without one (`ADR-0083`).
///
/// Only mobile uses it today: on Android/iOS the export and log directories are private, while a
/// desktop already has a save dialog and a reachable folder. Capability detection, not a platform
/// branch in the UI, decides whether the log page offers sharing.
@Riverpod(keepAlive: true)
FileSharer fileSharer(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile
      ? SharePlusFileSharer()
      : const UnsupportedFileSharer();
}

/// Provides the platform save path for single-source export.
///
/// Mobile platforms have no save dialog, so they hand the document to the system share sheet
/// (`ADR-0083`). Unsupported platforms report `not saved` instead of throwing.
@Riverpod(keepAlive: true)
JsonFileSaver jsonFileSaver(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  if (platform.isMobile) {
    return SharingJsonFileSaver(sharer: ref.watch(fileSharerProvider));
  }

  return platform.isDesktop
      ? const FileSelectorJsonFileSaver()
      : const UnsupportedJsonFileSaver();
}

/// Provides the platform save path for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Mobile platforms share the archive instead of opening a save dialog (`ADR-0083`). Unsupported
/// platforms report `not saved` instead of throwing.
@Riverpod(keepAlive: true)
BackupArchiveSaver backupArchiveSaver(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  if (platform.isMobile) {
    return SharingBackupArchiveSaver(sharer: ref.watch(fileSharerProvider));
  }

  return platform.isDesktop
      ? const FileSelectorBackupArchiveSaver()
      : const UnsupportedBackupArchiveSaver();
}

/// Provides the platform open dialog for backups (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Unsupported platforms answer “nothing picked” instead of throwing.
@Riverpod(keepAlive: true)
BackupArchivePicker backupArchivePicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBackupArchivePicker()
      : const UnsupportedBackupArchivePicker();
}

/// Provides the platform key store for the backup and WebDAV passwords
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 5).
///
/// Only Android / iOS / Windows ship a key store here; the other platforms answer “not stored” and
/// the backup page says the archive stays unencrypted rather than pretending otherwise.
@Riverpod(keepAlive: true)
SecretStore secretStore(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? FlutterSecureStorageSecretStore(logger: ref.watch(appLoggerProvider))
      : UnsupportedSecretStore(logger: ref.watch(appLoggerProvider));
}

/// Provides the folder dialog the backup location is chosen with (ADR-0074 §决策 1).
@Riverpod(keepAlive: true)
BackupDirectoryPicker backupDirectoryPicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBackupDirectoryPicker()
      : const UnsupportedBackupDirectoryPicker();
}

/// Provides the image dialog the theme background is chosen with (`ADR-0075` §决策 1).
@Riverpod(keepAlive: true)
BackgroundImagePicker backgroundImagePicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBackgroundImagePicker()
      : const UnsupportedBackgroundImagePicker();
}

/// Provides the long-task marker a batch check holds while it runs.
///
/// Only Android has a real one; other platforms get a no-op.
@Riverpod(keepAlive: true)
LongRunningTask longRunningTask(Ref ref) =>
    ref.watch(platformInfoProvider).isAndroid
    ? MethodChannelLongRunningTask(logger: ref.watch(appLoggerProvider))
    : const UnsupportedLongRunningTask();

/// Provides visible-WebView verification, unbound by default.
///
/// An unbound port answers `isSupported == false`, which surfaces as
/// `unsupportedRule`.
@Riverpod(keepAlive: true)
SourceVerification sourceVerification(Ref ref) =>
    UnboundSourceVerification(logger: ref.watch(appLoggerProvider));

/// Provides the install id `java.androidId` answers with (M25/S3b).
///
/// The holder is read **synchronously** from every job, so `main()` awaits `InstallId.hydrate`
/// before the first frame (the cookie jar's pattern, ADR-0068 §决策 4). A build that never hydrated
/// it answers `''`, which is what the sandbox does when the host has no id.
@Riverpod(keepAlive: true)
InstallId installId(Ref ref) => InstallId(logger: ref.watch(appLoggerProvider));

/// Provides the confirmation dialog `java.openUrl` shows before a rule opens an address.
///
/// Silent by default for the same reason as [sourceVerification]: `core/` cannot show a widget, so
/// the composition root binds the real one. A build without the override still runs every rule —
/// the bridge logs the address it refused to open.
@Riverpod(keepAlive: true)
ExternalUrlOpener externalUrlOpener(Ref ref) =>
    const UnboundExternalUrlOpener();

/// Provides WebView support for `,{webView:…}` rules and `java.webView`; unsupported by default.
///
/// It lives in `core/di/` because two features use it (the source engine's page fetch and the JS
/// sandbox) and `core/` may not import `features/` (C-ARCH-2). The real implementation is bound by
/// the composition root; the default answers `unsupportedRule`, which makes a forgotten binding a
/// readable failure instead of a rule that silently sees an unrendered page.
@Riverpod(keepAlive: true)
WebPageFetcher webPageFetcher(Ref ref) => const UnsupportedWebPageFetcher();
