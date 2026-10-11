import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_client_provider.g.dart';

/// Provides the cookie store shared by every request (C-NET-5).
///
/// In-memory for now; persistence and expiry arrive with the storage phase
/// (see the [CookieManager] contract).
@riverpod
CookieManager cookieManager(Ref ref) => InMemoryCookieManager();

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The settings phase overrides this provider with user-chosen values; nothing
/// else may construct a policy of its own.
@riverpod
HttpPolicy httpPolicy(Ref ref) => const HttpPolicy();

/// Provides the app-wide HTTP client (C-NET-1).
@riverpod
HttpClient httpClient(Ref ref) => DioHttpClient(
  cookies: ref.watch(cookieManagerProvider),
  logger: ref.watch(appLoggerProvider),
  policy: ref.watch(httpPolicyProvider),
);
