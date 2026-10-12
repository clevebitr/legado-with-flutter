import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group('jsBridge', () {
    /// A container whose database executor is the in-memory one.
    ///
    /// The bridge watches the app-wide HTTP client (3.4 的 `http.*`), which now also wires
    /// the charset cache on top of `CacheDao` — reading the provider graph therefore needs a
    /// database. `database_executor_provider.dart` is device-only (drift_flutter uses a
    /// platform channel), so the test overrides it with `NativeDatabase.memory()`, exactly
    /// like `cache_dao_test.dart` does.
    ProviderContainer containerForTest() => ProviderContainer.test(
      overrides: <Override>[
        databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
      ],
    );

    test('jsBridge_whenRead_returnsTheQuickJsBridgeWithoutStartingAWorker', () {
      final ProviderContainer container = containerForTest();

      // 读 provider 只构造桥，不拉起 worker：worker 懒创建（ADR-0030 §决策 6），
      // 所以宿主 VM 上不需要原生库，也就能被覆盖率门禁测到。
      expect(container.read(jsBridgeProvider), isA<QuickJsWorkerBridge>());
    });

    test('jsBridge_whenTheScopeIsDisposed_releasesTheBridge', () {
      final ProviderContainer container = containerForTest();
      container.read(jsBridgeProvider);

      // 释放作用域必须能正常走完（没有 worker 时是一次空释放）。
      expect(container.dispose, returnsNormally);
    });
  });
}
