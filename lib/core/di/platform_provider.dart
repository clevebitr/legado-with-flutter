import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/file_selector_book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_book_source_file_saver.dart';
import 'package:flutter_reader/core/platform/long_running_task.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
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
BookSourceFilePicker bookSourceFilePicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBookSourceFilePicker()
      : const UnsupportedBookSourceFilePicker();
}

/// Provides the platform save dialog for single-source export.
///
/// Unsupported platforms report `not saved` instead of throwing.
@Riverpod(keepAlive: true)
BookSourceFileSaver bookSourceFileSaver(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBookSourceFileSaver()
      : const UnsupportedBookSourceFileSaver();
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
