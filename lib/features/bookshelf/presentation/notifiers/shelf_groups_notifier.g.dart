// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_groups_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The shelf groups, and the only place that creates, renames, deletes or reorders them
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
///
/// `keepAlive` for the same reason as the shelf: the chip row reads it on every visit. Every
/// mutation reloads the group list **and** invalidates the shelf, because deleting a group changes
/// `books.groupId` for the books that were in it.

@ProviderFor(ShelfGroups)
final shelfGroupsProvider = ShelfGroupsProvider._();

/// The shelf groups, and the only place that creates, renames, deletes or reorders them
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
///
/// `keepAlive` for the same reason as the shelf: the chip row reads it on every visit. Every
/// mutation reloads the group list **and** invalidates the shelf, because deleting a group changes
/// `books.groupId` for the books that were in it.
final class ShelfGroupsProvider
    extends $AsyncNotifierProvider<ShelfGroups, List<ShelfGroup>> {
  /// The shelf groups, and the only place that creates, renames, deletes or reorders them
  /// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
  ///
  /// `keepAlive` for the same reason as the shelf: the chip row reads it on every visit. Every
  /// mutation reloads the group list **and** invalidates the shelf, because deleting a group changes
  /// `books.groupId` for the books that were in it.
  ShelfGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shelfGroupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shelfGroupsHash();

  @$internal
  @override
  ShelfGroups create() => ShelfGroups();
}

String _$shelfGroupsHash() => r'2fd1de4e704600d16861bbf23bd18e9b782ccf87';

/// The shelf groups, and the only place that creates, renames, deletes or reorders them
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
///
/// `keepAlive` for the same reason as the shelf: the chip row reads it on every visit. Every
/// mutation reloads the group list **and** invalidates the shelf, because deleting a group changes
/// `books.groupId` for the books that were in it.

abstract class _$ShelfGroups extends $AsyncNotifier<List<ShelfGroup>> {
  FutureOr<List<ShelfGroup>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ShelfGroup>>, List<ShelfGroup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ShelfGroup>>, List<ShelfGroup>>,
              AsyncValue<List<ShelfGroup>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
