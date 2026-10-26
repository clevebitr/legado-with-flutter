import 'dart:io';

/// Platform facts the app is allowed to branch on.
abstract interface class PlatformInfo {
  /// Whether the app runs on a phone or tablet (Android, iOS).
  bool get isMobile;

  /// Whether the app runs on a desktop OS (Windows, macOS, Linux).
  bool get isDesktop;

  /// Whether the app runs on Android.
  bool get isAndroid;
}

/// Reads the current platform from `dart:io`.
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
