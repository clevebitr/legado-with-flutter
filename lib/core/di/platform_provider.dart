import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_json_file_saver.dart';
import 'package:flutter_reader/core/platform/json_file_picker.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
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

/// Provides the platform save dialog for single-source export.
///
/// Unsupported platforms report `not saved` instead of throwing.
@Riverpod(keepAlive: true)
JsonFileSaver jsonFileSaver(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorJsonFileSaver()
      : const UnsupportedJsonFileSaver();
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

/// Provides WebView support for `,{webView:…}` rules and `java.webView`; unsupported by default.
///
/// It lives in `core/di/` because two features use it (the source engine's page fetch and the JS
/// sandbox) and `core/` may not import `features/` (C-ARCH-2). The real implementation is bound by
/// the composition root; the default answers `unsupportedRule`, which makes a forgotten binding a
/// readable failure instead of a rule that silently sees an unrendered page.
@Riverpod(keepAlive: true)
WebPageFetcher webPageFetcher(Ref ref) => const UnsupportedWebPageFetcher();
