// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_dav_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the WebDAV client the backup feature uploads to (`ADR-0074` §决策 6).
///
/// Its own `Dio` instance rather than `httpClientProvider`: the page-fetching client carries charset
/// detection, per-source budgets and rule headers, none of which apply to a WebDAV collection, and
/// its timeouts are tuned for reading pages. Auth and the plaintext switch are passed per call.

@ProviderFor(webDavClient)
final webDavClientProvider = WebDavClientProvider._();

/// Provides the WebDAV client the backup feature uploads to (`ADR-0074` §决策 6).
///
/// Its own `Dio` instance rather than `httpClientProvider`: the page-fetching client carries charset
/// detection, per-source budgets and rule headers, none of which apply to a WebDAV collection, and
/// its timeouts are tuned for reading pages. Auth and the plaintext switch are passed per call.

final class WebDavClientProvider
    extends $FunctionalProvider<WebDavClient, WebDavClient, WebDavClient>
    with $Provider<WebDavClient> {
  /// Provides the WebDAV client the backup feature uploads to (`ADR-0074` §决策 6).
  ///
  /// Its own `Dio` instance rather than `httpClientProvider`: the page-fetching client carries charset
  /// detection, per-source budgets and rule headers, none of which apply to a WebDAV collection, and
  /// its timeouts are tuned for reading pages. Auth and the plaintext switch are passed per call.
  WebDavClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webDavClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webDavClientHash();

  @$internal
  @override
  $ProviderElement<WebDavClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebDavClient create(Ref ref) {
    return webDavClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebDavClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebDavClient>(value),
    );
  }
}

String _$webDavClientHash() => r'24583537dba86d4607dcc5a6cdbe4db27ce3b6a4';
