// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every stored book source, in the order the list and the default pick share
/// (`BookSourceDao.findAll`: enabled first, then `customOrder`, then `id`).
///
/// `keepAlive` on purpose: the selection below watches it, so the list must not be re-read
/// (and the selection must not be lost) when the user walks from the reader back to the list.
/// Mutations invalidate it explicitly, so "fresh" is a decision rather than a side effect.

@ProviderFor(bookSourceList)
final bookSourceListProvider = BookSourceListProvider._();

/// Every stored book source, in the order the list and the default pick share
/// (`BookSourceDao.findAll`: enabled first, then `customOrder`, then `id`).
///
/// `keepAlive` on purpose: the selection below watches it, so the list must not be re-read
/// (and the selection must not be lost) when the user walks from the reader back to the list.
/// Mutations invalidate it explicitly, so "fresh" is a decision rather than a side effect.

final class BookSourceListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredBookSource>>,
          List<StoredBookSource>,
          FutureOr<List<StoredBookSource>>
        >
    with
        $FutureModifier<List<StoredBookSource>>,
        $FutureProvider<List<StoredBookSource>> {
  /// Every stored book source, in the order the list and the default pick share
  /// (`BookSourceDao.findAll`: enabled first, then `customOrder`, then `id`).
  ///
  /// `keepAlive` on purpose: the selection below watches it, so the list must not be re-read
  /// (and the selection must not be lost) when the user walks from the reader back to the list.
  /// Mutations invalidate it explicitly, so "fresh" is a decision rather than a side effect.
  BookSourceListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceListHash();

  @$internal
  @override
  $FutureProviderElement<List<StoredBookSource>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredBookSource>> create(Ref ref) {
    return bookSourceList(ref);
  }
}

String _$bookSourceListHash() => r'463f718c9157a957ec27e02ee168172cd0d53ac6';

/// Which stored source the pages work with, and the only place that changes it.
///
/// The selection is a plain id in a private field, so a reload of the list (after an import, a
/// toggle or a delete) keeps the user's choice **and** re-resolves it: when the selected row is
/// gone the notifier falls back to the default source, because a dangling selection would leave
/// every page pointing at a source that no longer exists (`docs/dev/roadmap.md` 5.1).

@ProviderFor(SelectedBookSource)
final selectedBookSourceProvider = SelectedBookSourceProvider._();

/// Which stored source the pages work with, and the only place that changes it.
///
/// The selection is a plain id in a private field, so a reload of the list (after an import, a
/// toggle or a delete) keeps the user's choice **and** re-resolves it: when the selected row is
/// gone the notifier falls back to the default source, because a dangling selection would leave
/// every page pointing at a source that no longer exists (`docs/dev/roadmap.md` 5.1).
final class SelectedBookSourceProvider
    extends $AsyncNotifierProvider<SelectedBookSource, StoredBookSource?> {
  /// Which stored source the pages work with, and the only place that changes it.
  ///
  /// The selection is a plain id in a private field, so a reload of the list (after an import, a
  /// toggle or a delete) keeps the user's choice **and** re-resolves it: when the selected row is
  /// gone the notifier falls back to the default source, because a dangling selection would leave
  /// every page pointing at a source that no longer exists (`docs/dev/roadmap.md` 5.1).
  SelectedBookSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedBookSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedBookSourceHash();

  @$internal
  @override
  SelectedBookSource create() => SelectedBookSource();
}

String _$selectedBookSourceHash() =>
    r'97e165f20780e28a97b9b0e73192a358de77400d';

/// Which stored source the pages work with, and the only place that changes it.
///
/// The selection is a plain id in a private field, so a reload of the list (after an import, a
/// toggle or a delete) keeps the user's choice **and** re-resolves it: when the selected row is
/// gone the notifier falls back to the default source, because a dangling selection would leave
/// every page pointing at a source that no longer exists (`docs/dev/roadmap.md` 5.1).

abstract class _$SelectedBookSource extends $AsyncNotifier<StoredBookSource?> {
  FutureOr<StoredBookSource?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<StoredBookSource?>, StoredBookSource?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StoredBookSource?>, StoredBookSource?>,
              AsyncValue<StoredBookSource?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The book source the parsing pages work with (`docs/dev/roadmap.md` 2.5's seam, now filled by 5.1).
///
/// It stays a **synchronous** projection of [SelectedBookSource] so the four parsing pages keep
/// reading a `BookSource?`; only the pages that manage sources look at the load state.
/// `null` means "no usable source", which is what makes every page show its empty state instead
/// of requesting pages with an empty rule set.

@ProviderFor(currentBookSource)
final currentBookSourceProvider = CurrentBookSourceProvider._();

/// The book source the parsing pages work with (`docs/dev/roadmap.md` 2.5's seam, now filled by 5.1).
///
/// It stays a **synchronous** projection of [SelectedBookSource] so the four parsing pages keep
/// reading a `BookSource?`; only the pages that manage sources look at the load state.
/// `null` means "no usable source", which is what makes every page show its empty state instead
/// of requesting pages with an empty rule set.

final class CurrentBookSourceProvider
    extends $FunctionalProvider<BookSource?, BookSource?, BookSource?>
    with $Provider<BookSource?> {
  /// The book source the parsing pages work with (`docs/dev/roadmap.md` 2.5's seam, now filled by 5.1).
  ///
  /// It stays a **synchronous** projection of [SelectedBookSource] so the four parsing pages keep
  /// reading a `BookSource?`; only the pages that manage sources look at the load state.
  /// `null` means "no usable source", which is what makes every page show its empty state instead
  /// of requesting pages with an empty rule set.
  CurrentBookSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentBookSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentBookSourceHash();

  @$internal
  @override
  $ProviderElement<BookSource?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookSource? create(Ref ref) {
    return currentBookSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSource?>(value),
    );
  }
}

String _$currentBookSourceHash() => r'4b345d64ed2c08b87fe3b3c03b8262e517edcc49';
