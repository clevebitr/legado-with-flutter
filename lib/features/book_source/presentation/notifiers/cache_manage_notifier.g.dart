// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_manage_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads and clears the cache per book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// Every action reloads: the counts are the answer, so showing a stale one after a clear would be
/// the one thing this page must not do.

@ProviderFor(CacheManage)
final cacheManageProvider = CacheManageProvider._();

/// Reads and clears the cache per book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// Every action reloads: the counts are the answer, so showing a stale one after a clear would be
/// the one thing this page must not do.
final class CacheManageProvider
    extends $AsyncNotifierProvider<CacheManage, CacheUsage> {
  /// Reads and clears the cache per book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
  ///
  /// Every action reloads: the counts are the answer, so showing a stale one after a clear would be
  /// the one thing this page must not do.
  CacheManageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheManageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheManageHash();

  @$internal
  @override
  CacheManage create() => CacheManage();
}

String _$cacheManageHash() => r'0d2d6b0b01f08851674dffc34d77cd9d816a808b';

/// Reads and clears the cache per book source (`docs/dev/roadmap.md` M22, ADR-0072 §决策 1).
///
/// Every action reloads: the counts are the answer, so showing a stale one after a clear would be
/// the one thing this page must not do.

abstract class _$CacheManage extends $AsyncNotifier<CacheUsage> {
  FutureOr<CacheUsage> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CacheUsage>, CacheUsage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CacheUsage>, CacheUsage>,
              AsyncValue<CacheUsage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
