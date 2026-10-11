import 'package:flutter_reader/core/platform/platform_info.dart';

/// 测试替身：用构造参数固定平台事实，使测试不依赖宿主机的真实平台（testing.md §4）。
final class FakePlatformInfo implements PlatformInfo {
  /// Creates a fake that reports the given facts.
  const FakePlatformInfo({required this.isAndroid, required this.isDesktop});

  @override
  final bool isAndroid;

  @override
  final bool isDesktop;

  @override
  bool get isMobile => !isDesktop;
}
