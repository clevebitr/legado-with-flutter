import 'package:flutter_reader/core/platform/platform_info.dart';

/// Test double reporting fixed platform facts, so tests never depend on the
/// host platform (`docs/dev/testing.md` §4).
///
/// All three facts are required and only reachable through the named
/// constructors, so a contradictory combination such as "Android on desktop"
/// cannot be built.
final class FakePlatformInfo implements PlatformInfo {
  const FakePlatformInfo._({
    required this.isMobile,
    required this.isDesktop,
    required this.isAndroid,
  });

  /// Creates a fake reporting an Android phone or tablet.
  const FakePlatformInfo.android()
    : this._(isMobile: true, isDesktop: false, isAndroid: true);

  /// Creates a fake reporting an iPhone or iPad.
  const FakePlatformInfo.ios()
    : this._(isMobile: true, isDesktop: false, isAndroid: false);

  /// Creates a fake reporting a desktop OS (Windows, macOS or Linux).
  const FakePlatformInfo.desktop()
    : this._(isMobile: false, isDesktop: true, isAndroid: false);

  /// Creates a fake reporting a platform that is neither mobile nor desktop.
  ///
  /// It stands in for a target this app does not ship (web), which is what the platform ports
  /// degrade for (`docs/dev/platform.md` §2).
  const FakePlatformInfo.unsupported()
    : this._(isMobile: false, isDesktop: false, isAndroid: false);

  @override
  final bool isMobile;

  @override
  final bool isDesktop;

  @override
  final bool isAndroid;
}
