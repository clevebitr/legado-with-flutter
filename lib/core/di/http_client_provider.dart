import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/persistent_cookie_manager.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_client_provider.g.dart';

/// Provides the persistent cookie jar shared by every request.
///
/// `main()` awaits [PersistentCookieManager.hydrate] before `runApp`.
@Riverpod(keepAlive: true)
PersistentCookieManager cookieManager(Ref ref) => PersistentCookieManager(
  store: ref.watch(cookieStoreProvider),
  clock: ref.watch(clockProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the network policy: timeouts, retry bound, `User-Agent` and
/// plaintext HTTP.
///
/// The concurrency budget comes from [concurrencySetting].
@Riverpod(keepAlive: true)
HttpPolicy httpPolicy(Ref ref) => HttpPolicy(
  maxConcurrentRequestsPerSource: budgetOrDefault(
    ref.watch(concurrencySettingProvider),
    ref.watch(appLoggerProvider),
  ),
  allowPlainHttp: ref.watch(plainHttpSettingProvider),
);

/// The per-source concurrency budget the user chose, or `null` when unset.
///
/// Declared in `core` so the composition root binds it without a feature import.
@Riverpod(keepAlive: true)
int? concurrencySetting(Ref ref) => null;

/// Whether the user opted into plaintext `http://`.
///
/// Bound by the composition root; gates both the HTTP client and the media
/// player.
@Riverpod(keepAlive: true)
bool plainHttpSetting(Ref ref) => false;

/// Maps a user-chosen budget to a value [RequestLimiter] can accept.
///
/// A non-positive value falls back to the default with a warning.
int budgetOrDefault(int? requested, AppLogger logger) {
  if (requested == null) {
    return defaultMaxConcurrentRequestsPerSource;
  }
  if (requested > 0) {
    return requested;
  }

  logger.warning('Ignoring a non-positive concurrency budget.');

  return defaultMaxConcurrentRequestsPerSource;
}

/// Provides the app-wide HTTP client.
///
/// `keepAlive` keeps the per-source concurrency budget alive across operations.
@Riverpod(keepAlive: true)
HttpClient httpClient(Ref ref) => DioHttpClient(
  cookies: ref.watch(cookieManagerProvider),
  logger: ref.watch(appLoggerProvider),
  policy: ref.watch(httpPolicyProvider),
  charsetCache: CacheDaoCharsetCache(
    ref.watch(cacheDaoProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);
