import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/features/book_source/presentation/pages/search_books_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 设备级 smoke：应用在真实引擎里能启动并渲染落地页。
///
/// 与 `test/app_test.dart` 的分工：那里跑在 `flutter test` 的宿主 VM 上、平台通道是假的；
/// 这里跑在 Windows 桌面或 Android 模拟器的真实引擎里，因此 `path_provider`、
/// `dynamic_color`、原生 SQLite 等**只能由设备提供**的接线才会被真正执行
/// （`docs/dev/testing.md` §1、`docs/dev/test-environment.md`）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('readerApp_whenLaunchedOnADevice_rendersTheSearchLandingPage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ReaderApp()));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBooksPage), findsOneWidget);
    // 平台通道若在启动路径上抛错，会在这里浮现而不是被静默吞掉（C-ERR-1 精神）。
    expect(tester.takeException(), isNull);
  });
}
