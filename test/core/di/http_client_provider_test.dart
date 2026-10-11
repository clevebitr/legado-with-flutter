import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
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
      final ProviderContainer container = ProviderContainer.test();

      expect(container.read(httpClientProvider), isA<DioHttpClient>());
    });
  });
}
