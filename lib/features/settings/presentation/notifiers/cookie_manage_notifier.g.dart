// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cookie_manage_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cookie jar, grouped by domain, and the ways to drop it.
///
/// The jar is **global by domain** on purpose: per-source isolation is registered as open
/// (`roadmap.md` §3.7), so this page is the honest view of what is stored — not a per-source one it
/// could not deliver.

@ProviderFor(CookieManage)
final cookieManageProvider = CookieManageProvider._();

/// The cookie jar, grouped by domain, and the ways to drop it.
///
/// The jar is **global by domain** on purpose: per-source isolation is registered as open
/// (`roadmap.md` §3.7), so this page is the honest view of what is stored — not a per-source one it
/// could not deliver.
final class CookieManageProvider
    extends $AsyncNotifierProvider<CookieManage, List<CookieDomainGroup>> {
  /// The cookie jar, grouped by domain, and the ways to drop it.
  ///
  /// The jar is **global by domain** on purpose: per-source isolation is registered as open
  /// (`roadmap.md` §3.7), so this page is the honest view of what is stored — not a per-source one it
  /// could not deliver.
  CookieManageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieManageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieManageHash();

  @$internal
  @override
  CookieManage create() => CookieManage();
}

String _$cookieManageHash() => r'79ea33a43bd900a3c0faeea6844f2fb7b74925a9';

/// The cookie jar, grouped by domain, and the ways to drop it.
///
/// The jar is **global by domain** on purpose: per-source isolation is registered as open
/// (`roadmap.md` §3.7), so this page is the honest view of what is stored — not a per-source one it
/// could not deliver.

abstract class _$CookieManage extends $AsyncNotifier<List<CookieDomainGroup>> {
  FutureOr<List<CookieDomainGroup>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CookieDomainGroup>>,
              List<CookieDomainGroup>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CookieDomainGroup>>,
                List<CookieDomainGroup>
              >,
              AsyncValue<List<CookieDomainGroup>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
