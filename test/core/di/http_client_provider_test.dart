import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group('cookieManager', () {
    test('cookieManager_whenRead_returnsAnInMemoryStore', () {
      final ProviderContainer container = ProviderContainer.test();

      expect(
        container.read(cookieManagerProvider),
        isA<InMemoryCookieManager>(),
      );
    });
  });

  group('httpPolicy', () {
    test('httpPolicy_whenRead_usesTheDocumentedDefaults', () {
      final ProviderContainer container = ProviderContainer.test();
      final HttpPolicy policy = container.read(httpPolicyProvider);

      expect(policy.timeout, const Duration(seconds: 15));
      expect(policy.allowPlainHttp, isFalse);
    });
  });

  group('httpClient', () {
    test('httpClient_whenRead_returnsADioClient', () {
      // 客户端现在带 charset 缓存（`book-source.md` §5、PLAN 3.9），而缓存在 `CacheDao`
      // 之上——读 provider 图就需要一个数据库。设备侧的 executor（drift_flutter）走平台通道，
      // 因此这里与 `cache_dao_test.dart` 一样换成内存 executor。
      final ProviderContainer container = ProviderContainer.test(
        overrides: <Override>[
          databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
        ],
      );

      expect(container.read(httpClientProvider), isA<DioHttpClient>());
      // 同一次读取会带上缓存所需的 DAO（即 `CacheDao` 的第一个生产消费方）。
      expect(container.read<CacheDao>(cacheDaoProvider), isNotNull);
    });
  });
}
