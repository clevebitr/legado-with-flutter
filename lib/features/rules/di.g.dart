// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the rules repository (`docs/dev/roadmap.md` M20, ADR-0070).

@ProviderFor(ruleRepository)
final ruleRepositoryProvider = RuleRepositoryProvider._();

/// Provides the rules repository (`docs/dev/roadmap.md` M20, ADR-0070).

final class RuleRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<RuleRepository>,
          RuleRepository,
          FutureOr<RuleRepository>
        >
    with $FutureModifier<RuleRepository>, $FutureProvider<RuleRepository> {
  /// Provides the rules repository (`docs/dev/roadmap.md` M20, ADR-0070).
  RuleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ruleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ruleRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<RuleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RuleRepository> create(Ref ref) {
    return ruleRepository(ref);
  }
}

String _$ruleRepositoryHash() => r'17cecca4a7c54e5cdd1a7029bc9addb170adc64c';

/// Provides the loader of the bundled seed rules.

@ProviderFor(ruleSeedLoader)
final ruleSeedLoaderProvider = RuleSeedLoaderProvider._();

/// Provides the loader of the bundled seed rules.

final class RuleSeedLoaderProvider
    extends $FunctionalProvider<RuleSeedLoader, RuleSeedLoader, RuleSeedLoader>
    with $Provider<RuleSeedLoader> {
  /// Provides the loader of the bundled seed rules.
  RuleSeedLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ruleSeedLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ruleSeedLoaderHash();

  @$internal
  @override
  $ProviderElement<RuleSeedLoader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RuleSeedLoader create(Ref ref) {
    return ruleSeedLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RuleSeedLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RuleSeedLoader>(value),
    );
  }
}

String _$ruleSeedLoaderHash() => r'69d93311b7e982c72a7bf3fae012e4793bf51ef4';

/// Provides the port that retires cached chapter bodies, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `ContentCache` (ADR-0041 §决策 2). The
/// default drops nothing and says so, so a forgotten binding costs a stale chapter instead of a
/// broken rule page.

@ProviderFor(chapterBodyInvalidator)
final chapterBodyInvalidatorProvider = ChapterBodyInvalidatorProvider._();

/// Provides the port that retires cached chapter bodies, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `ContentCache` (ADR-0041 §决策 2). The
/// default drops nothing and says so, so a forgotten binding costs a stale chapter instead of a
/// broken rule page.

final class ChapterBodyInvalidatorProvider
    extends
        $FunctionalProvider<
          ChapterBodyInvalidator,
          ChapterBodyInvalidator,
          ChapterBodyInvalidator
        >
    with $Provider<ChapterBodyInvalidator> {
  /// Provides the port that retires cached chapter bodies, **unbound** by default.
  ///
  /// The composition root overrides it with `book_source`'s `ContentCache` (ADR-0041 §决策 2). The
  /// default drops nothing and says so, so a forgotten binding costs a stale chapter instead of a
  /// broken rule page.
  ChapterBodyInvalidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chapterBodyInvalidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chapterBodyInvalidatorHash();

  @$internal
  @override
  $ProviderElement<ChapterBodyInvalidator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChapterBodyInvalidator create(Ref ref) {
    return chapterBodyInvalidator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChapterBodyInvalidator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChapterBodyInvalidator>(value),
    );
  }
}

String _$chapterBodyInvalidatorHash() =>
    r'7b5b7a55c874b4fbb310212bcc80eb7fe2973cc3';
