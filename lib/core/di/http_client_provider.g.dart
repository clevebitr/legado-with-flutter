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
        isAutoDispose: true,
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

String _$cookieManagerHash() => r'f60491ab9245ef9b1d9fc0489a13982415768039';

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The settings phase overrides this provider with user-chosen values; nothing
/// else may construct a policy of its own.

@ProviderFor(httpPolicy)
final httpPolicyProvider = HttpPolicyProvider._();

/// Provides the network policy: timeout, retry bound, `User-Agent` and the
/// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
///
/// The settings phase overrides this provider with user-chosen values; nothing
/// else may construct a policy of its own.

final class HttpPolicyProvider
    extends $FunctionalProvider<HttpPolicy, HttpPolicy, HttpPolicy>
    with $Provider<HttpPolicy> {
  /// Provides the network policy: timeout, retry bound, `User-Agent` and the
  /// plaintext-HTTP switch (C-NET-2, C-NET-4, C-SEC-2).
  ///
  /// The settings phase overrides this provider with user-chosen values; nothing
  /// else may construct a policy of its own.
  HttpPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpPolicyProvider',
        isAutoDispose: true,
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

String _$httpPolicyHash() => r'c938007d4eea9c35bf25dfc7a041b989882e7d35';

/// Provides the app-wide HTTP client (C-NET-1).
///
/// The charset cache is wired here because the app is the only place that has both halves:
/// the request layer that decodes a body and the TTL cache that can remember the result
/// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).

@ProviderFor(httpClient)
final httpClientProvider = HttpClientProvider._();

/// Provides the app-wide HTTP client (C-NET-1).
///
/// The charset cache is wired here because the app is the only place that has both halves:
/// the request layer that decodes a body and the TTL cache that can remember the result
/// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).

final class HttpClientProvider
    extends $FunctionalProvider<HttpClient, HttpClient, HttpClient>
    with $Provider<HttpClient> {
  /// Provides the app-wide HTTP client (C-NET-1).
  ///
  /// The charset cache is wired here because the app is the only place that has both halves:
  /// the request layer that decodes a body and the TTL cache that can remember the result
  /// (`book-source.md` §5). It is the first production consumer of `CacheDao` (C-NET-6).
  HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: true,
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

String _$httpClientHash() => r'71af85b34cc9d0db1354757b4190e71a2b7ce3d0';
