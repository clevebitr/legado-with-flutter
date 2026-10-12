import 'package:flutter_reader/core/di/js_bridge_provider.dart';
import 'package:flutter_reader/core/js/quickjs_worker_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group('jsBridge', () {
    test('jsBridge_whenRead_returnsTheQuickJsBridgeWithoutStartingAWorker', () {
      final ProviderContainer container = ProviderContainer.test();

      // 读 provider 只构造桥，不拉起 worker：worker 懒创建（ADR-0030 §决策 6），
      // 所以宿主 VM 上不需要原生库，也就能被覆盖率门禁测到。
      expect(container.read(jsBridgeProvider), isA<QuickJsWorkerBridge>());
    });

    test('jsBridge_whenTheScopeIsDisposed_releasesTheBridge', () {
      final ProviderContainer container = ProviderContainer.test();
      container.read(jsBridgeProvider);

      // 释放作用域必须能正常走完（没有 worker 时是一次空释放）。
      expect(container.dispose, returnsNormally);
    });
  });
}
