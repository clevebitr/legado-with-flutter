import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  test('jsBridge_whenRead_returnsTheQuickJsBridgeWithoutStartingAWorker', () {
    // 桥监听应用级 HTTP 客户端（3.4 的 `http.*`），而它现在把 charset 缓存挂在
    // `CacheDao` 上，所以读 provider 图需要一个数据库；设备侧 executor 走平台通道，
    // 因此换成内存 executor（与 `cache_dao_test.dart` 一致）。
    final ProviderContainer container = ProviderContainer.test(
      overrides: <Override>[
        databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
      ],
    );
    addTearDown(container.dispose);

    // 读 provider 只构造桥，不拉起 worker：worker 懒创建（ADR-0030 §决策 6），
    // 所以宿主 VM 上不需要原生库，也就能被覆盖率门禁测到。
    expect(container.read(jsBridgeProvider), isA<QuickJsWorkerBridge>());
  });
}
