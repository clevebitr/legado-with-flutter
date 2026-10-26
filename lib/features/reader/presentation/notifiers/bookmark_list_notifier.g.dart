// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every bookmark across books, newest first (`docs/dev/roadmap.md` M19).
///
/// The list is global (it is reached from 「我的」), so it neither knows which book is open nor
/// takes a key. Deleting a row reloads, which is what makes the list the stored truth instead of a
/// view of the page's hopes.

@ProviderFor(BookmarkList)
final bookmarkListProvider = BookmarkListProvider._();

/// Every bookmark across books, newest first (`docs/dev/roadmap.md` M19).
///
/// The list is global (it is reached from 「我的」), so it neither knows which book is open nor
/// takes a key. Deleting a row reloads, which is what makes the list the stored truth instead of a
/// view of the page's hopes.
final class BookmarkListProvider
    extends $AsyncNotifierProvider<BookmarkList, List<Bookmark>> {
  /// Every bookmark across books, newest first (`docs/dev/roadmap.md` M19).
  ///
  /// The list is global (it is reached from 「我的」), so it neither knows which book is open nor
  /// takes a key. Deleting a row reloads, which is what makes the list the stored truth instead of a
  /// view of the page's hopes.
  BookmarkListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkListHash();

  @$internal
  @override
  BookmarkList create() => BookmarkList();
}

String _$bookmarkListHash() => r'c53813358da95e16e51bed7341381929ad3d3aaa';

/// Every bookmark across books, newest first (`docs/dev/roadmap.md` M19).
///
/// The list is global (it is reached from 「我的」), so it neither knows which book is open nor
/// takes a key. Deleting a row reloads, which is what makes the list the stored truth instead of a
/// view of the page's hopes.

abstract class _$BookmarkList extends $AsyncNotifier<List<Bookmark>> {
  FutureOr<List<Bookmark>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Bookmark>>, List<Bookmark>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Bookmark>>, List<Bookmark>>,
              AsyncValue<List<Bookmark>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
