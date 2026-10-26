// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_book_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the shelf knows about this book: membership, group and cover.

@ProviderFor(shelfMembership)
final shelfMembershipProvider = ShelfMembershipFamily._();

/// What the shelf knows about this book: membership, group and cover.

final class ShelfMembershipProvider
    extends
        $FunctionalProvider<
          AsyncValue<ShelfMembership>,
          ShelfMembership,
          FutureOr<ShelfMembership>
        >
    with $FutureModifier<ShelfMembership>, $FutureProvider<ShelfMembership> {
  /// What the shelf knows about this book: membership, group and cover.
  ShelfMembershipProvider._({
    required ShelfMembershipFamily super.from,
    required ShelfBookKey super.argument,
  }) : super(
         retry: null,
         name: r'shelfMembershipProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$shelfMembershipHash();

  @override
  String toString() {
    return r'shelfMembershipProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ShelfMembership> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ShelfMembership> create(Ref ref) {
    final argument = this.argument as ShelfBookKey;
    return shelfMembership(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShelfMembershipProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$shelfMembershipHash() => r'5177a91c6fb522eb059212cd03cac4f0aaef3c7d';

/// What the shelf knows about this book: membership, group and cover.

final class ShelfMembershipFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ShelfMembership>, ShelfBookKey> {
  ShelfMembershipFamily._()
    : super(
        retry: null,
        name: r'shelfMembershipProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the shelf knows about this book: membership, group and cover.

  ShelfMembershipProvider call(ShelfBookKey book) =>
      ShelfMembershipProvider._(argument: book, from: this);

  @override
  String toString() => r'shelfMembershipProvider';
}

/// The shelf-side writes the detail page offers.
///
/// Each successful write reloads the membership snapshot; failures become [ParseResult] values.

@ProviderFor(ShelfBookActions)
final shelfBookActionsProvider = ShelfBookActionsFamily._();

/// The shelf-side writes the detail page offers.
///
/// Each successful write reloads the membership snapshot; failures become [ParseResult] values.
final class ShelfBookActionsProvider
    extends $NotifierProvider<ShelfBookActions, AsyncValue<void>> {
  /// The shelf-side writes the detail page offers.
  ///
  /// Each successful write reloads the membership snapshot; failures become [ParseResult] values.
  ShelfBookActionsProvider._({
    required ShelfBookActionsFamily super.from,
    required ShelfBookKey super.argument,
  }) : super(
         retry: null,
         name: r'shelfBookActionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$shelfBookActionsHash();

  @override
  String toString() {
    return r'shelfBookActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ShelfBookActions create() => ShelfBookActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ShelfBookActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$shelfBookActionsHash() => r'f2ac39e8db0e63dc2cc7af8b76b439eeb8310782';

/// The shelf-side writes the detail page offers.
///
/// Each successful write reloads the membership snapshot; failures become [ParseResult] values.

final class ShelfBookActionsFamily extends $Family
    with
        $ClassFamilyOverride<
          ShelfBookActions,
          AsyncValue<void>,
          AsyncValue<void>,
          AsyncValue<void>,
          ShelfBookKey
        > {
  ShelfBookActionsFamily._()
    : super(
        retry: null,
        name: r'shelfBookActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The shelf-side writes the detail page offers.
  ///
  /// Each successful write reloads the membership snapshot; failures become [ParseResult] values.

  ShelfBookActionsProvider call(ShelfBookKey book) =>
      ShelfBookActionsProvider._(argument: book, from: this);

  @override
  String toString() => r'shelfBookActionsProvider';
}

/// The shelf-side writes the detail page offers.
///
/// Each successful write reloads the membership snapshot; failures become [ParseResult] values.

abstract class _$ShelfBookActions extends $Notifier<AsyncValue<void>> {
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
