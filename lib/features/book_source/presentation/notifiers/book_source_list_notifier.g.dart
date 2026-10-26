// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every stored book source, in the order the list and the default pick share.
///
/// Kept alive so the selection below survives page navigation.

@ProviderFor(bookSourceList)
final bookSourceListProvider = BookSourceListProvider._();

/// Every stored book source, in the order the list and the default pick share.
///
/// Kept alive so the selection below survives page navigation.

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
  /// Every stored book source, in the order the list and the default pick share.
  ///
  /// Kept alive so the selection below survives page navigation.
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

/// The stored source the pages work with; the only place that changes it.
///
/// When the selected row disappears, the selection falls back to the default source.

@ProviderFor(SelectedBookSource)
final selectedBookSourceProvider = SelectedBookSourceProvider._();

/// The stored source the pages work with; the only place that changes it.
///
/// When the selected row disappears, the selection falls back to the default source.
final class SelectedBookSourceProvider
    extends $AsyncNotifierProvider<SelectedBookSource, StoredBookSource?> {
  /// The stored source the pages work with; the only place that changes it.
  ///
  /// When the selected row disappears, the selection falls back to the default source.
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

/// The stored source the pages work with; the only place that changes it.
///
/// When the selected row disappears, the selection falls back to the default source.

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

/// The book source the parsing pages work with; `null` when none is usable.

@ProviderFor(currentBookSource)
final currentBookSourceProvider = CurrentBookSourceProvider._();

/// The book source the parsing pages work with; `null` when none is usable.

final class CurrentBookSourceProvider
    extends $FunctionalProvider<BookSource?, BookSource?, BookSource?>
    with $Provider<BookSource?> {
  /// The book source the parsing pages work with; `null` when none is usable.
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

/// The list's sort key and group filter; the only place that changes them.

@ProviderFor(BookSourceView)
final bookSourceViewProvider = BookSourceViewProvider._();

/// The list's sort key and group filter; the only place that changes them.
final class BookSourceViewProvider
    extends $AsyncNotifierProvider<BookSourceView, BookSourceListView> {
  /// The list's sort key and group filter; the only place that changes them.
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

/// The list's sort key and group filter; the only place that changes them.

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

/// What the list page renders: the rows after filtering, the groups and the view.
///
/// A stored group filter that no longer exists is dropped while rendering, not written back.

@ProviderFor(bookSourceListData)
final bookSourceListDataProvider = BookSourceListDataProvider._();

/// What the list page renders: the rows after filtering, the groups and the view.
///
/// A stored group filter that no longer exists is dropped while rendering, not written back.

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
  /// What the list page renders: the rows after filtering, the groups and the view.
  ///
  /// A stored group filter that no longer exists is dropped while rendering, not written back.
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

/// The check-status axis of the list filter; session state, not persisted.

@ProviderFor(BookSourceCheckFilterSelection)
final bookSourceCheckFilterSelectionProvider =
    BookSourceCheckFilterSelectionProvider._();

/// The check-status axis of the list filter; session state, not persisted.
final class BookSourceCheckFilterSelectionProvider
    extends
        $NotifierProvider<
          BookSourceCheckFilterSelection,
          BookSourceCheckFilter
        > {
  /// The check-status axis of the list filter; session state, not persisted.
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

/// The check-status axis of the list filter; session state, not persisted.

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
