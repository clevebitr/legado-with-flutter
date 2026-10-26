// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the shelf persistence (`docs/dev/roadmap.md` 5.4).
///
/// The composition root's `BookshelfWriter` adapter is the only consumer outside this feature;
/// the reader (5.3) will write progress through its own port, so this provider stays feature
/// internal (C-ARCH-2).

@ProviderFor(bookshelfRepository)
final bookshelfRepositoryProvider = BookshelfRepositoryProvider._();

/// Provides the shelf persistence (`docs/dev/roadmap.md` 5.4).
///
/// The composition root's `BookshelfWriter` adapter is the only consumer outside this feature;
/// the reader (5.3) will write progress through its own port, so this provider stays feature
/// internal (C-ARCH-2).

final class BookshelfRepositoryProvider
    extends
        $FunctionalProvider<
          BookshelfRepository,
          BookshelfRepository,
          BookshelfRepository
        >
    with $Provider<BookshelfRepository> {
  /// Provides the shelf persistence (`docs/dev/roadmap.md` 5.4).
  ///
  /// The composition root's `BookshelfWriter` adapter is the only consumer outside this feature;
  /// the reader (5.3) will write progress through its own port, so this provider stays feature
  /// internal (C-ARCH-2).
  BookshelfRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookshelfRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookshelfRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookshelfRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookshelfRepository create(Ref ref) {
    return bookshelfRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookshelfRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookshelfRepository>(value),
    );
  }
}

String _$bookshelfRepositoryHash() =>
    r'bbd099b027e738d1eec40b8db3fb7d19df0ade6d';
