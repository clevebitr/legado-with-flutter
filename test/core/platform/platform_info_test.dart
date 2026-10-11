import 'package:flutter_reader/core/platform/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemPlatformInfo', () {
    test('SystemPlatformInfo_whenReadOnATestHost_reportsADesktopHost', () {
      const PlatformInfo info = SystemPlatformInfo();

      // CI 为 Linux、开发机为 Windows，两者都是桌面宿主；移动与桌面互斥，
      // 因此这两条断言与具体宿主无关（Android 上跑 flutter test 不在此列）。
      expect(info.isDesktop, isTrue, reason: 'Test hosts are desktop.');
      expect(info.isMobile, isFalse);
      expect(info.isAndroid, isFalse);
    });
  });
}
