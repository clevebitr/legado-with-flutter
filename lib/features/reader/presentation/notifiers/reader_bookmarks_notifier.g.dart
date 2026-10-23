// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_bookmarks_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The bookmarks of the book that is open, and the toggle behind the toolbar button
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The list is watched by the reader so the icon can show whether the current position is marked;
/// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
/// disagreeing after a failed write.

@ProviderFor(ReaderBookmarks)
final readerBookmarksProvider = ReaderBookmarksFamily._();

/// The bookmarks of the book that is open, and the toggle behind the toolbar button
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The list is watched by the reader so the icon can show whether the current position is marked;
/// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
/// disagreeing after a failed write.
final class ReaderBookmarksProvider
    extends $AsyncNotifierProvider<ReaderBookmarks, List<Bookmark>> {
  /// The bookmarks of the book that is open, and the toggle behind the toolbar button
  /// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
  ///
  /// The list is watched by the reader so the icon can show whether the current position is marked;
  /// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
  /// disagreeing after a failed write.
  ReaderBookmarksProvider._({
    required ReaderBookmarksFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'readerBookmarksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerBookmarksHash();

  @override
  String toString() {
    return r'readerBookmarksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReaderBookmarks create() => ReaderBookmarks();

  @override
  bool operator ==(Object other) {
    return other is ReaderBookmarksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerBookmarksHash() => r'54b9d877f6aba4c5ffc1f0bd69e02716fc628163';

/// The bookmarks of the book that is open, and the toggle behind the toolbar button
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The list is watched by the reader so the icon can show whether the current position is marked;
/// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
/// disagreeing after a failed write.

final class ReaderBookmarksFamily extends $Family
    with
        $ClassFamilyOverride<
          ReaderBookmarks,
          AsyncValue<List<Bookmark>>,
          List<Bookmark>,
          FutureOr<List<Bookmark>>,
          ReaderBook
        > {
  ReaderBookmarksFamily._()
    : super(
        retry: null,
        name: r'readerBookmarksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The bookmarks of the book that is open, and the toggle behind the toolbar button
  /// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
  ///
  /// The list is watched by the reader so the icon can show whether the current position is marked;
  /// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
  /// disagreeing after a failed write.

  ReaderBookmarksProvider call(ReaderBook book) =>
      ReaderBookmarksProvider._(argument: book, from: this);

  @override
  String toString() => r'readerBookmarksProvider';
}

/// The bookmarks of the book that is open, and the toggle behind the toolbar button
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 3).
///
/// The list is watched by the reader so the icon can show whether the current position is marked;
/// the **toggle** reloads after every write, which is what keeps the icon and the stored rows from
/// disagreeing after a failed write.

abstract class _$ReaderBookmarks extends $AsyncNotifier<List<Bookmark>> {
  late final _$args = ref.$arg as ReaderBook;
  ReaderBook get book => _$args;

  FutureOr<List<Bookmark>> build(ReaderBook book);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
