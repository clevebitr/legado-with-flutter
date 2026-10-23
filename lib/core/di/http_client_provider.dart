import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/charset_cache.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_policy.dart';
import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_client_provider.g.dart';

/// Provides the cookie store shared by every request (C-NET-5).
///
/// In-memory for now; persistence and expiry arrive with the storage phase
/// (see the [CookieManager] contract).
@Riverpod(keepAlive: true)
CookieManager cookieManager(Ref ref) => InMemoryCookieManager();

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The concurrency budget comes from [concurrencySettingProvider], which the composition root
/// binds to the settings feature; everything else still comes from the policy defaults, so
/// nothing else may construct a policy of its own.
@Riverpod(keepAlive: true)
HttpPolicy httpPolicy(Ref ref) => HttpPolicy(
  maxConcurrentRequestsPerSource: budgetOrDefault(
    ref.watch(concurrencySettingProvider),
    ref.watch(appLoggerProvider),
  ),
  allowPlainHttp: ref.watch(plainHttpSettingProvider),
);

/// The per-source concurrency budget the user chose, or `null` when nobody chose one.
///
/// Declared here so `core/` never imports a feature (C-ARCH-2): the composition root overrides
/// it with a value read from the settings feature (ADR-0042 的同一条机制）。 `null` is the
/// normal state before the settings are loaded and in tests that do not care.
@Riverpod(keepAlive: true)
int? concurrencySetting(Ref ref) => null;

/// Whether the user opted into plaintext `http://` (C-SEC-2).
///
/// Declared here for the same reason as [concurrencySetting]: `core/` must not import
/// `features/settings` (C-ARCH-2), so the composition root binds it. It gates **both** the page
/// loader (`HttpPolicy`) and the media player (the reader's audio notifier).
@riverpod
bool plainHttpSetting(Ref ref) => false;

/// Maps a user-chosen budget to a value [RequestLimiter] can accept.
///
/// The `assert` in [HttpPolicy] is stripped in release builds, and a budget of `0` would queue
/// every request of that source forever (`docs/dev/roadmap.md` §3.7 explicitly requires an
/// explicit check at the settings boundary). A non-positive value therefore falls back to the
/// default with a warning instead of being trusted — the app keeps working and the log says why.
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

/// Provides the app-wide HTTP client (C-NET-1).
///
/// The charset cache is wired here because the app is the only place that has both halves:
/// the request layer that decodes a body and the TTL cache that can remember the result
/// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).
///
/// `keepAlive` is what keeps the concurrency budget meaningful: the budget lives on the
/// [DioHttpClient] instance, so an auto-disposed client would be rebuilt between two operations
/// and a batch download would get a fresh budget per batch (`docs/dev/roadmap.md` §3.7)。
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
