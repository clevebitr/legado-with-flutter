// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_cache_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How many chapter bodies of this book are cached; a missing database answers `0`.

@ProviderFor(bookCacheCount)
final bookCacheCountProvider = BookCacheCountFamily._();

/// How many chapter bodies of this book are cached; a missing database answers `0`.

final class BookCacheCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many chapter bodies of this book are cached; a missing database answers `0`.
  BookCacheCountProvider._({
    required BookCacheCountFamily super.from,
    required ShelfBookKey super.argument,
  }) : super(
         retry: null,
         name: r'bookCacheCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookCacheCountHash();

  @override
  String toString() {
    return r'bookCacheCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as ShelfBookKey;
    return bookCacheCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookCacheCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookCacheCountHash() => r'6089f9ec915f6a32677118f108c040e5c9a42cbf';

/// How many chapter bodies of this book are cached; a missing database answers `0`.

final class BookCacheCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, ShelfBookKey> {
  BookCacheCountFamily._()
    : super(
        retry: null,
        name: r'bookCacheCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many chapter bodies of this book are cached; a missing database answers `0`.

  BookCacheCountProvider call(ShelfBookKey book) =>
      BookCacheCountProvider._(argument: book, from: this);

  @override
  String toString() => r'bookCacheCountProvider';
}

/// Clears one book's cached chapter bodies.
///
/// Failures are returned as [ParseResult] rather than thrown.

@ProviderFor(BookCacheActions)
final bookCacheActionsProvider = BookCacheActionsFamily._();

/// Clears one book's cached chapter bodies.
///
/// Failures are returned as [ParseResult] rather than thrown.
final class BookCacheActionsProvider
    extends $NotifierProvider<BookCacheActions, AsyncValue<void>> {
  /// Clears one book's cached chapter bodies.
  ///
  /// Failures are returned as [ParseResult] rather than thrown.
  BookCacheActionsProvider._({
    required BookCacheActionsFamily super.from,
    required ShelfBookKey super.argument,
  }) : super(
         retry: null,
         name: r'bookCacheActionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookCacheActionsHash();

  @override
  String toString() {
    return r'bookCacheActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookCacheActions create() => BookCacheActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookCacheActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookCacheActionsHash() => r'444a9196a995a0c4cc8566ee92e69bb20098e8b5';

/// Clears one book's cached chapter bodies.
///
/// Failures are returned as [ParseResult] rather than thrown.

final class BookCacheActionsFamily extends $Family
    with
        $ClassFamilyOverride<
          BookCacheActions,
          AsyncValue<void>,
          AsyncValue<void>,
          AsyncValue<void>,
          ShelfBookKey
        > {
  BookCacheActionsFamily._()
    : super(
        retry: null,
        name: r'bookCacheActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Clears one book's cached chapter bodies.
  ///
  /// Failures are returned as [ParseResult] rather than thrown.

  BookCacheActionsProvider call(ShelfBookKey book) =>
      BookCacheActionsProvider._(argument: book, from: this);

  @override
  String toString() => r'bookCacheActionsProvider';
}

/// Clears one book's cached chapter bodies.
///
/// Failures are returned as [ParseResult] rather than thrown.

abstract class _$BookCacheActions extends $Notifier<AsyncValue<void>> {
  late final _$args = ref.$arg as ShelfBookKey;
  ShelfBookKey get book => _$args;

  AsyncValue<void> build(ShelfBookKey book);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
