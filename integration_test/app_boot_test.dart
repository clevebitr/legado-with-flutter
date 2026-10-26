import 'package:flutter_reader/app_shell.dart';
import 'package:flutter_reader/main.dart' as bootstrap;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 设备级 smoke：应用在真实引擎里能启动并渲染落地页。
///
/// 与 `test/app_test.dart` 的分工：那里跑在 `flutter test` 的宿主 VM 上、平台通道是假的；这里跑
/// 在 Windows 桌面或 Android 模拟器的真实引擎里，因此 `path_provider`、`dynamic_color`、原生
/// SQLite 等**只能由设备提供**的接线才会被真正执行（`docs/dev/testing.md` §1、
/// `docs/dev/test-environment.md`）。
///
/// 自 M21a 起它调用的是**真正的 `main()`**，不是 `ReaderApp` 的裸树：`main()` 会先打开文件型
/// 数据库、hydrate 持久化 Cookie jar，再 `runApp`（ADR-0068 §决策 4）。这样「启动路径」本身
/// （含跨 feature 端口绑定 `appProviderOverrides()`）也在设备上被验证一次。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('readerApp_whenLaunchedOnADevice_rendersTheAppShell', (
    WidgetTester tester,
  ) async {
    await bootstrap.main();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    // 平台通道若在启动路径上抛错，会在这里浮现而不是被静默吞掉（C-ERR-1 精神）。
    expect(tester.takeException(), isNull);
  });
}
