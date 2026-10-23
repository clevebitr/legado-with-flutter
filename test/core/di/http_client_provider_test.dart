import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_reader/core/storage/cache_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../support/fake_log_printer.dart';

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

  group('budgetOrDefault', () {
    late FakeLogPrinter printer;
    late AppLogger logger;

    setUp(() {
      printer = FakeLogPrinter();
      logger = AppLogger(level: LogLevel.debug, printer: printer);
    });

    test('budgetOrDefault_givenNull_answersTheDefault', () {
      expect(
        budgetOrDefault(null, logger),
        defaultMaxConcurrentRequestsPerSource,
      );
      expect(printer.events, isEmpty);
    });

    test('budgetOrDefault_givenAPositiveValue_answersIt', () {
      expect(budgetOrDefault(5, logger), 5);
    });

    test('budgetOrDefault_givenZero_answersTheDefaultAndWarns', () {
      // roadmap §3.7 的登记项：`assert` 在 release 会被剥掉，`0` 会让该源的每个请求永久排队。
      expect(budgetOrDefault(0, logger), defaultMaxConcurrentRequestsPerSource);
      expect(printer.events.single.message, contains('non-positive'));
    });

    test('budgetOrDefault_givenANegativeValue_answersTheDefaultAndWarns', () {
      expect(
        budgetOrDefault(-2, logger),
        defaultMaxConcurrentRequestsPerSource,
      );
      expect(printer.events, hasLength(1));
    });
  });

  group('httpPolicy.givenAConcurrencySetting', () {
    test('httpPolicy_whenTheSettingIsBound_usesIt', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          concurrencySettingProvider.overrideWithValue(6),
          appLoggerProvider.overrideWithValue(
            AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(httpPolicyProvider).maxConcurrentRequestsPerSource,
        6,
      );
    });

    test('httpPolicy_whenTheSettingIsNonPositive_fallsBackToTheDefault', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          concurrencySettingProvider.overrideWithValue(0),
          appLoggerProvider.overrideWithValue(
            AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(httpPolicyProvider).maxConcurrentRequestsPerSource,
        defaultMaxConcurrentRequestsPerSource,
      );
    });
  });

  group('httpClient', () {
    test('httpClient_whenReadTwice_isTheSameInstance', () {
      // keepAlive 是并发预算成立的前提：预算挂在客户端实例上，跨操作重建就等于每批重新开始
      // （roadmap §3.7 的另一条登记项）。
      final ProviderContainer container = ProviderContainer(
        overrides: [
          databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(httpClientProvider),
        same(container.read(httpClientProvider)),
      );
    });
  });
}
