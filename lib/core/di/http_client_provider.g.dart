// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the persistent cookie jar shared by every request.
///
/// `main()` awaits [PersistentCookieManager.hydrate] before `runApp`.

@ProviderFor(cookieManager)
final cookieManagerProvider = CookieManagerProvider._();

/// Provides the persistent cookie jar shared by every request.
///
/// `main()` awaits [PersistentCookieManager.hydrate] before `runApp`.

final class CookieManagerProvider
    extends
        $FunctionalProvider<
          PersistentCookieManager,
          PersistentCookieManager,
          PersistentCookieManager
        >
    with $Provider<PersistentCookieManager> {
  /// Provides the persistent cookie jar shared by every request.
  ///
  /// `main()` awaits [PersistentCookieManager.hydrate] before `runApp`.
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
  $ProviderElement<PersistentCookieManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersistentCookieManager create(Ref ref) {
    return cookieManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersistentCookieManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersistentCookieManager>(value),
    );
  }
}

String _$cookieManagerHash() => r'd58419e0ca6a5202a4e3ce476b8889675a115d4e';

/// Provides the network policy: timeouts, retry bound, `User-Agent` and
/// plaintext HTTP.
///
/// The concurrency budget comes from [concurrencySetting].

@ProviderFor(httpPolicy)
final httpPolicyProvider = HttpPolicyProvider._();

/// Provides the network policy: timeouts, retry bound, `User-Agent` and
/// plaintext HTTP.
///
/// The concurrency budget comes from [concurrencySetting].

final class HttpPolicyProvider
    extends $FunctionalProvider<HttpPolicy, HttpPolicy, HttpPolicy>
    with $Provider<HttpPolicy> {
  /// Provides the network policy: timeouts, retry bound, `User-Agent` and
  /// plaintext HTTP.
  ///
  /// The concurrency budget comes from [concurrencySetting].
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

String _$httpPolicyHash() => r'c5f23f4c6c5affcc7aaacffe8a9ab4255142d682';

/// The per-source concurrency budget the user chose, or `null` when unset.
///
/// Declared in `core` so the composition root binds it without a feature import.

@ProviderFor(concurrencySetting)
final concurrencySettingProvider = ConcurrencySettingProvider._();

/// The per-source concurrency budget the user chose, or `null` when unset.
///
/// Declared in `core` so the composition root binds it without a feature import.

final class ConcurrencySettingProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// The per-source concurrency budget the user chose, or `null` when unset.
  ///
  /// Declared in `core` so the composition root binds it without a feature import.
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

/// Whether the user opted into plaintext `http://`.
///
/// Bound by the composition root; gates both the HTTP client and the media
/// player.

@ProviderFor(plainHttpSetting)
final plainHttpSettingProvider = PlainHttpSettingProvider._();

/// Whether the user opted into plaintext `http://`.
///
/// Bound by the composition root; gates both the HTTP client and the media
/// player.

final class PlainHttpSettingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the user opted into plaintext `http://`.
  ///
  /// Bound by the composition root; gates both the HTTP client and the media
  /// player.
  PlainHttpSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'plainHttpSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$plainHttpSettingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return plainHttpSetting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$plainHttpSettingHash() => r'bde3225d0d3cd9cd13b18d93093e2cc39c08c479';

/// Provides the app-wide HTTP client.
///
/// `keepAlive` keeps the per-source concurrency budget alive across operations.

@ProviderFor(httpClient)
final httpClientProvider = HttpClientProvider._();

/// Provides the app-wide HTTP client.
///
/// `keepAlive` keeps the per-source concurrency budget alive across operations.

final class HttpClientProvider
    extends $FunctionalProvider<HttpClient, HttpClient, HttpClient>
    with $Provider<HttpClient> {
  /// Provides the app-wide HTTP client.
  ///
  /// `keepAlive` keeps the per-source concurrency budget alive across operations.
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
