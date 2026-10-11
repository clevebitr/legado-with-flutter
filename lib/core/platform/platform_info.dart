import 'dart:io';

/// Platform facts the app is allowed to branch on (C-PLT-1).
///
/// Only `core/platform/` may read the platform directly; every other layer
/// depends on this interface, so tests can inject a fake instead of mocking
/// `dart:io` (`docs/dev/platform.md` §2).
abstract interface class PlatformInfo {
  /// Whether the app runs on a phone or tablet (Android, iOS).
  bool get isMobile;

  /// Whether the app runs on a desktop OS (Windows, macOS, Linux).
  bool get isDesktop;

  /// Whether the app runs on Android.
  bool get isAndroid;
}

/// Reads the current platform from `dart:io`.
///
/// The app only targets Android, iOS and Windows, so `dart:io` is always
/// available and no conditional import is needed.
final class SystemPlatformInfo implements PlatformInfo {
  /// Creates the `dart:io`-backed implementation.
  const SystemPlatformInfo();

  @override
  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  bool get isAndroid => Platform.isAndroid;
}
