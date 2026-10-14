import 'package:flutter_reader/core/platform/book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/dynamic_color_provider.dart';
import 'package:flutter_reader/core/platform/file_selector_book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_provider.g.dart';

/// Provides the platform facts every other layer is allowed to branch on
/// (C-PLT-1).
///
/// Tests override it with a fake to simulate Android or a desktop host.
@riverpod
PlatformInfo platformInfo(Ref ref) => const SystemPlatformInfo();

/// Provides the platform dynamic color source, or `null` when the platform has
/// none (`docs/dev/platform.md` §3).
///
/// Named `platformDynamicColor` on purpose: the generated provider class is
/// `<function>Provider`, so a function named `dynamicColor` would declare
/// `DynamicColorProvider` and collide with the platform interface of the same
/// name.
///
/// Consumers must handle `null` by falling back to the seed color; tests pin the
/// fallback with `platformDynamicColorProvider.overrideWithValue(null)`
/// (`docs/dev/testing.md` §5).
@riverpod
DynamicColorProvider? platformDynamicColor(Ref ref) =>
    resolveDynamicColorProvider(ref.watch(platformInfoProvider));

/// Provides the platform file picker for book source imports (`PLAN.md` 5.8, C-PLT-1).
///
/// Every target this app ships (Android, iOS, Windows) has a real dialog through `file_selector`;
/// anything else gets the fallback that answers “nothing picked”, so an unsupported platform
/// degrades instead of throwing (`docs/dev/platform.md` §2). Tests override the port, never the
/// plugin (`docs/dev/testing.md` §4).
@riverpod
BookSourceFilePicker bookSourceFilePicker(Ref ref) {
  final PlatformInfo platform = ref.watch(platformInfoProvider);

  return platform.isMobile || platform.isDesktop
      ? const FileSelectorBookSourceFilePicker()
      : const UnsupportedBookSourceFilePicker();
}
