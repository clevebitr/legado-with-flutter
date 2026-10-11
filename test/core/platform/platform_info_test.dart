import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemPlatformInfo', () {
    test('SystemPlatformInfo_whenReadOnAnyHost_reportsConsistentFacts', () {
      const PlatformInfo info = SystemPlatformInfo();

      // 先把三个 getter 都读出来：`&&` 会短路，直接写 `info.isMobile &&
      // info.isDesktop` 会让 isDesktop 在移动端宿主上根本不被求值。
      final bool isMobile = info.isMobile;
      final bool isDesktop = info.isDesktop;
      final bool isAndroid = info.isAndroid;

      // 与宿主无关的断言（CI 为 Linux、开发机为 Windows，也可能是 macOS）：
      // 桌面与移动互斥，且 Android 必然属于移动端。
      expect(isMobile && isDesktop, isFalse);
      expect(isAndroid && !isMobile, isFalse);
    });
  });
}
