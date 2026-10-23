// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the cookie store shared by every request (C-NET-5).
///
/// In-memory for now; persistence and expiry arrive with the storage phase
/// (see the [CookieManager] contract).

@ProviderFor(cookieManager)
final cookieManagerProvider = CookieManagerProvider._();

/// Provides the cookie store shared by every request (C-NET-5).
///
/// In-memory for now; persistence and expiry arrive with the storage phase
/// (see the [CookieManager] contract).

final class CookieManagerProvider
    extends $FunctionalProvider<CookieManager, CookieManager, CookieManager>
    with $Provider<CookieManager> {
  /// Provides the cookie store shared by every request (C-NET-5).
  ///
  /// In-memory for now; persistence and expiry arrive with the storage phase
  /// (see the [CookieManager] contract).
  CookieManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieManagerHash();

  @$internal
  @override
  $ProviderElement<CookieManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CookieManager create(Ref ref) {
    return cookieManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CookieManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CookieManager>(value),
    );
  }
}

String _$cookieManagerHash() => r'da2c49b0ddfc973f5c6b1cd8270e68cecc1bd200';

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The concurrency budget comes from [concurrencySettingProvider], which the composition root
/// binds to the settings feature; everything else still comes from the policy defaults, so
/// nothing else may construct a policy of its own.

@ProviderFor(httpPolicy)
final httpPolicyProvider = HttpPolicyProvider._();

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The concurrency budget comes from [concurrencySettingProvider], which the composition root
/// binds to the settings feature; everything else still comes from the policy defaults, so
/// nothing else may construct a policy of its own.

final class HttpPolicyProvider
    extends $FunctionalProvider<HttpPolicy, HttpPolicy, HttpPolicy>
    with $Provider<HttpPolicy> {
  /// Provides the network policy: timeout, retry bound, `User-Agent` and the
  /// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
  ///
  /// The concurrency budget comes from [concurrencySettingProvider], which the composition root
  /// binds to the settings feature; everything else still comes from the policy defaults, so
  /// nothing else may construct a policy of its own.
  HttpPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpPolicyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpPolicyHash();

  @$internal
  @override
  $ProviderElement<HttpPolicy> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HttpPolicy create(Ref ref) {
    return httpPolicy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HttpPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HttpPolicy>(value),
    );
  }
}

String _$httpPolicyHash() => r'b6dcc4f5d47468a1d4ccd04e41e8c593dc98a22c';

/// The per-source concurrency budget the user chose, or `null` when nobody chose one.
///
/// Declared here so `core/` never imports a feature (C-ARCH-2): the composition root overrides
/// it with a value read from the settings feature (ADR-0042 的同一条机制）。 `null` is the
/// normal state before the settings are loaded and in tests that do not care.

@ProviderFor(concurrencySetting)
final concurrencySettingProvider = ConcurrencySettingProvider._();

/// The per-source concurrency budget the user chose, or `null` when nobody chose one.
///
/// Declared here so `core/` never imports a feature (C-ARCH-2): the composition root overrides
/// it with a value read from the settings feature (ADR-0042 的同一条机制）。 `null` is the
/// normal state before the settings are loaded and in tests that do not care.

final class ConcurrencySettingProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// The per-source concurrency budget the user chose, or `null` when nobody chose one.
  ///
  /// Declared here so `core/` never imports a feature (C-ARCH-2): the composition root overrides
  /// it with a value read from the settings feature (ADR-0042 的同一条机制）。 `null` is the
  /// normal state before the settings are loaded and in tests that do not care.
  ConcurrencySettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'concurrencySettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$concurrencySettingHash();

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    return concurrencySetting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$concurrencySettingHash() =>
    r'111cfdbb93c3bd5ae03ab33709aec712e2e6468f';

/// Provides the app-wide HTTP client (C-NET-1).
///
/// The charset cache is wired here because the app is the only place that has both halves:
/// the request layer that decodes a body and the TTL cache that can remember the result
/// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).
///
/// `keepAlive` is what keeps the concurrency budget meaningful: the budget lives on the
/// [DioHttpClient] instance, so an auto-disposed client would be rebuilt between two operations
/// and a batch download would get a fresh budget per batch (`docs/dev/roadmap.md` §3.7)。

@ProviderFor(httpClient)
final httpClientProvider = HttpClientProvider._();

/// Provides the app-wide HTTP client (C-NET-1).
///
/// The charset cache is wired here because the app is the only place that has both halves:
/// the request layer that decodes a body and the TTL cache that can remember the result
/// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).
///
/// `keepAlive` is what keeps the concurrency budget meaningful: the budget lives on the
/// [DioHttpClient] instance, so an auto-disposed client would be rebuilt between two operations
/// and a batch download would get a fresh budget per batch (`docs/dev/roadmap.md` §3.7)。

final class HttpClientProvider
    extends $FunctionalProvider<HttpClient, HttpClient, HttpClient>
    with $Provider<HttpClient> {
  /// Provides the app-wide HTTP client (C-NET-1).
  ///
  /// The charset cache is wired here because the app is the only place that has both halves:
  /// the request layer that decodes a body and the TTL cache that can remember the result
  /// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).
  ///
  /// `keepAlive` is what keeps the concurrency budget meaningful: the budget lives on the
  /// [DioHttpClient] instance, so an auto-disposed client would be rebuilt between two operations
  /// and a batch download would get a fresh budget per batch (`docs/dev/roadmap.md` §3.7)。
  HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpClientHash();

  @$internal
  @override
  $ProviderElement<HttpClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HttpClient create(Ref ref) {
    return httpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HttpClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HttpClient>(value),
    );
  }
}

String _$httpClientHash() => r'8a93694eaa9d62d24c2f8e3da6ec48487af69754';
