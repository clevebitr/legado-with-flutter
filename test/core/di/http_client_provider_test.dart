import 'package:drift/native.dart';
import 'package:flutter_reader/core/di/database_executor_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../support/fake_log_printer.dart';

/// A container whose database executor is the in-memory one: the HTTP client
/// wires the charset cache on top of `CacheDao`, so reading its graph needs a
/// database (same override as `cache_dao_test.dart`).
ProviderContainer _memoryContainer({List<Override> overrides = const []}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('httpPolicy_whenNothingIsBound_usesTheDocumentedDefaults', () {
    final HttpPolicy policy = ProviderContainer.test().read(httpPolicyProvider);

    expect(policy.timeout, const Duration(seconds: 15));
    expect(policy.allowPlainHttp, isFalse);
  });

  test('httpPolicy_givenAConcurrencySetting_bindsItAndClampsNonPositive', () {
    expect(
      _memoryContainer(
        overrides: <Override>[concurrencySettingProvider.overrideWithValue(6)],
      ).read(httpPolicyProvider).maxConcurrentRequestsPerSource,
      6,
    );

    // roadmap §3.7：`assert` 在 release 会被剥掉，`0` 会让该源的每个请求永久排队。
    expect(
      _memoryContainer(
        overrides: <Override>[concurrencySettingProvider.overrideWithValue(0)],
      ).read(httpPolicyProvider).maxConcurrentRequestsPerSource,
      defaultMaxConcurrentRequestsPerSource,
    );
  });

  test('httpClient_whenReadTwice_isTheSameDioClient', () {
    // keepAlive 是并发预算成立的前提：预算挂在客户端实例上，跨操作重建就等于每批重新开始
    // （roadmap §3.7）。
    final ProviderContainer container = _memoryContainer();

    final HttpClient client = container.read(httpClientProvider);

    expect(client, isA<DioHttpClient>());
    expect(container.read(httpClientProvider), same(client));
  });

  test('sourceVerification_whenNothingIsBound_answersTheUnboundPort', () {
    // ADR-0068 §决策 3：绑定只发生在装配根；默认值必须是「不可用」而不是挂起。
    expect(
      ProviderContainer.test().read(sourceVerificationProvider).isSupported,
      isFalse,
    );
  });

  group('budgetOrDefault', () {
    late FakeLogPrinter printer;
    late AppLogger logger;

    setUp(() {
      printer = FakeLogPrinter();
      logger = AppLogger(level: LogLevel.debug, printer: printer);
    });

    test('budgetOrDefault_givenAMissingOrUsableValue_answersThatValue', () {
      expect(
        budgetOrDefault(null, logger),
        defaultMaxConcurrentRequestsPerSource,
      );
      expect(budgetOrDefault(5, logger), 5);
      expect(printer.events, isEmpty);
    });

    test(
      'budgetOrDefault_givenANonPositiveValue_warnsAndAnswersTheDefault',
      () {
        for (final int budget in <int>[0, -2]) {
          printer.events.clear();

          expect(
            budgetOrDefault(budget, logger),
            defaultMaxConcurrentRequestsPerSource,
          );
          expect(printer.events.single.message, contains('non-positive'));
        }
      },
    );
  });
}
