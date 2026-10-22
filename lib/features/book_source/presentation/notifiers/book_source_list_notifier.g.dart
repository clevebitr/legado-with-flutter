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
    r'c4d9215f2882ee3f2175194120dbbf71e5a84067';

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

/// The list's own view state — sort key and group filter — and the only place that changes it
/// (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// `keepAlive` like the list itself: the choice survives walking to a source's debug console and
/// back, and the store write happens once per change rather than once per visit.

@ProviderFor(BookSourceView)
final bookSourceViewProvider = BookSourceViewProvider._();

/// The list's own view state — sort key and group filter — and the only place that changes it
/// (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// `keepAlive` like the list itself: the choice survives walking to a source's debug console and
/// back, and the store write happens once per change rather than once per visit.
final class BookSourceViewProvider
    extends $AsyncNotifierProvider<BookSourceView, BookSourceListView> {
  /// The list's own view state — sort key and group filter — and the only place that changes it
  /// (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
  ///
  /// `keepAlive` like the list itself: the choice survives walking to a source's debug console and
  /// back, and the store write happens once per change rather than once per visit.
  BookSourceViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceViewHash();

  @$internal
  @override
  BookSourceView create() => BookSourceView();
}

String _$bookSourceViewHash() => r'1ff826e9dab2cddcfda4a3c521c9fd077de0eccf';

/// The list's own view state — sort key and group filter — and the only place that changes it
/// (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// `keepAlive` like the list itself: the choice survives walking to a source's debug console and
/// back, and the store write happens once per change rather than once per visit.

abstract class _$BookSourceView extends $AsyncNotifier<BookSourceListView> {
  FutureOr<BookSourceListView> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<BookSourceListView>, BookSourceListView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BookSourceListView>, BookSourceListView>,
              AsyncValue<BookSourceListView>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What the list page renders: the rows after the filter, the groups they carry, and the view.
///
/// The group fallback lives **here** rather than in the store: whether a group still exists depends
/// on the rows, which the store cannot see. A stored filter that names a group nobody carries is
/// therefore dropped while rendering instead of being written back from a `build`
/// (ADR-0045 §决策 4).

@ProviderFor(bookSourceListData)
final bookSourceListDataProvider = BookSourceListDataProvider._();

/// What the list page renders: the rows after the filter, the groups they carry, and the view.
///
/// The group fallback lives **here** rather than in the store: whether a group still exists depends
/// on the rows, which the store cannot see. A stored filter that names a group nobody carries is
/// therefore dropped while rendering instead of being written back from a `build`
/// (ADR-0045 §决策 4).

final class BookSourceListDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookSourceListData>,
          BookSourceListData,
          FutureOr<BookSourceListData>
        >
    with
        $FutureModifier<BookSourceListData>,
        $FutureProvider<BookSourceListData> {
  /// What the list page renders: the rows after the filter, the groups they carry, and the view.
  ///
  /// The group fallback lives **here** rather than in the store: whether a group still exists depends
  /// on the rows, which the store cannot see. A stored filter that names a group nobody carries is
  /// therefore dropped while rendering instead of being written back from a `build`
  /// (ADR-0045 §决策 4).
  BookSourceListDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceListDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceListDataHash();

  @$internal
  @override
  $FutureProviderElement<BookSourceListData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookSourceListData> create(Ref ref) {
    return bookSourceListData(ref);
  }
}

String _$bookSourceListDataHash() =>
    r'157a28db61cad6680c99df520971a7dad5378fea';

/// The check-status axis of the list filter (session state, ADR-0050 §决策 1).
///
/// It is **not** persisted, unlike the sort key and the group: it describes "what I am looking at
/// right now" (usually "show me what broke"), and a stored value would silently hide sources on
/// the next launch.

@ProviderFor(BookSourceCheckFilterSelection)
final bookSourceCheckFilterSelectionProvider =
    BookSourceCheckFilterSelectionProvider._();

/// The check-status axis of the list filter (session state, ADR-0050 §决策 1).
///
/// It is **not** persisted, unlike the sort key and the group: it describes "what I am looking at
/// right now" (usually "show me what broke"), and a stored value would silently hide sources on
/// the next launch.
final class BookSourceCheckFilterSelectionProvider
    extends
        $NotifierProvider<
          BookSourceCheckFilterSelection,
          BookSourceCheckFilter
        > {
  /// The check-status axis of the list filter (session state, ADR-0050 §决策 1).
  ///
  /// It is **not** persisted, unlike the sort key and the group: it describes "what I am looking at
  /// right now" (usually "show me what broke"), and a stored value would silently hide sources on
  /// the next launch.
  BookSourceCheckFilterSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceCheckFilterSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceCheckFilterSelectionHash();

  @$internal
  @override
  BookSourceCheckFilterSelection create() => BookSourceCheckFilterSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceCheckFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceCheckFilter>(value),
    );
  }
}

String _$bookSourceCheckFilterSelectionHash() =>
    r'480163a0f83616a3e38d817f3d0c57ea18f765e2';

/// The check-status axis of the list filter (session state, ADR-0050 §决策 1).
///
/// It is **not** persisted, unlike the sort key and the group: it describes "what I am looking at
/// right now" (usually "show me what broke"), and a stored value would silently hide sources on
/// the next launch.

abstract class _$BookSourceCheckFilterSelection
    extends $Notifier<BookSourceCheckFilter> {
  BookSourceCheckFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BookSourceCheckFilter, BookSourceCheckFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookSourceCheckFilter, BookSourceCheckFilter>,
              BookSourceCheckFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
